const { app, BrowserWindow, dialog, ipcMain } = require("electron");
const fs = require("fs");
const os = require("os");
const path = require("path");

const devServerUrl = process.env.VITE_DEV_SERVER_URL;
const STEAM_APP_ID = "3751260";

function readText(filePath) {
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch {
    return null;
  }
}

function isDawnwalkerRunning() {
  try {
    const output = require("child_process").execFileSync(
      "tasklist",
      ["/FI", "IMAGENAME eq Dawnwalker.exe", "/NH"],
      { encoding: "utf8" }
    );
    return output.toLowerCase().includes("dawnwalker.exe");
  } catch {
    return false;
  }
}

function isCheatEvolutionRunning() {
  try {
    const output = require("child_process").execFileSync(
      "tasklist",
      ["/FI", "IMAGENAME eq CheatEvolution.exe", "/NH"],
      { encoding: "utf8" }
    );
    return output.toLowerCase().includes("cheatevolution.exe");
  } catch {
    return false;
  }
}

function vdfValue(content, key) {
  const match = content?.match(new RegExp(`"${key}"\\s*"([^"]+)"`, "i"));
  return match?.[1] ?? null;
}

function resolveGameRoot(installPath) {
  const candidates = [installPath, path.join(installPath, "Dawnwalker")];
  return candidates.find((candidate) => (
    fs.existsSync(path.join(candidate, "Content", "Paks"))
    || fs.existsSync(path.join(candidate, "Binaries", "Win64"))
  )) || installPath;
}

function steamLibraryPaths() {
  const steamRoots = [
    path.join(process.env.PROGRAMFILES_X86 || "C:\\Program Files (x86)", "Steam"),
    path.join(process.env.PROGRAMFILES || "C:\\Program Files", "Steam"),
    path.join(os.homedir(), "AppData", "Local", "Steam"),
  ];
  const libraries = new Set(steamRoots.filter((steamPath) => fs.existsSync(steamPath)));

  for (const steamPath of steamRoots) {
    const libraryFile = path.join(steamPath, "steamapps", "libraryfolders.vdf");
    const content = readText(libraryFile);
    const pathPattern = /"path"\s*"([^"]+)"/gi;
    for (const match of content?.matchAll(pathPattern) || []) {
      libraries.add(match[1].replace(/\\\\/g, "\\"));
    }
  }

  return [...libraries];
}

function collectModdingFiles(gameRoot) {
  const extensions = new Set([".pak", ".utoc", ".ucas", ".ini", ".uplugin", ".exe", ".dll"]);
  const files = [];

  function visit(directory) {
    let entries;
    try {
      entries = fs.readdirSync(directory, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const absolutePath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        visit(absolutePath);
        continue;
      }

      const extension = path.extname(entry.name).toLowerCase();
      if (!entry.isFile() || !extensions.has(extension)) continue;

      try {
        const stats = fs.statSync(absolutePath);
        files.push({
          relativePath: path.relative(gameRoot, absolutePath).split(path.sep).join("/"),
          extension,
          sizeBytes: stats.size,
          modifiedAt: stats.mtime.toISOString(),
        });
      } catch {
        // A file can disappear while the read-only scan is in progress.
      }
    }
  }

  visit(gameRoot);
  return files.sort((left, right) => left.relativePath.localeCompare(right.relativePath));
}

