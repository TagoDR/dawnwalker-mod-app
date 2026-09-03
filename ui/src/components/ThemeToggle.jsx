import { useTheme } from "../theme/useTheme";

export default function ThemeToggle() {
  const { theme, toggleTheme } = useTheme();
  const label = theme.mode === "nightfall" ? "Invoke Dawn" : "Invoke Night";

  return (
    <button
      className="theme-toggle"
      data-clickpulse
      data-glow
      onClick={toggleTheme}
      type="button"
    >
      {label}
    </button>
  );
}
