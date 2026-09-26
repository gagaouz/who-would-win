#!/usr/bin/env python3
"""Read-only ASC build/group audit. Never prints authentication or tester PII."""
import argparse
import base64
import datetime as dt
import json
from pathlib import Path
import re
import time
import urllib.error
import urllib.parse
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credential-config", type=Path, required=True,
                        help="Existing trusted deployment script containing ASC_KEY_ID and ASC_ISSUER_ID")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = args.credential_config.read_text()
    key_id = re.search(r'^ASC_KEY_ID="([A-Z0-9]+)"$', source, re.M).group(1)
    issuer = re.search(r'^ASC_ISSUER_ID="([a-f0-9-]+)"$', source, re.M).group(1)
    key_path = Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{key_id}.p8"
    signing_key = serialization.load_pem_private_key(key_path.read_bytes(), password=None)
    now = int(time.time())
    message = b".".join([b64(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode()),
                          b64(json.dumps({"iss": issuer, "iat": now, "exp": now + 600,
                                          "aud": "appstoreconnect-v1"}).encode())])
    r, s = decode_dss_signature(signing_key.sign(message, ec.ECDSA(hashes.SHA256())))
    token = (message + b"." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode()

    def get(path, **query):
        url = "https://api.appstoreconnect.apple.com/v1/" + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            return {"unavailable": True, "httpStatus": error.code}

    report = {"checkedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
              "readOnly": True, "authenticationMaterialIncluded": False}
    apps = get("apps", **{"filter[bundleId]": "com.whowouldin.WhoWouldWin"})
    if apps.get("unavailable") or not apps.get("data"):
        report["appLookup"] = {"available": False, "httpStatus": apps.get("httpStatus")}
    else:
        app = apps["data"][0]
        app_id = app["id"]
        report["app"] = {key: app["attributes"].get(key) for key in ("name", "bundleId")}
        report["app"]["id"] = app_id
        builds = get("builds", **{"filter[app]": app_id, "sort": "-uploadedDate", "limit": 200, "include": "preReleaseVersion"})
        versions = {item["id"]: item["attributes"].get("version") for item in builds.get("included", []) if item["type"] == "preReleaseVersions"}
        report["builds"] = []
        for build in builds.get("data", []):
            attrs = build["attributes"]
            version_id = (build.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}).get("id")
            report["builds"].append({"id": build["id"], "marketingVersion": versions.get(version_id),
                                     **{key: attrs.get(key) for key in ("version", "uploadedDate", "processingState", "expired", "expirationDate")}})
        report["buildHistoryComplete"] = not bool(builds.get("links", {}).get("next")) and not builds.get("unavailable", False)
        report["buildLookupHTTPStatus"] = builds.get("httpStatus", 200)
        released = get(f"apps/{app_id}/appStoreVersions", limit=20)
        report["appStoreVersions"] = [{key: item["attributes"].get(key) for key in ("versionString", "appStoreState", "platform")} for item in released.get("data", [])]
        groups = get(f"apps/{app_id}/betaGroups", limit=100)
        report["groups"] = []
        for group in groups.get("data", []):
            attrs = group["attributes"]
            members = get(f"betaGroups/{group['id']}/betaTesters", limit=1)
            report["groups"].append({"id": group["id"], **{key: attrs.get(key) for key in ("name", "isInternalGroup", "hasAccessToAllBuilds", "publicLinkEnabled")},
                                      "testerCount": members.get("meta", {}).get("paging", {}).get("total"),
                                      "testerLookupHTTPStatus": members.get("httpStatus", 200)})
        report["groupLookupHTTPStatus"] = groups.get("httpStatus", 200)
        report["unknowns"] = ["Owner's exact membership and installation access were not individually inspected",
                              "No developer membership or agreements acceptance check",
                              "No new build upload, assignment, review request, or tester invitation"]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    summary = {key: value for key, value in report.items() if key not in {"builds", "appStoreVersions"}}
    summary["buildCount"] = len(report.get("builds", []))
    summary["latestBuilds"] = report.get("builds", [])[:3]
    summary["latestAppStoreVersion"] = report.get("appStoreVersions", [])[:1]
    summary["fullEvidence"] = str(args.output)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
