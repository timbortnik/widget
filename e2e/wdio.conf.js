const fs = require('fs');
const path = require('path');

// Failure diagnostics (screenshot + UI tree) land here; uploaded as a CI artifact.
const ARTIFACTS = path.resolve(__dirname, 'artifacts');

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

  // On a failed test, capture a screenshot + the UiAutomator2 page source so CI
  // can show what the app looked like (e.g. stuck on the loading spinner vs an
  // error screen). Files are uploaded as the `e2e-diagnostics` artifact.
  afterTest: async function (test, _context, { error }) {
    if (!error) return;
    fs.mkdirSync(ARTIFACTS, { recursive: true });
    const base = `${test.parent} - ${test.title}`
      .replace(/[^a-z0-9]+/gi, '_')
      .slice(0, 120);
    try {
      await browser.saveScreenshot(path.join(ARTIFACTS, `${base}.png`));
    } catch (e) {
      console.log('afterTest: screenshot failed:', e.message);
    }
    try {
      fs.writeFileSync(path.join(ARTIFACTS, `${base}.xml`), await browser.getPageSource());
    } catch (e) {
      console.log('afterTest: page source failed:', e.message);
    }
  },
};
