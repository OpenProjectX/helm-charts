Built on GitHub CI by `.github/workflows/docker-bump.yml` — push an empty
commit to `gh-pages` with the bump message:

```shell
git commit --allow-empty -m "bump(docker): docker/wrenai"
git push
```

The workflow auto-increments the `0.1.x` tag on `ghcr.io/openprojectx/wrenai`
(and moves `latest`). Downloaded artifacts (Temurin / Node tarballs) are cached
across runs via the `/var/cache/downloads` BuildKit cache mount +
`actions/cache`; image layers are cached in the `-cache:latest` registry ref.

## Why this image exists

Upstream publishes **no** image for the current product. `docker/` exists only
on the frozen `legacy/v1` branch, and every `ghcr.io/canner/*` image
(`wren-ui`, `wren-ai-service`, `wren-engine`, published to 0.29.1) belongs to
the sunset "GenBI Classic" stack, which receives no security fixes. The current
OSS product is the `wrenai` PyPI package plus a Rust core — a CLI, not a
service — so an image has to be maintained here.

## Contents

| Component | Version | Purpose |
|---|---|---|
| Python | 3.12 | Runs the CLI (needs 3.11+) |
| `wren` CLI | `ARG WRENAI_VERSION` | Semantic layer, MDL, MCP server |
| Temurin JDK | `ARG JDK_VERSION` (21) | JVM/JDBC tooling; `JAVA_HOME` set |
| Node.js | `ARG NODE_VERSION` (22) | GenBI apps: `wren-core-wasm`, `wrangler`, `vercel` |

The CLI lives in an isolated venv at `/opt/wren/venv`, first on `PATH`, so it
never collides with an application's own Python packages.

## The mcp pin — do not remove

`wrenai` declares `mcp[cli]>=1.19` with **no upper bound**, but `mcp` 2.0
removed `mcp.server.fastmcp`, which `wren/mcp_server.py` imports. Installing
`wrenai[mcp]` on its own produces a server that dies with:

```
ModuleNotFoundError: No module named 'mcp.server.fastmcp'
```

The Dockerfile pins `"mcp[cli]<2"` alongside `wrenai`. The sanity-check layer
imports `FastMCP` so a bad resolution fails the build rather than shipping.

## Connector extras

`ARG WREN_EXTRAS` controls which warehouse connectors are installed. Default:

```
postgres,mysql,oracle,bigquery,snowflake,redshift,clickhouse,trino,
athena,databricks,spark,main,mcp
```

Deliberately excluded:

- **`memory`** — pulls LanceDB plus an embedding model (~800 MB). Only worth it
  past ~200 models; add it if you need `wren memory index` semantic recall.
- **`mssql`** — `pyodbc` builds fine but cannot connect without Microsoft's
  ODBC driver, which needs a separate apt repo. Add both together or not at all.

`mysql` needs a C toolchain: `build-essential`, `default-libmysqlclient-dev`
and `pkg-config` are installed and **purged in the same layer**, so they never
ship. `libmariadb3` stays — that is what the compiled extension links against.

Build a leaner image by overriding:

```shell
docker build --build-arg WREN_EXTRAS=postgres,main,mcp -t wrenai:pg .
```

## Usage

Default command is the MCP server over stdio:

```shell
docker run --rm -i -v "$PWD:/project" ghcr.io/openprojectx/wrenai
```

> Every example below omits `--user`/`HOME` for brevity. On a host-owned
> checkout you will need them — see **File ownership and `.env`**.

Anything else, by overriding the command:

```shell
# one-off query through the semantic layer
docker run --rm -v "$PWD:/project" --env-file .env \
  ghcr.io/openprojectx/wrenai wren --sql "SELECT count(*) FROM orders"

# build the MDL manifest
docker run --rm -v "$PWD:/project" ghcr.io/openprojectx/wrenai wren context build

# MCP over HTTP (see the K8s topologies note below)
docker run --rm -p 8080:8080 -v "$PWD:/project" --env-file .env \
  ghcr.io/openprojectx/wrenai \
  wren serve mcp --transport http --host 0.0.0.0 --port 8080
```

