const LAYER_Z_INDEX = {
  ambient: 0,
  theme: 1,
  corruption: 2,
  "theme-switch": 500,
  "corruption-pulse": 700,
  transition: 999,
};

export default function VFXLayer({ id, children }) {
  return (
    <div
      aria-hidden="true"
      className="vfx-layer"
      data-layer={id}
      style={{
        position: "fixed",
        inset: 0,
        pointerEvents: "none",
        overflow: "hidden",
        zIndex: LAYER_Z_INDEX[id] ?? 0,
      }}
    >
      {children}
    </div>
  );
}