import "./style.css";

const API = "/api";
const estado = document.getElementById("estado");
const lista = document.getElementById("lista");
const form = document.getElementById("form-tarea");
const inputTitulo = document.getElementById("titulo");

// VITE_APP_VERSION se inyecta en el build (Pipeline 2) con el SHA del commit.
document.getElementById("version-frontend").textContent =
  `Frontend ${(import.meta.env.VITE_APP_VERSION ?? "local").slice(0, 7)}`;

async function api(ruta, opciones = {}) {
  const r = await fetch(`${API}${ruta}`, {
    headers: { "Content-Type": "application/json" },
    ...opciones,
  });
  if (!r.ok) throw new Error(`${r.status} ${r.statusText}`);
  return r.status === 204 ? null : r.json();
}

async function cargarInfo() {
  try {
    const info = await api("/info");
    estado.className = "estado ok";
    estado.textContent = `Backend en línea · versión ${info.version.slice(0, 7)} · contenedor ${info.contenedor} · ${info.region}`;
  } catch (e) {
    estado.className = "estado error";
    estado.textContent = `No se pudo conectar con el backend (${e.message})`;
  }
}

function pintar(tareas) {
  lista.replaceChildren(
    ...tareas.map((t) => {
      const li = document.createElement("li");
      li.className = t.completada ? "hecha" : "";

      const check = document.createElement("input");
      check.type = "checkbox";
      check.checked = t.completada;
      check.addEventListener("change", () =>
        api(`/tareas/${t.id}`, { method: "PATCH", body: JSON.stringify({ completada: check.checked }) }).then(cargarTareas),
      );

      const texto = document.createElement("span");
      texto.textContent = t.titulo;

      const borrar = document.createElement("button");
      borrar.className = "borrar";
      borrar.title = "Eliminar";
      borrar.textContent = "✕";
      borrar.addEventListener("click", () => api(`/tareas/${t.id}`, { method: "DELETE" }).then(cargarTareas));

      li.append(check, texto, borrar);
      return li;
    }),
  );
  if (tareas.length === 0) {
    const vacio = document.createElement("li");
    vacio.className = "vacio";
    vacio.textContent = "No hay tareas todavía.";
    lista.append(vacio);
  }
}

async function cargarTareas() {
  try {
    pintar(await api("/tareas"));
  } catch {
    lista.replaceChildren();
  }
}

form.addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const titulo = inputTitulo.value.trim();
  if (!titulo) return;
  await api("/tareas", { method: "POST", body: JSON.stringify({ titulo }) });
  inputTitulo.value = "";
  cargarTareas();
});

cargarInfo();
cargarTareas();
