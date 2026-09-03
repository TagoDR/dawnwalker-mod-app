export default function DWSlider({ label, value, onChange, min = 0, max = 100 }) {
  return (
    <div className="field">
      <label className="field-label">
        <span>{label}</span>
        <span className="field-value">{value}</span>
      </label>
      <input
        className="dw-range"
        type="range"
        min={min}
        max={max}
        value={value}
        onChange={(event) => onChange(Number(event.target.value))}
      />
    </div>
  );
}
