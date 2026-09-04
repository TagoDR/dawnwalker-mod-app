const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("dawnwalker", {
	scanInstall: () => ipcRenderer.invoke("game:scan"),
	backupUserData: () => ipcRenderer.invoke("game:backup-user-data"),
	compareSaves: (leftName, rightName) => ipcRenderer.invoke("game:compare-saves", leftName, rightName),
	deployBridge: () => ipcRenderer.invoke("bridge:deploy"),
	bridgeStatus: () => ipcRenderer.invoke("bridge:status"),
	applyLevel: (level) => ipcRenderer.invoke("bridge:apply-level", level),
	applyLevelCap: (cap) => ipcRenderer.invoke("bridge:apply-level-cap", cap),
	applyInfiniteHealth: (enabled) => ipcRenderer.invoke("bridge:apply-infinite-health", enabled),
	applyInfiniteStamina: (enabled) => ipcRenderer.invoke("bridge:apply-infinite-stamina", enabled),
	applySpeedMultiplier: (mult) => ipcRenderer.invoke("bridge:apply-speed", mult),
	applyJumpMultiplier: (mult) => ipcRenderer.invoke("bridge:apply-jump", mult),
	applyFovMultiplier: (mult) => ipcRenderer.invoke("bridge:apply-fov", mult),
	applyGameSpeed: (speed) => ipcRenderer.invoke("bridge:apply-game-speed", speed),
	applyDamageMultiplier: (mult) => ipcRenderer.invoke("bridge:apply-damage-multiplier", mult),
});
