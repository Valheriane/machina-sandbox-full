import React, { useState } from "react";
import Modal from "./ui/Modal";              // <-- garde ton Modal vanilla
import { createDrone } from "../services/api";
import Hint from "./Hint";                   // <-- bulles d’aide

/** --------- Formulaire “pur” --------- */
function DroneFormPure({ onCreated }) {
  const [form, setForm] = useState({
    id: "drone-101",
    topic_prefix: "lab",
    start_lat: 43.611,
    start_lon: 3.877,
    start_alt: 0,
    publish_interval_sec: 1.0,
    cruise_speed_mps: 9.0,
    battery_drain: 0.006,
    heading_noise: 1.0,
  });
  const [loading, setLoading] = useState(false);

  const update = (k, v) => setForm(prev => ({ ...prev, [k]: v }));

  const submit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await createDrone({
        id: form.id,
        topic_prefix: form.topic_prefix,
        start_lat: Number(form.start_lat),
        start_lon: Number(form.start_lon),
        start_alt: Number(form.start_alt),
        publish_interval_sec: Number(form.publish_interval_sec),
        cruise_speed_mps: Number(form.cruise_speed_mps),
        battery_drain: Number(form.battery_drain),
        heading_noise: Number(form.heading_noise),
      });
      onCreated?.();
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={submit} className="card space-y-3">
      

      <div className="grid md:grid-cols-3 gap-3">
        <div>
          <div className="label-row">
            <label className="text-sm">ID</label>
            <Hint text="Identifiant unique du drone. Lettres/chiffres, sans espace." />
          </div>
          <input
            data-autofocus
            className="input"
            value={form.id}
            onChange={e => update("id", e.target.value)}
            required
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Topic prefix</label>
            <Hint text="Préfixe des topics MQTT, ex. 'lab' → lab/drone-101/telemetry." />
          </div>
          <input
            className="input"
            value={form.topic_prefix}
            onChange={e => update("topic_prefix", e.target.value)}
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Interval (s)</label>
            <Hint text="Intervalle d’émission de la télémétrie (secondes), ex. 1.0." />
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
            <label className="text-sm">Start lat</label>
            <Hint text="Latitude de départ (WGS84). Ex. 43.611 pour Montpellier." />
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
            <Hint text="Longitude de départ (WGS84). Ex. 3.877 pour Montpellier." />
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
            <Hint text="Altitude de départ (m) AMSL (au-dessus du niveau de la mer)." />
          </div>
          <input
            type="number" step="1"
            className="input"
            value={form.start_alt}
            onChange={e => update("start_alt", e.target.value)}
          />
        </div>

        <div>
          <div className="label-row">
            <label className="text-sm">Cruise speed (m/s)</label>
            <Hint text="Vitesse de croisière en m/s. 9 m/s ≈ 32 km/h." />
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
            <Hint text="Taux de décharge par tick (simulation). 0.006 ≈ 0.6%/pas." />
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
            <Hint text="Bruit angulaire en degrés pour simuler la dérive du cap." />
          </div>
          <input
            type="number" step="0.1"
            className="input"
            value={form.heading_noise}
            onChange={e => update("heading_noise", e.target.value)}
          />
        </div>
      </div>

      <div className="flex items-center justify-end gap-3 pt-2">
        <button className="btn btn-accent" disabled={loading}>
          {loading ? "Création..." : "Créer"}
        </button>
      </div>
    </form>
  );
}

/** --------- Wrapper : bouton + modal --------- */
export default function DroneForm({ onCreated }) {
  const [open, setOpen] = useState(false);

  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <button className="btn btn-accent" onClick={() => setOpen(true)}>
          Nouveau drone
        </button>
      </div>

      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title="Créer un drone"
        size="md"
      >
        <DroneFormPure
          onCreated={() => {
            onCreated?.();      // notifie App (refresh table)
            setOpen(false);     // ferme la modale
          }}
        />
      </Modal>
    </div>
  );
}
