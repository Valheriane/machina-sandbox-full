import { useEffect, useMemo, useState, Fragment  } from "react";
import { listDrones, startDrone, stopDrone, sendCmd, deleteDrone  } from "../services/api";
import Hint from "./Hint";
import { makePageItems } from "./ui/Utils";
import Modal from "./ui/Modal";
import { EditDroneForm } from "./EditDroneForm";


export default function DroneTable({ onSelect, refresh }) {
  const [rows, setRows] = useState([]);
  const [busy, setBusy] = useState({});            // {id:true} pendant une action
  const [gotoArgs, setGotoArgs] = useState({ lat: "", lon: "", alt: "" });
  const [gotoId, setGotoId] = useState("");        // drone choisi pour GOTO
  const [log, setLog] = useState([]);              // mini journal

  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(5);
  const [search, setSearch] = useState("");
  const [activeFirst, setActiveFirst] = useState(true);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [toDelete, setToDelete] = useState(null);
  const [editOpen, setEditOpen] = useState(false);
  const [editDrone, setEditDrone] = useState(null); // objet drone à éditer
  const [expandedId, setExpandedId] = useState(null);


  const fetchDrones = async () => {
    try {
      const data = await listDrones();
      setRows(data);
      // si aucun choix GOTO, prend le premier
      if (!gotoId && data.length) setGotoId(data[0].id);
    } catch (e) {
      console.error("Erreur listDrones:", e);
      addLog("error", "Échec du chargement de la flotte");
    }
  };
  useEffect(() => { fetchDrones(); }, []);
  useEffect(() => { if (refresh !== undefined) fetchDrones(); }, [refresh]);

  const addLog = (type, msg) =>
    setLog(prev => [...prev.slice(-50), `[${new Date().toLocaleTimeString()}] ${type.toUpperCase()}: ${msg}`]);

  const doStart = async (id) => {
    setBusy(b => ({...b, [id]: true}));
    try {
      await startDrone(id);
      addLog("ok", `Start ${id}`);
      fetchDrones();
    } catch { addLog("error", `Start ${id} a échoué`); }
    finally { setBusy(b => ({...b, [id]: false})); }
  };

  const doStop = async (id) => {
    setBusy(b => ({...b, [id]: true}));
    try {
      await stopDrone(id);
      addLog("ok", `Stop ${id}`);
      fetchDrones();
    } catch { addLog("error", `Stop ${id} a échoué`); }
    finally { setBusy(b => ({...b, [id]: false})); }
  };

  const cmd = async (id, c, args) => {
    setBusy(b => ({...b, [id]: true}));
    try {
      await sendCmd(id, c, args);
      addLog("ok",
        `Cmd ${c} → ${id}` +
        (c==="goto" ? ` (${args.lat}, ${args.lon}${Number.isFinite(args.alt)?`, ${args.alt}`:""})` : "")
      );
    } catch {
      addLog("error", `Cmd ${c} → ${id} a échoué`);
    } finally {
      setBusy(b => ({...b, [id]: false}));
    }
  };


  const parseDec = (v) => {
    if (v == null) return undefined;
    const s = String(v).trim().replace(',', '.');
    const n = Number(s);
    return Number.isFinite(n) ? n : undefined;
  };
  const isValidLat = (v) => Number.isFinite(v) && v >= -90 && v <= 90;
  const isValidLon = (v) => Number.isFinite(v) && v >= -180 && v <= 180;

  const onGoto = async () => {
    const lat = parseDec(gotoArgs.lat);
    const lon = parseDec(gotoArgs.lon);
    const alt = parseDec(gotoArgs.alt);

    if (!gotoId || !isValidLat(lat) || !isValidLon(lon)) {
      addLog("error", "GOTO invalide (lat/lon)");
      return;
    }
    await cmd(gotoId, "goto", { lat, lon, alt });
  };


  const runningIds = useMemo(() => new Set(rows.filter(r=>r.status==="running").map(r=>r.id)), [rows]);

  const processed = useMemo(() => {
    let arr = rows;
    if (search.trim()) {
      const q = search.trim().toLowerCase();
      arr = arr.filter(r => r.id.toLowerCase().includes(q));
    }
    if (activeFirst) {
      arr = [...arr].sort((a,b) => {
        const A = a.status === "running" ? 0 : 1;
        const B = b.status === "running" ? 0 : 1;
        if (A !== B) return A - B;
        return a.id.localeCompare(b.id);
      });
    } else {
      arr = [...arr].sort((a,b)=>a.id.localeCompare(b.id));
    }
    return arr;
  }, [rows, search, activeFirst]);

  const totalPages = Math.max(1, Math.ceil(processed.length / pageSize));
  const pageRows = useMemo(() => {
    const start = (page - 1) * pageSize;
    return processed.slice(start, start + pageSize);
  }, [processed, page, pageSize]);

  const pageItems = useMemo(
  () => makePageItems(totalPages, page),
  [totalPages, page]
);

  useEffect(()=>{ if (page > totalPages) setPage(totalPages); }, [totalPages, page]);

  return (
    <div className="card space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center">
          <h2 className="text-lg font-semibold">Flotte</h2>
          <Hint
            ml="6px"
            wide
            placement="right"
            text={`Affiche la liste des drones.

• Start : démarre la simulation
• Stop  : arrête
• Ping  : teste la communication
• RTH   : retour au point de départ
• Land  : atterrissage

Indice visuel :
— ligne en vert = drone en cours (running)
— badge d’état à droite
— GOTO envoie une cible (lat, lon, alt).`}
          />
        </div>
        <div className="flex items-center gap-2">
          <input className="input" placeholder="Rechercher par ID…" value={search} onChange={e=>{setSearch(e.target.value); setPage(1);}} style={{width:220}}/>
          <label className="goto-hint flex items-center gap-2">
            <input type="checkbox" checked={activeFirst} onChange={e=>setActiveFirst(e.target.checked)}/>
            Actifs en tête
          </label>
          <select className="select" value={pageSize} onChange={e=>{setPageSize(Number(e.target.value)); setPage(1);}} style={{width:110}}>
            <option value={5}>5 / page</option>
            <option value={10}>10 / page</option>
            <option value={20}>20 / page</option>
            <option value={9999}>Tout</option>
          </select>
          <button className="btn" onClick={fetchDrones}>Rafraîchir</button>
        </div>
      </div>

      <table className="table">
        <thead>
          <tr className="text-gray-400">
            <th className="col-toggle"></th>
            <th>ID</th>
            <th>Interval</th>
            <th>Speed</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {pageRows.map(d => {
            const isRunning = d.status === "running";
            const isBusy = !!busy[d.id];
            const isOpen = expandedId === d.id;
            return (
              <Fragment key={d.id}>
              <tr key={d.id} className={`border-t border-soft/50 hover:bg-soft/40 ${isRunning ? "tr-running" : ""}`}>
                <td className="col-toggle">
                  <button
                    type="button"
                    className={`row-toggle ${isOpen ? "is-open" : ""}`}
                    onClick={() => setExpandedId(isOpen ? null : d.id)}
                    aria-label={isOpen ? "Replier les détails" : "Voir les détails"}
                    title={isOpen ? "Replier" : "Voir les détails"}
                  >
                    <svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true">
                      <path
                        d="M8 10l4 4 4-4"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  </button>
                </td>
                <td className="drone-id-cell btn "
                    onClick={() => { setEditDrone(d); setEditOpen(true); }}
                    title="Modifier ce drone">
                      {d.id}
                </td>
                <td>{d.publish_interval_sec}s</td>
                <td>{d.cruise_speed_mps} m/s</td>
                <td>
                  <span className={`badge ${isRunning ? "badge-running" : "badge-stopped"}`}>
                    {isRunning ? "running" : "stopped"}
                  </span>
                </td>
                <td className="drone-actions">
                  <button className="btn btn-primary"
                          disabled={isRunning || isBusy}
                          onClick={()=>doStart(d.id)}>
                    {isBusy ? "..." : "Start"}
                  </button>
                  <button className="btn"
                          disabled={!isRunning || isBusy}
                          onClick={()=>doStop(d.id)}>
                    Stop
                  </button>
                  <button className="btn btn-ghost" disabled={isBusy} onClick={()=>cmd(d.id, "ping")}>Ping</button>
                  <button className="btn btn-ghost" disabled={isBusy} onClick={()=>cmd(d.id, "rth")}>RTH</button>
                  <button className="btn btn-ghost" disabled={isBusy} onClick={()=>cmd(d.id, "land")}>Land</button>

                  {/* 👉 Supprimer */}
                  <button
                    className="btn btn-danger"
                    disabled={isBusy}
                    onClick={()=>{ setToDelete(d.id); setConfirmOpen(true); }}
                    title="Supprimer ce drone"
                  >
                    Supprimer
                  </button>
                </td>
              </tr>
                      {/* Ligne détails (affichée seulement si ouverte) */}
        {isOpen && (
          <tr className="drone-details-row">
            <td colSpan={6}>
              <div className="drone-details">
                <div className="drone-details__item">
                  <div className="drone-details__label">Position initiale</div>
                  <div className="drone-details__value">
                    lat <code>{d.start_lat}</code>,
                    {" "}lon <code>{d.start_lon}</code>,
                    {" "}alt <code>{d.start_alt}</code> m
                  </div>
                </div>

                <div className="drone-details__item">
                  <div className="drone-details__label">MQTT</div>
                  <div className="drone-details__value">
                    Cmd topic : <code>lab/{d.id}/command</code><br />
                    Télémétrie : <code>lab/{d.id}/telemetry</code>
                  </div>
                </div>

                <div className="drone-details__item">
                  <div className="drone-details__label">Authentification</div>
                  <div className="drone-details__value">
                    <em>Token / clé à afficher ici plus tard</em>
                  </div>
                </div>
              </div>
            </td>
          </tr>
        )}
              </Fragment>
            );
          })}
        </tbody>
      </table>

      {/* Pager */}
<div className="pager">
  <button className="btn" onClick={()=>setPage(1)} disabled={page===1}>«</button>
  <button className="btn" onClick={()=>setPage(p=>Math.max(1, p-1))} disabled={page===1}>‹</button>

  {pageItems.map((it, i) =>
    it === "…" ? (
      <span key={"sep"+i} className="pager-sep">…</span>
    ) : (
      <button
        key={it}
        className={`btn pager-num ${it === page ? "is-active" : ""}`}
        onClick={()=>setPage(it)}
        aria-current={it === page ? "page" : undefined}
        title={it === page ? `Page ${it} (courante)` : `Aller à la page ${it}`}
      >
        {it}
      </button>
    )
  )}

  <button className="btn" onClick={()=>setPage(p=>Math.min(totalPages, p+1))} disabled={page===totalPages}>›</button>
  <button className="btn" onClick={()=>setPage(totalPages)} disabled={page===totalPages}>»</button>
</div>


      {/* GOTO amélioré */}
      <div className="goto">
        <div className="goto__header">
          <strong>GOTO</strong>
          <span className="goto__hint">Choisis un drone et des coordonnées (WGS84).</span>
        </div>

        <form
          className="goto__form"
          onSubmit={(e) => { e.preventDefault(); onGoto(); }}
        >
          <label className="goto__field">
            <span className="goto__label">Drone</span>
            <select
              className="goto__control"
              value={gotoId}
              onChange={(e) => setGotoId(e.target.value)}
            >
              {processed.map(d => (
                <option key={d.id} value={d.id}>
                  {d.id}{runningIds.has(d.id) ? " • running" : ""}
                </option>
              ))}
            </select>
          </label>

          <label className="goto__field">
            <span className="goto__label">Latitude</span>
            <input
                className="goto__control"
                inputMode="decimal"
                placeholder="ex: 43.611"
                value={gotoArgs.lat}
                onChange={e => setGotoArgs(s => ({ ...s, lat: e.target.value }))}
                onPaste={(e) => {
                  const text = (e.clipboardData || window.clipboardData).getData('text');
                  const m = text.match(/^\s*(-?\d+(?:[.,]\d+)?)\s*[,;\s]\s*(-?\d+(?:[.,]\d+)?)\s*$/);
                  if (m) {
                    e.preventDefault();
                    setGotoArgs({ lat: m[1], lon: m[2], alt: gotoArgs.alt });
                  }
                }}
              />
            {gotoArgs.lat && (Number(String(gotoArgs.lat).replace(',', '.')) > 90 ||
                              Number(String(gotoArgs.lat).replace(',', '.')) < -90) && (
              <small className="goto__error">La latitude doit être entre -90 et 90.</small>
            )}
          </label>

          <label className="goto__field">
            <span className="goto__label">Longitude</span>
            <input
              className="goto__control"
              inputMode="decimal"
              placeholder="ex: 3.877"
              value={gotoArgs.lon}
              onChange={e => setGotoArgs(s => ({ ...s, lon: e.target.value }))}
            />
            {gotoArgs.lon && (Number(String(gotoArgs.lon).replace(',', '.')) > 180 ||
                              Number(String(gotoArgs.lon).replace(',', '.')) < -180) && (
              <small className="goto__error">La longitude doit être entre -180 et 180.</small>
            )}
          </label>

          <label className="goto__field">
            <span className="goto__label">Altitude (m) <i className="goto__label--muted">(optionnel)</i></span>
            <input
              className="goto__control"
              inputMode="numeric"
              placeholder="ex: 50"
              value={gotoArgs.alt}
              onChange={e => setGotoArgs(s => ({ ...s, alt: e.target.value }))}
            />
          </label>

          <div className="goto__actions">
            <button
              type="button"
              className="btn btn--ghost"
              onClick={() => setGotoArgs({ lat: "", lon: "", alt: "" })}
            >
              Réinitialiser
            </button>
            <button
                type="submit"
                className="btn btn--primary"
                disabled={
                  !gotoId ||
                  !isValidLat(parseDec(gotoArgs.lat)) ||
                  !isValidLon(parseDec(gotoArgs.lon))
                }
              >
                Envoyer GOTO
              </button>
          </div>
        </form>

        <p className="goto__help">
          Astuce : tu peux coller <code>43.611, 3.877</code> et corriger si besoin. Les virgules sont acceptées.
        </p>
      </div>


      {/* Journal d’actions */}
      <div>
        <div className="flex items-center justify-between">
          <strong>Journal</strong>
          <button className="btn btn-ghost" onClick={()=>setLog([])}>Vider</button>
        </div>
        <ul className="log">
          {log.slice().reverse().map((l, i) => <li key={i}>{l}</li>)}
        </ul>
      </div>

      {/* ---- Modal de confirmation ---- */}
      <Modal
        open={confirmOpen}
        onClose={()=>{ setConfirmOpen(false); setToDelete(null); }}
        title="Confirmer la suppression"
        size="md"
      >
        <div className="space-y-4">
          <p>
            Tu es sur le point de <strong>supprimer</strong> le drone
            {toDelete ? <> <code>{toDelete}</code></> : null}.<br />
            Cette action est définitive.
          </p>

          <div className="flex items-center justify-end gap-2">
            <button className="btn" onClick={()=>{ setConfirmOpen(false); setToDelete(null); }}>
              Annuler
            </button>
            <button
              className="btn btn-danger"
              onClick={async ()=>{
                if (!toDelete) return;
                setBusy(b => ({...b, [toDelete]: true}));
                try{
                  await deleteDrone(toDelete);
                  // retire du tableau immédiatement
                  setRows(prev => prev.filter(r => r.id !== toDelete));
                  addLog("ok", `Suppression ${toDelete}`);
                  // si la page devient vide, recule d'une page
                  const after = processed.length - 1; // -1 car on supprime une ligne
                  const newTotalPages = Math.max(1, Math.ceil(after / pageSize));
                  if (page > newTotalPages) setPage(newTotalPages);
                } catch(e){
                  console.error(e);
                  addLog("error", `Suppression ${toDelete} a échoué`);
                } finally{
                  setBusy(b => ({...b, [toDelete]: false}));
                  setConfirmOpen(false);
                  setToDelete(null);
                }
              }}
            >
              Oui, supprimer
            </button>
          </div>
        </div>
      </Modal>
      <Modal
        open={editOpen}
        onClose={() => { setEditOpen(false); setEditDrone(null); }}
        title={editDrone ? `Modifier le drone ${editDrone.id}` : "Modifier un drone"}
        size="md"
      >
        {editDrone && (
          <EditDroneForm
            drone={editDrone}
            onCancel={() => { setEditOpen(false); setEditDrone(null); }}
            onSaved={(updated) => {
              // Mise à jour immédiate de la ligne dans le tableau
              setRows(prev => prev.map(r => r.id === updated.id ? updated : r));
              setEditOpen(false);
              setEditDrone(null);
              addLog("ok", `Mise à jour ${updated.id}`);
            }}
          />
        )}
      </Modal>




    {/* ---- Fin de la zone droneTable ---- */}
    </div> 

  );
}
