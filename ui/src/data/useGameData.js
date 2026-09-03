import { useEffect, useState } from "react";
import { loadGameData } from "./GameData";

export function useGameData() {
  const [gameData, setGameData] = useState({
    installed: false,
    path: "",
    data: null,
    loading: true,
  });

  async function refresh() {
    setGameData((current) => ({ ...current, loading: true }));
    const result = await loadGameData();
    setGameData({ ...result, loading: false });
  }

  useEffect(() => {
    let active = true;
    loadGameData().then((result) => {
      if (active) setGameData({ ...result, loading: false });
    });

    return () => {
      active = false;
    };
  }, []);

  return { ...gameData, refresh };
}
