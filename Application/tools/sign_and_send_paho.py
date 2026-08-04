import json, hmac, hashlib, argparse, time
import paho.mqtt.client as mqtt

SECRET = "dev-secret-change-me"  # doit matcher SHARED_SECRET dans docker-compose.yml

def sign(payload: dict) -> str:
    body = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    return hmac.new(SECRET.encode(), body, hashlib.sha256).hexdigest()

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="localhost")
    p.add_argument("--port", type=int, default=1883)
    #p.add_argument("--topic", default="lab/drone/drone-001/commands")
    p.add_argument("--topic", default=None)
    p.add_argument("--cmd", required=True, choices=["ping","takeoff","land","rth","goto"])
    p.add_argument("--lat", type=float)
    p.add_argument("--lon", type=float)
    p.add_argument("--alt", type=float)
    p.add_argument("--topic-prefix", default="lab")
    p.add_argument("--drone-id", default="drone-001")

    args = p.parse_args()

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
    topic = args.topic or f"{args.topic_prefix}/drone/{args.drone_id}/commands"

    client = mqtt.Client()  # paho 1.x compatible
    client.connect(args.host, args.port, keepalive=15)
    client.loop_start()
    #client.publish(args.topic, msg, qos=0)
    client.publish(topic, msg, qos=0)
    time.sleep(0.5)
    client.loop_stop()
    #print("OK ->", args.topic, msg)
    print("OK ->", topic, msg)

if __name__ == "__main__":
    main()