function inspectUserData() {
  const userRoot = path.join(process.env.LOCALAPPDATA || "", "Dawnwalker");
  const saveRoot = path.join(userRoot, "Saved");
  const configRoot = path.join(saveRoot, "Config", "Windows");
  const saveDirectory = path.join(saveRoot, "SaveGames");
  const saveFiles = fs.existsSync(saveDirectory)
    ? fs.readdirSync(saveDirectory, { withFileTypes: true })
      .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".sav"))
      .map((entry) => {
        const filePath = path.join(saveDirectory, entry.name);
        let sizeBytes = 0;
        let format = "Unknown";
        try {
          sizeBytes = fs.statSync(filePath).size;
          const signature = Buffer.alloc(4);
          const descriptor = fs.openSync(filePath, "r");
          try {
            fs.readSync(descriptor, signature, 0, signature.length, 0);
          } finally {
            fs.closeSync(descriptor);
          }
          if (signature.toString("ascii") === "GVAS") format = "Unreal GVAS";
          if (signature.toString("ascii") === "DSAV") format = "Dawnwalker DSAV";
        } catch {
          format = "Unreadable";
        }
        return { name: entry.name, sizeBytes, format };
      })
    : [];
  const configFiles = fs.existsSync(configRoot)
    ? fs.readdirSync(configRoot, { withFileTypes: true })
      .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".ini"))
      .map((entry) => entry.name)
    : [];
  const settingsSave = saveFiles.find((file) => file.name === "RebelSettings.sav");
  const settingsPath = settingsSave ? path.join(saveDirectory, settingsSave.name) : null;
  const settingsProperties = [];
  if (settingsPath) {
    try {
      const settingsText = fs.readFileSync(settingsPath, "latin1");
      const propertyPattern = /(?:Game|Controls|Video|Audio)_[A-Za-z0-9_]+/g;
      for (const match of settingsText.matchAll(propertyPattern)) {
        if (!settingsProperties.includes(match[0])) settingsProperties.push(match[0]);
      }
    } catch {
      // Property names are optional metadata for the read-only scan.
    }
  }
  const settingsCandidates = [
    ["Difficulty", "Game_Difficulty_DifficultyLevel"],
    ["Combat rules", "Game_Difficulty_Combat"],
    ["Time limit", "Game_Difficulty_TimeLimit"],
    ["Inventory during combat", "Game_Difficulty_AllowInventoryConsumptionDuringCombat"],
  ].map(([label, property]) => ({
    label,
    property,
    present: settingsProperties.includes(property),
  }));

  return {
    root: userRoot,
    exists: fs.existsSync(userRoot),
    saveRoot,
    saveFiles,
    configRoot,
    configFiles,
    settingsProperties,
    settingsCandidates,
  };
}

function inspectRuntimeLoader(gameRoot) {
  const binaryRoot = path.join(gameRoot, "Binaries", "Win64");
  const loaderRoot = fs.existsSync(path.join(binaryRoot, "ue4ss"))
    ? path.join(binaryRoot, "ue4ss")
    : binaryRoot;
  const markerNames = ["UE4SS.dll", "UE4SS-settings.ini", "UE4SS.log"];
  const foundMarkers = markerNames.filter((name) => fs.existsSync(path.join(loaderRoot, name)));
  const modDirectories = ["Mods", "~mods"].filter((name) => (
    fs.existsSync(path.join(binaryRoot, name)) || fs.existsSync(path.join(gameRoot, name))
  ));

  return {
    binaryRoot,
    loaderRoot,
    foundMarkers,
    modDirectories,
    detected: foundMarkers.includes("UE4SS.dll"),
    supported: foundMarkers.includes("UE4SS.dll"),
    status: foundMarkers.includes("UE4SS.log") && readText(path.join(loaderRoot, "UE4SS.log"))?.includes("PS scan successful")
      ? "Runtime loader initialized successfully"
      : foundMarkers.includes("UE4SS.dll")
        ? "Runtime loader detected; game-specific hooks are not configured"
      : modDirectories.length > 0
        ? "Mod directory detected, but no supported runtime loader was found"
        : "No supported runtime loader detected",
  };
}

function findGameplaySymbols(gameRoot) {
  const executablePath = path.join(gameRoot, "Binaries", "Win64", "Dawnwalker.exe");
  const symbols = [
    ["Experience gained event", "OnExperienceGained", "Experience / progression"],
    ["Experience changed event", "OnExperienceChanged", "Experience / progression"],
    ["Experience notification", "PushExperienceNotification", "Experience / progression"],
    ["Skill tree setter", "SetOpenedSkillTree", "Skill tree / abilities"],
    ["Skill tree getter", "GetOpenedSkillTree", "Skill tree / abilities"],
    ["Quest skill rewards", "ReceiveQuestSkillRewards", "Skill tree / abilities"],
    ["Skill unlock property", "bUnlockSkills", "Skill tree / abilities"],
    ["Level XP table", "LevelExperienceRequirementTable", "Experience / progression"],
  ];
  try {
    const executableText = fs.readFileSync(executablePath).toString("ascii");
    return symbols.map(([label, symbol, targetGroup]) => ({ label, symbol, targetGroup, present: executableText.includes(symbol) }));
  } catch {
    return symbols.map(([label, symbol, targetGroup]) => ({ label, symbol, targetGroup, present: false }));
  }
}

