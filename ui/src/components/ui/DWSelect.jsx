export default function DWSelect({ label, value, onChange, options }) {
  return (
    <div className="field">
      <label className="field-label">{label}</label>
      <select
        className="dw-select"
        value={value}
        onChange={(event) => onChange(event.target.value)}
      >
        {options.map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
    </div>
  );
}
