// Deep-merges incoming overrides onto a base object, preserving untouched nested defaults.
export function mergeGameplayState(base, incoming) {
  const next = { ...(base ?? {}) };

  for (const [key, value] of Object.entries(incoming ?? {})) {
    if (value && typeof value === "object" && !Array.isArray(value)) {
      next[key] = mergeGameplayState(base?.[key], value);
      continue;
    }

    next[key] = value;
  }

  return next;
}
