import { useEffect } from "react";
import "./clickpulse.css";

export default function ClickPulse() {
  useEffect(() => {
    const handleClick = (event) => {
      const target = event.target.closest("[data-clickpulse]");

      if (!target) {
        return;
      }

      target.classList.remove("clickpulse-active");
      void target.offsetWidth;
      target.classList.add("clickpulse-active");
    };

    document.addEventListener("click", handleClick);
    return () => document.removeEventListener("click", handleClick);
  }, []);

  return null;
}
