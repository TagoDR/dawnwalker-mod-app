const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("dawnwalker", {
	scanInstall: () => ipcRenderer.invoke("game:scan"),
	backupUserData: () => ipcRenderer.invoke("game:backup-user-data"),
	compareSaves: (leftName, rightName) => ipcRenderer.invoke("game:compare-saves", leftName, rightName),
	deployBridge: () => ipcRenderer.invoke("bridge:deploy"),
	bridgeStatus: () => ipcRenderer.invoke("bridge:status"),
	getBridgeCommandState: () => ipcRenderer.invoke("bridge:get-command"),
	applyLevel: (level) => ipcRenderer.invoke("bridge:apply-level", level),
	applyLevelCap: (cap) => ipcRenderer.invoke("bridge:apply-level-cap", cap),
	applyInfiniteHealth: (enabled) => ipcRenderer.invoke("bridge:apply-infinite-health", enabled),
	applyInfiniteStamina: (enabled) => ipcRenderer.invoke("bridge:apply-infinite-stamina", enabled),
	applySpeedMultiplier: (mult) => ipcRenderer.invoke("bridge:apply-speed", mult),
	applyJumpMultiplier: (mult) => ipcRenderer.invoke("bridge:apply-jump", mult),
	applyFovMultiplier: (mult) => ipcRenderer.invoke("bridge:apply-fov", mult),
	applyGameSpeed: (speed) => ipcRenderer.invoke("bridge:apply-game-speed", speed),
	applyDamageMultiplier: (mult) => ipcRenderer.invoke("bridge:apply-damage-multiplier", mult),
	nukeTarget: (amount) => ipcRenderer.invoke("bridge:nuke-target", amount),
	// Generic persistent field (infiniteBlood, noCooldowns, movementMode, difficulty, ...) - the
	// main process validates the key against an allowlist and clamps the value.
	applyBridgeField: (key, value) => ipcRenderer.invoke("bridge:apply-field", key, value),
	applyBridgePreset: (values) => ipcRenderer.invoke("bridge:apply-preset", values),
	// Forget every live setting and hand the game back its defaults.
	resetBridge: () => ipcRenderer.invoke("bridge:reset"),
	// One-shot action executed once by the Lua mod (grantXP, addCoins, killTarget, ...).
	runBridgeAction: (name, arg) => ipcRenderer.invoke("bridge:action", name, arg),
	deployNativeFix: () => ipcRenderer.invoke("nativefix:deploy"),
	nativeFixStatus: () => ipcRenderer.invoke("nativefix:status"),
	giveGearNative: (gearId) => ipcRenderer.invoke("nativefix:give-gear", gearId),
	removeGearNative: (gearId) => ipcRenderer.invoke("nativefix:remove-gear", gearId),
});
