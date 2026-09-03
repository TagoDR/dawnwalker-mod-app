import "./loadingscreen.css";

export default function LoadingScreen({ active }) {
  return (
    <div
      aria-hidden="true"
      className={`loading-container ${
        active ? "loading-active" : "loading-fade"
      }`}
    >
      <div className="loading-core" />
      <div className="loading-ring loading-ring-1" />
      <div className="loading-ring loading-ring-2" />
      <div className="loading-ring loading-ring-3" />
      <div className="loading-haze" />
    </div>
  );
}
