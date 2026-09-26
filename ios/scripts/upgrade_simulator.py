#!/usr/bin/env python3
"""In-place synthetic 1.1.7 -> 2.0 validation on a NEW disposable simulator.

No production launch, signing, network service, purchase, or owner data access.
The old source is instrumented only in an ignored temporary output directory.
"""
import argparse
import base64
import datetime as dt
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tarfile
import time
import uuid

REPO = Path(__file__).resolve().parents[2]
BUNDLE = "com.whowouldin.WhoWouldWin.uitesting"
BASELINE = "107bf7327f1c82e85282101e2294fb6f9ded3639"


def run(*args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-app", type=Path, required=True)
    parser.add_argument("--source-packages", type=Path, help="Existing resolved package cache to reuse")
    parser.add_argument("--reuse-baseline-run", type=Path, help="Reuse this tool's already-built identical fixture host")
    args = parser.parse_args()
    app = args.candidate_app.resolve()
    info = plistlib.loads((app / "Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == BUNDLE, "Only the isolated Testing app is allowed"
    assert info["AVAIsolatedTestBuild"] == "YES", "Candidate must block external services"
    assert info["CFBundleShortVersionString"] == "2.0", "Expected 2.0 candidate"
    sections = run("xcrun", "otool", "-s", "__TEXT", "__entitlements", str(app / info["CFBundleExecutable"]))
    assert len(sections.splitlines()) > 2, "Build Testing with CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- so simulator Keychain works"
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = REPO / "ios/build/runs" / f"{stamp}-upgrade-{uuid.uuid4().hex[:6]}"
    output.mkdir(parents=True)
    print(f"Upgrade evidence: {output}", flush=True)
    source = output / "baseline-source"
    source.mkdir()
    archive = output / "baseline.tar"
    with archive.open("wb") as stream:
        subprocess.run(["git", "archive", BASELINE, "ios"], cwd=REPO, stdout=stream, check=True)
    with tarfile.open(archive) as stream:
        # The host's system Python may predate tarfile's extraction filters.
        # Accept only regular files/directories from the fixed git commit.
        for member in stream.getmembers():
            assert not Path(member.name).is_absolute() and ".." not in Path(member.name).parts
            assert member.isfile() or member.isdir(), "Unexpected link/special file in baseline archive"
        stream.extractall(source)

    # Reuse the exact observer compiled into the candidate. It only reads stores
    # and verifies a known synthetic PIN; its multiple guards exclude owner data.
    config = (REPO / "ios/WhoWouldWin/App/AppConfig.swift").read_text()
    observer = config[config.index("enum UpgradeFixtureAudit {"):].split("\n#endif", 1)[0]
    fixtures = REPO / "ios/scripts/fixtures/1.1.7"
    encoded = base64.b64encode((fixtures / "progress-1.1.7.plist").read_bytes()).decode()
    pending = base64.b64encode((fixtures / "tournament-pending-1.1.7.json").read_bytes()).decode()
    legacy_host = '''import SwiftUI
import Foundation

@main
struct WhoWouldWinApp: App {
    init() {
        URLProtocol.registerClass(LegacyUpgradeNetworkBlocker.self)
        guard Bundle.main.bundleIdentifier == "com.whowouldin.WhoWouldWin.uitesting" else {
            fatalError("Fixture host requires isolated bundle identity")
        }
        if ProcessInfo.processInfo.environment["AVA_SEED_UPGRADE_FIXTURE"] == "1" {
            let ud = UserDefaults.standard
            let data = Data(base64Encoded: "__PREFERENCES__")!
            var values = try! PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
            if ProcessInfo.processInfo.environment["AVA_UPGRADE_CASE"] == "pending" {
                values["tournament.active"] = Data(base64Encoded: "__PENDING__")!
            }
            values["qa.upgradeFixture"] = "synthetic-1.1.7"
            ud.setPersistentDomain(values, forName: Bundle.main.bundleIdentifier!)
            ParentalPIN.setPIN("2479")
        }
        UpgradeFixtureAudit.captureIfRequested()
        // The observer initializes the original stores, which may themselves
        // write preferences. Do not signal readiness until those writes flush.
        precondition(UserDefaults.standard.synchronize())
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try! Data("baseline-flushed".utf8).write(to: documents.appendingPathComponent("upgrade-baseline-ready"), options: .atomic)
    }
    var body: some Scene {
        WindowGroup { Text("Synthetic 1.1.7 upgrade fixture — external services disabled") }
    }
}

private final class LegacyUpgradeNetworkBlocker: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}

'''.replace("__PREFERENCES__", encoded).replace("__PENDING__", pending) + observer + "\n"
    (source / "ios/WhoWouldWin/App/WhoWouldWinApp.swift").write_text(legacy_host)
    command = ["xcodebuild", "-project", str(source / "ios/WhoWouldWin.xcodeproj"),
               "-scheme", "WhoWouldWin", "-configuration", "Debug", "-sdk", "iphonesimulator",
               "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", str(output / "DerivedData"),
               "-disableAutomaticPackageResolution", "-onlyUsePackageVersionsFromResolvedFile",
               f"PRODUCT_BUNDLE_IDENTIFIER={BUNDLE}", "CODE_SIGNING_ALLOWED=YES", "CODE_SIGN_IDENTITY=-", "build"]
    if args.source_packages:
        command[1:1] = ["-clonedSourcePackagesDirPath", str(args.source_packages.resolve())]
    (output / "baseline-build-command.json").write_text(json.dumps(command, indent=2) + "\n")
    if args.reuse_baseline_run:
        previous = args.reuse_baseline_run.resolve()
        assert (previous / "baseline-source/ios/WhoWouldWin/App/WhoWouldWinApp.swift").read_text() == legacy_host, "Cached fixture host differs from current synthetic inputs"
        baseline_app = previous / "DerivedData/Build/Products/Debug-iphonesimulator/WhoWouldWin.app"
        (output / "baseline-reuse.json").write_text(json.dumps({"run": str(previous), "fixtureSourceIdentical": True}, indent=2) + "\n")
    else:
        with (output / "baseline-build.log").open("w") as stream:
            subprocess.run(command, cwd=REPO, stdout=stream, stderr=subprocess.STDOUT, check=True)
        baseline_app = output / "DerivedData/Build/Products/Debug-iphonesimulator/WhoWouldWin.app"
    listing = json.loads(run("xcrun", "simctl", "list", "-j"))
    runtime = max((r for r in listing["runtimes"] if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")),
                  key=lambda r: tuple(map(int, r["version"].split("."))))
    device = run("xcrun", "simctl", "create", f"AvA disposable upgrade {uuid.uuid4().hex[:8]}",
                 "com.apple.CoreSimulator.SimDeviceType.iPhone-17", runtime["identifier"])
    report = {"baselineCommit": BASELINE, "candidateApp": str(app), "candidateVersion": info["CFBundleShortVersionString"],
              "candidateBuild": info["CFBundleVersion"], "device": device, "runtime": runtime["identifier"],
              "instrumentation": "Archived baseline app entry point replaced with isolated synthetic fixture host; persistence services/models unchanged. Xcode Sign to Run Locally embeds simulator entitlements; no distribution signing/profile/account request.",
              "limitations": ["Simulator, not physical App Store/TestFlight upgrade", "No receipt, purchase, iCloud, or live service verification"], "cases": []}
    (output / "upgrade-report.json").write_text(json.dumps(report, indent=2) + "\n")
    try:
        run("xcrun", "simctl", "boot", device)
        run("xcrun", "simctl", "bootstatus", device, "-b")
        for scenario in ("settled", "pending"):
            case_dir = output / scenario
            case_dir.mkdir()
            run("xcrun", "simctl", "install", device, str(baseline_app))
            container = Path(run("xcrun", "simctl", "get_app_container", device, BUNDLE, "data"))
            clear_snapshots(container)
            environment = os.environ.copy()
            for key in list(environment):
                if key.startswith("SIMCTL_CHILD_AVA_"):
                    environment.pop(key)
            environment.update({"SIMCTL_CHILD_AVA_CAPTURE_UPGRADE_STATE": "1", "SIMCTL_CHILD_AVA_SEED_UPGRADE_FIXTURE": "1",
                                "SIMCTL_CHILD_AVA_UPGRADE_CASE": scenario})
            run("xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE, env=environment)
            before = snapshot(container, case_dir, "before")
            assert before["version"] == "1.1.7" and before["balance"] == 1234
            assert before["syntheticPinVerifies"] and before["hasResumableTournament"]
            before_preferences = plistlib.loads((case_dir / "before-preferences.plist").read_bytes())
            verify_durable_preferences(container, before_preferences, case_dir / "baseline-durable-preferences.plist")
            run("xcrun", "simctl", "terminate", device, BUNDLE)
            clear_snapshots(container)
            environment.pop("SIMCTL_CHILD_AVA_SEED_UPGRADE_FIXTURE")
            run("xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE, env=environment)
            cold = snapshot(container, case_dir, "baseline-cold")
            assert cold == before, "Baseline could not reload its own complete fixture/PIN after a cold launch"
            verify_durable_preferences(container, before_preferences, case_dir / "baseline-cold-durable-preferences.plist")
            run("xcrun", "simctl", "terminate", device, BUNDLE)
            sentinel = uuid.uuid4().hex
            (container / "Documents/upgrade-data-sentinel").write_text(sentinel)
            clear_snapshots(container)
            run("xcrun", "simctl", "install", device, str(app))
            after_container = Path(run("xcrun", "simctl", "get_app_container", device, BUNDLE, "data"))
            # iOS may relocate the data directory while preserving its contents.
            # Verify retained state, not the allocator's UUID/path.
            assert (after_container / "Documents/upgrade-data-sentinel").read_text() == sentinel, "Documents contents were not retained"
            verify_durable_preferences(after_container, before_preferences, case_dir / "installed-durable-preferences.plist", require_ready=False)
            environment.update({"SIMCTL_CHILD_AVA_UI_TESTING": "1", "SIMCTL_CHILD_AVA_BLOCK_EXTERNAL_SERVICES": "1"})
            run("xcrun", "simctl", "launch", "--terminate-running-process", device, BUNDLE, "--uitesting", env=environment)
            after = snapshot(after_container, case_dir, "after")
            run("xcrun", "simctl", "io", device, "screenshot", str(case_dir / "candidate-home.png"))
            assert after.pop("version") == "2.0"
            before.pop("version")
            assert before == after, f"Loaded service state changed during {scenario} upgrade"
            after_preferences = plistlib.loads((case_dir / "after-preferences.plist").read_bytes())
            for key, value in before_preferences.items():
                assert after_preferences.get(key) == value, f"Preference changed during upgrade: {key}"
            report["cases"].append({"scenario": scenario, "loadedStatePreserved": True, "preferencesPreserved": True,
                                    "keychainPINPreserved": True, "baselineColdLaunchPassed": True,
                                    "documentsPreserved": True, "dataContainerRelocated": after_container != container,
                                    "status": "passed"})
            print(f"Passed {scenario}: preferences, loaded stores, custom entrant, wager/result guards, keychain PIN", flush=True)
            run("xcrun", "simctl", "terminate", device, BUNDLE)
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["failure"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        subprocess.run(["xcrun", "simctl", "shutdown", device], capture_output=True)
        report["completedAt"] = dt.datetime.now(dt.timezone.utc).isoformat()
        (output / "upgrade-report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(f"Dedicated simulator retained shutdown: {device}", flush=True)


def snapshot(container, output, prefix):
    state = container / "Documents/upgrade-state.json"
    preferences = container / "Documents/upgrade-preferences.plist"
    deadline = time.monotonic() + 20
    while not (state.exists() and preferences.exists()):
        if time.monotonic() >= deadline:
            raise TimeoutError("Fixture app did not write its marked synthetic upgrade snapshot")
        time.sleep(0.2)
    content = state.read_bytes()
    (output / f"{prefix}-state.json").write_bytes(content)
    (output / f"{prefix}-preferences.plist").write_bytes(preferences.read_bytes())
    return json.loads(content)


def clear_snapshots(container):
    for name in ("upgrade-state.json", "upgrade-preferences.plist", "upgrade-baseline-ready"):
        (container / "Documents" / name).unlink(missing_ok=True)


def verify_durable_preferences(container, expected, destination, require_ready=True):
    """Observe actual old-app disk state; never write/repair candidate data."""
    preferences = container / "Library/Preferences" / f"{BUNDLE}.plist"
    deadline = time.monotonic() + 20
    while True:
        ready = not require_ready or (container / "Documents/upgrade-baseline-ready").exists()
        try:
            actual = plistlib.loads(preferences.read_bytes())
            retained = all(actual.get(key) == value for key, value in expected.items())
        except (FileNotFoundError, plistlib.InvalidFileException):
            retained = False
        if ready and retained:
            shutil.copyfile(preferences, destination)
            return
        if time.monotonic() >= deadline:
            raise AssertionError("Baseline fixture preferences were not durable; refusing to test an invalid starting state")
        time.sleep(0.2)


if __name__ == "__main__":
    main()