function backupUserData() {
  const userRoot = path.join(process.env.LOCALAPPDATA || "", "Dawnwalker");
  const saveRoot = path.join(userRoot, "Saved");
  if (!fs.existsSync(saveRoot)) {
    return { ok: false, error: "Dawnwalker user data was not found" };
  }

  const gameProcess = require("child_process").execFileSync("tasklist", ["/FI", "IMAGENAME eq Dawnwalker.exe", "/NH"], { encoding: "utf8" });
  if (gameProcess.toLowerCase().includes("dawnwalker.exe")) {
    return { ok: false, error: "Close Dawnwalker before creating a backup" };
  }

  const backupRoot = path.join(app.getPath("userData"), "backups", `Dawnwalker-${new Date().toISOString().replace(/[:.]/g, "-")}`);
  const copiedFiles = [];
  const directories = [path.join(saveRoot, "SaveGames"), path.join(saveRoot, "Config", "Windows")];
  for (const sourceDirectory of directories) {
    if (!fs.existsSync(sourceDirectory)) continue;
    const relativeDirectory = path.relative(saveRoot, sourceDirectory);
    const destinationDirectory = path.join(backupRoot, relativeDirectory);
    fs.mkdirSync(destinationDirectory, { recursive: true });
    for (const entry of fs.readdirSync(sourceDirectory, { withFileTypes: true })) {
      if (!entry.isFile()) continue;
      const source = path.join(sourceDirectory, entry.name);
      const destination = path.join(destinationDirectory, entry.name);
      fs.copyFileSync(source, destination, fs.constants.COPYFILE_EXCL);
      copiedFiles.push(path.relative(backupRoot, destination).split(path.sep).join("/"));
    }
  }

  return { ok: true, backupRoot, copiedFiles };
}

function compareSaves(leftName, rightName) {
  const saveRoot = path.join(process.env.LOCALAPPDATA || "", "Dawnwalker", "Saved", "SaveGames");
  const safeName = (name) => typeof name === "string" && path.basename(name) === name && name.toLowerCase().endsWith(".sav");
  if (!safeName(leftName) || !safeName(rightName)) return { ok: false, error: "Invalid save selection" };

  const leftPath = path.join(saveRoot, leftName);
  const rightPath = path.join(saveRoot, rightName);
  if (!fs.existsSync(leftPath) || !fs.existsSync(rightPath)) return { ok: false, error: "Selected save was not found" };

  const left = fs.readFileSync(leftPath);
  const right = fs.readFileSync(rightPath);
  const limit = Math.min(left.length, right.length);
  const ranges = [];
  let changedBytes = 0;
  let rangeStart = -1;
  for (let offset = 0; offset < limit; offset++) {
    if (left[offset] !== right[offset]) {
      changedBytes += 1;
      if (rangeStart < 0) rangeStart = offset;
    } else if (rangeStart >= 0) {
      ranges.push({ start: rangeStart, end: offset - 1, length: offset - rangeStart });
      rangeStart = -1;
    }
  }
  if (rangeStart >= 0) ranges.push({ start: rangeStart, end: limit - 1, length: limit - rangeStart });

  return {
    ok: true,
    left: { name: leftName, sizeBytes: left.length },
    right: { name: rightName, sizeBytes: right.length },
    changedRanges: ranges.slice(0, 100),
    totalChangedRanges: ranges.length,
    changedBytes,
    trailingBytes: Math.abs(left.length - right.length),
  };
}

function inspectIoStoreToc(gameRoot, tocPath) {
  const header = Buffer.alloc(108);
  let fileDescriptor;
  try {
    fileDescriptor = fs.openSync(tocPath, "r");
    fs.readSync(fileDescriptor, header, 0, header.length, 0);
  } catch (error) {
    return {
      relativePath: path.relative(gameRoot, tocPath).split(path.sep).join("/"),
      readable: false,
      error: error.code || "read-failed",
    };
  } finally {
    if (fileDescriptor !== undefined) fs.closeSync(fileDescriptor);
  }

  const magic = header.subarray(0, 4).toString("ascii");
  const relativePath = path.relative(gameRoot, tocPath).split(path.sep).join("/");
  if (magic !== "-==-" || header.readUInt32LE(20) < 108) {
    return {
      relativePath,
      readable: false,
      magic,
      error: "unsupported-toc-header",
    };
  }

  return {
    relativePath,
    readable: true,
    magic,
    version: header.readUInt32LE(16),
    headerSize: header.readUInt32LE(20),
    tocEntryCount: header.readUInt32LE(24),
    compressedBlockCount: header.readUInt32LE(28),
    compressedBlockEntrySize: header.readUInt32LE(32),
    compressionMethodCount: header.readUInt32LE(36),
    compressionMethodNameLength: header.readUInt32LE(40),
    compressionBlockSize: header.readUInt32LE(44),
    directoryIndexSize: header.readUInt32LE(48),
    partitionCount: header.readUInt32LE(52),
    containerFlags: header.readUInt8(80),
    encryptionMethod: header.readUInt8(81),
    perfectHashSeedCount: header.readUInt32LE(84),
    partitionSize: Number(header.readBigUInt64LE(88)),
    chunksWithoutPerfectHashCount: header.readUInt32LE(96),
    compressed: (header.readUInt8(80) & 1) !== 0,
    encrypted: (header.readUInt8(80) & 2) !== 0,
    signed: (header.readUInt8(80) & 4) !== 0,
    indexed: (header.readUInt8(80) & 8) !== 0,
    directoryIndex: "Directory index is present; package-path decoding is not enabled",
  };
}

