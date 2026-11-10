# CLAUDE.md — Instrucciones para Claude Code

> Este archivo lo lee Claude Code automáticamente al abrir la carpeta.
> Escrito tras una revisión completa del repositorio (9-nov-2026).
> Product owner: el equipo. Claude Code construye; **el equipo decide**.

## 1. Contexto en una frase

Proyecto final de la materia: una app de tareas (FastAPI + Vite/nginx) que se
despliega en **AWS ECS Fargate** mediante **tres pipelines de GitHub Actions**
(Terraform → build/push a ECR → deploy a ECS), con autenticación **OIDC** (cero
llaves en el repo). Se evalúa en una **demo en vivo** ante un docente experto en
AWS. Plazo: **2 días**.

Situación del equipo:
- Cuenta de AWS **personal** (se pueden crear roles IAM y proveedor OIDC).
- **No existe aún** el repositorio en GitHub ni nada creado en AWS.
- Equipo de **2 a 4 personas** → una sola cuenta AWS y un solo repo.

## 2. Estado actual (ya verificado — NO rehacer)

El código está **completo y bien diseñado**. No reescribas ni "mejores" la
arquitectura. Solo aplica los cambios puntuales de la Etapa 1.

| Verificación | Resultado |
|---|---|
| `python -m pytest` en `aplicacion/backend` | ✅ 4/4 pruebas |
| `npm run build` en `aplicacion/frontend` | ✅ compila (Vite 7, Node 22) |
| `bash -n` en los scripts de `pipelines/` | ✅ sintaxis OK |
| Saltos de línea CRLF en `.sh/.yml/.tf` | ✅ ninguno (`.gitattributes` lo protege) |
| `pipelines/*.yml` vs `.github/workflows/*.yml` | ✅ idénticos |
| `terraform fmt -check` / `terraform validate` | ⚠️ **NO verificado** (no había Terraform) → Etapa 0 |
| `docker compose up` | ⚠️ **NO verificado** → Etapa 0 |

Documentos que ya existen y deben mantenerse coherentes:
`README.md` (entrega), `GUIA_PASO_A_PASO.txt` (guía + solución de errores),
`terraform/README.md`, `pipelines/README.md`.

## 3. Reglas de trabajo

1. **Cambios mínimos.** Cada cambio debe estar en la lista de la Etapa 1 o ser
   aprobado por el equipo. Si ves algo más, propónlo; no lo hagas.
2. **Nunca** escribas llaves, contraseñas, tokens, IDs de cuenta ni ARNs reales
   en archivos del repo. Los valores reales van en variables de GitHub o en
   `*.tfvars` (ignorados por git).
3. **Nunca** ejecutes `terraform apply`, `terraform destroy`, `git push`,
   `gh repo create` ni nada que cree recursos o cueste dinero **sin
   confirmación explícita** del equipo en ese momento.
4. Si editas un workflow, edítalo en `pipelines/` y luego ejecuta
   `bash pipelines/sincronizar-workflows.sh`. Verifica con `diff` que
   `pipelines/` y `.github/workflows/` quedan idénticos.
5. Si cambias el texto `Tablero de tareas` en `index.html`, cámbialo también
   en `pipelines/scripts/smoke-test.sh`.
6. Trabaja **por etapas**. Al final de cada etapa: muestra qué cambió, ejecuta
   la validación de esa etapa y **detente** a esperar el visto bueno.
7. Ante un bloqueo, da **2-3 opciones con sus pros y contras**; no elijas solo.
8. Explica en español claro, sin jerga innecesaria.

## 4. Etapas

### Etapa 0 — Verificación local (sin AWS, sin costo)

Objetivo: confirmar lo que no se pudo verificar en la revisión.

- `terraform -version` (≥ 1.10). Si no está: `winget install Hashicorp.Terraform`.
- En `terraform/` y en `terraform/bootstrap/`:
  `terraform fmt -check -recursive -diff`, luego
  `terraform init -backend=false` y `terraform validate`.
  Si `fmt` falla, ejecuta `terraform fmt -recursive` y muestra el diff.
- `cd aplicacion && docker compose up --build -d`, luego comprueba:
  `curl http://localhost:8080/api/health` → `{"status":"ok",...}` y
  `curl http://localhost:8080/` contiene `Tablero de tareas`.
  Después: `docker compose down`.
- Borra cualquier `.terraform/`, `node_modules/`, `dist/` o `.venv/` generado
  (están en `.gitignore`, pero que no queden basura en la entrega).

