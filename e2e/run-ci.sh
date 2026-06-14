#!/usr/bin/env bash
# CI entrypoint for the E2E specs: start the Appium server (the UiAutomator2
# driver lives under ./.appium), wait for it to come up, run the WebdriverIO
# specs, then stop it. Kept as a file rather than an inline `script:` because
# android-emulator-runner mangles multi-line inline shell (the for-loop is split
# and `sh -c` sees `for … do` with no `done`).
set -o pipefail
cd "$(dirname "$0")" || exit 1

APPIUM_HOME="$PWD/.appium" npx appium --base-path / --log-timestamp > appium.log 2>&1 &
appium_pid=$!

# Wait up to ~60s for the server to accept connections, then fail fast if it
# never came up — otherwise `npm test` runs against a dead server and reports
# misleading session-creation errors instead of the real cause.
ready=
for _ in $(seq 1 60); do
  if curl -sf http://127.0.0.1:4723/status >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [ -z "$ready" ]; then
  echo "Appium server did not become ready within 60s; aborting." >&2
  cat appium.log >&2 || true
  kill "$appium_pid" >/dev/null 2>&1 || true
  exit 1
fi

# Feed the emulator a GPS fix so the app's location resolves immediately instead
# of waiting out its ~15s fallback timeout — keeps the success screen quick in CI.
adb emu geo fix -0.1278 51.5074 >/dev/null 2>&1 || true

npm test
status=$?

kill "$appium_pid" >/dev/null 2>&1 || true
exit "$status"
