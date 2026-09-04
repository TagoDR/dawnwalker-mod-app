import { useState } from "react";
import { useTheme } from "../theme/useTheme";
import { useModding } from "../modding/useModding";
import DWButton from "../components/ui/DWButton";
import DWSelect from "../components/ui/DWSelect";
import PageHeader from "../components/ui/PageHeader";
import SavePresetModal from "../modding/SavePresetModal";
import { useToast } from "../modding/useToast";

function SaveLoadInner() {
  const { theme } = useTheme();
  const { presets, loadPreset, removePreset, exportAll, importAll, savePreset } = useModding();
  const toast = useToast();

  const [importText, setImportText] = useState("");
  const [selectedPreset, setSelectedPreset] = useState("");
  const [showModal, setShowModal] = useState(false);

  function handleExportDownload() {
    const data = exportAll();
    const blob = new Blob([data], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "dawnwalker-modding-presets.json";
    a.click();
    URL.revokeObjectURL(url);
    toast.push({ type: "success", text: "Export started" });
  }

  function handleImport() {
    if (!importText) {
      toast.push({ type: "error", text: "Paste JSON to import." });
      return;
    }
    const ok = importAll(importText);
    if (!ok) {
      toast.push({ type: "error", text: "Import failed: invalid JSON" });
    } else {
      toast.push({ type: "success", text: "Import successful" });
      setImportText("");
    }
  }

  function handleSave(name) {
    savePreset(name);
    toast.push({ type: "success", text: `Saved preset: ${name}` });
  }

  return (
    <div>
      <PageHeader title="Profiles & Backups" />

      <div style={{ marginTop: 12 }}>
        <h3>Presets</h3>

        <div style={{ display: "flex", gap: 8, alignItems: "center", marginBottom: 12 }}>
          <DWSelect
            label="Apply Preset"
            value={selectedPreset}
            onChange={(v) => {
              setSelectedPreset(v);
              const idx = parseInt(v, 10);
              if (!Number.isNaN(idx)) {
                loadPreset(idx);
                toast.push({ type: "success", text: `Applied preset: ${presets[idx]?.name ?? idx}` });
              }
            }}
            options={presets.map((p, i) => `${i}: ${p.name}`)}
          />
          <DWButton label="Save Current" onClick={() => setShowModal(true)} data-clickpulse data-glow />
          <DWButton label="Export All" onClick={handleExportDownload} />
        </div>

        <div style={{ marginTop: 8 }}>
          <h4>Import Presets</h4>
          <textarea
            value={importText}
            onChange={(e) => setImportText(e.target.value)}
            placeholder="Paste exported JSON here"
            style={{ width: "100%", minHeight: 120, background: theme.colors.surface, color: theme.colors.text, border: `1px solid ${theme.colors.divider}`, padding: 8 }}
          />
          <div style={{ marginTop: 8, display: "flex", gap: 8 }}>
            <DWButton label="Import" onClick={handleImport} />
            <DWButton label="Clear" onClick={() => setImportText("")} />
          </div>
        </div>

        <div style={{ marginTop: 16 }}>
          <h4>Manage Presets</h4>

          {presets.length === 0 ? (
            <div style={{ opacity: 0.9 }}>
              <p>No presets saved yet.</p>
              <DWButton label="Save Current as Preset" onClick={() => setShowModal(true)} data-clickpulse data-glow />
            </div>
          ) : (
            <ul style={{ paddingLeft: 0 }}>
              {presets.map((p, i) => {
                const gp = p.data?.gameplay || {};
                const xp = gp.xpMultiplier ?? gp.xp ?? 1;
                const days = gp.timer?.dayLimit ?? gp.timerDayLimit ?? "-";
                const diff = gp.difficulty ?? "normal";
                return (
                  <li key={p.createdAt} style={{ marginBottom: 10, listStyle: "none", padding: 10, borderRadius: 8, background: theme.colors.surface, border: `1px solid ${theme.colors.divider}` }}>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12 }}>
                      <div>
                        <div style={{ fontWeight: 700 }}>{p.name}</div>
                        <div style={{ fontSize: 12, opacity: 0.8 }}>
                          XP x{xp} • Days {days} • {diff}
                        </div>
                      </div>

                      <div style={{ display: "flex", gap: 8 }}>
                        <DWButton label="Load" onClick={() => { loadPreset(i); toast.push({ type: "success", text: `Loaded: ${p.name}` }); }} />
                        <DWButton label="Delete" onClick={() => { removePreset(i); toast.push({ type: "success", text: `Deleted: ${p.name}` }); }} />
                      </div>
                    </div>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </div>

      <SavePresetModal open={showModal} onClose={() => setShowModal(false)} onSave={handleSave} />
    </div>
  );
}

export default function SaveLoadPage() {
  return <SaveLoadInner />;
}