Runs as non-root (`wren`, uid 10001). `WREN_PROJECT_HOME=/project` and
`WORKDIR=/project`, so mount the Wren project there. `$HOME/.wren` is writable
for `wren profile add` and `wren memory index`.

## File ownership and `.env` — read this before first run

The image runs as `wren` (uid 10001). A Wren project checked out on a host
normally has a `chmod 600 .env` owned by *your* uid, which uid 10001 cannot
read — and `wren` loads `.env` unconditionally, surfacing the `EACCES` as an
unhandled `PermissionError` traceback rather than a clean message.

**Local development** — run as yourself and give `HOME` somewhere writable:

```shell
docker run --rm --network host \
  --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$PWD:/project" \
  ghcr.io/openprojectx/wrenai \
  wren --sql "SELECT count(*) FROM orders"
```

`HOME=/tmp` matters: `~/.wren/profiles.yml` is written at that path, and
`/home/wren` is not writable by an arbitrary uid.

**Profiles do not travel with the project.** `~/.wren/profiles.yml` lives in the
container's home, so a fresh container has none. Either mount the host's
`~/.wren`, or — better, and what CI should do — recreate the profile from a
checked-in placeholder file each run:

```shell
wren profile add <name> --from-file connection.yml   # ${VAR} placeholders only
```

**Deployed environments should ship no `.env` at all.** Put the credentials in
a Kubernetes Secret and let `${VAR}` placeholders in `connection.yml` resolve
from the environment. That sidesteps both the ownership problem and the
practice of baking a secrets file into an image.

## Verified

Built and exercised against a live Postgres project:

- `python 3.12.14`, `java 21.0.12.1 LTS`, `node v22.23.1` / `npm 10.9.8`,
  `wrenai 0.13.3` — on `PATH` for both the default command and `bash -l`
- `wren context validate` and `wren --sql` returning real rows through the MDL
- `wren serve mcp --transport http` exposing all **17** tools, `run_sql`
  answering over the network
- `from mcp.server.fastmcp import FastMCP` — the pin holds

Image size ~3.2 GB, dominated by the 165 MB Rust core plus the connector
extras, JDK and Node. Override `WREN_EXTRAS` for a much smaller image if you
only need one warehouse.

## Kubernetes notes

- **Never expose the MCP HTTP port outside the cluster.** `wren serve mcp` has
  no authentication, TLS or token option of any kind. Bind `127.0.0.1` for a
  sidecar, or put a gateway in front.
- **MCP sessions are held in-process**, so a multi-replica Service needs
  session affinity — hash on the `mcp-session-id` header, or co-locate one
  instance per agent pod. A plain round-robin Service returns
  `404 Session not found`.
- **One instance serves one query at a time** (single shared psycopg
  connection, no pool). Size replicas to peak concurrent queries.
- **No health endpoint**: `GET /` and `/health` are 404, `GET /mcp` is 406. Use
  a TCP socket probe.
- Bake the compiled `target/mdl.json` into a derived image, or mount it; put
  warehouse credentials in a Secret rather than a `.env` file.
- `--no-connect` (transpile only) and withholding `--allow-write` are the two
  gating flags worth setting when an autonomous agent has access.

## Bumping

- `WRENAI_VERSION` — the CLI release to install.
- `NODE_VERSION` — pinned patch; edit to bump.
- `JDK_VERSION` — major only; the latest Temurin GA patch is pulled when not
  already cached.
- `UV_VERSION` — the `uv` binary copied from `ghcr.io/astral-sh/uv`.

After changing any of them, re-run the sanity-check layer by rebuilding; it
verifies `python`, `java`, `node`, `npm`, `wren --version`, a real
`wren docs connection-info postgres` call, and the `FastMCP` import.
