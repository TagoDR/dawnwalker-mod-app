import "./dawnrays.css";

export default function DawnRays({ intensity }) {
  return (
    <div
      className="dawnrays-container"
      style={{ "--effect-intensity": intensity / 100 }}
    >
      <div className="ray ray-1" />
      <div className="ray ray-2" />
      <div className="ray ray-3" />
      <div className="ray ray-4" />
      <div className="ray ray-5" />
    </div>
  );
}