✅ Validación: todo lo anterior en verde. **Detente y reporta.**

### Etapa 1 — Correcciones puntuales (v1)

Aplicar en este orden. Cada una es pequeña.

1. **[Bug latente — Pipeline 1] El lock file no viaja entre jobs.**
   `actions/upload-artifact@v4` excluye archivos ocultos por defecto desde la
   v4.4, así que `terraform/.terraform.lock.hcl` **no** se sube con el plan.
   En el paso "Guardar plan" de `pipelines/1-infraestructura.yml` agrega
   `include-hidden-files: true` bajo `with:`.
2. **[Demo limpia] El smoke test deja basura en el tablero.** En
   `pipelines/scripts/smoke-test.sh`, el POST crea la tarea
   "Smoke test del pipeline" y queda visible en la demo. Guarda el `id` que
   devuelve el POST y bórrala con `DELETE /api/tareas/{id}` (con `-fsS`, para
   que un fallo también ponga el pipeline en rojo). Así se prueba el CRUD de
   punta a punta y el tablero queda limpio.
3. **[Build reproducible] Falta `package-lock.json`.** En `aplicacion/frontend`
   ejecuta `npm install` para generarlo y súbelo al repo. Cambia
   `npm install --no-audit --no-fund` por `npm ci --no-audit --no-fund` en
   `aplicacion/frontend/Dockerfile` y en `pipelines/2-build-ecr.yml`
   (job `build-frontend`). Agrega `cache: npm` y
   `cache-dependency-path: aplicacion/frontend/package-lock.json` a
   `actions/setup-node`.
4. **[Cosmético] Etiqueta incorrecta.** En `pipelines/2-build-ecr.yml`, paso
   "Verificar que la imagen quedó en ECR", la columna se llama `tamanoMB` pero
   el valor es en bytes. Renómbrala a `tamanoBytes`.
5. **[Cosmético] Versión del frontend.** En `aplicacion/frontend/src/main.js`
   muestra `VITE_APP_VERSION` recortado a 7 caracteres (igual que el backend).
6. Sincroniza los workflows (regla 4).

✅ Validación: `pytest`, `npm ci && npm run build`, `bash -n` de los scripts,
`diff -r` entre `pipelines/*.yml` y `.github/workflows/`, y de nuevo
`docker compose up --build` + los dos `curl` de la Etapa 0.
**Detente y muestra el diff completo.**

### Etapa 2 — Repositorio en GitHub

Lo hace **una sola persona** del equipo.

- Requisitos: `git`, y de preferencia `gh` (GitHub CLI) con `gh auth login`.
- Recomendación: repositorio **público** (los "Required reviewers" del
  environment son gratis en repos públicos; en privados requieren GitHub Pro /
  Student Pack). **Pide confirmación de público vs privado.**
- `git init`, `git add .`, revisa `git status` y confirma que **no** hay
  `*.tfvars`, `*.tfstate`, `.env` ni llaves. Commit inicial.
- Crear el repo y hacer push **solo con confirmación** (`gh repo create ...`).
  Es normal que los workflows fallen en este primer push (aún no hay variables).
- Agregar a los compañeros como colaboradores (Settings → Collaborators).

✅ Validación: el repo existe, `main` tiene el código y `.github/workflows/`
tiene los 3 archivos. **Detente.**

### Etapa 3 — Bootstrap en AWS (una vez, desde la PC)

- Verifica credenciales: `aws sts get-caller-identity` (usuario administrador
  configurado por el equipo con `aws configure`; Claude Code **no** debe pedir
  ni escribir las llaves).
- Crea los roles vinculados a servicio (si responde "has been taken", ya
  existían y está bien):
  `aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com`
  `aws iam create-service-linked-role --aws-service-name elasticloadbalancing.amazonaws.com`
- En `terraform/bootstrap/`: copia `terraform.tfvars.example` a
  `terraform.tfvars` con `github_repo = "<usuario>/<repo>"` **exacto**.
  `terraform init`, `terraform plan`, y `terraform apply` **solo con
  confirmación**.
- Anota las salidas `tf_state_bucket` y `github_actions_role_arn`.
  Recuerda al equipo **guardar** `terraform/bootstrap/terraform.tfstate`
  fuera del repo (se necesita para el `destroy` final).

