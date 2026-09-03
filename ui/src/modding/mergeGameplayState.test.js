import test from 'node:test';
import assert from 'node:assert/strict';

const DEFAULT_GAMEPLAY = {
  xpMultiplier: 1,
  timer: { enabled: true, dayLimit: 30, speedMultiplier: 1, frozen: false },
  difficulty: 'normal',
  advanced: { ai: { difficulty: 'Normal', reactionTime: 250 } },
  skills: { points: { skillPoints: 10 } },
};

function mergeGameplayState(base, incoming) {
  const next = { ...base };
  for (const [key, value] of Object.entries(incoming || {})) {
    if (value && typeof value === 'object' && !Array.isArray(value) && value !== null) {
      next[key] = mergeGameplayState(base[key] && typeof base[key] === 'object' ? base[key] : {}, value);
    } else {
      next[key] = value;
    }
  }
  return next;
}

test('mergeGameplayState preserves nested defaults while applying incoming overrides', () => {
  const incoming = {
    timer: { dayLimit: 60 },
    difficulty: 'hard',
    advanced: { ai: { reactionTime: 300 } },
  };

  const merged = mergeGameplayState(DEFAULT_GAMEPLAY, incoming);

  assert.equal(merged.difficulty, 'hard');
  assert.equal(merged.timer.enabled, true);
  assert.equal(merged.timer.dayLimit, 60);
  assert.equal(merged.advanced.ai.difficulty, 'Normal');
  assert.equal(merged.advanced.ai.reactionTime, 300);
  assert.equal(merged.skills.points.skillPoints, 10);
});
