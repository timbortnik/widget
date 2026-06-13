// Lean happy-path smoke test: the app launches and its core navigation works.
// Pure black-box (Appium + UiAutomator2) against the installed apk — no Flutter.
// Assertions target launch-stable chrome (located by resource-id), never weather
// values or chart content, so a live Open-Meteo fetch can't make this flaky.
const ids = require('../a11y_ids');

const byId = (id) => $(`android=new UiSelector().resourceId("${id}")`);

describe('Meteograph — home happy path', () => {
  it('launches to the home screen', async () => {
    await byId(ids.homeThemeButton).waitForDisplayed({ timeout: 30000 });
    await expect(byId(ids.homeLocationSelector)).toBeExisting();

    // Both meteogram charts render (located by their native content-desc, since
    // a PlatformView has no resource-id).
    const hourly = await $$('android=new UiSelector().descriptionContains("48-hour")');
    const weekly = await $$('android=new UiSelector().descriptionContains("14-day")');
    expect(hourly.length).toBeGreaterThanOrEqual(1);
    expect(weekly.length).toBeGreaterThanOrEqual(1);
  });

  it('opens the location picker from the location selector', async () => {
    await byId(ids.homeLocationSelector).click();
    await byId(ids.locationSearchField).waitForDisplayed({ timeout: 10000 });
    await expect(byId(ids.locationGpsTile)).toBeExisting();
    await driver.back(); // dismiss the sheet
  });

  it('opens the theme picker with all three options', async () => {
    await byId(ids.homeThemeButton).click();
    await byId(ids.themeOptionLight).waitForDisplayed({ timeout: 10000 });
    await expect(byId(ids.themeOptionSystem)).toBeExisting();
    await expect(byId(ids.themeOptionDark)).toBeExisting();
    await driver.back(); // dismiss the sheet
  });
});
