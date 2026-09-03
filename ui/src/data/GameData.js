import { detectDawnwalkerInstall } from "../utils/gameDetection";

export async function loadGameData() {
  const game = await detectDawnwalkerInstall();

  if (!game.installed) {
    return {
      installed: false,
      path: game.path,
      appId: game.appId,
      unavailable: game.unavailable ?? false,
      data: null,
    };
  }

  return {
    installed: true,
    path: game.path,
    appId: game.appId,
    scan: game,
    data: {
      gameplay: null,
      skills: null,
      combat: null,
      movement: null,
      advanced: null,
    },
  };
}
