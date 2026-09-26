#!/usr/bin/env bash
# Compatibility entry point. Local validation only; never uploads or bumps builds.
set -euo pipefail
AVA_IOS_ROOT="$(cd "$(dirname "$0")" && pwd)"
if [ "$#" -eq 0 ]; then
  echo 'The old automatic upload flow has been replaced with explicit local stages.'
  echo 'Usage: ./deploy.sh preflight | build | test | archive --qa-record /path/to/qa.json'
  echo 'No action here uploads to App Store Connect. See scripts/README.md.'
  exit 0
fi
exec python3 "$AVA_IOS_ROOT/scripts/release.py" "$@"