function inspectInstall(installPath, manifestPath = null) {
  const gameRoot = resolveGameRoot(installPath);
  const binaryPath = path.join(gameRoot, "Binaries", "Win64");
  const executableFiles = fs.existsSync(binaryPath)
    ? fs.readdirSync(binaryPath, { withFileTypes: true })
      .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".exe"))
      .map((entry) => path.join("Binaries", "Win64", entry.name))
    : [];
  const paksPath = path.join(gameRoot, "Content", "Paks");
  const pakFiles = fs.existsSync(paksPath)
    ? fs.readdirSync(paksPath, { withFileTypes: true })
      .filter((entry) => entry.isFile())
      .map((entry) => entry.name)
    : [];
  const extensionCount = (extension) => pakFiles.filter((file) => file.toLowerCase().endsWith(extension)).length;
  const savedConfigPath = path.join(gameRoot, "Saved", "Config", "Windows");
  const manifest = manifestPath ? readText(manifestPath) : null;
  const inventory = collectModdingFiles(gameRoot);
  const userData = inspectUserData();
  const runtimeLoader = inspectRuntimeLoader(gameRoot);
  const gameplaySymbols = findGameplaySymbols(gameRoot);
  const tocInspections = fs.existsSync(paksPath)
    ? pakFiles
      .filter((file) => file.toLowerCase().endsWith(".utoc"))
      .map((file) => inspectIoStoreToc(gameRoot, path.join(paksPath, file)))
    : [];
  const inventorySummary = inventory.reduce((summary, file) => {
    summary[file.extension] = (summary[file.extension] || 0) + 1;
    return summary;
  }, {});

  return {
    installed: true,
    appId: STEAM_APP_ID,
    path: installPath,
    gameRoot,
    gameName: vdfValue(manifest, "name") || path.basename(installPath),
    buildId: vdfValue(manifest, "buildid"),
    gameRunning: isDawnwalkerRunning(),
    trainerRunning: isCheatEvolutionRunning(),
    executableFiles,
    inventory,
    inventorySummary,
    userData,
    runtimeLoader,
    gameplaySymbols,
    tocInspections,
    signals: {
      unrealPackDirectory: fs.existsSync(paksPath),
      pakFiles: extensionCount(".pak"),
      ioStoreTocFiles: extensionCount(".utoc"),
      ioStoreDataFiles: extensionCount(".ucas"),
      pluginsDirectory: fs.existsSync(path.join(gameRoot, "Plugins")),
      modDirectory: ["Mods", "~mods"].find((directory) => fs.existsSync(path.join(gameRoot, directory))) || null,
      userConfigDirectory: userData.configFiles.length > 0 || fs.existsSync(savedConfigPath),
      easyAntiCheat: fs.existsSync(path.join(installPath, "EasyAntiCheat")),
    },
  };
}

function scanSteamInstall() {
  for (const libraryPath of steamLibraryPaths()) {
    const steamAppsPath = path.join(libraryPath, "steamapps");
    const manifestPath = path.join(steamAppsPath, `appmanifest_${STEAM_APP_ID}.acf`);
    const manifest = readText(manifestPath);
    if (!manifest) continue;

    const installDirectory = vdfValue(manifest, "installdir");
    if (!installDirectory) continue;
    const installPath = path.join(steamAppsPath, "common", installDirectory);
    if (fs.existsSync(installPath)) return inspectInstall(installPath, manifestPath);
  }

  return { installed: false, appId: STEAM_APP_ID, path: null };
}

// --- Live mod bridge (UE4SS) ---
// Cached so apply/status calls don't have to re-run a full install scan every time.
let cachedGameRoot = null;

