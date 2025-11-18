# Centralise la lecture des variables d'env pour l'API.
import os

def env_str(name: str, default: str) -> str:
    return os.getenv(name, default)

def env_int(name: str, default: int) -> int:
    v = os.getenv(name);  return int(v) if v is not None else default

def get_config():
    return {
        "mqtt": {
            "host": env_str("MQTT_HOST", "localhost"),
            "port": env_int("MQTT_PORT", 1883),
            "topic_prefix": env_str("TOPIC_PREFIX", "lab"),
        },
        "shared_secret": env_str("SHARED_SECRET", "dev-secret-change-me"),
        "database_url": env_str("DATABASE_URL", "sqlite:///data/fleet.db"),
    }
