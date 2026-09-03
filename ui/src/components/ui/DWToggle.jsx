export default function DWToggle({ label, value, onChange }) {
  return (
    <div className="field toggle-field">
      <span className="toggle-label">{label}</span>
      <label className="toggle-control">
        <input
          type="checkbox"
          checked={value}
          onChange={(event) => onChange(event.target.checked)}
        />
        <span className="toggle-track" />
      </label>
    </div>
  );
}
