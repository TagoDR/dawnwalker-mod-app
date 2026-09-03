export const DAWN_THEME = {
  mode: "dawn",
  colors: {
    /* 🌅 Nightfall's black fading into a reddened sunrise horizon */
    background: `linear-gradient(
      180deg,
      #0a0a0a 0%,      /* nightfall black, unchanged at the top */
      #2c1414 18%,     /* embers stirring in the dark */
      #6e2320 38%,     /* deep crimson dawn */
      #a13a3a 55%,     /* burnt red */
      #c1683f 72%,     /* terracotta ember */
      #d99a52 88%,     /* amber gold */
      #e8c98a 100%     /* warm horizon glow */
    )`,

    /* 🌄 Nightfall's surface warming with early sunlight */
    surface: "#241a18",

    /* 📜 Soft parchment text (slightly brighter) */
    text: "#f2e0cc",

    /* ✨ Warm highlight color (UI glow, sliders, toggles) */
    highlight: "#d97a5c",

    /* 🌅 Sunrise accent glow (secondary glow for shimmer) */
    accentGlow: "rgba(180, 50, 45, 0.45)",

    /* 🌞 Warm sunrise gold accents */
    accent: "#b8503f",

    /* Shared colors (kept close to nightfall's for a smooth crossfade) */
    crimson: "#b03030",
    gold: "#c9a34e",

    /* 🔥 Unified glow (main glow for animations) */
    glow: "rgba(200, 60, 50, 0.4)",

    /* Softer divider, still close to nightfall's neutral divider */
    divider: "#3d2e29",
  },
};
