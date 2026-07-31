const host = window.location.hostname;

window.APP_CONFIG = {
  API_URL: `http://${host}:30800`,
  MQTT_WS_URL: `ws://${host}:30901`,
};

window.__APP_CONFIG__ = window.APP_CONFIG;
