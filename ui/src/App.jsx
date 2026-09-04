import { useState, useEffect } from "react";
import Layout from "./components/Layout";

import GameplayPage from "./pages/GameplayPage";
import GearPage from "./pages/GearPage";
import SkillsPage from "./pages/SkillsPage";
import DayNightPage from "./pages/DayNightPage";
import CombatPage from "./pages/CombatPage";
import MovementPage from "./pages/MovementPage";
import AdvancedPage from "./pages/AdvancedPage";
import SaveLoadPage from "./pages/SaveLoadPage";
import VFXPage from "./pages/VFXPage";
import GameStatusPage from "./pages/GameStatusPage";

import VFXProvider from "./vfx/core/VFXProvider";
import VFXEngine from "./vfx/core/VFXEngine";
import { useTheme } from "./theme/useTheme";
import DivineHoverGlow from "./vfx/core/effects/DivineHoverGlow";
import ClickPulse from "./vfx/core/effects/ClickPulse";
import LoadingScreen from "./vfx/core/effects/LoadingScreen";

import { ModdingProvider } from "./modding/ModdingProvider";
import { ToastProvider } from "./modding/ToastProvider";

export default function App() {
  const [page, setPage] = useState("Gameplay Profile");
  const [loading, setLoading] = useState(true);
  const { theme } = useTheme();

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 1200);
    return () => clearTimeout(timer);
  }, []);

  return (
    <ToastProvider>
      <ModdingProvider>
        <VFXProvider theme={theme}>
          <DivineHoverGlow />
          <ClickPulse />
          <VFXEngine page={page} />
          <LoadingScreen active={loading} />
          <Layout page={page} setPage={setPage}>
            {page === "Install & Capabilities" && <GameStatusPage />}
            {page === "Gameplay Profile" && <GameplayPage />}
            {page === "Gear" && <GearPage />}
            {page === "Skills & Progression" && <SkillsPage />}
            {page === "Day / Night & Timer" && <DayNightPage />}
            {page === "Combat & Experience" && <CombatPage />}
            {page === "Movement & Stamina" && <MovementPage />}
            {page === "Advanced Tuning" && <AdvancedPage />}
            {page === "Visual Effects" && <VFXPage />}
            {page === "Profiles & Backups" && <SaveLoadPage />}
          </Layout>
        </VFXProvider>
      </ModdingProvider>
    </ToastProvider>
  );
}
