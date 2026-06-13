// Black-box ADA checks (Appium + UiAutomator2), replacing Flutter
// meetsGuideline() tests so the harness stays Flutter-independent. Verifies two
// guidelines on the device's accessibility tree:
//   * Labeled: every interactive control exposes a non-empty content-desc.
//   * Tap target: controls are at least 48dp (Android) on both axes.
// Contrast is NOT checked here — it needs screenshot pixel-sampling (deferred).
//
// Exemptions: the two attribution links (open-meteo / github) are inline text
// links, which WCAG 2.5.8 explicitly excludes from the target-size minimum, so
// they are checked for a label but not for size.
const ids = require('../a11y_ids');

const byId = (id) => $(`android=new UiSelector().resourceId("${id}")`);

let minTapPx;

async function assertLabeled(id) {
  const el = await byId(id);
  await el.waitForExist({ timeout: 15000 });
  const cd = await el.getAttribute('content-desc');
  console.log(`  labeled? ${id}: content-desc="${cd}"`);
  expect(cd).not.toBe('');
  expect(cd).not.toBe(null);
}

async function assertTapTarget(id) {
  const el = await byId(id);
  await el.waitForExist({ timeout: 15000 });
  const { width, height } = await el.getSize();
  console.log(`  tap-target ${id}: ${width}x${height}px (min ${minTapPx}px)`);
  expect(width).toBeGreaterThanOrEqual(minTapPx);
  expect(height).toBeGreaterThanOrEqual(minTapPx);
}

describe('Meteograph — accessibility (black-box)', () => {
  before(() => {
    const density = (driver.capabilities || {}).deviceScreenDensity;
    if (!density) throw new Error('deviceScreenDensity capability missing — cannot compute 48dp');
    minTapPx = 48 * (density / 160);
  });

  describe('home screen', () => {
    before(async () => {
      await byId(ids.homeThemeButton).waitForDisplayed({ timeout: 30000 });
    });

    it('controls are labeled', async () => {
      await assertLabeled(ids.homeThemeButton);
      await assertLabeled(ids.homeLocationSelector);
      await assertLabeled(ids.homeOpenMeteoLink); // inline link: labeled, size-exempt
      await assertLabeled(ids.homeGithubLink); // inline link: labeled, size-exempt
    });

    it('chart images are labeled (native content-desc)', async () => {
      const hourly = await $$('android=new UiSelector().descriptionContains("48-hour")');
      const weekly = await $$('android=new UiSelector().descriptionContains("7-day")');
      console.log(`  charts: hourly=${hourly.length} weekly=${weekly.length}`);
      expect(hourly.length).toBeGreaterThanOrEqual(1);
      expect(weekly.length).toBeGreaterThanOrEqual(1);
    });

    it('control tap targets are >= 48dp', async () => {
      await assertTapTarget(ids.homeThemeButton);
      await assertTapTarget(ids.homeLocationSelector);
    });
  });

  describe('location picker', () => {
    before(async () => {
      await byId(ids.homeLocationSelector).click();
      await byId(ids.locationGpsTile).waitForDisplayed({ timeout: 10000 });
    });
    after(async () => {
      await driver.back();
    });

    it('GPS tile is labeled and >= 48dp', async () => {
      await assertLabeled(ids.locationGpsTile);
      await assertTapTarget(ids.locationGpsTile);
    });
  });

  describe('theme picker', () => {
    before(async () => {
      await byId(ids.homeThemeButton).click();
      await byId(ids.themeOptionLight).waitForDisplayed({ timeout: 10000 });
    });
    after(async () => {
      await driver.back();
    });

    it('options are labeled and >= 48dp', async () => {
      for (const id of [ids.themeOptionSystem, ids.themeOptionLight, ids.themeOptionDark]) {
        await assertLabeled(id);
        await assertTapTarget(id);
      }
    });
  });
});
