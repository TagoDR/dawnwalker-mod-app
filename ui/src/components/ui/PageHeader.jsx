import { useTheme } from "../../theme/useTheme";

// Shared title + glowing divider used at the top of every page (was copy-pasted in all 9 pages).
export default function PageHeader({ title }) {
  const { theme } = useTheme();
  return (
    <>
      <h1
        style={{
          marginBottom: "10px",
          color: theme.colors.gold,
          letterSpacing: "1px",
          textTransform: "uppercase",
        }}
      >
        {title}
      </h1>
      <div
        style={{
          height: "2px",
          background: theme.colors.divider,
          boxShadow: `0 0 10px ${theme.colors.glow}`,
          marginBottom: "20px",
        }}
      />
    </>
  );
}
