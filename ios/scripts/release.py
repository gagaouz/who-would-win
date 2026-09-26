#!/usr/bin/env python3
"""Reproducible local build/test/archive tooling. This program NEVER uploads."""

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import uuid

IOS = Path(__file__).resolve().parents[1]
REPO = IOS.parent
CANONICAL_BUNDLE = "com.whowouldin.WhoWouldWin"
PROJECT = IOS / "WhoWouldWin.xcodeproj"


def capture(*args):
    return subprocess.check_output(args, cwd=REPO, text=True).strip()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def version_settings():
    text = (IOS / "config/Version.xcconfig").read_text()
    values = dict(re.findall(r"^([A-Z_]+)\s*=\s*([^\n]+)", text, re.M))
    require(re.fullmatch(r"\d+\.\d+(?:\.\d+)?", values.get("MARKETING_VERSION", "")),
            "Invalid MARKETING_VERSION in config/Version.xcconfig")
    require(re.fullmatch(r"[1-9]\d*", values.get("CURRENT_PROJECT_VERSION", "")),
            "CURRENT_PROJECT_VERSION must be a positive integer")
    return values


def validate_source(distribution=False):
    values = version_settings()
    with (IOS / "WhoWouldWin/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    require(info["CFBundleShortVersionString"] == "$(MARKETING_VERSION)",
            "Info.plist must reference MARKETING_VERSION, not duplicate a literal")
    require(info["CFBundleVersion"] == "$(CURRENT_PROJECT_VERSION)",
            "Info.plist must reference CURRENT_PROJECT_VERSION")
    spec = (IOS / "project.yml").read_text()
    for expected in ('CFBundleShortVersionString: "$(MARKETING_VERSION)"',
                     'CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"'):
        require(expected in spec, f"Generator does not preserve {expected}")
    scheme = PROJECT / "xcshareddata/xcschemes/WhoWouldWin.xcscheme"
    require(scheme.is_file(), "Missing shared scheme; coordinate one xcodegen generate after new files exist")
    require('buildConfiguration = "Testing"' in scheme.read_text()
            or 'buildConfiguration="Testing"' in scheme.read_text(),
            "Shared scheme test action must use the isolated Testing configuration")
    pins = json.loads((PROJECT / "project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())
    expected_pins = {"swift-package-manager-google-mobile-ads": "13.9.0",
                     "swift-package-manager-google-user-messaging-platform": "3.1.0"}
    require({pin["identity"]: pin["state"]["version"] for pin in pins["pins"]} == expected_pins,
            "Swift package pins changed; review dependencies before proceeding")
    if distribution:
        asset_validator = REPO / "tools/retro/validate_assets.py"
        require(asset_validator.is_file(), "Missing complete-roster asset validator")
        subprocess.run([sys.executable, str(asset_validator), "--require-complete"], cwd=REPO, check=True)
        require(values.get("AVA_BUILD_ALLOCATION") == "confirmed",
                "Build number remains provisional: check ASC history/maintenance ledger before confirming allocation")
        record_path = IOS / "config/BuildAllocation.json"
        require(record_path.is_file(), "Missing config/BuildAllocation.json recording ASC verification")
        record = json.loads(record_path.read_text())
        require(str(record.get("build")) == values["CURRENT_PROJECT_VERSION"]
                and record.get("version") == values["MARKETING_VERSION"],
                "ASC allocation record does not match Version.xcconfig")
        require(record.get("ascVerifiedAt") and record.get("evidence"),
                "ASC allocation record needs ascVerifiedAt and an evidence reference")
        require(not capture("git", "status", "--porcelain", "--untracked-files=normal"),
                "Archive requires a clean reviewed worktree; preserve/stage only intended changes")
        require(capture("git", "branch", "--show-current") in {"develop/2.0", "release/2.0"},
                "Canonical 2.0 archive must originate from the 2.0 development/release line")
    return values


def new_run(action, values):
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    commit = capture("git", "rev-parse", "HEAD")
    name = f"{stamp}-{action}-{values['MARKETING_VERSION']}-{values['CURRENT_PROJECT_VERSION']}-{commit[:8]}-{uuid.uuid4().hex[:6]}"
    output = IOS / "build/runs" / name
    output.mkdir(parents=True)
    metadata = {"action": action, "version": values["MARKETING_VERSION"],
                "build": values["CURRENT_PROJECT_VERSION"], "commit": commit,
                "allocation": values.get("AVA_BUILD_ALLOCATION"), "startedAt": stamp,
                "dirty": bool(capture("git", "status", "--porcelain")),
                "xcode": capture("xcodebuild", "-version"), "status": "running"}
    (output / "run.json").write_text(json.dumps(metadata, indent=2) + "\n")
    return output, metadata


def execute(command, output, metadata):
    metadata["command"] = command
    print(f"Running {metadata['action']}; full output: {output / 'xcodebuild.log'}", flush=True)
    environment = os.environ.copy()
    if metadata["action"] == "test":
        environment["AVA_BLOCK_EXTERNAL_SERVICES"] = "1"
    with (output / "xcodebuild.log").open("w") as log:
        result = subprocess.run(command, cwd=IOS, stdout=log, stderr=subprocess.STDOUT, env=environment)
    metadata.update(status="passed" if result.returncode == 0 else "failed", exitCode=result.returncode)
    (output / "run.json").write_text(json.dumps(metadata, indent=2) + "\n")
    if result.returncode:
        print("\n".join((output / "xcodebuild.log").read_text(errors="replace").splitlines()[-35:]))
        raise ValueError(f"xcodebuild failed; retain {output} for diagnosis")
    print(f"Passed: {output}")


def isolated_simulator():
    listing = json.loads(capture("xcrun", "simctl", "list", "-j"))
    runtimes = [r for r in listing["runtimes"] if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]
    require(runtimes, "No available iOS Simulator runtime")
    runtime = max(runtimes, key=lambda r: tuple(map(int, r["version"].split("."))))
    phones = [d for d in listing["devicetypes"] if d["name"].startswith("iPhone")]
    preferred = next((d for d in phones if d["name"] == "iPhone 17"), phones[-1] if phones else None)
    require(preferred, "No iPhone simulator device type")
    identifier = capture("xcrun", "simctl", "create", f"AvA v2 QA {uuid.uuid4().hex[:8]}", preferred["identifier"], runtime["identifier"])
    return identifier


def validate_qa(path):
    require(path and path.is_file(), "Archive requires --qa-record containing completed candidate evidence")
    record = json.loads(path.read_text())
    require(record.get("sourceCommit") == capture("git", "rev-parse", "HEAD"), "QA record sourceCommit is not HEAD")
    require(record.get("distributionScope") == "internal-testflight",
            "This candidate workflow is scoped to owner internal TestFlight, not public/external distribution")
    for key in ("requiredChecksPassed", "featureParityPassed", "upgradePassed",
                "localCustomArtworkPassed", "backendCompatibilityPassed"):
        require(record.get(key) is True, f"QA gate not passed: {key}")
    require(record.get("physicalDeviceStatus") in {"passed", "pending-owner-testflight"},
            "Record actual physical-device status; do not imply unperformed checks passed")
    if record.get("physicalDeviceStatus") == "pending-owner-testflight":
        checks = record.get("ownerDeviceChecks")
        require(isinstance(checks, list) and checks and all(isinstance(item, str) and item.strip() for item in checks),
                "Internal beta awaiting hardware QA needs explicit ownerDeviceChecks")
    require(record.get("blockingDefects") == 0, "QA record must state zero blocking defects")
    require(record.get("evidence"), "QA record must link verification evidence")


def inspect_archive(path, expected=None):
    apps = list((path / "Products/Applications").glob("*.app"))
    require(len(apps) == 1, "Archive must contain exactly one application")
    with (apps[0] / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    expected = expected or version_settings()
    require(info["CFBundleIdentifier"] == CANONICAL_BUNDLE, "Archive has incorrect bundle identity")
    require(info["CFBundleShortVersionString"] == expected["MARKETING_VERSION"], "Archive version differs from source")
    require(info["CFBundleVersion"] == expected["CURRENT_PROJECT_VERSION"], "Archive build differs from source")
    require(info.get("AVAEnvironment") == "production", "Archive is not production configured")
    require(info.get("AVAAPIBaseURL") == "https://api.animal-vs-animal.com", "Unexpected archive API URL")
    require(info.get("AVAIsolatedTestBuild") == "NO", "Testing build cannot be distributed")
    require(info.get("AVABuildAllocation") == "confirmed", "Archive build allocation is unconfirmed")
    require((apps[0] / "PrivacyInfo.xcprivacy").is_file(), "Privacy manifest absent from application")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(apps[0])], check=True)
    entitlements = subprocess.run(["codesign", "--display", "--entitlements", ":-", str(apps[0])], capture_output=True, check=True)
    signed = plistlib.loads(entitlements.stdout)
    require(signed.get("com.apple.developer.devicecheck.appattest-environment") == "production", "App Attest environment is not production")
    require(signed.get("com.apple.developer.game-center") is True, "Game Center entitlement absent")
    require(signed.get("com.apple.developer.ubiquity-kvstore-identifier", "").endswith(CANONICAL_BUNDLE), "iCloud identity changed")
    require(list((path / "dSYMs").glob("*.dSYM")), "Archive has no symbols")
    print(json.dumps({"archive": str(path), "version": info["CFBundleShortVersionString"],
                      "build": info["CFBundleVersion"], "bundle": info["CFBundleIdentifier"],
                      "status": "local archive checks passed; not uploaded"}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["preflight", "build", "test", "archive", "inspect-archive"])
    parser.add_argument("--distribution", action="store_true", help="Require confirmed ASC allocation and clean release source")
    parser.add_argument("--device", help="Existing simulator UDID; default creates a separate QA simulator")
    parser.add_argument("--only-testing", action="append", default=[], help="XCTest target or target/class/method; repeatable")
    parser.add_argument("--qa-record", type=Path)
    parser.add_argument("--archive-path", type=Path, help="Existing archive to inspect")
    parser.add_argument("--allow-provisioning-updates", action="store_true", help="Explicitly permit Xcode provisioning during archive")
    args = parser.parse_args()
    values = validate_source(distribution=args.distribution or args.action == "archive")
    if args.action == "preflight":
        print(json.dumps({"version": values["MARKETING_VERSION"], "build": values["CURRENT_PROJECT_VERSION"],
                          "allocation": values["AVA_BUILD_ALLOCATION"], "sourceChecks": "passed", "asc": "not queried"}, indent=2))
        return
    if args.action == "inspect-archive":
        require(args.archive_path, "Provide --archive-path")
        inspect_archive(args.archive_path)
        return
    if args.action == "archive":
        validate_qa(args.qa_record)
    output, metadata = new_run(args.action, values)
    command = ["xcodebuild", "-project", str(PROJECT), "-scheme", "WhoWouldWin",
               "-derivedDataPath", str(output / "DerivedData"), "-disableAutomaticPackageResolution",
               "-onlyUsePackageVersionsFromResolvedFile"]
    created_device = None
    try:
        if args.action == "build":
            command += ["-configuration", "Debug", "-sdk", "iphonesimulator", "-destination", "generic/platform=iOS Simulator", "CODE_SIGNING_ALLOWED=YES", "CODE_SIGN_IDENTITY=-", "build"]
        elif args.action == "test":
            device = args.device or isolated_simulator()
            if not args.device:
                created_device = device
            metadata["simulator"] = device
            command += ["-configuration", "Testing", "-destination", f"platform=iOS Simulator,id={device}",
                        "-parallel-testing-enabled", "NO", "-resultBundlePath", str(output / "Tests.xcresult"),
                        "CODE_SIGNING_ALLOWED=YES", "CODE_SIGN_IDENTITY=-"]
            command += [f"-only-testing:{target}" for target in args.only_testing]
            command += ["test"]
        else:
            command += ["-configuration", "Release", "-destination", "generic/platform=iOS", "-archivePath", str(output / "WhoWouldWin.xcarchive")]
            if args.allow_provisioning_updates:
                command += ["-allowProvisioningUpdates"]
            command += ["archive"]
        execute(command, output, metadata)
        if args.action == "archive":
            inspect_archive(output / "WhoWouldWin.xcarchive", values)
    finally:
        if created_device:
            subprocess.run(["xcrun", "simctl", "shutdown", created_device], capture_output=True)
            # Retain device state for inspection; never erase a user's device.
            print(f"Dedicated QA simulator retained (shutdown): {created_device}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, subprocess.CalledProcessError, KeyError, OSError, json.JSONDecodeError) as error:
        print(f"Release tooling stopped: {error}", file=sys.stderr)
        sys.exit(1)