function resolveCachedGameRoot() {
  if (cachedGameRoot && fs.existsSync(cachedGameRoot)) return cachedGameRoot;
  const scan = scanSteamInstall();
  cachedGameRoot = scan.installed ? scan.gameRoot : null;
  return cachedGameRoot;
}

function getBridgePaths() {
  const gameRoot = resolveCachedGameRoot();
  if (!gameRoot) return null;
  const modsDir = path.join(gameRoot, "Binaries", "Win64", "Mods");
  const bridgeDir = path.join(modsDir, "DawnwalkerModBridge");
  return {
    gameRoot,
    modsDir,
    bridgeDir,
    scriptsDir: path.join(bridgeDir, "Scripts"),
    commandFile: path.join(bridgeDir, "command.txt"),
    statusFile: path.join(bridgeDir, "status.txt"),
    mainLuaSource: path.join(__dirname, "runtime-mods", "DawnwalkerModBridge", "Scripts", "main.lua"),
  };
}

function ensureBridgeEnabledInModsTxt(modsDir) {
  const modsTxtPath = path.join(modsDir, "mods.txt");
  const content = readText(modsTxtPath) || "";
  if (/^\s*DawnwalkerModBridge\s*:/m.test(content)) {
    if (/^\s*DawnwalkerModBridge\s*:\s*0/m.test(content)) {
      fs.writeFileSync(modsTxtPath, content.replace(/^\s*DawnwalkerModBridge\s*:\s*0/m, "DawnwalkerModBridge : 1"));
    }
    return;
  }
  const separator = content.length > 0 && !content.endsWith("\n") ? "\n" : "";
  fs.writeFileSync(modsTxtPath, `${content}${separator}DawnwalkerModBridge : 1\n`);
}

function deployBridge() {
  const paths = getBridgePaths();
  if (!paths) return { ok: false, error: "Game install was not found" };
  if (!fs.existsSync(paths.modsDir)) {
    return { ok: false, error: "UE4SS Mods directory was not found; install UE4SS before deploying the bridge" };
  }

  try {
    fs.mkdirSync(paths.scriptsDir, { recursive: true });
    fs.copyFileSync(paths.mainLuaSource, path.join(paths.scriptsDir, "main.lua"));
    ensureBridgeEnabledInModsTxt(paths.modsDir);
    return { ok: true, bridgeDir: paths.bridgeDir };
  } catch (error) {
    return { ok: false, error: error.message || "Failed to deploy the bridge mod" };
  }
}

function isBridgeDeployed() {
  const paths = getBridgePaths();
  if (!paths) return false;
  return fs.existsSync(path.join(paths.scriptsDir, "main.lua"));
}

let bridgeRequestCounter = 0;
// Full desired-state, always written in full so one apply call never clobbers another's fields.
let bridgeState = {};

function writeBridgeCommand(patch) {
  const paths = getBridgePaths();
  if (!paths) return { ok: false, error: "Game install was not found" };
  if (!isBridgeDeployed()) return { ok: false, error: "Bridge mod is not deployed yet" };

  bridgeState = { ...bridgeState, ...patch };

  try {
    fs.mkdirSync(paths.bridgeDir, { recursive: true });
    const lines = Object.entries(bridgeState)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => `${key}=${value}`);
    fs.writeFileSync(paths.commandFile, `${lines.join("\n")}\n`);
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error.message || "Failed to write bridge command" };
  }
}

function applyPlayerLevel(level) {
  // Clamped to 99: the game's level/XP requirement tables don't have entries above that,
  // and ForceLevelUpTo() with a higher level reads past the end of the table and crashes the game.
  const numericLevel = Math.max(1, Math.min(99, Math.floor(Number(level))));
  if (!Number.isFinite(numericLevel)) return { ok: false, error: "Invalid level" };
  bridgeRequestCounter += 1;
  return writeBridgeCommand({ requestId: bridgeRequestCounter, setLevel: numericLevel });
}

function applyLevelCap(cap) {
  const numericCap = Math.max(1, Math.min(99, Math.floor(Number(cap))));
  if (!Number.isFinite(numericCap)) return { ok: false, error: "Invalid level cap" };
  return writeBridgeCommand({ levelCap: numericCap });
}

function applyInfiniteHealth(enabled) {
  return writeBridgeCommand({ infiniteHealth: enabled ? 1 : 0 });
}

function applyInfiniteStamina(enabled) {
  return writeBridgeCommand({ infiniteStamina: enabled ? 1 : 0 });
}