✅ Validación: el bucket existe y el rol `triple-pipeline-github-actions` existe
(`aws iam get-role --role-name triple-pipeline-github-actions`). **Detente.**

### Etapa 4 — Configurar GitHub

Con `gh` (o guiar al equipo por la interfaz web):

- Variables (pestaña **Variables**, no Secrets):
  `gh variable set AWS_REGION --body us-east-1`
  `gh variable set PROJECT_NAME --body triple-pipeline`
  `gh variable set AWS_ROLE_ARN --body <salida github_actions_role_arn>`
  `gh variable set TF_STATE_BUCKET --body <salida tf_state_bucket>`
- Environments: `infraestructura` con **Required reviewers** (al menos 1
  integrante) y `produccion` sin reglas. Pueden crearse con
  `gh api -X PUT repos/<owner>/<repo>/environments/<nombre>`; los reviewers
  requieren el ID numérico del usuario (`gh api users/<login> --jq .id`).

✅ Validación: `gh variable list` muestra las 4 variables y
`gh api repos/<owner>/<repo>/environments --jq '.environments[].name'` muestra
los 2 environments. **Detente.**

### Etapa 5 — Ejecutar los tres pipelines (primera vez)

Todo esto **con confirmación** (crea recursos con costo ≈ 1 USD/día).

1. `gh workflow run "1 - Infraestructura (Terraform)" -f accion=apply`
   → un integrante aprueba en "Review deployments". ~5 min.
2. `gh workflow run "2 - Build y publicación en ECR"`.
3. El Pipeline 3 arranca solo al terminar bien el 2.
   Sigue el avance con `gh run list` / `gh run watch`.

✅ Validación:
- `aws ecr describe-images --repository-name triple-pipeline-backend` (y
  `-frontend`) muestran los tags `<sha>` y `latest`.
- `aws ecs describe-services --cluster triple-pipeline-cluster --services backend frontend`
  → `runningCount = 1` en ambos.
- `curl http://<alb>/api/health` devuelve la versión = SHA del último commit.
- Abrir la URL en el navegador (escritorio **y** móvil) y crear/completar/borrar
  una tarea.
**Detente y reporta la URL.**

### Etapa 6 — Ensayo de la demo y evidencia

- Ensayar el "cambio en vivo": editar el texto de `<p class="sub">` en
  `aplicacion/frontend/index.html` (no el `<h1>`), commit + push, y medir
  cuánto tardan los pipelines 2 y 3 en total. Anotar el tiempo.
- Ensayar el rollback manual: ejecutar el Pipeline 3 con `image_tag` = SHA del
  commit anterior y comprobar que la barra verde muestra ese SHA.
- Completar la sección **"Evidencia de la demo"** del `README.md` con la URL
  usada, enlaces a las ejecuciones de Actions y nombres de las capturas
  (guardar capturas en `docs/evidencia/`, sin datos sensibles: ocultar el ID
  de cuenta si se desea).
- Agregar al `README.md` una sección corta **"Equipo y roles en la demo"**
  (nombres y qué parte presenta cada uno; los nombres los da el equipo).

✅ Validación: el README se lee completo de principio a fin sin "pendiente".
**Detente.**

### Etapa 7 — Limpieza (después de la calificación)

Seguir la Parte D de `GUIA_PASO_A_PASO.txt`: Pipeline 1 con `destroy`, vaciar
el bucket de estado (todas las versiones) y `terraform destroy` en
`terraform/bootstrap/`. **Solo con confirmación.**

## 5. Fuera de alcance en v1 (no implementar sin aprobación)

- Persistencia (DynamoDB/RDS): hoy las tareas viven en memoria y se pierden en
  cada despliegue. Es una decisión consciente y documentada.
- HTTPS/dominio propio (ACM + Route 53).
- Subredes privadas + NAT Gateway o VPC endpoints.
- Autoescalado, varios ambientes (dev/prod), blue/green con CodeDeploy.
- Alarma de presupuesto en AWS Budgets (recomendable: créala a mano en la
  consola, 5 USD, antes de la Etapa 5).

## 6. Si algo falla

Primero busca el mensaje de error en `GUIA_PASO_A_PASO.txt` (Parte C), que
cubre los fallos más comunes de cada pipeline. Riesgos conocidos de una cuenta
nueva: ALB bloqueado ("does not support creating load balancers") → requiere
caso en AWS Support y puede tardar horas; por eso la Etapa 5 debe hacerse
**el primer día**, no el día de la demo.
