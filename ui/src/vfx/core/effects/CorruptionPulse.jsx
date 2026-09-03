import { useEffect, useRef } from "react";
import "./corruptionpulse.css";

export default function CorruptionPulse({ corruption, intensity }) {
  const pulseRef = useRef(null);

  useEffect(() => {
    if (!corruption || !pulseRef.current) {
      return;
    }

    const pulse = pulseRef.current;
    pulse.classList.remove("pulse-active");
    void pulse.offsetWidth;
    pulse.classList.add("pulse-active");
  }, [corruption]);

  return (
    <div
      ref={pulseRef}
      className="corruptionpulse-container"
      style={{ "--effect-intensity": intensity / 100 }}
    >
      <div className="pulse-ring" />
      <div className="pulse-core" />
      <div className="pulse-distort" />
    </div>
  );
}
