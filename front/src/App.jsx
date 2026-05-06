import { useState } from "react";
import DroneForm from "./components/DroneForm";
import DroneTable from "./components/DroneTable";
import TelemetryFeed from "./components/TelemetryFeed";
import MapPanel from "./components/MapPanel";

export default function App() {
  const [selected, setSelected] = useState("");
  const [refreshKey, setRefreshKey] = useState(0);

  const apiUrl =
    window.__APP_CONFIG__?.API_URL ||
    import.meta.env.VITE_API_URL ||
    "http://localhost:8000";

  const mqttUrl =
    window.__APP_CONFIG__?.MQTT_WS_URL ||
    import.meta.env.VITE_MQTT_WS_URL ||
    "ws://localhost:9001";

  const handleCreated = () => {
    setRefreshKey((prev) => prev + 1);
  };

  return (
    <div className="app-shell">
      <header className="header">
        <div className="header__left">
          <img
            src="/logo-sombre.png"
            alt="Machina Sandbox"
            className="header__logo"
          />
          <div className="header__title">
            <h1>Machina — <span>Fleet Dashboard</span></h1>
            <div className="header__meta">
              API: {apiUrl} {" · "} MQTT WS: {mqttUrl}
            </div>
          </div>
        </div>
      </header>

      <main className="p-6 grid lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <DroneForm onCreated={handleCreated} />
          <DroneTable refresh={refreshKey} onSelect={setSelected} />
        </div>
        <div>
          <TelemetryFeed selected={selected} />
          <MapPanel />
        </div>
      </main>
    </div>
  );
}