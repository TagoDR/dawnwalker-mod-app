import { useState, useEffect } from "react";
import { ThemeContext } from "./ThemeContextValue.js";

import { NIGHTFALL_THEME } from "./nightfall.js";
import { DAWN_THEME } from "./dawn.js";
import { animations } from "./animations.js";

export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState(NIGHTFALL_THEME);

  function toggleTheme() {
    setTheme((prev) =>
      prev.mode === "nightfall" ? DAWN_THEME : NIGHTFALL_THEME
    );
  }

  useEffect(() => {
    const style = document.createElement("style");

    style.innerHTML = `
      ${animations.fadeSlideIn}
      ${animations.runeFadeIn}
      ${animations.globalEase}
      ${animations.hoverShimmer}

      :root {
        --background: ${theme.colors.background};
        --surface: ${theme.colors.surface};
        --text: ${theme.colors.text};
        --accent: ${theme.colors.accent};
        --crimson: ${theme.colors.crimson};
        --gold: ${theme.colors.gold};
        --divider: ${theme.colors.divider};
        --glow: ${theme.colors.glow};
      }
    `;

    document.head.appendChild(style);

    return () => {
      document.head.removeChild(style);
    };
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}
