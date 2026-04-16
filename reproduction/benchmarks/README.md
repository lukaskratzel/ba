# Benchmark Reproduction Package

This directory is the self-contained reproduction package for the benchmark results reported in the thesis. It contains:

- the Bun-based benchmark runner used to measure session startup latency,
- the six CSV exports used for the figures in the benchmark chapter,
- the Python plotting script used to generate the duration boxplot from the benchmark CSV files.

The package is intentionally cleaned up compared to the original scratch directory: it excludes local environment state (`node_modules`, `.venv`, `.env`, `.mplconfig`), ad hoc session CSV exports, editor metadata, and generated plot outputs.

## Directory Layout

```text
.
├── README.md
├── index.ts
├── package.json
├── bun.lock
├── tsconfig.json
├── pyproject.toml
├── uv.lock
├── data/
│   ├── 100-pre-lazy-seq.csv
│   ├── 100-post-lazy-seq.csv
│   ├── 100-post-eager-seq.csv
│   ├── 50-pre-lazy-concurrent.csv
│   ├── 50-post-lazy-concurrent.csv
│   └── 50-post-eager-concurrent.csv
└── plot_duration_boxplots.py
```

## Prerequisites

### Benchmark Execution

- `bun` installed locally
- network access to the target Theia Cloud service deployment
- a valid bearer access token in `AUTH_TOKEN`, or a valid refresh token in `REFRESH_TOKEN`
- if token refresh is used: access to the OIDC token endpoint and matching client credentials
- if `--cleanup=true` is used: `kubectl` configured against the cluster that hosts the benchmarked Theia Cloud deployment

Install the Bun development dependencies in this directory:

```bash
bun install
```

### Plot Generation

- `uv` installed locally
- Python 3.13 or newer, as declared in `pyproject.toml`

No manual virtual environment setup is required. `uv run ...` will use the locked dependencies in `uv.lock`.

## What Is Measured

The benchmark measures end-to-end backend session preparation time for `POST /service` launch requests.

- The timer starts immediately before the launch request is sent to the Theia Cloud service.
- The timer stops when the service responds with the externally reachable redirect URL for the launched session.
- The measurement includes control-plane processing, routing propagation, and session exposure.
- The measurement excludes browser-side loading, frontend rendering, and IDE asset download time.

Every successful launch appends one CSV row with the schema:

```text
appdef,environment,startedEpochMs,durationMs,strategy
```

Column meanings:

- `appdef`: app definition name passed via `--appDefinition`
- `environment`: logical environment label; either supplied via `--environment` or derived from the service hostname
- `startedEpochMs`: Unix epoch timestamp in milliseconds at the start of the measured request
- `durationMs`: measured request-to-redirect duration in milliseconds
- `strategy`: inferred startup mode based on the redirect token format

Startup mode classification:

- `lazy`: the redirect token is a UUID
- `eager`: the redirect token matches `{appDefinition}-{instanceIdMonotonic}`

## Workloads Under Test

The thesis evaluates two workload scenarios. The benchmark runner itself is generic; these scenarios are produced by how the CLI is invoked.

### Scenario 1: Sequential Workload

- 100 launch requests
- requests are started one after another
- a fixed 10 second gap is inserted between launches
- purpose: measure steady-state latency without deliberate burst contention

Reference thesis dataset files:

- `data/100-pre-lazy-seq.csv`
- `data/100-post-lazy-seq.csv`
- `data/100-post-eager-seq.csv`

Example command:

```bash
AUTH_TOKEN=<token> bun run index.ts \
  --appDefinition c-latest \
  --user <user-email-or-id> \
  --number 100 \
  --cleanup=true \
  --output data/100-post-eager-seq.csv
```

### Scenario 2: Concurrent Workload

- 50 launch requests
- each request receives a random offset within a 20 second window
- all launches are scheduled up front and then executed in parallel
- purpose: simulate a burst such as a lab or exam start

Reference thesis dataset files:

- `data/50-pre-lazy-concurrent.csv`
- `data/50-post-lazy-concurrent.csv`
- `data/50-post-eager-concurrent.csv`

Example command:

```bash
AUTH_TOKEN=<token> bun run index.ts \
  --appDefinition c-latest \
  --user <user-email-or-id> \
  --number 50 \
  --parallelIntervalMs 20000 \
  --cleanup=true \
  --output data/50-post-eager-concurrent.csv
```

## Compared System States

The runner does not switch deployment states by itself. The three compared states are external deployment configurations against which the same benchmark command is executed:

- `pre-lazy`: lazy startup before the routing and control-plane optimizations
- `post-lazy`: lazy startup after the routing and control-plane optimizations
- `post-eager`: eager startup with a prewarmed instance pool enabled

These state labels are encoded only in the output filenames in `data/`. Reproducing the thesis figures requires running the same workload against each deployment state and storing the outputs under distinct filenames.

## Benchmark Commands

### Show CLI Help

```bash
bun run index.ts --help
```

### Sequential Benchmark Template

```bash
AUTH_TOKEN=<token> bun run index.ts \
  --appDefinition <app-definition> \
  --user <user-email-or-id> \
  --number 100 \
  --cleanup=true \
  --output data/<label>-seq.csv
```

### Concurrent Benchmark Template

```bash
AUTH_TOKEN=<token> bun run index.ts \
  --appDefinition <app-definition> \
  --user <user-email-or-id> \
  --number 50 \
  --parallelIntervalMs 20000 \
  --cleanup=true \
  --output data/<label>-concurrent.csv
```

