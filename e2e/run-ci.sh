#!/usr/bin/env bash
# CI entrypoint for the E2E specs: start the Appium server (the UiAutomator2
# driver lives under ./.appium), wait for it to come up, run the WebdriverIO
# specs, then stop it. Kept as a file rather than an inline `script:` because
# android-emulator-runner mangles multi-line inline shell (the for-loop is split
# and `sh -c` sees `for … do` with no `done`).
set -o pipefail
cd "$(dirname "$0")"

APPIUM_HOME="$PWD/.appium" npx appium --base-path / --log-timestamp > appium.log 2>&1 &
appium_pid=$!

# Wait up to ~60s for the server to accept connections.
for _ in $(seq 1 60); do
  curl -sf http://127.0.0.1:4723/status >/dev/null 2>&1 && break
  sleep 1
done

npm test
status=$?

kill "$appium_pid" >/dev/null 2>&1 || true
exit "$status"
