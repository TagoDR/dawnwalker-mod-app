// Per-page namespaced gameplay defaults, shared between ModdingProvider and individual pages
// (kept in their own module so Fast Refresh only sees components in ModdingProvider.jsx)

export const DEFAULT_ADVANCED = {
  ai: { difficulty: "Normal", reactionTime: 250, accuracy: 50 },
  physics: { gravity: 100, ragdollForce: 100, collisionDamage: true },
  graphics: { renderDistance: 100, shadowQuality: "High", particleDensity: 50 },
  devTools: { debugLogs: false, profilingMode: false, hotReload: true }
};

export const DEFAULT_COMBAT = {
  player: { damage: 100, critChance: 10, critDamage: 150, attackSpeed: 100 },
  enemy: { health: 100, damage: 100, aggro: 50 },
  mechanics: { stealthDifficulty: "Normal", parryWindow: 150, autoAim: false },
  boss: { health: 100, damage: 100, phaseSpeed: 100 }
};

export const DEFAULT_DAYNIGHT = {
  cycle: { dayLength: 30, nightLength: 30, eclipseIntensity: 50 },
  season: { length: 30, boost: true },
  weather: { randomness: 50, stormChance: 20, fogDensity: 40 }
};

export const DEFAULT_MOVEMENT = {
  basic: { walkSpeed: 100, runSpeed: 150, sprintSpeed: 200, jumpHeight: 100, fallDamage: true },
  stamina: { drain: 10, regen: 20, climbSpeed: 100 },
  dash: { enabled: true, cooldown: 3, distance: 10 }
};

export const DEFAULT_SKILLS = {
  points: { skillPoints: 10, passiveBoost: 5, unlockRate: 100, hybridSkills: true, skillPreset: "Balanced" },
  attributes: { magicPower: 50, weaponMastery: 50, stealthRating: 50 }
};

export const DEFAULT_VFX = {
  corruption: false,
  intensity: {
    ambientHaze: 55,
    dawnRays: 60,
    dawnParticles: 70,
    nightfallMist: 55,
    corruptionFog: 50,
    themeSwitchFlare: 75,
    corruptionPulse: 75,
    runeStagger: 65
  }
};
