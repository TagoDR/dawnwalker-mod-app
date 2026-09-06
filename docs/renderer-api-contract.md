# In-Engine HUD Menu & Rendering Specification

This document defines the in-engine user interface architecture and rendering contract of **DawnwalkerMod**.

---

## 1. Architectural Overview

In the legacy architecture, the user interface was an external Electron/React application rendering in Chromium and communicating over disk files.

In **DawnwalkerMod v2.0+**:
- **Canvas Overlay**: The UI is rendered directly onto the Unreal Engine viewport via the engine's `AHUD:ReceiveDrawHUD` event.
- **Zero Process Overhead**: No browser subprocesses, no WebView instances, and zero additional RAM overhead.
- **Input Integration**: Direct integration with UE4SS input hooks, supporting both keyboard navigation (Arrow Keys, Tab, Enter) and mouse cursor interaction.

---

## 2. Canvas Hook Architecture

The menu hooks into the Unreal Engine HUD rendering pipeline in [`main.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/main.lua):

```lua
RegisterHook("/Script/Engine.HUD:ReceiveDrawHUD", function(hudContext)
    local hud = hudContext:get()
    if not hud or not Safety.SafeIsValid(hud) then return end
    
    -- Forward HUD canvas context to HUD menu module
    Menu.Render(hud)
end)
```

### Canvas Primitives
All visual elements are drawn using native `AHUD` methods exposed to UE4SS Lua:
- `hud:DrawRect(Color, ScreenX, ScreenY, Width, Height)`: Renders flat rectangles for panels, borders, highlight bars, and sliders.
- `hud:DrawText(Text, Color, ScreenX, ScreenY, Font, Scale, bScalePosition)`: Renders text strings with custom colors and scaling.

### Color Palette Specification
The HUD menu uses an atmospheric dark fantasy color palette matching *The Blood of the Dawnwalker*'s aesthetic:

| Element | Color (RGBA / FLinearColor) | Visual Role |
| :--- | :--- | :--- |
| **Window Background** | `(R=0.03, G=0.03, B=0.04, A=0.92)` | High-contrast translucent dark backdrop |
| **Window Border** | `(R=0.60, G=0.10, B=0.10, A=1.00)` | Crimson border defining menu bounds |
| **Header Bar** | `(R=0.10, G=0.02, B=0.02, A=1.00)` | Deep blood-red header background |
| **Active Tab** | `(R=0.85, G=0.15, B=0.15, A=1.00)` | Bright crimson tab indicator |
| **Inactive Tab** | `(R=0.40, G=0.40, B=0.40, A=0.70)` | Muted gray tab title |
| **Selected Row** | `(R=0.30, G=0.05, B=0.05, A=0.75)` | Highlight bar for currently focused option |
| **Active Toggle (ON)** | `(R=0.20, G=0.85, B=0.30, A=1.00)` | Emerald green state badge |
| **Inactive Toggle (OFF)**| `(R=0.60, G=0.20, B=0.20, A=1.00)` | Dark crimson state badge |
| **Primary Text** | `(R=0.95, G=0.95, B=0.95, A=1.00)` | Pure white option labels |
| **Secondary Text** | `(R=0.65, G=0.65, B=0.70, A=0.90)` | Silver metadata & instructions |
| **Telemetry Accents** | `(R=0.90, G=0.75, B=0.30, A=1.00)` | Gold status badges (Day, Time, Level) |

---

## 3. Menu Layout & Component Model

The menu overlay is structured into five distinct vertical zones:

```text
+-------------------------------------------------------------------------+
| [HEADER] DawnwalkerMod v2.0 | In-Engine Control Panel              [X] |
+-------------------------------------------------------------------------+
| [TABS] [1. Combat] [2. Character] [3. Movement] [4. Skills] ...         |
+-------------------------------------------------------------------------+
| [CONTENT AREA]                                                          |
|  > [ON ] God Mode (Infinite Health)               [ENTER] Toggle        |
|    [OFF] Infinite Stamina                         [ENTER] Toggle        |
|    [---] Walk Speed Multiplier: < 1.50x >         [LEFT/RIGHT] Adjust   |
|    [ACT] Instant Full Heal & Blood Replenish      [ENTER] Execute       |
|    ... (scrollable rows)                                                |
+-------------------------------------------------------------------------+
| [TELEMETRY FOOTER]                                                      |
| Level: 45 | XP: 3400/5000 | Day: 3 | Time: 21:40 | Hostiles: 2 | OK     |
+-------------------------------------------------------------------------+
| [KEY HINTS] [Tab] Next Tab | [Arrows] Navigate/Adjust | [F1/Esc] Close  |
+-------------------------------------------------------------------------+
```

### Component Types
1. **Toggle Row**: Controls boolean features in `State.Toggles`. Displays `[ ON ]` or `[ OFF ]`. Pressing `Enter` toggles state.
2. **Slider / Stepper Row**: Controls numeric multipliers in `State.Multipliers` or `State.Gameplay`. Displays `< Value >`. Pressing `Left` / `Right` steps the value within defined minimum and maximum bounds.
3. **Action Button Row**: Triggers one-shot actions (e.g. `Heal Now`, `Kill Hostiles`, `Unlock All Traits`). Pressing `Enter` executes the function and displays visual feedback.
4. **Catalog Item Row**: Lists cataloged weapons, armor sets, and consumables with item category badges and granting triggers.

---

## 4. Input Handling & State Machine

Input processing is handled by [`ui/keybinds.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/ui/keybinds.lua) and [`ui/hud_menu.lua`](file:///C:/Users/Admin/WebstormProjects/dawnwalker-mod-app-master/runtime-mods/DawnwalkerMod/Scripts/ui/hud_menu.lua):

### Menu Toggle (`F1` / `dw_menu`)
- When opened:
  1. Sets `Menu.IsOpen = true`.
  2. Acquires the local `APlayerController`.
  3. Enables `bShowMouseCursor = true` and `bEnableClickEvents = true` so the player can interact directly.
- When closed:
  1. Sets `Menu.IsOpen = false`.
  2. Restores `bShowMouseCursor = false` and `bEnableClickEvents = false`.
  3. Restores input focus to game movement and camera controls.

### Navigation Controls
| Key | Context | Action |
| :--- | :--- | :--- |
| **`Tab`** | Any | Cycles forward through the 7 category tabs |
| **`Up Arrow`** | Content Area | Moves selection cursor to the previous row |
| **`Down Arrow`** | Content Area | Moves selection cursor to the next row |
| **`Left Arrow`** | Multiplier / Stepper | Decrements value by defined step size |
| **`Right Arrow`**| Multiplier / Stepper | Increments value by defined step size |
| **`Enter` / `E`**| Toggle / Action | Toggles boolean or executes one-shot action |
| **`Escape` / `F1`**| Menu Open | Closes the menu overlay |

---

## 5. Viewport Adaptation & Resolution Independence

The menu layout dynamically adapts to the current viewport dimensions:
- Dimensions are derived per-frame from `hud.Canvas.SizeX` and `hud.Canvas.SizeY`.
- Default menu dimensions are pinned to `Width = 720px`, `Height = 560px`, centered horizontally and vertically on screen.
- Text scaling automatically clamps so text remains legible across 1080p, 1440p, and 4K viewports without clipping.
