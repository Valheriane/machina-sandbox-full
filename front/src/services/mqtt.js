// src/services/mqtt.js

// Import compatible (tu peux garder ta version si elle marche déjà)
let MQTT = null;
try {
  MQTT = await import('mqtt/dist/mqtt.min.js');
} catch {
  MQTT = await import('mqtt');
}

// Récupère la bonne fonction connect(), selon la forme d'export
const connectFn =
  MQTT.connect ||
  (MQTT.default && MQTT.default.connect) ||
  (MQTT.MQTT && MQTT.MQTT.connect);

if (typeof connectFn !== 'function') {
  console.error('[MQTT] connect export introuvable dans', Object.keys(MQTT));
  throw new Error('MQTT connect() non trouvé (vérifie la version du paquet).');
}

const WS_URL = import.meta.env.VITE_MQTT_WS_URL || 'ws://localhost:9001';

let client;
function ensureClient() {
  if (client) return client;

  const url = new URL(WS_URL);
  client = connectFn({
    protocol: 'ws',
    hostname: url.hostname,
    port: Number(url.port || 9001),
    path: '/',              // crucial pour Mosquitto
    reconnectPeriod: 1000,
  });

  client.on('connect', () => console.log('[MQTT] connected'));
  client.on('reconnect', () => console.log('[MQTT] reconnecting...'));
  client.on('error', (e) => console.error('[MQTT] error', e));

  return client;
}

export function getClient() {
  return ensureClient();
}

export function subscribe(topic, handler) {
  const c = ensureClient();

  const doSubscribe = () => {
    c.subscribe(topic, (err) => {
      if (err) console.error('subscribe error', err);
    });
  };

  // Si pas encore connecté, on attend l’événement 'connect'
  if (!c.connected) {
    const onceConnect = () => {
      c.removeListener?.('connect', onceConnect);
      doSubscribe();
    };
    c.on('connect', onceConnect);
  } else {
    doSubscribe();
  }

  const onMessage = (t, payload) => {
    try {
      handler(t, JSON.parse(payload.toString()));
    } catch {
      handler(t, payload.toString());
    }
  };


  c.on('message', onMessage);

  // cleanup compatible (pas de .off() → on enlève via removeListener)
  return () => {
    if (c) {
      c.removeListener?.('message', onMessage);
      c.unsubscribe(topic, (err) => {
        if (err) console.warn('unsubscribe error', err);
      });
    }
  };
}
