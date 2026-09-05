import { useEffect, useState } from "react";
import { useTheme } from "../theme/useTheme";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";
import DWButton from "../components/ui/DWButton";
import SavePresetModal from "../modding/SavePresetModal";
import { useToast } from "../modding/useToast";

import { useBridge } from "../bridge/useBridge";
import BridgePanel, { Note } from "../bridge/BridgePanel";

const STORAGE_KEY = "dawnwalker-bridge-presets-v1";

// Persistent (continuously re-applied) bridge fields that make sense to snapshot. One-shot
// nonces/actions (requestId, actionId, setLevel, nukeDamage...) are deliberately excluded.
const PRESET_FIELDS = [
  "levelCap",
  "infiniteHealth",
  "infiniteStamina",
  "infiniteBlood",
  "keepActionSlotsCharged",
  "noCooldowns",
  "speedMultiplier",
  "jumpMultiplier",
  "fovMultiplier",
  "gameSpeed",
  "damageAmplifier",
  "carryWeightMultiplier",
  "actionDifficulty",
  "rpgDifficulty",
  "movementMode",
];

const FIELD_LABELS = {
  levelCap: "Level cap",
  infiniteHealth: "Infinite health",
  infiniteStamina: "Infinite stamina",
  infiniteBlood: "Infinite blood",
  keepActionSlotsCharged: "Charges full",
  noCooldowns: "No cooldowns",
  speedMultiplier: "Speed",
  jumpMultiplier: "Jump",
  fovMultiplier: "FOV",
  gameSpeed: "Game speed",
  damageAmplifier: "Damage",
  carryWeightMultiplier: "Carry weight",
  actionDifficulty: "Combat difficulty",
  rpgDifficulty: "RPG difficulty",
  movementMode: "Movement mode",
};

