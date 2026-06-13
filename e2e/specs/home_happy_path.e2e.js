// Lean happy-path smoke test: the app launches and its core navigation works.
// Pure black-box (Appium + UiAutomator2) against the installed apk — no Flutter.
// Assertions target launch-stable chrome (located by resource-id), never weather
// values or chart content.
const ids = require('../a11y_ids');

const byId = (id) => $(`android=new UiSelector().resourceId("${id}")`);

// The home (success) screen only renders once weather has loaded. On a cold CI
// emulator with no cached data that means waiting out location resolution (up to
// a 15s fallback timeout) plus the fetch + first render — so allow generous time
// and ALWAYS wait for an element before acting on it.
const READY = 60000;

describe('Meteograph — home happy path', () => {
  it('launches to the home screen', async () => {
    await byId(ids.homeThemeButton).waitForDisplayed({ timeout: READY });
    await expect(byId(ids.homeLocationSelector)).toBeDisplayed();

    // Both meteogram charts render (located by their native content-desc, since
    // a PlatformView has no resource-id).
    const hourly = await $$('android=new UiSelector().descriptionContains("48-hour")');
    const weekly = await $$('android=new UiSelector().descriptionContains("7-day")');
    expect(hourly.length).toBeGreaterThanOrEqual(1);
    expect(weekly.length).toBeGreaterThanOrEqual(1);
  });

  it('opens the location picker from the location selector', async () => {
    const selector = byId(ids.homeLocationSelector);
    await selector.waitForDisplayed({ timeout: READY });
    await selector.click();
    await byId(ids.locationSearchField).waitForDisplayed({ timeout: 15000 });
    await expect(byId(ids.locationGpsTile)).toBeExisting();
    await driver.back(); // dismiss the sheet
  });

  it('opens the theme picker with all three options', async () => {
    const themeBtn = byId(ids.homeThemeButton);
    await themeBtn.waitForDisplayed({ timeout: READY });
    await themeBtn.click();
    await byId(ids.themeOptionLight).waitForDisplayed({ timeout: 15000 });
    await expect(byId(ids.themeOptionSystem)).toBeExisting();
    await expect(byId(ids.themeOptionDark)).toBeExisting();
    await driver.back(); // dismiss the sheet
  });
});
