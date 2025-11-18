import React, { useEffect, useRef, useState } from "react";
import { updateDrone } from "../services/api";

function field(n, v) {
  // helper pour caster proprement les numériques
  if (n === "" || n === null || n === undefined) return undefined;
  const num = Number(n);
  return Number.isFinite(num) ? num : undefined;
}

export function EditDroneForm({ drone, onCancel, onSaved }) {
  const [form, setForm] = useState({
    id: drone.id,
    topic_prefix: drone.topic_prefix ?? "lab",
    publish_interval_sec: drone.publish_interval_sec ?? 1.0,
    cruise_speed_mps: drone.cruise_speed_mps ?? 9.0,
    battery_drain: drone.battery_drain ?? 0.006,
    heading_noise: drone.heading_noise ?? 1.0,
    start_lat: drone.start_lat ?? 0,
    start_lon: drone.start_lon ?? 0,
    start_alt: drone.start_alt ?? 0
  });
  const [loading, setLoading] = useState(false);
  const firstRef = useRef(null);

  // si on rouvre sur un autre drone, synchronise le formulaire
  useEffect(() => {
    setForm({
      id: drone.id,
      topic_prefix: drone.topic_prefix ?? "lab",
      publish_interval_sec: drone.publish_interval_sec ?? 1.0,
      cruise_speed_mps: drone.cruise_speed_mps ?? 9.0,
      battery_drain: drone.battery_drain ?? 0.006,
      heading_noise: drone.heading_noise ?? 1.0,
      start_lat: drone.start_lat ?? 0,
      start_lon: drone.start_lon ?? 0,
      start_alt: drone.start_alt ?? 0
    });
  }, [drone]);

  const update = (k, v) => setForm(prev => ({ ...prev, [k]: v }));

  const submit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      // id souvent immuable côté backend : on désactive l’édition de l’ID
      const payload = {
        topic_prefix: form.topic_prefix,
        publish_interval_sec: field(form.publish_interval_sec),
        cruise_speed_mps: field(form.cruise_speed_mps),
        battery_drain: field(form.battery_drain),
        heading_noise: field(form.heading_noise),
        start_lat: field(form.start_lat),
        start_lon: field(form.start_lon),
        start_alt: field(form.start_alt),
      };

      const updated = await updateDrone(drone.id, payload);
      onSaved?.(updated ?? { ...drone, ...payload }); // fallback si l’API ne renvoie pas la ligne
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={submit} className="space-y-4">
      <div className="grid md:grid-cols-3 gap-3">
        <div>
          <div className="label-row">
            <label className="text-sm">ID</label>
          </div>
          <input
            className="input"
            value={form.id}
            disabled   // 🔒 id non modifiable par défaut
            readOnly
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Topic prefix</label>
          </div>
          <input
            ref={firstRef}
            className="input"
            value={form.topic_prefix}
            onChange={e => update("topic_prefix", e.target.value)}
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Interval (s)</label>
          </div>
          <input
            type="number" step="0.1"
            className="input"
            value={form.publish_interval_sec}
            onChange={e => update("publish_interval_sec", e.target.value)}
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Cruise speed (m/s)</label>
          </div>
          <input
            type="number" step="0.1"
            className="input"
            value={form.cruise_speed_mps}
            onChange={e => update("cruise_speed_mps", e.target.value)}
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Battery drain</label>
          </div>
          <input
            type="number" step="0.001"
            className="input"
            value={form.battery_drain}
            onChange={e => update("battery_drain", e.target.value)}
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Heading noise</label>
          </div>
          <input
            type="number" step="0.1"
            className="input"
            value={form.heading_noise}
            onChange={e => update("heading_noise", e.target.value)}
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Start lat</label>
          </div>
          <input
            type="number" step="0.0001"
            className="input"
            value={form.start_lat}
            onChange={e => update("start_lat", e.target.value)}
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Start lon</label>
          </div>
          <input
            type="number" step="0.0001"
            className="input"
            value={form.start_lon}
            onChange={e => update("start_lon", e.target.value)}
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Start alt</label>
          </div>
          <input
            type="number" step="1"
            className="input"
            value={form.start_alt}
            onChange={e => update("start_alt", e.target.value)}
          />
        </div>
      </div>

      <div className="sticky bottom-0 mt-6 border-t border-white/10 pt-4 bg-gray-900/60 backdrop-blur supports-[backdrop-filter]:bg-gray-900/40">
        <div className="flex items-center justify-end gap-2 zone-btn">
            <button type="button" className="btn" onClick={onCancel}>Annuler</button>
            <button className="btn btn-accent" disabled={loading}>
            {loading ? "Enregistrement..." : "Enregistrer"}
            </button>
        </div>
      </div>
    </form>
  );
}
