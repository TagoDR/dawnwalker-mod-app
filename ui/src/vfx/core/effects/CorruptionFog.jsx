import "./corruptionfog.css";

export default function CorruptionFog({ intensity }) {
  return (
    <div className="corruptionfog-container" style={{ opacity: intensity / 100 }}>
      <div className="corruption-fog corruption-fog-1" />
      <div className="corruption-fog corruption-fog-2" />
      <div className="corruption-fog corruption-fog-3" />
    </div>
  );
}
