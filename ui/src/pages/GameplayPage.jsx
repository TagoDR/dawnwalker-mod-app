import { useState } from "react";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";
import DWSlider from "../components/ui/DWSlider";
import DWSelect from "../components/ui/DWSelect";

import { useBridge, commandNumber } from "../bridge/useBridge";
import BridgePanel, { Readouts, ActionRow, Note } from "../bridge/BridgePanel";

// EQuestExperienceRewardAmount tiers understood by CharacterDevelopmentSubsystem:AddQuestXP.
const XP_TIERS = [
  { value: "1", label: "Very Small quest reward" },
  { value: "2", label: "Small quest reward" },
  { value: "3", label: "Medium quest reward" },
  { value: "4", label: "Large quest reward" },
  { value: "5", label: "Very Large quest reward" },
];

export default function GameplayPage() {
  const api = useBridge();
  const { bridge, status, command, busy, setBusy, setMessage, applyField, runAction } = api;
  const [levelInput, setLevelInput] = useState(null);
  const [xpTier, setXpTier] = useState("5");

  const level = levelInput ?? commandNumber(command, "setLevel", 20);
  const levelCap = commandNumber(command, "levelCap", 99);

  const handleSetLevel = async () => {
    setBusy(true);
    setMessage(null);
    const result = await bridge.applyLevel(level);
    setMessage(result.ok ? "Level change sent to the game." : result.error);
    setBusy(false);
  };

  return (
    <div>
      <PageHeader title="Character" />

      <RuneStagger index={0}>
        <BridgePanel
          bridgeApi={api}
          intro="Level, experience and level cap - applied to the running game through the DawnwalkerModBridge UE4SS mod via CharacterDevelopmentSubsystem."
        >
          <RuneStagger index={1}>
            <RuneSection title="Level">
              <Readouts
                items={[
                  ["Current level", status?.currentLevel],
                  ["Current XP", status?.currentXP],
                  ["XP for this level", status?.xpRequirement],
                  ["Level cap", status?.levelCap],
                ]}
              />
              <Note tone="warn">
                Stay at or below 99. The game's level/XP tables have no entries above that, and requesting a
                higher level crashes the game.
              </Note>
              <ActionRow label="Apply Level" onClick={handleSetLevel} disabled={busy}>
                <DWSlider label="Set Player Level" value={level} onChange={setLevelInput} min={1} max={99} />
              </ActionRow>
              <DWSlider label="Level Cap" value={levelCap} onChange={(v) => applyField("levelCap", v)} min={1} max={99} />
            </RuneSection>
          </RuneStagger>

          <RuneStagger index={2}>
            <RuneSection title="Experience">
              <Note>
                XP is granted through the game's own quest-reward tiers (the same amounts real quests pay out),
                so it triggers level-ups, trait points and notifications exactly like normal play.
              </Note>
              <ActionRow
                label="Grant XP"
                disabled={busy}
                onClick={() => runAction("grantXP", Number(xpTier), "XP grant sent to the game.")}
              >
                <DWSelect label="Reward Size" value={xpTier} onChange={setXpTier} options={XP_TIERS} />
              </ActionRow>
            </RuneSection>
          </RuneStagger>
        </BridgePanel>
      </RuneStagger>
    </div>
  );
}
