const path = require('path');

// The test consumes a PREBUILT apk by path — it has no knowledge of Flutter and
// does not build anything. Override with APP_PATH to point at any apk.
const APP_PATH =
  process.env.APP_PATH ||
  path.resolve(__dirname, '../build/app/outputs/flutter-apk/app-debug.apk');

exports.config = {
  runner: 'local',

  // Expect an Appium 2 server already running on this address (started by the
  // CI step / `npm run appium`). Appium 2's default base path is '/'.
  hostname: process.env.APPIUM_HOST || '127.0.0.1',
  port: Number(process.env.APPIUM_PORT || 4723),
  path: '/',

  specs: ['./specs/**/*.e2e.js'],
  exclude: [],
  maxInstances: 1,

  framework: 'mocha',
  reporters: ['spec'],
  logLevel: 'info',
  mochaOpts: { ui: 'bdd', timeout: 180000 },

  capabilities: [
    {
      platformName: 'Android',
      'appium:automationName': 'UiAutomator2',
      'appium:appPackage': 'org.bortnik.meteogram',
      'appium:appActivity': 'org.bortnik.meteogram.MainActivity',
      'appium:app': APP_PATH,
      // Auto-grant manifest permissions so the runtime location dialog never
      // blocks the run (the happy path stays off the GPS branch anyway).
      'appium:autoGrantPermissions': true,
      // Pin locale so content-desc labels match app_en.arb.
      'appium:language': 'en',
      'appium:locale': 'US',
      'appium:disableWindowAnimation': true,
      'appium:newCommandTimeout': 180,
      'appium:fullReset': false,
      'appium:noReset': false,
      // Always install the apk under test, even if a same-version package is
      // already present — otherwise a rebuilt apk (unchanged version) is skipped.
      'appium:enforceAppInstall': true,
    },
  ],
};