function applySpeedMultiplier(mult) {
  const numericMult = Math.max(0.1, Math.min(5, Number(mult)));
  if (!Number.isFinite(numericMult)) return { ok: false, error: "Invalid speed multiplier" };
  return writeBridgeCommand({ speedMultiplier: numericMult });
}

function applyJumpMultiplier(mult) {
  const numericMult = Math.max(0.1, Math.min(5, Number(mult)));
  if (!Number.isFinite(numericMult)) return { ok: false, error: "Invalid jump multiplier" };
  return writeBridgeCommand({ jumpMultiplier: numericMult });
}

function applyFovMultiplier(mult) {
  const numericMult = Math.max(0.1, Math.min(5, Number(mult)));
  if (!Number.isFinite(numericMult)) return { ok: false, error: "Invalid FOV multiplier" };
  return writeBridgeCommand({ fovMultiplier: numericMult });
}

function applyGameSpeed(speed) {
  const numericSpeed = Math.max(0.1, Math.min(4, Number(speed)));
  if (!Number.isFinite(numericSpeed)) return { ok: false, error: "Invalid game speed" };
  return writeBridgeCommand({ gameSpeed: numericSpeed });
}

function applyDamageMultiplier(mult) {
  const numericMult = Math.max(0.1, Math.min(50, Number(mult)));
  if (!Number.isFinite(numericMult)) return { ok: false, error: "Invalid damage multiplier" };
  return writeBridgeCommand({ damageMultiplier: numericMult });
}

function readBridgeStatus() {
  const paths = getBridgePaths();
  if (!paths) return { ok: false, error: "Game install was not found", deployed: false, gameRunning: isDawnwalkerRunning() };
  const deployed = isBridgeDeployed();
  const content = readText(paths.statusFile);
  const gameRunning = isDawnwalkerRunning();
  if (!content) return { ok: false, deployed, gameRunning, error: gameRunning ? "No status yet; is the game running with the bridge mod enabled?" : "Game is not running" };

  const status = {};
  for (const line of content.split(/\r?\n/)) {
    const [key, ...rest] = line.split("=");
    if (!key) continue;
    status[key] = rest.join("=");
  }
  return { ok: status.ok === "1", deployed, gameRunning, ...status };
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 960,
    minHeight: 640,
    backgroundColor: "#0a0a0a",
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  win.once("ready-to-show", () => {
    win.show();
    win.focus();
  });

  win.webContents.on("did-fail-load", (_event, errorCode, errorDescription, validatedURL) => {
    dialog.showErrorBox(
      "Dawnwalker Mod App could not load",
      `The app window could not load (${errorCode}: ${errorDescription}).\n\n${validatedURL}`
    );
  });

  if (devServerUrl) {
    win.loadURL(devServerUrl);
  } else {
    win.loadFile(path.join(__dirname, "ui", "dist", "index.html"));
  }
}

app.whenReady().then(() => {
  ipcMain.handle("game:scan", () => {
    const scan = scanSteamInstall();
    cachedGameRoot = scan.installed ? scan.gameRoot : null;
    return scan;
  });
  ipcMain.handle("game:backup-user-data", () => backupUserData());
  ipcMain.handle("game:compare-saves", (_event, leftName, rightName) => compareSaves(leftName, rightName));
  ipcMain.handle("bridge:deploy", () => deployBridge());
  ipcMain.handle("bridge:status", () => readBridgeStatus());
  ipcMain.handle("bridge:apply-level", (_event, level) => applyPlayerLevel(level));
  ipcMain.handle("bridge:apply-level-cap", (_event, cap) => applyLevelCap(cap));
  ipcMain.handle("bridge:apply-infinite-health", (_event, enabled) => applyInfiniteHealth(enabled));
  ipcMain.handle("bridge:apply-infinite-stamina", (_event, enabled) => applyInfiniteStamina(enabled));
  ipcMain.handle("bridge:apply-speed", (_event, mult) => applySpeedMultiplier(mult));
  ipcMain.handle("bridge:apply-jump", (_event, mult) => applyJumpMultiplier(mult));
  ipcMain.handle("bridge:apply-fov", (_event, mult) => applyFovMultiplier(mult));
  ipcMain.handle("bridge:apply-game-speed", (_event, speed) => applyGameSpeed(speed));
  ipcMain.handle("bridge:apply-damage-multiplier", (_event, mult) => applyDamageMultiplier(mult));
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
