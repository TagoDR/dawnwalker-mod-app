import { useTheme } from "../../theme/useTheme";

export default function DWButton({ label, onClick, children, className = "", ...rest }) {
  const { theme } = useTheme?.() || { theme: { colors: { surface: "#222", text: "#eee", gold: "#c9a34e" } } };

  return (
    <button
      onClick={onClick}
      className={`dw-button ${className}`}
      style={{
        background: theme.colors.surface,
        color: theme.colors.text,
        border: `1px solid ${theme.colors.divider || "rgba(255,255,255,0.06)"}`,
        padding: "8px 12px",
        borderRadius: 8,
        cursor: "pointer",
      }}
      {...rest}
    >
      {label ?? children}
    </button>
  );
}
