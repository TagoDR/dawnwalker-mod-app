import { useContext } from "react";
import { ThemeContext } from "./ThemeContextValue.js";

export function useTheme() {
  return useContext(ThemeContext);
}
