import { useMemo } from "react";
import "./dawnparticles.css";

const MOTE_COUNT = 40;

function createMotes() {
  return Array.from({ length: MOTE_COUNT }, (_, index) => ({
    id: index,
    left: `${Math.random() * 100}%`,
    top: `${Math.random() * 100}%`,
    duration: `${6 + Math.random() * 6}s`,
    delay: `${Math.random() * -12}s`,
    size: `${2 + Math.random() * 4}px`,
  }));
}

export default function DawnParticles({ intensity }) {
  const motes = useMemo(() => createMotes(), []);

  return (
    <div className="dawnparticles-container" style={{ opacity: intensity / 100 }}>
      {motes.map((mote) => (
        <span
          className="mote"
          key={mote.id}
          style={{
            left: mote.left,
            top: mote.top,
            width: mote.size,
            height: mote.size,
            animationDuration: mote.duration,
            animationDelay: mote.delay,
          }}
        />
      ))}
    </div>
  );
}