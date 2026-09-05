import { useState } from "react";

import PageHeader from "../components/ui/PageHeader";
import RuneSection from "../components/ui/RuneSection";
import RuneStagger from "../components/ui/RuneStagger";
import DWSlider from "../components/ui/DWSlider";
import DWButton from "../components/ui/DWButton";

import { useBridge } from "../bridge/useBridge";
import BridgePanel, { Readouts, ActionRow, ButtonRow, Note } from "../bridge/BridgePanel";

function formatHours(value) {
  const hours = Number(value);
  if (!Number.isFinite(hours)) return undefined;
  const h = Math.floor(hours) % 24;
  const m = Math.floor((hours - Math.floor(hours)) * 60);
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

export default function DayNightPage() {
  const api = useBridge();
  const { status, busy, runAction } = api;
  const [hour, setHour] = useState(12);
  const [minute, setMinute] = useState(0);

  const targetTime = `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;

  return (
    <div>
      <PageHeader title="World & Time" />

      <RuneStagger index={0}>
        <BridgePanel
          bridgeApi={api}
          intro="The in-game clock and the open-world map - via TimeSystemImpl and the OpenWorldJournal."
        >
          <RuneStagger index={1}>
            <RuneSection title="Game Clock">
              <Readouts
                items={[
                  ["Current day", status?.currentDay],
                  ["Story deadline day", status?.mainGoalDay],
                  ["Time of day", status?.timeOfDay ?? formatHours(status?.dayTimeHours)],
                ]}
              />
              <ActionRow
                label={`Set Time to ${targetTime}`}
                disabled={busy}
                onClick={() => runAction("setTimeOfDay", targetTime, "Time change sent to the game.")}
              >
                <DWSlider label="Hour" value={hour} onChange={setHour} min={0} max={23} />
                <DWSlider label="Minute" value={minute} onChange={setMinute} min={0} max={59} />
              </ActionRow>
              <Note tone="warn">
                Sets the clock within the current day (TimeSystemImpl:SetTime). Time in this game drives the story
                deadline and day/night phases - moving it forward past a phase change counts as time passing.
              </Note>
            </RuneSection>
          </RuneStagger>

          <RuneStagger index={2}>
            <RuneSection title="Map & Fast Travel">
              <ButtonRow>
                <DWButton
                  label="Unlock All Fast Travel Points"
                  disabled={busy}
                  onClick={() => runAction("unlockAllFastTravel", null, "Fast travel unlock sent to the game.")}
                  data-clickpulse
                  data-glow
                />
                <DWButton
                  label="Reveal All Map Pins"
                  disabled={busy}
                  onClick={() => runAction("revealAllMappins", null, "Map reveal sent to the game.")}
                />
              </ButtonRow>
              <Note tone="warn">
                Both persist into your save and may affect achievements. Use outside combat and reopen the map to see
                the result.
              </Note>
            </RuneSection>
          </RuneStagger>
        </BridgePanel>
      </RuneStagger>
    </div>
  );
}
