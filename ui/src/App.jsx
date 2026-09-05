import { useState, useEffect } from "react";
import Layout from "./components/Layout";

import GameplayPage from "./pages/GameplayPage";
import GearPage from "./pages/GearPage";
import SkillsPage from "./pages/SkillsPage";
import DayNightPage from "./pages/DayNightPage";
import CombatPage from "./pages/CombatPage";
import MovementPage from "./pages/MovementPage";
import SaveLoadPage from "./pages/SaveLoadPage";
import VFXPage from "./pages/VFXPage";
import GameStatusPage from "./pages/GameStatusPage";

import VFXProvider from "./vfx/core/VFXProvider";
import VFXEngine from "./vfx/core/VFXEngine";
import { useTheme } from "./theme/useTheme";
import DivineHoverGlow from "./vfx/core/effects/DivineHoverGlow";
import ClickPulse from "./vfx/core/effects/ClickPulse";
import LoadingScreen from "./vfx/core/effects/LoadingScreen";

import { ToastProvider } from "./modding/ToastProvider";

export default function App() {
  const [page, setPage] = useState("Character");
  const [loading, setLoading] = useState(true);
  const { theme } = useTheme();

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 1200);
    return () => clearTimeout(timer);
  }, []);

  return (
    <ToastProvider>
      <VFXProvider theme={theme}>
        <DivineHoverGlow />
        <ClickPulse />
        <VFXEngine page={page} />
        <LoadingScreen active={loading} />
        <Layout page={page} setPage={setPage}>
          {page === "Install & Capabilities" && <GameStatusPage />}
          {page === "Character" && <GameplayPage />}
          {page === "Skills & Progression" && <SkillsPage />}
          {page === "Combat" && <CombatPage />}
          {page === "Movement & Camera" && <MovementPage />}
          {page === "World & Time" && <DayNightPage />}
          {page === "Gear & Inventory" && <GearPage />}
          {page === "Visual Effects" && <VFXPage />}
          {page === "Profiles & Backups" && <SaveLoadPage />}
        </Layout>
      </VFXProvider>
    </ToastProvider>
  );
}
