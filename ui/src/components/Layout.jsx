import { useTheme } from "../theme/useTheme";
import characterArt from "../assets/vale-sangora-characters.png";
import ThemeToggle from "./ThemeToggle";

const pages = [
  "Install & Capabilities",
  "Character",
  "Skills & Progression",
  "Combat",
  "Movement & Camera",
  "World & Time",
  "Gear & Inventory",
  "Visual Effects",
  "Profiles & Backups",
];

export default function Layout({ page, setPage, children }) {
  const { theme } = useTheme();

  return (
    <div className={`app-shell theme-${theme.mode}`}>
      <div
        aria-hidden="true"
        className="character-portrait"
        style={{ "--character-art": `url(${characterArt})` }}
      />

      <aside className="app-sidebar">
        <div className="brand">
          <span className="brand-mark">D</span>
          <div>
            <span className="brand-kicker">Vale Sangora</span>
            <p className="brand-name">Dawnwalker</p>
          </div>
        </div>

        <div className="sidebar-rule" />

        <nav className="app-nav" aria-label="Mod settings">
          {pages.map((item) => (
            <button
              className={`nav-button ${page === item ? "is-active" : ""}`}
              data-clickpulse
              data-glow
              key={item}
              onClick={() => setPage(item)}
              type="button"
            >
              {item}
            </button>
          ))}
        </nav>

        <ThemeToggle />
      </aside>

      <main className="app-main" key={page}>
        <div className="content-frame">{children}</div>
      </main>
    </div>
  );
}
