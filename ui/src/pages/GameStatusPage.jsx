import { useTheme } from "../theme/useTheme";
import { useGameData } from "../data/useGameData";
import DWButton from "../components/ui/DWButton";
import DWSelect from "../components/ui/DWSelect";
import RuneSection from "../components/ui/RuneSection";
import { useState } from "react";
import { TRAINER_CAPABILITIES } from "../modding/gameplayAdapter";

const signalLabels = {
  unrealPackDirectory: "Unreal Content/Paks directory",
  pakFiles: ".pak archives",
  ioStoreTocFiles: ".utoc tables of contents",
  ioStoreDataFiles: ".ucas data containers",
  pluginsDirectory: "Plugins directory",
  modDirectory: "Existing mod directory",
  userConfigDirectory: "Saved/Config/Windows directory",
  easyAntiCheat: "Easy Anti-Cheat directory",
};

function signalValue(key, value) {
  if (key === "modDirectory") return value || "Not found";
  if (["pakFiles", "ioStoreTocFiles", "ioStoreDataFiles"].includes(key)) return String(value);
  return value ? "Found" : "Not found";
}

function formatBytes(bytes) {
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function GameStatusPage() {
  const { theme } = useTheme();
  const game = useGameData();
  const [backupMessage, setBackupMessage] = useState("");
  const [leftSave, setLeftSave] = useState("");
  const [rightSave, setRightSave] = useState("");
  const [comparison, setComparison] = useState(null);

  async function handleBackup() {
    if (!window.dawnwalker?.backupUserData) {
      setBackupMessage("Backups are available in the desktop app only.");
      return;
    }
    const result = await window.dawnwalker.backupUserData();
    setBackupMessage(result.ok ? `Backup created: ${result.copiedFiles.length} files` : result.error);
  }

  return (
    <div>
      <h1 style={{ marginBottom: 10, color: theme.colors.gold, textTransform: "uppercase" }}>
        Install & Capabilities
      </h1>
      <div style={{ height: 2, background: theme.colors.divider, boxShadow: `0 0 10px ${theme.colors.glow}`, marginBottom: 20 }} />

      {game.loading ? (
        <p style={{ opacity: 0.8 }}>Scanning Steam libraries for The Blood of Dawnwalker...</p>
      ) : game.unavailable ? (
        <RuneSection title="Desktop Integration Required">
          <p>This scan is available only in the Electron desktop app, not the Vite browser preview.</p>
        </RuneSection>
      ) : !game.installed ? (
        <RuneSection title="Steam Installation Not Found">
          <p>Steam app ID 3751260 was not found in the standard Steam library locations.</p>
          <p style={{ opacity: 0.78 }}>No game files were changed. Manual folder selection will be added after the released installation structure is verified.</p>
          <DWButton label="Scan Steam Libraries" onClick={game.refresh} />
        </RuneSection>
      ) : (
        <>
          <RuneSection title="Detected Installation">
            <p><strong>{game.scan.gameName}</strong> was found through Steam app ID {game.appId}.</p>
            <p style={{ overflowWrap: "anywhere" }}>{game.path}</p>
            <p style={{ overflowWrap: "anywhere" }}>Game root: {game.scan.gameRoot}</p>
            <p>Build ID: {game.scan.buildId || "Not reported by Steam"}</p>
            <p>Game process: {game.scan.gameRunning ? "Running (read-only scan only)" : "Not running"}</p>
            <p>Cheat Evolution: {game.scan.trainerRunning ? "Running" : "Not running"}</p>
            <p>Executables: {game.scan.executableFiles.length ? game.scan.executableFiles.join(", ") : "None found at install root"}</p>
            <DWButton label="Rescan Installation" onClick={game.refresh} />
          </RuneSection>

          <div style={{ marginTop: 16 }}>
            <RuneSection title="Read-Only UE5 Packaging Scan">
              <div style={{ display: "grid", gap: 9 }}>
                {Object.entries(game.scan.signals).map(([key, value]) => (
                  <div key={key} style={{ display: "flex", justifyContent: "space-between", gap: 16, borderBottom: `1px solid ${theme.colors.divider}`, paddingBottom: 7 }}>
                    <span>{signalLabels[key]}</span>
                    <strong>{signalValue(key, value)}</strong>
                  </div>
                ))}
              </div>
            </RuneSection>
          </div>

          <div style={{ marginTop: 16 }}>
            <RuneSection title="Mod-Relevant Files">
              <p style={{ opacity: 0.78 }}>
                Files below are detected under the game root only. The scan is read-only and does not include Unreal Engine files.
              </p>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 12 }}>
                {Object.entries(game.scan.inventorySummary).map(([extension, count]) => (
                  <strong key={extension} style={{ border: `1px solid ${theme.colors.divider}`, padding: "6px 9px" }}>
                    {extension}: {count}
                  </strong>
                ))}
              </div>
              <div style={{ display: "grid", gap: 7, maxHeight: 360, overflowY: "auto" }}>
                {game.scan.inventory.map((file) => (
                  <div key={file.relativePath} style={{ display: "flex", justifyContent: "space-between", gap: 16, borderBottom: `1px solid ${theme.colors.divider}`, paddingBottom: 6 }}>
                    <span style={{ overflowWrap: "anywhere" }}>{file.relativePath}</span>
                    <strong style={{ whiteSpace: "nowrap" }}>{formatBytes(file.sizeBytes)}</strong>
                  </div>
                ))}
              </div>
            </RuneSection>
          </div>

          <div style={{ marginTop: 16 }}>
            <RuneSection title="IoStore Archive Inspection">
              <p style={{ opacity: 0.78 }}>
                The TOC headers are read-only and verified without opening the large UCAS containers for writing.
              </p>
              <div style={{ display: "grid", gap: 9 }}>
                {game.scan.tocInspections.map((toc) => (
                  <div key={toc.relativePath} style={{ borderBottom: `1px solid ${theme.colors.divider}`, paddingBottom: 9 }}>
                    <strong style={{ overflowWrap: "anywhere" }}>{toc.relativePath}</strong>
                    {toc.readable ? (
                      <div style={{ display: "grid", gap: 4, marginTop: 5, opacity: 0.82 }}>
                        <span>Format: {toc.magic}, version {toc.version}</span>
                        <span>Header: {toc.headerSize} bytes; TOC entries: {toc.tocEntryCount.toLocaleString()}</span>
                        <span>Compression blocks: {toc.compressedBlockCount.toLocaleString()} at {formatBytes(toc.compressionBlockSize)}; directory index: {formatBytes(toc.directoryIndexSize)}</span>
                        <span>Partitions: {toc.partitionCount}; container flags: 0x{toc.containerFlags.toString(16).padStart(2, "0")}</span>
                        <span>Indexed: {toc.indexed ? "yes" : "no"}; encrypted: {toc.encrypted ? "yes" : "no"}; compressed: {toc.compressed ? "yes" : "no"}; signed: {toc.signed ? "yes" : "no"}</span>
                        <span>{toc.directoryIndex}</span>
                      </div>
                    ) : (
                      <div style={{ marginTop: 5, opacity: 0.82 }}>Unable to read this TOC header: {toc.error}</div>
                    )}
                  </div>
                ))}
              </div>
            </RuneSection>
          </div>

          <div style={{ marginTop: 16 }}>
            <RuneSection title="User Data Discovery">
              <p style={{ overflowWrap: "anywhere" }}>Profile root: {game.scan.userData.root}</p>
              <p style={{ overflowWrap: "anywhere" }}>Save directory: {game.scan.userData.saveRoot}</p>
              <p>Save files: {game.scan.userData.saveFiles.length ? `${game.scan.userData.saveFiles.length} found` : "None found"}</p>
              {game.scan.userData.saveFiles.length > 0 && (
                <div style={{ display: "grid", gap: 7 }}>
                  {game.scan.userData.saveFiles.map((file) => (
                    <div key={file.name} style={{ display: "flex", justifyContent: "space-between", gap: 16, borderBottom: `1px solid ${theme.colors.divider}`, paddingBottom: 6 }}>
                      <span style={{ overflowWrap: "anywhere" }}>{file.name}</span>
                      <strong style={{ whiteSpace: "nowrap" }}>{file.format}, {formatBytes(file.sizeBytes)}</strong>
                    </div>
                  ))}
                </div>
              )}
              {game.scan.userData.settingsProperties.length > 0 && (
                <div style={{ marginTop: 10 }}>
                  <strong>Detected RebelSettings properties</strong>
                  <p style={{ overflowWrap: "anywhere", opacity: 0.82 }}>{game.scan.userData.settingsProperties.join(", ")}</p>
                </div>
              )}
              <div style={{ display: "grid", gap: 7, marginTop: 10 }}>
                <strong>Gameplay setting candidates</strong>
                {game.scan.userData.settingsCandidates.map((candidate) => (
                  <div key={candidate.property} style={{ display: "flex", justifyContent: "space-between", gap: 16, borderBottom: `1px solid ${theme.colors.divider}`, paddingBottom: 6 }}>
                    <span>{candidate.label}</span>
                    <strong>{candidate.present ? "Present in GVAS" : "Not present"}</strong>
                  </div>
                ))}
                <p style={{ opacity: 0.78 }}>XP and skill unlock fields were not found in RebelSettings.sav; they are expected to require DSAV parsing or runtime integration.</p>
              </div>
              <p style={{ overflowWrap: "anywhere" }}>Config directory: {game.scan.userData.configRoot}</p>
              <p>Config files: {game.scan.userData.configFiles.length ? game.scan.userData.configFiles.join(", ") : "None found"}</p>
              <DWButton label="Create Read-Only Backup" onClick={handleBackup} />
              {backupMessage && <p style={{ opacity: 0.82 }}>{backupMessage}</p>}
              <p style={{ opacity: 0.78 }}>User data is detected read-only. No saves or configuration files have been changed.</p>
              {game.scan.userData.saveFiles.length > 1 && (
                <div style={{ marginTop: 14 }}>
                  <strong>Compare DSAV saves</strong>
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 10, alignItems: "end", marginTop: 8 }}>
                    <DWSelect label="Before" value={leftSave} onChange={setLeftSave} options={["", ...game.scan.userData.saveFiles.map((file) => file.name)]} />
                    <DWSelect label="After" value={rightSave} onChange={setRightSave} options={["", ...game.scan.userData.saveFiles.map((file) => file.name)]} />
                    <DWButton label="Compare" onClick={async () => setComparison(await window.dawnwalker.compareSaves(leftSave, rightSave))} />
                  </div>
                  {comparison && (comparison.ok ? (
                    <p style={{ opacity: 0.82 }}>{comparison.left.name} to {comparison.right.name}: {comparison.changedBytes.toLocaleString()} changed bytes across {comparison.totalChangedRanges} ranges; size difference: {comparison.trailingBytes} bytes. First ranges: {comparison.changedRanges.slice(0, 5).map((range) => `${range.start}-${range.end}`).join(", ") || "none"}</p>
                  ) : <p style={{ opacity: 0.82 }}>{comparison.error}</p>)}
                </div>
              )}
            </RuneSection>
          </div>

          <div style={{ marginTop: 16 }}>
            <RuneSection title="Runtime Mod Loader">
              <p style={{ overflowWrap: "anywhere" }}>Binary directory: {game.scan.runtimeLoader.binaryRoot}</p>
              <p style={{ overflowWrap: "anywhere" }}>Loader directory: {game.scan.runtimeLoader.loaderRoot}</p>
              <p>Status: {game.scan.runtimeLoader.status}</p>
              <p>Loader markers: {game.scan.runtimeLoader.foundMarkers.length ? game.scan.runtimeLoader.foundMarkers.join(", ") : "None found"}</p>
              <p>Runtime mod directories: {game.scan.runtimeLoader.modDirectories.length ? game.scan.runtimeLoader.modDirectories.join(", ") : "None found"}</p>
              <p>Gameplay controls: {game.scan.runtimeLoader.supported ? "Runtime profile support available" : "Not active"}</p>
              <p style={{ opacity: 0.78 }}>The app does not install loaders, inject DLLs, or alter game binaries. Game-specific runtime hooks must be verified before enabling gameplay changes.</p>
            </RuneSection>
          </div>

          <div style={{ marginTop: 16 }}>
            <RuneSection title="Gameplay Runtime Candidates">
              <p style={{ opacity: 0.78 }}>These symbols are present in Dawnwalker.exe and identify likely runtime targets. Presence does not yet prove a safe hook or editable value.</p>
              <div style={{ display: "grid", gap: 7 }}>
                {game.scan.gameplaySymbols.map((candidate) => (
                  <div key={candidate.symbol} style={{ display: "flex", justifyContent: "space-between", gap: 16, borderBottom: `1px solid ${theme.colors.divider}`, paddingBottom: 6 }}>
                    <span>{candidate.label} <small style={{ opacity: 0.7 }}>({candidate.symbol})</small><small style={{ display: "block", opacity: 0.62 }}>{candidate.targetGroup}</small></span>
                    <strong>{candidate.present ? "Found" : "Not found"}</strong>
                  </div>
                ))}
              </div>
            </RuneSection>
          </div>

          <div style={{ marginTop: 16 }}>
            <RuneSection title="Trainer Capability Map">
              <p style={{ opacity: 0.78 }}>Mapped from the verified FearLess trainer listing. The trainer backend is not connected to this app yet.</p>
              <div style={{ display: "grid", gap: 7 }}>
                {TRAINER_CAPABILITIES.map((capability) => (
                  <div key={`${capability.page}-${capability.control}`} style={{ display: "flex", justifyContent: "space-between", gap: 16, borderBottom: `1px solid ${theme.colors.divider}`, paddingBottom: 6 }}>
                    <span>{capability.page}: {capability.control}</span>
                    <strong>{capability.supported ? capability.trainerOption : "Unavailable"}</strong>
                  </div>
                ))}
              </div>
            </RuneSection>
          </div>

          <p style={{ marginTop: 16, opacity: 0.78 }}>
            This scan does not install, unpack, patch, or alter any game files. Mod installation remains unavailable until a supported format is verified.
          </p>
        </>
      )}
    </div>
  );
}