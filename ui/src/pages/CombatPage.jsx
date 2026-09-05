import { useState } from "react";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";
import DWSlider from "../components/ui/DWSlider";
import DWToggle from "../components/ui/DWToggle";
import DWSelect from "../components/ui/DWSelect";
import DWButton from "../components/ui/DWButton";

import { useBridge, commandFlag, commandNumber, commandString } from "../bridge/useBridge";
import BridgePanel, { Readouts, ActionRow, ButtonRow, Note } from "../bridge/BridgePanel";

// EDWDifficultyLevel (DogwoodStats) - the game's own labels for the fourth tier is "NewHard".
const DIFFICULTY_LEVELS = [
  { value: "0", label: "Story" },
  { value: "1", label: "Normal" },
  { value: "2", label: "Immersive" },
  { value: "3", label: "Hard" },
];

export default function CombatPage() {
  const api = useBridge();
  const { bridge, status, command, busy, setBusy, setMessage, applyField, runAction } = api;
  const [nukeAmount, setNukeAmount] = useState(5000);

  const handleNuke = async () => {
    setBusy(true);
    setMessage(null);
    const result = await bridge.nukeTarget(nukeAmount);
    setMessage(result.ok ? "Damage request sent to the game." : result.error);
    setBusy(false);
  };

  return (
    <div>
      <PageHeader title="Combat" />

      <RuneStagger index={0}>
        <BridgePanel
          bridgeApi={api}
          intro="Survivability, damage and difficulty - applied live via the player's CombatComponentBase, BloodBarComponent, CombatSubsystem and the engine CheatManager."
        >
          <RuneStagger index={1}>
            <RuneSection title="Survivability">
              <Readouts
                items={[
                  ["Health", status?.healthPercent !== undefined ? `${Math.round(Number(status.healthPercent) * 100)}%` : undefined],
                  ["Stamina", status?.staminaPercent !== undefined ? `${Math.round(Number(status.staminaPercent) * 100)}%` : undefined],
                  ["Blood", status?.blood],
                  ["In combat", status?.inCombat === "1" ? "Yes" : "No"],
                  ["Aggressive enemies", status?.aggressiveNpcCount],
                ]}
              />
              <DWToggle label="Infinite Health" value={commandFlag(command, "infiniteHealth")} onChange={(v) => applyField("infiniteHealth", v)} />
              <DWToggle label="Infinite Stamina" value={commandFlag(command, "infiniteStamina")} onChange={(v) => applyField("infiniteStamina", v)} />
              <DWToggle label="Infinite Blood" value={commandFlag(command, "infiniteBlood")} onChange={(v) => applyField("infiniteBlood", v)} />
              <Note>
                Infinite Blood keeps the vampire blood bar full and locked (same mechanism the game uses for stamina locks).
              </Note>
              <ButtonRow>
                <DWButton label="Heal Now" disabled={busy} onClick={() => runAction("healNow", null, "Heal sent to the game.")} data-clickpulse data-glow />
                <DWButton label="Replenish Blood" disabled={busy} onClick={() => runAction("refillBlood", null, "Blood refill sent to the game.")} />
              </ButtonRow>
            </RuneSection>
          </RuneStagger>

          <RuneStagger index={2}>
            <RuneSection title="Enemies">
              <ButtonRow>
                <DWButton label="Kill Locked Target" disabled={busy} onClick={() => runAction("killTarget", null, "Kill request sent to the game.")} data-clickpulse data-glow />
                <DWButton label="Kill All Aggressive Enemies" disabled={busy} onClick={() => runAction("killAllAggressive", null, "Kill-all request sent to the game.")} />
              </ButtonRow>
              <Note>
                Kill Locked Target uses the enemy you're currently locked on to (CombatComponentBase:GetTargetedEnemy).
                Kill All uses the game's own list of NPCs currently hostile to you.
              </Note>
              <div style={{ marginTop: 16 }}>
                <ActionRow label="Nuke Aimed Target" onClick={handleNuke} disabled={busy}>
                  <DWSlider label="Nuke Damage Amount" value={nukeAmount} onChange={setNukeAmount} min={1} max={999999} step={1} />
                </ActionRow>
                <Note>Engine CheatManager:DamageTarget - deals this much damage to whatever you're aiming at.</Note>
              </div>
            </RuneSection>
          </RuneStagger>

          <RuneStagger index={3}>
            <RuneSection title="Damage Output">
              <DWSlider
                label="Damage Multiplier"
                value={commandNumber(command, "damageMultiplier", 1)}
                onChange={(v) => applyField("damageMultiplier", v)}
                min={0.1}
                max={10}
                step={0.1}
              />
              <Readouts items={[["Applied to attributes", status?.damageMultiplierApplied === "1" ? "Yes" : "No"]]} />
              <Note tone="warn">
                Experimental: writes the game's damage attributes and scales displayed weapon damage, but the
                per-hit damage formula has not been confirmed to read them. Use the enemy actions above for a
                guaranteed effect.
              </Note>
            </RuneSection>
          </RuneStagger>

          <RuneStagger index={4}>
            <RuneSection title="Difficulty">
              <DWSelect
                label="Combat (Action) Difficulty"
                value={commandString(command, "actionDifficulty", String(status?.actionDifficulty ?? "1"))}
                onChange={(v) => applyField("actionDifficulty", Number(v))}
                options={DIFFICULTY_LEVELS}
              />
              <DWSelect
                label="RPG (Exploration) Difficulty"
                value={commandString(command, "rpgDifficulty", "1")}
                onChange={(v) => applyField("rpgDifficulty", Number(v))}
                options={DIFFICULTY_LEVELS}
              />
              <Readouts items={[["Combat difficulty in game", DIFFICULTY_LEVELS.find((d) => d.value === String(status?.actionDifficulty))?.label]]} />
              <Note>
                Applied through CombatSubsystem:SetActionDifficulty / SetRPGDifficulty, the same setters the
                game's own settings menu drives. Combat difficulty is restored on reset; RPG difficulty has no
                getter, so it keeps the last value you chose until you change it in the game's settings.
              </Note>
            </RuneSection>
          </RuneStagger>
        </BridgePanel>
      </RuneStagger>
    </div>
  );
}
