import { useEffect, useRef } from "react";
import "./runestagger.css";

export default function RuneStagger({ trigger, intensity }) {
  const containerRef = useRef(null);

  useEffect(() => {
    if (!trigger || !containerRef.current) {
      return;
    }

    const container = containerRef.current;
    container.classList.remove("active");
    void container.offsetWidth;
    container.classList.add("active");
  }, [trigger]);

  return (
    <div
      ref={containerRef}
      className="runestagger-container"
      style={{ "--effect-intensity": intensity / 100 }}
    >
      <div className="vfx-burst vfx-burst-1" />
      <div className="vfx-burst vfx-burst-2" />
      <div className="vfx-burst vfx-burst-3" />
      <div className="vfx-rune vfx-rune-1" />
      <div className="vfx-rune vfx-rune-2" />
      <div className="vfx-rune vfx-rune-3" />
    </div>
  );
}
