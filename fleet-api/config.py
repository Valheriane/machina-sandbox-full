# fleet-api/config.py
import os

def env_str(name: str, default: str) -> str:
    return os.getenv(name, default)

def env_int(name: str, default: int) -> int:
    v = os.getenv(name)
    return int(v) if v is not None else default

def get_config():
    env = env_str("APP_ENV", "dev")  # "dev" ou "prod"

    # --- CORS ---
    if env == "dev":
        # En dev : on autorise tout ce qui ressemble à localhost / 127.0.0.1,
        # peu importe le port (donc ça couvre minikube, port-forward, etc.)
        cors_allow_origins: list[str] = []  # on laisse la liste vide
        cors_allow_origin_regex = r"http://(localhost|127\.0\.0\.1)(:\d+)?"
    else:
        # En prod : liste stricte, fournie par une variable d'environnement
        raw = env_str("CORS_ALLOWED_ORIGINS", "")
        cors_allow_origins = [
            origin.strip()
            for origin in raw.split(",")
            if origin.strip()
        ]
        cors_allow_origin_regex = None

    return {
        "env": env,
        "mqtt": {
            "host": env_str("MQTT_HOST", "localhost"),
            "port": env_int("MQTT_PORT", 1883),
            "topic_prefix": env_str("TOPIC_PREFIX", "lab"),
        },
        "shared_secret": env_str("SHARED_SECRET", "dev-secret-change-me"),
        "database_url": env_str("DATABASE_URL", "sqlite:///data/fleet.db"),
        "cors": {
            "allow_origins": cors_allow_origins,
            "allow_origin_regex": cors_allow_origin_regex,
        },
    }
