import "./ambienthaze.css";

export default function AmbientHaze({ intensity }) {
  return (
    <div className="ambienthaze-container" style={{ opacity: intensity / 100 }}>
      <div className="haze-layer haze-1" />
      <div className="haze-layer haze-2" />
      <div className="haze-layer haze-3" />
    </div>
  );
}
