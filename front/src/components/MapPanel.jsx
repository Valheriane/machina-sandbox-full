import { useEffect, useRef, useState, useMemo, Fragment } from "react";
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  Polyline,
  CircleMarker,
} from "react-leaflet";
import L from "leaflet";
import { subscribe } from "../services/mqtt";

const ALL = "__all__";

// icône standard Leaflet pour le drone
const droneIcon = new L.Icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

// petite palette de couleurs par drone
const PALETTE = [
  "#22d3ee", // cyan
  "#22c55e", // vert
  "#f97316", // orange
  "#eab308", // jaune
  "#a855f7", // violet
  "#f97373", // rouge doux
];

export default function MapPanel() {
  // pos = { [id]: { lat, lon, alt, status, ts, history: [[lat,lon], ...] } }
  const [pos, setPos] = useState({});
  // targets = { [id]: { lat, lon, alt } }
  const [targets, setTargets] = useState({});

  const [filterId, setFilterId] = useState(ALL);
  const [follow, setFollow] = useState(false);

  const subTelemetryRef = useRef(null);
  const subCmdRef = useRef(null);
  const mapRef = useRef(null);

  const refreshMap = () => {
    setPos({});
    setTargets({});
  };

  // Abonnements MQTT
  useEffect(() => {
    // télémétrie
    subTelemetryRef.current = subscribe(
      "lab/drone/+/telemetry",
      (_topic, msg) => {
        const id = msg.drone_id || "unknown";
        const lat = msg?.position?.lat;
        const lon = msg?.position?.lon;
        if (typeof lat !== "number" || typeof lon !== "number") return;

        setPos(prev => {
          const prevEntry = prev[id];
          const history = prevEntry?.history
            ? [...prevEntry.history, [lat, lon]]
            : [[lat, lon]];
          if (history.length > 200) history.shift(); // limite historique

          return {
            ...prev,
            [id]: {
              lat,
              lon,
              alt: msg?.position?.alt,
              status: msg?.status,
              ts: msg?.ts,
              history,
            },
          };
        });
      }
    );

    // commandes (pour récupérer les GOTO)
    subCmdRef.current = subscribe("lab/drone/+/commands", (topic, msg) => {
      const payload = msg?.payload;
      if (!payload || payload.cmd !== "goto" || !payload.args) return;

      const parts = topic.split("/"); // lab / drone / drone-101 / commands
      const id = parts[2] || "unknown";

      const { lat, lon, alt } = payload.args;
      if (typeof lat !== "number" || typeof lon !== "number") return;

      setTargets(prev => ({
        ...prev,
        [id]: { lat, lon, alt },
      }));
    });

    return () => {
      subTelemetryRef.current?.();
      subCmdRef.current?.();
    };
  }, []);

  // Liste des drones connus
  const droneIds = useMemo(() => {
    return Object.keys(pos).sort();
  }, [pos]);

  // Couleur par drone (stable)
  const colorById = useMemo(() => {
    const map = {};
    droneIds.forEach((id, idx) => {
      map[id] = PALETTE[idx % PALETTE.length];
    });
    return map;
  }, [droneIds]);

  // IDs visibles selon le filtre
  const visibleIds = useMemo(() => {
    if (filterId === ALL) return droneIds;
    return droneIds.includes(filterId) ? [filterId] : [];
  }, [droneIds, filterId]);

  // centre de la carte = moyenne des positions visibles (fallback Montpellier)
  const center = useMemo(() => {
    const pts = visibleIds
      .map(id => pos[id])
      .filter(Boolean)
      .map(p => [p.lat, p.lon]);

    if (!pts.length) return [43.611, 3.877];

    const lat = pts.reduce((a, c) => a + c[0], 0) / pts.length;
    const lon = pts.reduce((a, c) => a + c[1], 0) / pts.length;
    return [lat, lon];
  }, [visibleIds, pos]);

  // bouton "Ajuster vue"
  const fitToDrones = () => {
    const map = mapRef.current;
    if (!map) return;

    const pts = visibleIds
      .map(id => pos[id])
      .filter(Boolean)
      .map(p => [p.lat, p.lon]);

    if (!pts.length) return;
    if (pts.length === 1) {
      map.setView(pts[0], 14);
    } else {
      const bounds = L.latLngBounds(pts);
      map.fitBounds(bounds, { padding: [40, 40] });
    }
  };

  // mode "suivi" : recadre sur le drone filtré
  useEffect(() => {
    if (!follow) return;
    if (filterId === ALL) return;
    const map = mapRef.current;
    const p = pos[filterId];
    if (!map || !p) return;
    map.setView([p.lat, p.lon]);
  }, [follow, filterId, pos]);

  // si on passe sur "Tous", on coupe le suivi
  useEffect(() => {
    if (filterId === ALL && follow) {
      setFollow(false);
    }
  }, [filterId, follow]);

  return (
    <div className="card space-y-3">
      <div className="map-header">
        <h2 className="text-lg font-semibold">Carte</h2>

        <div className="map-header-right">
          <div className="map-tabs">
            <button
              type="button"
              className={"map-tab" + (filterId === ALL ? " is-active" : "")}
              onClick={() => setFilterId(ALL)}
            >
              Tous
            </button>
            {droneIds.map(id => (
              <button
                key={id}
                type="button"
                className={"map-tab" + (filterId === id ? " is-active" : "")}
                onClick={() => setFilterId(id)}
              >
                {id}
              </button>
            ))}
          </div>

          <button className="btn btn-ghost" onClick={fitToDrones}>
            Ajuster vue
          </button>
          <button className="btn btn-ghost" onClick={refreshMap}>
            Rafraîchir
          </button>
        </div>
      </div>

      {filterId !== ALL && pos[filterId] && (
        <label className="map-follow">
          <input
            type="checkbox"
            checked={follow}
            onChange={e => setFollow(e.target.checked)}
          />
          <span>Suivre automatiquement {filterId} sur la carte</span>
        </label>
      )}

      <MapContainer
        center={center}
        zoom={13}
        style={{ height: 400, borderRadius: 12 }}
        whenCreated={map => {
          mapRef.current = map;
        }}
      >
        <TileLayer
          attribution="&copy; OpenStreetMap"
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {/* trajectoires + positions */}
        {visibleIds.map(id => {
          const p = pos[id];
          if (!p) return null;
          const color = colorById[id] || "#22d3ee";

          return (
            <Fragment key={id}>
              {/* trajectoire */}
              {p.history && p.history.length > 1 && (
                <Polyline
                  positions={p.history}
                  pathOptions={{
                    color,
                    weight: 2,
                    opacity: 0.8,
                  }}
                />
              )}

              {/* halo coloré + marker */}
              <CircleMarker
                center={[p.lat, p.lon]}
                radius={6}
                pathOptions={{
                  color,
                  fillColor: color,
                  fillOpacity: 0.9,
                }}
              />
              <Marker position={[p.lat, p.lon]} icon={droneIcon}>
                <Popup>
                  <div className="text-sm">
                    <div><b>{id}</b></div>
                    <div>Status: {p.status}</div>
                    <div>Alt: {p.alt}</div>
                    <div>Lat: {p.lat.toFixed(5)}</div>
                    <div>Lon: {p.lon.toFixed(5)}</div>
                  </div>
                </Popup>
              </Marker>
            </Fragment>
          );
        })}

        {/* cibles GOTO + segment de trajet prévu */}
        {visibleIds.map(id => {
          const t = targets[id];
          const p = pos[id];
          if (!t) return null;
          const color = colorById[id] || "#f97316";

          const line =
            p && typeof p.lat === "number" && typeof p.lon === "number"
              ? [
                  [p.lat, p.lon],
                  [t.lat, t.lon],
                ]
              : null;

          return (
            <Fragment key={`goto-${id}`}>
              {line && (
                <Polyline
                  positions={line}
                  pathOptions={{
                    color,
                    weight: 2,
                    opacity: 0.9,
                    dashArray: "4 4",
                  }}
                />
              )}

              <CircleMarker
                center={[t.lat, t.lon]}
                radius={7}
                pathOptions={{
                  color,
                  fillColor: "#0f172a",
                  fillOpacity: 0.9,
                }}
              >
                <Popup>
                  <div className="text-sm">
                    <div>
                      <b>Cible GOTO</b> ({id})
                    </div>
                    <div>Alt: {t.alt ?? "—"} m</div>
                    <div>Lat: {t.lat.toFixed(5)}</div>
                    <div>Lon: {t.lon.toFixed(5)}</div>
                  </div>
                </Popup>
              </CircleMarker>
            </Fragment>
          );
        })}
      </MapContainer>
    </div>
  );
}