## All Benchmark Configuration Options

Required options:

- `--appDefinition <name>`: The Theia Cloud app definition to launch. This value is also used when classifying eager redirect tokens.
- `--user <email-or-id>`: The user identifier sent to the service. It controls which user the session is created for.
- `--number <count>`: Number of launch requests to execute. Must be a positive integer.

Optional options:

- `--serviceUrl <url>`: Full `POST /service` endpoint URL. Defaults to `https://service.test1.theia-test.artemis.cit.tum.de/service`.
- `--appId <id>`: The Theia application ID used when resolving existing sessions and cleanup targets. Defaults to `nJV3nKZmpxTD4wu2`.
- `--parallelIntervalMs <ms>`: Enables the concurrent workload mode. Each request receives a random start offset from `0` up to but excluding this value. If omitted, the benchmark runs sequentially with a fixed 10 second gap between requests.
- `--cleanup <true|false>`: If `true`, the script resolves each created session and deletes the backing `Session` custom resource via `kubectl`. This is useful when the benchmark targets ephemeral sessions and the cluster should be left clean after the run.
- `--namespace <name>`: Kubernetes namespace used for cleanup. Resolution order is: explicit flag, `KUBECTL_NAMESPACE`, then the current `kubectl` context namespace.
- `--environment <name>`: Human-readable environment label written into the CSV. If omitted, it is derived from the service hostname. For a hostname like `service.test1.example.org`, the derived environment is `test1`.
- `--output <path>`: Output CSV path. If omitted, the script writes `session-benchmark-<timestamp>.csv` in the current directory.
- `--timeoutMinutes <min>`: Launch timeout value forwarded to the service request payload. Defaults to `3`.
- `--tokenUrl <url>`: OIDC token endpoint used for the refresh-token grant. Defaults to `https://keycloak.ase.in.tum.de/realms/Test/protocol/openid-connect/token`.
- `--clientId <id>`: OIDC client ID used for token refresh. Defaults to `theia-test`.
- `--clientSecret <secret>`: OIDC client secret for confidential clients. Omit it for public clients.
- `--refreshSkewMs <ms>`: Time window before token expiry in which the script proactively refreshes the access token. Defaults to `30000`.
- `--env KEY=VALUE`: Adds one custom key/value pair to `env.fromMap` in the launch request. This flag can be repeated. `THEIA=true` is always injected automatically.

Environment variables:

- `AUTH_TOKEN`: current bearer access token. The script accepts either the raw token or a `Bearer ...` string.
- `REFRESH_TOKEN`: refresh token used to mint new access tokens.
- `OIDC_TOKEN_URL`: fallback for `--tokenUrl`.
- `OIDC_CLIENT_ID`: fallback for `--clientId`.
- `OIDC_CLIENT_SECRET`: fallback for `--clientSecret`.
- `OIDC_REFRESH_SKEW_MS`: fallback for `--refreshSkewMs`.
- `KUBECTL_NAMESPACE`: fallback namespace for cleanup if `--namespace` is not passed.

Important behavioral details:

- `reuseExistingSession=false` is always sent so every benchmark request creates a fresh session instead of reusing an existing one.
- the request always includes `ephemeral=true`
- the request always injects `THEIA=true` into `env.fromMap`
- when refresh configuration is present, the script refreshes the access token once before the benchmark starts
- if a request returns `401` and refresh is configured, the script refreshes the access token and retries the request once

## Authentication Modes

### Access Token Only

Use this when you already have a valid bearer token for the service:

```bash
AUTH_TOKEN=<token> bun run index.ts ...
```

### Refresh Token Flow

Use this when the benchmark run may outlive the current access token:

```bash
REFRESH_TOKEN=<refresh-token> \
OIDC_TOKEN_URL=<token-endpoint> \
OIDC_CLIENT_ID=<client-id> \
OIDC_CLIENT_SECRET=<client-secret-if-needed> \
bun run index.ts ...
```

If both `AUTH_TOKEN` and refresh settings are present, the benchmark starts with the provided access token and refreshes only when needed.

## Cleanup Behavior

When `--cleanup=true` is enabled, the benchmark performs extra work after a successful launch:

1. It lists sessions before the launch.
2. It injects a unique benchmark marker into the launch request environment.
3. It polls the session list API until exactly one new session with the marker appears.
4. It deletes the matching `Session` custom resource using `kubectl delete sessions.theia.cloud ... --wait=false`.

This keeps the benchmark from steadily filling the cluster with leftover sessions, but it also means the machine running the benchmark must have working cluster access.

## Plot Generation

Generate one combined boxplot figure across every CSV in `data/`:

```bash
uv run plot_duration_boxplots.py
```

Options:

- `--data-dir <path>`: override the input directory
- `--output <path>`: output file for the PNG figure

## Expected Outputs

The packaged thesis datasets contain:

- three sequential runs with 100 samples each
- three concurrent runs with 50 samples each

You can verify that directly from the data directory:

```bash
python3 - <<'PY'
import csv
from pathlib import Path
for path in sorted(Path("data").glob("*.csv")):
    with path.open() as handle:
        print(path.name, sum(1 for _ in csv.DictReader(handle)))
PY
```

## Notes on Reproduction Scope

This package reproduces the benchmark tooling and the figure generation. Reproducing the exact latency numbers from scratch additionally requires access to three matching Theia Cloud deployment states (`pre-lazy`, `post-lazy`, and `post-eager`) on comparable infrastructure.
