import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";
import DWSlider from "../components/ui/DWSlider";
import DWSelect from "../components/ui/DWSelect";
import DWButton from "../components/ui/DWButton";

import { useBridge, commandNumber, commandString } from "../bridge/useBridge";
import BridgePanel, { Readouts, ButtonRow, Note } from "../bridge/BridgePanel";

const MOVEMENT_MODES = [
  { value: "walk", label: "Walk (normal)" },
  { value: "fly", label: "Fly" },
  { value: "ghost", label: "Ghost (fly + no collision)" },
];

export default function MovementPage() {
  const api = useBridge();
  const { status, command, busy, applyField, runAction } = api;

  return (
    <div>
      <PageHeader title="Movement & Camera" />

      <RuneStagger index={0}>
        <BridgePanel
          bridgeApi={api}
          intro="Movement, camera and time scale - applied live via the player's CharacterMovementComponent, PlayerCameraManager and the engine CheatManager."
        >
          <RuneStagger index={1}>
            <RuneSection title="Movement">
              <Readouts items={[["Movement component", status?.movementFound === "1" ? "tracked" : "not found yet"]]} />
              <DWSlider
                label="Player Speed Multiplier"
                value={commandNumber(command, "speedMultiplier", 1)}
                onChange={(v) => applyField("speedMultiplier", v)}
                min={0.1}
                max={5}
                step={0.1}
              />
              <DWSlider
                label="Jump Height Multiplier"
                value={commandNumber(command, "jumpMultiplier", 1)}
                onChange={(v) => applyField("jumpMultiplier", v)}
                min={0.1}
                max={5}
                step={0.1}
              />
              <DWSelect
                label="Movement Mode"
                value={commandString(command, "movementMode", "walk")}
                onChange={(v) => applyField("movementMode", v)}
                options={MOVEMENT_MODES}
              />
              <Note>
                Fly and Ghost are the engine's own cheat modes; switch back to Walk to land. They re-apply after
                every respawn while selected.
              </Note>
              <ButtonRow>
                <DWButton
                  label="Teleport to Aim Point"
                  disabled={busy}
                  onClick={() => runAction("teleport", null, "Teleport sent to the game.")}
                  data-clickpulse
                  data-glow
                />
              </ButtonRow>
            </RuneSection>
          </RuneStagger>

          <RuneStagger index={2}>
            <RuneSection title="Camera & Time Scale">
              <DWSlider
                label="Field of View Multiplier"
                value={commandNumber(command, "fovMultiplier", 1)}
                onChange={(v) => applyField("fovMultiplier", v)}
                min={0.1}
                max={5}
                step={0.1}
              />
              <DWSlider
                label="Game Speed"
                value={commandNumber(command, "gameSpeed", 1)}
                onChange={(v) => applyField("gameSpeed", v)}
                min={0.1}
                max={4}
                step={0.1}
              />
              <Note>Game Speed uses the engine's Slomo time dilation; 1.0 is normal speed. The resulting FOV must stay within 10–170°, so multipliers that push past that are rejected by the mod.</Note>
            </RuneSection>
          </RuneStagger>
        </BridgePanel>
      </RuneStagger>
    </div>
  );
}
