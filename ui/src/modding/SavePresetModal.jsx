import { useEffect, useRef, useState } from "react";
import DWButton from "../components/ui/DWButton";
import { useTheme } from "../theme/useTheme";

export default function SavePresetModal({ open, onClose, onSave }) {
  const { theme } = useTheme();
  const [name, setName] = useState("");
  const inputRef = useRef(null);

  useEffect(() => {
    if (open) {
      // reset the field each time the modal is (re)opened
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setName("");
      // focus the input when modal opens
      setTimeout(() => inputRef.current?.focus(), 0);
    }
  }, [open]);

  if (!open) return null;

  return (
    <div
      role="dialog"
      aria-modal="true"
      style={{
        position: "fixed",
        inset: 0,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        zIndex: 1200,
        background: "rgba(0,0,0,0.45)",
        padding: 16,
      }}
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        style={{
          width: 420,
          maxWidth: "100%",
          background: theme.colors.surface,
          color: theme.colors.text,
          borderRadius: 10,
          padding: 18,
          boxShadow: `0 10px 30px rgba(0,0,0,0.5)`,
          border: `1px solid ${theme.colors.divider}`,
        }}
      >
        <h3 style={{ margin: 0, marginBottom: 8, color: theme.colors.gold, textTransform: "uppercase", letterSpacing: 1 }}>
          Save Preset
        </h3>

        <div style={{ marginTop: 10 }}>
          <label style={{ display: "block", fontSize: 13, marginBottom: 6, opacity: 0.9 }}>Preset name</label>
          <input
            ref={inputRef}
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Enter preset name"
            style={{
              width: "100%",
              padding: "8px 10px",
              borderRadius: 6,
              border: `1px solid ${theme.colors.divider}`,
              background: theme.colors.background || "#111",
              color: theme.colors.text,
              outline: "none",
            }}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                if (name.trim()) {
                  onSave(name.trim());
                  onClose();
                }
              } else if (e.key === "Escape") {
                onClose();
              }
            }}
          />
        </div>

        <div style={{ marginTop: 14, display: "flex", gap: 8, justifyContent: "flex-end" }}>
          <DWButton label="Cancel" onClick={() => onClose()} />
          <DWButton
            label="Save"
            onClick={() => {
              if (!name.trim()) return;
              onSave(name.trim());
              onClose();
            }}
            data-clickpulse
            data-glow
          />
        </div>
      </div>
    </div>
  );
}
