import { useState } from "react";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";
import DWSlider from "../components/ui/DWSlider";
import DWToggle from "../components/ui/DWToggle";
import DWButton from "../components/ui/DWButton";

import { useBridge, commandFlag } from "../bridge/useBridge";
import BridgePanel, { Readouts, ActionRow, ButtonRow, Note } from "../bridge/BridgePanel";

export default function SkillsPage() {
  const api = useBridge();
  const { status, command, busy, applyField, runAction } = api;
  const [traitDelta, setTraitDelta] = useState(5);
  const [traitTotal, setTraitTotal] = useState(50);
  const [mutationDelta, setMutationDelta] = useState(1);

  return (
    <div>
      <PageHeader title="Skills & Progression" />

      <RuneStagger index={0}>
        <BridgePanel
          bridgeApi={api}
          intro="Trait (skill) points, the trait tree, vampire mutation and ability cooldowns - all via CharacterDevelopmentSubsystem and FocusAbilitiesSubsystem."
        >
          <RuneStagger index={1}>
            <RuneSection title="Trait Points">
              <Readouts items={[["Unspent trait points", status?.traitPoints]]} />
              <ActionRow
                label="Add Points"
                disabled={busy}
                onClick={() => runAction("addTraitPoints", traitDelta, "Trait points sent to the game.")}
              >
                <DWSlider label="Points to Add" value={traitDelta} onChange={setTraitDelta} min={1} max={200} />
              </ActionRow>
              <ActionRow
                label="Remove Points"
                disabled={busy}
                onClick={() => runAction("addTraitPoints", -traitDelta, "Trait point removal sent to the game.")}
              >
                <Note>Removes unspent points only - learned traits are untouched.</Note>
              </ActionRow>
              <ActionRow
                label="Set Total"
                disabled={busy}
                onClick={() => runAction("setTraitPoints", traitTotal, "Trait point total sent to the game.")}
              >
                <DWSlider label="Set Unspent Points To" value={traitTotal} onChange={setTraitTotal} min={0} max={999} />
              </ActionRow>
            </RuneSection>
          </RuneStagger>

          <RuneStagger index={2}>
            <RuneSection title="Trait Tree">
              <Note tone="warn">
                These change your save permanently. Make a manual save first - there is no undo.
              </Note>
              <ButtonRow>
                <DWButton
                  label="Unlock All Traits"
                  disabled={busy}
                  onClick={() => runAction("unlockAllTraits", null, "Unlock request sent to the game.")}
                  data-clickpulse
                  data-glow
                />
                <DWButton
                  label="Reset All Traits"
                  disabled={busy}
                  onClick={() => runAction("resetAllTraits", null, "Reset request sent to the game.")}
                />
              </ButtonRow>
              <Note>
                Unlock All calls the game's own UnlockAllTraits (unlock + unblock + unhide every trait level).
                Reset All calls ResetAllTraits - the game's own full respec.
              </Note>
            </RuneSection>
          </RuneStagger>

          <RuneStagger index={3}>
            <RuneSection title="Vampire Mutation (Corruption)">
              <Readouts
                items={[
                  ["Mutation level", status?.mutationLevel],
                  ["Mutation charges", status?.mutationCharges],
                ]}
              />
              <ActionRow
                label="Add Charges"
                disabled={busy}
                onClick={() => runAction("addMutationCharges", mutationDelta, "Mutation charges sent to the game.")}
              >
                <DWSlider label="Raw Mutation Charges" value={mutationDelta} onChange={setMutationDelta} min={1} max={100} />
              </ActionRow>
              <ActionRow
                label="Remove Charges"
                disabled={busy}
                onClick={() => runAction("addMutationCharges", -mutationDelta, "Mutation charge removal sent to the game.")}
              >
                <Note>Raw charges, not levels - start small. Removing charges is not confirmed to undo an attained level.</Note>
              </ActionRow>
            </RuneSection>
          </RuneStagger>

          <RuneStagger index={4}>
            <RuneSection title="Abilities">
              <DWToggle
                label="No Ability Cooldowns"
                value={commandFlag(command, "noCooldowns")}
                onChange={(v) => applyField("noCooldowns", v)}
              />
              <Readouts items={[["Cooldowns disabled in game", status?.cooldownsDisabled === "1" ? "Yes" : "No"]]} />
              <DWToggle
                label="Keep Activation Charges Full"
                value={commandFlag(command, "keepActionSlotsCharged")}
                onChange={(v) => applyField("keepActionSlotsCharged", v)}
              />
              <Note>
                Refills your unlocked ability activation-charge slots every second (uses the capacity you've actually
                unlocked, it doesn't add slots).
              </Note>
            </RuneSection>
          </RuneStagger>
        </BridgePanel>
      </RuneStagger>
    </div>
  );
}
