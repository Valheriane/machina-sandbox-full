import os
os.environ["DISABLE_MQTT"] = "1"   # pour éviter la connexion au broker pendant les tests

import pytest
from httpx import AsyncClient, ASGITransport
from main import app  # FastAPI app


@pytest.mark.asyncio
async def test_health():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data.get("status") == "ok"


@pytest.mark.asyncio
async def test_list_drones_empty_ok():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.get("/drones")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


@pytest.mark.asyncio
async def test_create_drone_and_list():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # 1) Création
        payload = {
            "id": "drone-123",
            "name": "Test Drone 123",
            "status": "idle",
            "position": {"lat": 43.6, "lon": 1.44, "alt": 100},
        }
        resp = await ac.post("/drones", json=payload)
        assert resp.status_code == 201

        created = resp.json()
        assert created["id"] == "drone-123"

        # 2) Vérifier qu'il apparait dans /drones
        resp_list = await ac.get("/drones")
        assert resp_list.status_code == 200
        drones = resp_list.json()
        assert any(d["id"] == "drone-123" for d in drones)
        
        
@pytest.mark.asyncio
async def test_create_drone_and_list():
    transport = ASGITransport(app=app)
    drone_id = "drone-123"

    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # 1) Création
        payload = {
            "id": drone_id,
            "name": "Test Drone 123",
            "status": "idle",
            "position": {"lat": 43.6, "lon": 1.44, "alt": 100},
        }

        resp = await ac.post("/drones", json=payload)
        assert resp.status_code == 201
        created = resp.json()
        assert created["id"] == drone_id

        # 2) Vérifier qu'il apparait dans /drones
        resp_list = await ac.get("/drones")
        assert resp_list.status_code == 200
        drones = resp_list.json()
        assert any(d["id"] == drone_id for d in drones)

        # 3) 🔥 Cleanup : suppression du drone
        resp_del = await ac.delete(f"/drones/{drone_id}")
        assert resp_del.status_code in (200, 204)



