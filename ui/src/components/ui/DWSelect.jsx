export default function DWSelect({ label, value, onChange, options }) {
  return (
    <div className="field">
      <label className="field-label">{label}</label>
      <select
        className="dw-select"
        value={value}
        onChange={(event) => onChange(event.target.value)}
      >
        {options.map((option) => {
          const optionValue = typeof option === "string" ? option : option.value;
          const optionLabel = typeof option === "string" ? option : option.label;
          return (
            <option key={optionValue} value={optionValue}>
              {optionLabel}
            </option>
          );
        })}
      </select>
    </div>
  );
}
