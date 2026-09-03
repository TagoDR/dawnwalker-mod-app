export async function detectDawnwalkerInstall() {
  if (!window.dawnwalker?.scanInstall) {
    return { installed: false, appId: "3751260", path: null, unavailable: true };
  }

  return window.dawnwalker.scanInstall();
}