function readPresets() {
  try {
    const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function snapshot(command) {
  const values = {};
  for (const key of PRESET_FIELDS) {
    if (command?.[key] !== undefined && command?.[key] !== "") values[key] = command[key];
  }
  return values;
}

function summarize(values) {
  return Object.entries(values)
    .map(([key, value]) => `${FIELD_LABELS[key] ?? key}: ${value}`)
    .join(" • ");
}

export default function SaveLoadPage() {
  const { theme } = useTheme();
  const toast = useToast();
  const api = useBridge();
  const { bridge, command, applyPreset } = api;
  const [presets, setPresets] = useState(readPresets);
  const [showModal, setShowModal] = useState(false);
  const [importText, setImportText] = useState("");
  const [backupMessage, setBackupMessage] = useState("");

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(presets));
    } catch (error) {
      console.warn("[Presets] Failed to persist presets", error);
    }
  }, [presets]);

  function handleSave(name) {
    const values = snapshot(command);
    if (Object.keys(values).length === 0) {
      toast.push({ type: "error", text: "No live settings to save yet - change something first." });
      return;
    }
    setPresets((prev) => [{ name, createdAt: new Date().toISOString(), values }, ...prev].slice(0, 50));
    toast.push({ type: "success", text: `Saved preset: ${name}` });
  }

  async function handleApply(preset) {
    const result = await applyPreset(preset.values);
    toast.push(result.ok ? { type: "success", text: `Applied: ${preset.name}` } : { type: "error", text: result.error || "Apply failed" });
  }

  function handleExport() {
    const blob = new Blob([JSON.stringify(presets, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "dawnwalker-bridge-presets.json";
    a.click();
    URL.revokeObjectURL(url);
    toast.push({ type: "success", text: "Export started" });
  }

  function handleImport() {
    try {
      const parsed = JSON.parse(importText);
      const incoming = (Array.isArray(parsed) ? parsed : []).filter((p) => p && typeof p.name === "string" && p.values && typeof p.values === "object");
      if (incoming.length === 0) throw new Error("no presets");
      setPresets((prev) => [...incoming, ...prev].slice(0, 50));
      setImportText("");
      toast.push({ type: "success", text: `Imported ${incoming.length} preset(s)` });
    } catch {
      toast.push({ type: "error", text: "Import failed: expected exported preset JSON" });
    }
  }

  async function handleBackup() {
    if (!bridge?.backupUserData) {
      setBackupMessage("Backups are available in the desktop app only.");
      return;
    }
    const result = await bridge.backupUserData();
    setBackupMessage(result.ok ? `Backup created (${result.copiedFiles.length} files): ${result.backupRoot}` : result.error);
  }

  return (
    <div>
      <PageHeader title="Profiles & Backups" />

      <RuneStagger index={0}>
        <BridgePanel
          bridgeApi={api}
          title="Live Settings Presets"
          intro="The app and the game always start at the game's own defaults - nothing is carried over between launches. Save the settings you've found to work as a preset here, then apply it once you're loaded into a save."
        >
          <RuneStagger index={1}>
            <RuneSection title="Presets">
              <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 12 }}>
                <DWButton label="Save Current Settings" onClick={() => setShowModal(true)} data-clickpulse data-glow />
                <DWButton label="Export All" onClick={handleExport} disabled={presets.length === 0} />
              </div>
              {presets.length === 0 ? (
                <p style={{ opacity: 0.85 }}>No presets saved yet.</p>
              ) : (
                <ul style={{ paddingLeft: 0, margin: 0 }}>
                  {presets.map((preset, index) => (
                    <li
                      key={`${preset.createdAt}-${index}`}
                      style={{ marginBottom: 10, listStyle: "none", padding: 10, borderRadius: 8, background: theme.colors.surface, border: `1px solid ${theme.colors.divider}` }}
                    >
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12, flexWrap: "wrap" }}>
                        <div style={{ minWidth: 0 }}>
                          <div style={{ fontWeight: 700 }}>{preset.name}</div>
                          <div style={{ fontSize: 12, opacity: 0.8, overflowWrap: "anywhere" }}>{summarize(preset.values)}</div>
                        </div>
                        <div style={{ display: "flex", gap: 8 }}>
                          <DWButton label="Apply" onClick={() => handleApply(preset)} />
                          <DWButton
                            label="Delete"
                            onClick={() => {
                              setPresets((prev) => prev.filter((_, i) => i !== index));
                              toast.push({ type: "success", text: `Deleted: ${preset.name}` });
                            }}
                          />
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </RuneSection>
          </RuneStagger>

          <RuneStagger index={2}>
            <RuneSection title="Import Presets">
              <textarea
                value={importText}
                onChange={(e) => setImportText(e.target.value)}
                placeholder="Paste exported preset JSON here"
                style={{ width: "100%", minHeight: 100, background: theme.colors.surface, color: theme.colors.text, border: `1px solid ${theme.colors.divider}`, padding: 8 }}
              />
              <div style={{ marginTop: 8, display: "flex", gap: 8 }}>
                <DWButton label="Import" onClick={handleImport} disabled={!importText} />
                <DWButton label="Clear" onClick={() => setImportText("")} />
              </div>
            </RuneSection>
          </RuneStagger>
        </BridgePanel>
      </RuneStagger>

      <RuneStagger index={3}>
        <RuneSection title="Save Game Backup">
          <Note>
            Copies your SaveGames and Config folders from %LOCALAPPDATA%\Dawnwalker\Saved into this app's data
            folder. Close the game first. Strongly recommended before unlocking traits, fast travel or granting gear.
          </Note>
          <DWButton label="Create Backup" onClick={handleBackup} data-clickpulse data-glow />
          {backupMessage && <p style={{ opacity: 0.85, overflowWrap: "anywhere" }}>{backupMessage}</p>}
        </RuneSection>
      </RuneStagger>

      <SavePresetModal open={showModal} onClose={() => setShowModal(false)} onSave={handleSave} />
    </div>
  );
}
