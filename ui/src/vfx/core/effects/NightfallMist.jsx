import "./nightfallmist.css";

export default function NightfallMist({ intensity }) {
  return (
    <div className="nightfallmist-container" style={{ opacity: intensity / 100 }}>
      <div className="night-mist night-mist-1" />
      <div className="night-mist night-mist-2" />
      <div className="night-mist night-mist-3" />
    </div>
  );
}
