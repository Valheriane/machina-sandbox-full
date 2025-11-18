# sign_and_send.py
import json, hmac, hashlib, argparse, subprocess

SECRET = "dev-secret-change-me"  # doit correspondre à SHARED_SECRET dans docker-compose

def sign(payload: dict) -> str:
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    return hmac.new(SECRET.encode(), body, hashlib.sha256).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=1883)
    parser.add_argument("--topic", default="lab/drone/drone-001/commands")
    parser.add_argument("--cmd", required=True, choices=["ping","takeoff","land","rth","goto"])
    parser.add_argument("--lat", type=float)
    parser.add_argument("--lon", type=float)
    parser.add_argument("--alt", type=float)
    args = parser.parse_args()

    payload = {"cmd": args.cmd}
    if args.cmd == "goto":
        if args.lat is None or args.lon is None:
            raise SystemExit("Pour 'goto', il faut --lat et --lon (et optionnellement --alt).")
        payload["args"] = {"lat": args.lat, "lon": args.lon}
        if args.alt is not None:
            payload["args"]["alt"] = args.alt

    sig = sign(payload)
    envelope = {"sig": sig, "payload": payload}
    msg = json.dumps(envelope, separators=(",", ":"))

    # Nécessite mosquitto_pub (client mosquitto) installé sur ta machine.
    # Sous MobaXterm, tu peux l’installer sur Windows (Mosquitto) et l’appeler pareil.
    cmd = [
        "mosquitto_pub",
        "-h", args.host,
        "-p", str(args.port),
        "-t", args.topic,
        "-m", msg,
    ]
    print(">>> publish:", " ".join(cmd))
    print(">>> message:", msg)
    subprocess.check_call(cmd)

if __name__ == "__main__":
    main()
