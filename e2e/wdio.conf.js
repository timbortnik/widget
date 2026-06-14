const fs = require('fs');
const path = require('path');

// Screenshots + UI tree land here; uploaded as a CI artifact every run.
const ARTIFACTS = path.resolve(__dirname, 'artifacts');

// Sequential screenshot counter + current test label (per worker/spec process).
let shotSeq = 0;
let currentTest = 'session';

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

  // Grouped (nested array) so both specs run in ONE worker = one Appium session
  // = one app install/launch = ONE weather fetch per job (instead of one fetch
  // per spec). accessibility runs first; home_happy_path's theme switch is last.
  specs: [
    ['./specs/accessibility.e2e.js', './specs/home_happy_path.e2e.js'],
  ],
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

  // Track the running test so per-action screenshots can be labelled.
  beforeTest: function (test) {
    currentTest = `${test.parent} - ${test.title}`
      .replace(/[^a-z0-9]+/gi, '_')
      .slice(0, 80);
  },

  // Screenshot after each user action (tap / back / text entry) — i.e. each step
  // — so the artifacts show the flow progressing, not just end-of-test states.
  // Filtered to action commands so element lookups/polling don't spam shots, and
  // 'takeScreenshot' itself never matches (no recursion).
  afterCommand: async function (commandName) {
    if (!/click|back|sendkeys|touch|presskey/i.test(commandName)) return;
    fs.mkdirSync(ARTIFACTS, { recursive: true });
    shotSeq += 1;
    const seq = String(shotSeq).padStart(3, '0');
    try {
      await browser.saveScreenshot(
        path.join(ARTIFACTS, `${seq}_${currentTest}_${commandName}.png`),
      );
    } catch (e) {
      console.log('afterCommand: screenshot failed:', e.message);
    }
  },

  // Capture a screenshot after EVERY test (pass or fail) so every run has visual
  // artifacts; additionally dump the UiAutomator2 page source on failure (bulky,
  // only useful for debugging). Uploaded as the `e2e-artifacts` artifact.
  afterTest: async function (test, _context, { error }) {
    fs.mkdirSync(ARTIFACTS, { recursive: true });
    const base = `${test.parent} - ${test.title}`
      .replace(/[^a-z0-9]+/gi, '_')
      .slice(0, 120);
    try {
      await browser.saveScreenshot(path.join(ARTIFACTS, `${base}.png`));
    } catch (e) {
      console.log('afterTest: screenshot failed:', e.message);
    }
    if (error) {
      try {
        fs.writeFileSync(path.join(ARTIFACTS, `${base}.xml`), await browser.getPageSource());
      } catch (e) {
        console.log('afterTest: page source failed:', e.message);
      }
    }
  },
};
