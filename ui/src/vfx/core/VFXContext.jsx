import { createContext, useContext } from "react";

export const VFXContext = createContext({
  theme: null,
  corruption: false,
  setCorruption: () => {},
  intensity: {},
  setIntensity: () => {},
});

export function useVFX() {
  return useContext(VFXContext);
}
