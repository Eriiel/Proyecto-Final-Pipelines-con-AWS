"""API de tareas para el proyecto final (FastAPI).

Todas las rutas cuelgan de /api porque el ALB envía /api/* al backend
y el resto al frontend.
"""

import os
import socket
from datetime import datetime, timezone
from threading import Lock

from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field

APP_VERSION = os.getenv("APP_VERSION", "local")
STARTED_AT = datetime.now(timezone.utc)

app = FastAPI(
    title="API Tareas - Triple Pipeline",
    version=APP_VERSION,
    docs_url="/api/docs",
    openapi_url="/api/openapi.json",
    redoc_url=None,
)


class TareaNueva(BaseModel):
    titulo: str = Field(min_length=1, max_length=120)


class TareaCambio(BaseModel):
    titulo: str | None = Field(default=None, min_length=1, max_length=120)
    completada: bool | None = None


class Tarea(BaseModel):
    id: int
    titulo: str
    completada: bool = False
    creada: datetime


# Almacenamiento en memoria: suficiente para la demo con 1 tarea ECS.
# (Mejora posible: DynamoDB o RDS para persistir y escalar a varias tareas.)
_tareas: dict[int, Tarea] = {}
_siguiente_id = 1
_lock = Lock()


def _semilla() -> None:
    for titulo in ("Pipeline 1: Terraform", "Pipeline 2: imágenes a ECR", "Pipeline 3: despliegue a ECS"):
        crear_tarea(TareaNueva(titulo=titulo))


@app.get("/api/health")
def health() -> dict:
    """Usado por el health check del ALB y por el smoke test del Pipeline 3."""
    return {"status": "ok", "version": APP_VERSION}


@app.get("/api/info")
def info() -> dict:
    """Datos para mostrar en la demo qué versión y qué contenedor responde."""
    return {
        "servicio": "backend",
        "version": APP_VERSION,
        "contenedor": socket.gethostname(),
        "iniciado": STARTED_AT.isoformat(),
        "region": os.getenv("AWS_REGION", "local"),
    }


@app.get("/api/tareas", response_model=list[Tarea])
def listar_tareas() -> list[Tarea]:
    return sorted(_tareas.values(), key=lambda t: t.id)


@app.post("/api/tareas", response_model=Tarea, status_code=status.HTTP_201_CREATED)
def crear_tarea(datos: TareaNueva) -> Tarea:
    global _siguiente_id
    with _lock:
        tarea = Tarea(id=_siguiente_id, titulo=datos.titulo.strip(), creada=datetime.now(timezone.utc))
        _tareas[tarea.id] = tarea
        _siguiente_id += 1
    return tarea


@app.patch("/api/tareas/{tarea_id}", response_model=Tarea)
def actualizar_tarea(tarea_id: int, cambios: TareaCambio) -> Tarea:
    tarea = _tareas.get(tarea_id)
    if tarea is None:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")
    actualizada = tarea.model_copy(update=cambios.model_dump(exclude_none=True))
    _tareas[tarea_id] = actualizada
    return actualizada


@app.delete("/api/tareas/{tarea_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_tarea(tarea_id: int) -> None:
    if _tareas.pop(tarea_id, None) is None:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")


_semilla()
