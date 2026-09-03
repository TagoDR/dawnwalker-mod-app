import { useState, useCallback, useEffect } from "react";
import { ToastContext } from "./ToastContext";

/**
 * Simple toast provider.
 *
 * Usage:
 *  - Wrap a part of the app with <ToastProvider>
 *  - Call const toast = useToast(); toast.push({ type: "success", text: "Saved" });
 */
export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);

  const push = useCallback(({ type = "info", text = "", duration = 3500 }) => {
    const id = Date.now() + Math.floor(Math.random() * 1000);
    const t = { id, type, text, duration };
    setToasts((s) => [...s, t]);
    return id;
  }, []);

  const remove = useCallback((id) => {
    setToasts((s) => s.filter((t) => t.id !== id));
  }, []);

  useEffect(() => {
    const timers = toasts.map((t) =>
      setTimeout(() => {
        setToasts((s) => s.filter((x) => x.id !== t.id));
      }, t.duration)
    );
    return () => timers.forEach((id) => clearTimeout(id));
  }, [toasts]);

  return (
    <ToastContext.Provider value={{ push, remove }}>
      {children}
      <div style={{ position: "fixed", top: 18, right: 18, zIndex: 1400, display: "flex", flexDirection: "column", gap: 8 }}>
        {toasts.map((t) => (
          <Toast key={t.id} toast={t} onClose={() => remove(t.id)} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

function Toast({ toast, onClose }) {
  const color = toast.type === "success" ? "#2ecc71" : toast.type === "error" ? "#e74c3c" : "#3498db";
  return (
    <div
      role="status"
      aria-live="polite"
      style={{
        minWidth: 220,
        maxWidth: 360,
        background: "rgba(20,20,20,0.95)",
        color: "#fff",
        padding: "10px 12px",
        borderRadius: 8,
        boxShadow: "0 6px 18px rgba(0,0,0,0.45)",
        borderLeft: `4px solid ${color}`,
        fontSize: 13,
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", gap: 8 }}>
        <div style={{ flex: 1 }}>{toast.text}</div>
        <button
          onClick={onClose}
          aria-label="Dismiss"
          style={{
            background: "transparent",
            border: "none",
            color: "rgba(255,255,255,0.7)",
            cursor: "pointer",
            padding: 4,
            marginLeft: 8,
          }}
        >
          ✕
        </button>
      </div>
    </div>
  );
}
