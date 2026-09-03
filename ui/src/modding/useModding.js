import { useContext } from "react";
import { ModdingContext } from "./ModdingContext";

export function useModding() {
  return useContext(ModdingContext);
}
