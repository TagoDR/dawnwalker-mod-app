import { useEffect, useRef } from "react";
import "./themeswitchflare.css";

export default function ThemeSwitchFlare({ theme, intensity }) {
  const flareRef = useRef(null);
  const previousThemeRef = useRef(theme);

  useEffect(() => {
    if (!flareRef.current || previousThemeRef.current === theme) {
      previousThemeRef.current = theme;
      return;
    }

    const flare = flareRef.current;
    previousThemeRef.current = theme;
    flare.classList.remove("flare-active");
    void flare.offsetWidth;
    flare.classList.add("flare-active");
  }, [theme]);

  return (
    <div
      ref={flareRef}
      className="flare-container"
      style={{ "--effect-intensity": intensity / 100 }}
    >
      <div className="flare-core" />
      <div className="flare-ring" />
      <div className="flare-rays" />
    </div>
  );
}
