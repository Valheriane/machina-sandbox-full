import { useEffect, useMemo, useState } from "react";
import { subscribe } from "../services/mqtt";

const ALL_TAB = "__all__";

export default function TelemetryFeed({ selected }) {
  const [lines, setLines] = useState([]);
  const [activeTab, setActiveTab] = useState(ALL_TAB);

  // Abonnement MQTT global (tous les drones)
  useEffect(() => {
    const handler = (topic, msg) => {
      // 1) On ne garde que les messages "objet"
      if (!msg || typeof msg !== "object") {
        // console.log("[Telemetry] ignoré (non-objet)", topic, msg);
        return;
      }

      const { drone_id, position, status, speed_mps, battery_pct, ts } = msg;

      // 2) On vérifie que ça ressemble bien à de la télémétrie
      if (
        !drone_id ||
        !position ||
        typeof position.lat !== "number" ||
        typeof position.lon !== "number"
      ) {
        // console.log("[Telemetry] ignoré (structure invalide)", topic, msg);
        return;
      }

      setLines(prev => {
        const entry = {
          ts: ts || Date.now() / 1000,
          id: drone_id,
          status,
          lat: position.lat,
          lon: position.lon,
          alt: position.alt,
          speed: speed_mps,
          batt: battery_pct,
        };
        const next = [entry, ...prev];
        return next.slice(0, 150); // on garde un peu d’historique
      });
    };

    const off1 = subscribe("lab/drone/+/telemetry", handler);
    // tu peux supprimer off2 si tu veux éviter les surprises :
    // const off2 = subscribe("lab/+/telemetry", handler);

    return () => {
      off1 && off1();
      // off2 && off2();
    };
  }, []);


  // Si l’utilisateur sélectionne un drone dans le tableau, on peut auto-switch l’onglet
  useEffect(() => {
    if (!selected) return;
    setActiveTab(selected);
  }, [selected]);

  // Liste des drones présents dans la télémétrie
  const droneIds = useMemo(() => {
    const set = new Set(lines.map(l => l.id).filter(Boolean));
    return Array.from(set).sort();
  }, [lines]);

  // Lignes filtrées selon l’onglet actif
  const filteredLines = useMemo(() => {
    if (activeTab === ALL_TAB) return lines;
    return lines.filter(l => l.id === activeTab);
  }, [activeTab, lines]);

  const clear = () => setLines([]);

  return (
    <div className="card space-y-3">
      <div className="telemetry-header">
        <h2 className="text-lg font-semibold">
          Télémétrie{" "}
          {activeTab === ALL_TAB ? "(tous)" : `: ${activeTab}`}
        </h2>

        <div className="telemetry-header-right">
          <button
            type="button"
            className="btn btn-ghost"
            onClick={clear}
          >
            Vider
          </button>
        </div>
      </div>

      <div className="telemetry-tabs">
            <button
              type="button"
              className={
                "telemetry-tab" +
                (activeTab === ALL_TAB ? " is-active" : "")
              }
              onClick={() => setActiveTab(ALL_TAB)}
            >
              Tous
            </button>
            {droneIds.map(id => (
              <button
                key={id}
                type="button"
                className={
                  "telemetry-tab" +
                  (activeTab === id ? " is-active" : "")
                }
                onClick={() => setActiveTab(id)}
              >
                {id}
              </button>
            ))}
          </div>
      <div className="telemetry-list">
        {filteredLines.length === 0 && (
          <div className="telemetry-empty">
            Aucune télémétrie reçue pour cet onglet pour l’instant.
          </div>
        )}

        {filteredLines.map((l, i) => {
          const ts = new Date(l.ts * 1000);
          const timeStr = ts.toLocaleTimeString();
          const lat =
            l.lat != null && l.lat.toFixed ? l.lat.toFixed(5) : l.lat ?? "—";
          const lon =
            l.lon != null && l.lon.toFixed ? l.lon.toFixed(5) : l.lon ?? "—";
          const alt = l.alt ?? "—";
          const speed = l.speed ?? "—";
          const batt = l.batt != null ? Math.round(l.batt) : "—";

          const isFlying = l.status === "flying";
          const isIdle = l.status === "idle";

          return (
            <div key={i} className="telemetry-item">
              <div className="telemetry-item__header">
                <span className="telemetry-time">{timeStr}</span>
                <span className="telemetry-id">
                  ID&nbsp;:<span>{l.id}</span>
                </span>
                <span
                  className={
                    "telemetry-status " +
                    (isFlying ? "is-flying" : isIdle ? "is-idle" : "")
                  }
                >
                  {(l.status || "unknown").toUpperCase()}
                </span>
              </div>

              <div className="telemetry-item__body">
                <div className="telemetry-line">
                  <span className="label">Lat</span>
                  <span className="value mono">{lat}</span>

                  <span className="label">Lon</span>
                  <span className="value mono">{lon}</span>

                  <span className="label">Alt</span>
                  <span className="value mono">{alt} m</span>
                </div>

                <div className="telemetry-line">
                  <span className="label">Speed</span>
                  <span className="value">{speed} m/s</span>

                  <span className="label">Batt</span>
                  <span className="value">{batt}%</span>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
