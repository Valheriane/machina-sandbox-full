//App.jsx
import { useState } from "react";
import DroneForm from "./components/DroneForm";
import DroneTable from "./components/DroneTable";
import TelemetryFeed from "./components/TelemetryFeed";
import MapPanel from "./components/MapPanel";

export default function App() {
  const [selected, setSelected] = useState("");
  const [refreshKey, setRefreshKey] = useState(0); // <- clé de rafraîchissement

  const handleCreated = () => {
    setRefreshKey(prev => prev + 1); // incrémente → force le DroneTable à se recharger
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
              API: {import.meta.env.VITE_API_URL}
              {" · "}
              MQTT WS: {import.meta.env.VITE_MQTT_WS_URL}
            </div>
          </div>
        </div>
      </header>
      <main className="p-6 grid lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          {/* Passe bien la callback */}
          <DroneForm onCreated={handleCreated} />
          {/* Passe le signal de refresh */}
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
