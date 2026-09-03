export const TRAINER_CAPABILITIES = [
  { page: "Combat & Experience", control: "Infinite health", trainerOption: "Infinite Health", supported: true },
  { page: "Movement & Stamina", control: "Infinite stamina", trainerOption: "Infinite Stamina", supported: true },
  { page: "Movement & Stamina", control: "Player speed", trainerOption: "Player Speed Multiplier", supported: true },
  { page: "Advanced Tuning", control: "Jump height", trainerOption: "Jump Height Multiplier", supported: true },
  { page: "Advanced Tuning", control: "Game speed", trainerOption: "Set Game Speed", supported: true },
  { page: "Advanced Tuning", control: "Field of view", trainerOption: "FOV Multiplier", supported: true },
  { page: "Gameplay Profile", control: "XP multiplier", trainerOption: "Not listed by trainer", supported: false },
  { page: "Skills & Progression", control: "Unlock all skills", trainerOption: "Not listed by trainer", supported: false },
  { page: "Combat & Experience", control: "Cooldown reduction", trainerOption: "Not listed by trainer", supported: false },
  { page: "Day / Night & Timer", control: "Time limit", trainerOption: "Not listed by trainer", supported: false },
];

const CAPABILITIES = Object.fromEntries(
  TRAINER_CAPABILITIES.map(({ control, supported }) => [control, supported])
);

export function createUnavailableGameplayAdapter() {
  return {
    id: "unavailable",
    status: "No verified gameplay backend",
    capabilities: Object.fromEntries(Object.keys(CAPABILITIES).map((capability) => [capability, false])),
    async apply() {
      return { ok: false, error: "No verified gameplay backend is available" };
    },
    async restore() {
      return { ok: false, error: "No verified gameplay backend is available" };
    },
  };
}