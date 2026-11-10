from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    r = client.get("/api/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_info_incluye_version():
    r = client.get("/api/info")
    assert r.status_code == 200
    assert "version" in r.json()


def test_crud_tareas():
    creada = client.post("/api/tareas", json={"titulo": "Probar el pipeline"})
    assert creada.status_code == 201
    tarea_id = creada.json()["id"]

    assert any(t["id"] == tarea_id for t in client.get("/api/tareas").json())

    cambio = client.patch(f"/api/tareas/{tarea_id}", json={"completada": True})
    assert cambio.status_code == 200
    assert cambio.json()["completada"] is True

    assert client.delete(f"/api/tareas/{tarea_id}").status_code == 204
    assert client.delete(f"/api/tareas/{tarea_id}").status_code == 404


def test_titulo_vacio_rechazado():
    assert client.post("/api/tareas", json={"titulo": ""}).status_code == 422
