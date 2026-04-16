type Strategy = "eager" | "lazy";

type CliOptions = {
  serviceUrl: string;
  appId: string;
  appDefinition: string;
  user: string;
  number: number;
  parallelIntervalMs?: number;
  cleanup: boolean;
  environment: string;
  output: string;
  timeoutMinutes: number;
  envFromMap: Record<string, string>;
  namespace?: string;
  oauth?: OAuthConfig;
};

type OAuthConfig = {
  tokenUrl: string;
  clientId: string;
  clientSecret?: string;
  refreshSkewMs: number;
};

type BenchmarkRow = {
  appdef: string;
  environment: string;
  startedEpochMs: number;
  durationMs: number;
  strategy: Strategy;
};

type SessionSpec = {
  name?: string;
  appDefinition?: string;
  user?: string;
  workspace?: string | null;
  envVars?: Record<string, string>;
};

type LaunchResult = {
  row: BenchmarkRow;
  redirectUrl: string;
  redirectToken: string;
  cleanupSessionName?: string;
};

type LaunchContext = {
  index: number;
  opts: CliOptions;
  authManager: AuthManager;
};

const UUID_SEGMENT_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const SEQUENTIAL_GAP_MS = 10_000;
const CLEANUP_RESOLUTION_TIMEOUT_MS = 30_000;
const CLEANUP_RESOLUTION_POLL_MS = 1_000;
const DEFAULT_REFRESH_SKEW_MS = 30_000;
const DEFAULT_SERVICE_URL =
  "https://service.test1.theia-test.artemis.cit.tum.de/service";
const DEFAULT_APP_ID = "nJV3nKZmpxTD4wu2";
const DEFAULT_OIDC_TOKEN_URL =
  "https://keycloak.ase.in.tum.de/realms/Test/protocol/openid-connect/token";
const DEFAULT_OIDC_CLIENT_ID = "theia-test";
const BENCHMARK_SESSION_ID_ENV = "THEIA_BENCHMARK_SESSION_ID";

type TokenResponse = {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
  refresh_expires_in?: number;
  token_type?: string;
};

class AuthManager {
  private accessToken?: string;
  private refreshToken?: string;
  private accessTokenExpiresAtMs?: number;
  private readonly oauth?: OAuthConfig;
  private refreshInFlight?: Promise<void>;

  constructor(args: {
    accessToken?: string;
    refreshToken?: string;
    oauth?: OAuthConfig;
  }) {
    this.accessToken = args.accessToken;
    this.refreshToken = args.refreshToken;
    this.oauth = args.oauth;
  }

  async getAuthorizationHeader(): Promise<string> {
    await this.ensureFreshToken();

    if (!this.accessToken) {
      throw new Error("No access token available. Set AUTH_TOKEN or refresh configuration.");
    }

    return this.accessToken.startsWith("Bearer ")
      ? this.accessToken
      : `Bearer ${this.accessToken}`;
  }

  async fetch(input: string | URL, init: RequestInit = {}): Promise<Response> {
    const response = await this.fetchWithCurrentToken(input, init);
    if (response.status !== 401 || !this.canRefresh()) {
      return response;
    }

    log("Received 401, refreshing access token and retrying once");
    await this.refreshAccessToken();
    return await this.fetchWithCurrentToken(input, init);
  }

  async refreshBeforeStartup(): Promise<void> {
    if (!this.canRefresh()) {
      return;
    }

    log("Refreshing access token before benchmark startup");
    await this.refreshAccessToken();
  }

  private async fetchWithCurrentToken(
    input: string | URL,
    init: RequestInit,
  ): Promise<Response> {
    const authHeader = await this.getAuthorizationHeader();
    const headers = new Headers(init.headers);
    headers.set("Authorization", authHeader);

    return await fetch(input, {
      ...init,
      headers,
    });
  }

  private async ensureFreshToken(): Promise<void> {
    if (this.accessToken && !this.shouldRefreshSoon()) {
      return;
    }

    if (this.canRefresh()) {
      await this.refreshAccessToken();
      return;
    }

    if (!this.accessToken) {
      throw new Error(
        "AUTH_TOKEN is missing and refresh configuration is incomplete.",
      );
    }
  }

  private shouldRefreshSoon(): boolean {
    if (!this.accessTokenExpiresAtMs) {
      return false;
    }

    return Date.now() >= this.accessTokenExpiresAtMs - this.getRefreshSkewMs();
  }

  private canRefresh(): boolean {
    return Boolean(
      this.refreshToken && this.oauth?.tokenUrl && this.oauth.clientId,
    );
  }

  private getRefreshSkewMs(): number {
    return this.oauth?.refreshSkewMs ?? DEFAULT_REFRESH_SKEW_MS;
  }

  private async refreshAccessToken(): Promise<void> {
    if (!this.canRefresh()) {
      throw new Error(
        "Refresh requested but REFRESH_TOKEN, OIDC_TOKEN_URL, or OIDC_CLIENT_ID is missing.",
      );
    }

    if (!this.refreshInFlight) {
      this.refreshInFlight = this.performRefresh().finally(() => {
        this.refreshInFlight = undefined;
      });
    }

    await this.refreshInFlight;
  }

  private async performRefresh(): Promise<void> {
    const oauth = this.oauth!;
    const currentRefreshToken = this.refreshToken;
    if (!currentRefreshToken) {
      throw new Error("No refresh token available.");
    }

    log(`Refreshing access token via ${oauth.tokenUrl}`);

    const form = new URLSearchParams();
    form.set("grant_type", "refresh_token");
    form.set("client_id", oauth.clientId);
    form.set("refresh_token", currentRefreshToken);
    if (oauth.clientSecret) {
      form.set("client_secret", oauth.clientSecret);
    }

    const response = await fetch(oauth.tokenUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form.toString(),
    });

    const text = await response.text();
    if (!response.ok) {
      throw new Error(
        `Token refresh failed with ${response.status} ${response.statusText}: ${text}`,
      );
    }

    const payload = JSON.parse(text) as TokenResponse;
    if (!payload.access_token) {
      throw new Error(`Token refresh response is missing access_token: ${text}`);
    }

    this.accessToken = payload.access_token;
    this.refreshToken = payload.refresh_token ?? currentRefreshToken;
    if (typeof payload.expires_in === "number" && Number.isFinite(payload.expires_in)) {
      this.accessTokenExpiresAtMs = Date.now() + payload.expires_in * 1000;
    } else {
      this.accessTokenExpiresAtMs = undefined;
    }

    log("Access token refreshed");
  }
}

async function main(): Promise<void> {
  const opts = parseArgs(Bun.argv.slice(2));
  const authManager = createAuthManager(opts);

  await authManager.refreshBeforeStartup();

  log(
    `Starting benchmark: ${opts.number} session start(s), mode=${
      opts.parallelIntervalMs === undefined
        ? "sequential"
        : `parallel within ${opts.parallelIntervalMs} ms`
    }, cleanup=${opts.cleanup}`,
  );
  log(`Service URL: ${opts.serviceUrl}`);
  log(`App definition: ${opts.appDefinition}`);
  log(`Environment: ${opts.environment}`);
  log(`CSV output: ${opts.output}`);
  if (opts.cleanup) {
    log(
      `Cleanup namespace: ${opts.namespace ?? process.env.KUBECTL_NAMESPACE ?? "current kubectl context"}`,
    );
  }

  const results =
    opts.parallelIntervalMs === undefined
      ? await runSequential(opts, authManager)
      : await runParallel(opts, authManager);

  const successfulResults = results.filter(
    (result): result is LaunchResult => result !== null,
  );
  const rows = successfulResults.map((result) => result.row);

  await writeCsv(opts.output, rows);
  log(`Wrote ${rows.length} row(s) to ${opts.output}`);

  const failureCount = results.length - successfulResults.length;
  if (failureCount > 0) {
    throw new Error(
      `${failureCount} session start(s) failed. CSV contains only successful launches.`,
    );
  }
}

async function runSequential(
  opts: CliOptions,
  authManager: AuthManager,
): Promise<Array<LaunchResult | null>> {
  const results: Array<LaunchResult | null> = [];

  for (let index = 0; index < opts.number; index += 1) {
    results.push(await runSingleLaunch({ index, opts, authManager }));

    if (index < opts.number - 1) {
      log(
        `Waiting ${SEQUENTIAL_GAP_MS} ms before starting session ${index + 2}/${opts.number}`,
      );
      await sleep(SEQUENTIAL_GAP_MS);
    }
  }

  return results;
}

async function runParallel(
  opts: CliOptions,
  authManager: AuthManager,
): Promise<Array<LaunchResult | null>> {
  const interval = opts.parallelIntervalMs!;
  const offsets = Array.from({ length: opts.number }, () =>
    Math.floor(Math.random() * interval),
  );

  offsets.forEach((offset, index) => {
    log(`Scheduled session ${index + 1}/${opts.number} at +${offset} ms`);
  });

  return await Promise.all(
    offsets.map((offset, index) =>
      (async () => {
        await sleep(offset);
        return await runSingleLaunch({ index, opts, authManager });
      })(),
    ),
  );
}

async function runSingleLaunch(
  context: LaunchContext,
): Promise<LaunchResult | null> {
  const { index, opts, authManager } = context;
  const ordinal = `${index + 1}/${opts.number}`;
  const benchmarkSessionId = `${Date.now()}-${index}-${crypto.randomUUID()}`;

  try {
    log(`Starting session ${ordinal}`);

    const beforeSessions = opts.cleanup
      ? await listSessions(opts, authManager)
      : undefined;

    const startedEpochMs = Date.now();
    const startedAt = performance.now();

    const response = await authManager.fetch(opts.serviceUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        kind: "launchRequest",
        serviceUrl: opts.serviceUrl,
        appId: opts.appId,
        user: opts.user,
        appDefinition: opts.appDefinition,
        ephemeral: true,
        reuseExistingSession: false,
        timeout: opts.timeoutMinutes,
        env: {
          fromMap: {
            ...opts.envFromMap,
            [BENCHMARK_SESSION_ID_ENV]: benchmarkSessionId,
          },
        },
      }),
    });

    const responseText = await response.text();
    const durationMs = Math.round(performance.now() - startedAt);

    if (!response.ok) {
      throw new Error(
        `Launch request failed with ${response.status} ${response.statusText}: ${responseText}`,
      );
    }

    const redirectUrl = normalizeRedirectUrl(
      extractRedirectUrl(responseText),
      opts.serviceUrl,
    );
    const redirectToken = extractRedirectToken(redirectUrl);
    const strategy = classifyStrategy(opts.appDefinition, redirectToken);

    log(
      `Started session ${ordinal} in ${durationMs} ms, strategy=${strategy}, redirect=${redirectUrl}`,
    );

    let cleanupSessionName: string | undefined;
    if (opts.cleanup) {
      cleanupSessionName = await resolveSessionNameForCleanup({
        opts,
        authManager,
        beforeSessions: beforeSessions ?? [],
        benchmarkSessionId,
        redirectToken,
        ordinal,
      });

      await cleanupSession(opts, cleanupSessionName, ordinal);
    }

    return {
      row: {
        appdef: opts.appDefinition,
        environment: opts.environment,
        startedEpochMs,
        durationMs,
        strategy,
      },
      redirectUrl,
      redirectToken,
      cleanupSessionName,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    log(`Session ${ordinal} failed: ${message}`);
    return null;
  }
}

async function listSessions(
  opts: CliOptions,
  authManager: AuthManager,
): Promise<SessionSpec[]> {
  const sessionUrl = new URL(
    "./session/",
    ensureTrailingSlash(opts.serviceUrl),
  );
  sessionUrl.pathname = `${sessionUrl.pathname.replace(/\/$/, "")}/${encodeURIComponent(
    opts.appId,
  )}/${encodeURIComponent(opts.user)}`;

  const response = await authManager.fetch(sessionUrl);

  const text = await response.text();
  if (!response.ok) {
    throw new Error(
      `Failed to list sessions with ${response.status} ${response.statusText}: ${text}`,
    );
  }

  const parsed = JSON.parse(text);
  if (!Array.isArray(parsed)) {
    throw new Error(`Unexpected session list response: ${text}`);
  }

  return parsed as SessionSpec[];
}

async function resolveSessionNameForCleanup(args: {
  opts: CliOptions;
  authManager: AuthManager;
  beforeSessions: SessionSpec[];
  benchmarkSessionId: string;
  redirectToken: string;
  ordinal: string;
}): Promise<string> {
  const {
    opts,
    authManager,
    beforeSessions,
    benchmarkSessionId,
    redirectToken,
    ordinal,
  } = args;
  const knownNames = new Set(
    beforeSessions.map((session) => session.name).filter(Boolean),
  );

  const deadline = Date.now() + CLEANUP_RESOLUTION_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const currentSessions = await listSessions(opts, authManager);
    const candidates = currentSessions.filter((session) => {
      if (!session.name || knownNames.has(session.name)) {
        return false;
      }

      if (session.appDefinition !== opts.appDefinition) {
        return false;
      }

      return session.envVars?.[BENCHMARK_SESSION_ID_ENV] === benchmarkSessionId;
    });

    const onlyCandidate = candidates[0];
    if (candidates.length === 1 && onlyCandidate?.name) {
      log(
        `Resolved cleanup session for ${ordinal}: ${onlyCandidate.name} (redirect token ${redirectToken})`,
      );
      return onlyCandidate.name;
    }

    if (candidates.length > 1) {
      throw new Error(
        `Could not resolve cleanup session uniquely for ${ordinal}. Found ${candidates.length} new sessions.`,
      );
    }

    await sleep(CLEANUP_RESOLUTION_POLL_MS);
  }

  throw new Error(
    `Timed out after ${CLEANUP_RESOLUTION_TIMEOUT_MS} ms while resolving cleanup session for ${ordinal}.`,
  );
}

async function cleanupSession(
  opts: CliOptions,
  sessionName: string,
  ordinal: string,
): Promise<void> {
  log(`Cleaning up session ${ordinal}: ${sessionName}`);

  const namespace = await resolveKubectlNamespace(opts);
  const args = ["delete", "sessions.theia.cloud", sessionName, "--wait=false"];
  if (namespace) {
    args.push("--namespace", namespace);
  }

  const proc = Bun.spawn({
    cmd: ["kubectl", ...args],
    stdout: "pipe",
    stderr: "pipe",
  });

  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);

  if (exitCode !== 0) {
    throw new Error(
      `kubectl cleanup failed with exit code ${exitCode}: ${stderr.trim() || stdout.trim()}`,
    );
  }

  log(`Cleaned up session ${ordinal}: ${sessionName}`);
}

function extractRedirectUrl(responseText: string): string {
  const trimmed = responseText.trim();
  const rawValue =
    trimmed.startsWith('"') && trimmed.endsWith('"')
      ? (JSON.parse(trimmed) as string)
      : trimmed;

  return rawValue;
}

function normalizeRedirectUrl(redirectUrl: string, serviceUrl: string): string {
  try {
    return new URL(redirectUrl).toString();
  } catch {
    const service = new URL(serviceUrl);
    const normalizedInput = redirectUrl.replace(/^\/+/, "");
    return new URL(`${service.protocol}//${normalizedInput}`).toString();
  }
}

function extractRedirectToken(redirectUrl: string): string {
  const url = new URL(redirectUrl);
  const pathSegment = url.pathname
    .split("/")
    .map((segment) => segment.trim())
    .filter(Boolean)[0];

  if (pathSegment) {
    return pathSegment;
  }

  const hostLabel = url.hostname.split(".")[0];
  if (hostLabel) {
    return hostLabel;
  }

  throw new Error(`Could not extract redirect token from URL: ${redirectUrl}`);
}

function classifyStrategy(
  appDefinition: string,
  redirectToken: string,
): Strategy {
  if (UUID_SEGMENT_PATTERN.test(redirectToken)) {
    return "lazy";
  }

  const eagerPattern = new RegExp(`^${escapeRegExp(appDefinition)}-\\d+$`, "i");
  if (eagerPattern.test(redirectToken)) {
    return "eager";
  }

  throw new Error(
    `Could not classify redirect token "${redirectToken}" as eager or lazy for app definition "${appDefinition}".`,
  );
}

function parseArgs(argv: string[]): CliOptions {
  if (argv.includes("--help") || argv.includes("-h")) {
    printHelp();
    process.exit(0);
  }

  const values = new Map<string, string[]>();
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === undefined) {
      throw new Error("Unexpected missing CLI argument.");
    }

    if (!token.startsWith("--")) {
      throw new Error(`Unexpected argument: ${token}`);
    }

    const parts = token.slice(2).split("=", 2);
    const rawKey = parts[0];
    const inlineValue = parts[1];
    if (rawKey === undefined) {
      throw new Error(`Invalid option: ${token}`);
    }
    const key = rawKey.trim();
    const nextToken = argv[index + 1];
    const value =
      inlineValue !== undefined
        ? inlineValue
        : nextToken !== undefined && !nextToken.startsWith("--")
          ? nextToken
          : "true";

    if (
      inlineValue === undefined &&
      nextToken !== undefined &&
      !nextToken.startsWith("--")
    ) {
      index += 1;
    }

    const existing = values.get(key) ?? [];
    existing.push(value);
    values.set(key, existing);
  }

  const serviceUrl = getOptionalArg(values, "serviceUrl") ?? DEFAULT_SERVICE_URL;
  const appId = getOptionalArg(values, "appId") ?? DEFAULT_APP_ID;
  const appDefinition = getRequiredArg(values, "appDefinition");
  const user = getRequiredArg(values, "user");
  const number = parsePositiveInteger(
    getRequiredArg(values, "number"),
    "number",
  );
  const parallelIntervalMs = getOptionalArg(values, "parallelIntervalMs");
  const cleanup = parseBoolean(getOptionalArg(values, "cleanup") ?? "false");
  const environment =
    getOptionalArg(values, "environment") ?? deriveEnvironment(serviceUrl);
  const output =
    getOptionalArg(values, "output") ?? `session-benchmark-${Date.now()}.csv`;
  const timeoutMinutes = parsePositiveInteger(
    getOptionalArg(values, "timeoutMinutes") ?? "3",
    "timeoutMinutes",
  );
  const namespace = getOptionalArg(values, "namespace");
  const tokenUrl =
    getOptionalArg(values, "tokenUrl") ??
    process.env.OIDC_TOKEN_URL ??
    DEFAULT_OIDC_TOKEN_URL;
  const clientId =
    getOptionalArg(values, "clientId") ??
    process.env.OIDC_CLIENT_ID ??
    DEFAULT_OIDC_CLIENT_ID;
  const clientSecret =
    getOptionalArg(values, "clientSecret") ?? process.env.OIDC_CLIENT_SECRET;
  const refreshSkewMs = parsePositiveInteger(
    getOptionalArg(values, "refreshSkewMs") ??
      process.env.OIDC_REFRESH_SKEW_MS ??
      String(DEFAULT_REFRESH_SKEW_MS),
    "refreshSkewMs",
  );

  const envEntries = values.get("env") ?? [];
  const envFromMap: Record<string, string> = { THEIA: "true" };
  for (const entry of envEntries) {
    const equalsIndex = entry.indexOf("=");
    if (equalsIndex <= 0) {
      throw new Error(`Invalid --env value "${entry}". Expected KEY=VALUE.`);
    }

    const key = entry.slice(0, equalsIndex).trim();
    const value = entry.slice(equalsIndex + 1);
    envFromMap[key] = value;
  }

  return {
    serviceUrl,
    appId,
    appDefinition,
    user,
    number,
    parallelIntervalMs:
      parallelIntervalMs === undefined
        ? undefined
        : parsePositiveInteger(parallelIntervalMs, "parallelIntervalMs"),
    cleanup,
    environment,
    output,
    timeoutMinutes,
    envFromMap,
    namespace,
    oauth:
      tokenUrl && clientId
        ? {
            tokenUrl,
            clientId,
            clientSecret: clientSecret || undefined,
            refreshSkewMs,
          }
        : undefined,
  };
}

function createAuthManager(opts: CliOptions): AuthManager {
  const accessToken = normalizeBearerToken(process.env.AUTH_TOKEN);
  const refreshToken = process.env.REFRESH_TOKEN?.trim() || undefined;

  if (!accessToken && !refreshToken) {
    throw new Error("Set AUTH_TOKEN or REFRESH_TOKEN.");
  }

  if (refreshToken && !opts.oauth) {
    throw new Error(
      "REFRESH_TOKEN was provided but token refresh config is incomplete. Provide --tokenUrl/--clientId or OIDC_TOKEN_URL/OIDC_CLIENT_ID.",
    );
  }

  return new AuthManager({
    accessToken,
    refreshToken,
    oauth: opts.oauth,
  });
}

function normalizeBearerToken(token: string | undefined): string | undefined {
  if (!token || !token.trim()) {
    return undefined;
  }

  return token.startsWith("Bearer ") ? token : `Bearer ${token}`;
}

function getRequiredArg(values: Map<string, string[]>, key: string): string {
  const value = getOptionalArg(values, key);
  if (!value) {
    throw new Error(`Missing required option --${key}`);
  }
  return value;
}

function getOptionalArg(
  values: Map<string, string[]>,
  key: string,
): string | undefined {
  return values.get(key)?.at(-1);
}

function parsePositiveInteger(value: string, key: string): number {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`--${key} must be a positive integer, got "${value}"`);
  }
  return parsed;
}

function parseBoolean(value: string): boolean {
  if (value === "true") {
    return true;
  }

  if (value === "false") {
    return false;
  }

  throw new Error(`Boolean option must be "true" or "false", got "${value}"`);
}

function deriveEnvironment(serviceUrl: string): string {
  const hostnameLabels = new URL(serviceUrl).hostname.split(".");
  const firstLabel = hostnameLabels[0];
  const secondLabel = hostnameLabels[1];
  if (firstLabel === "service" && secondLabel) {
    return secondLabel;
  }

  return firstLabel ?? "unknown";
}

function ensureTrailingSlash(url: string): string {
  return url.endsWith("/") ? url : `${url}/`;
}

async function resolveKubectlNamespace(
  opts: CliOptions,
): Promise<string | undefined> {
  if (opts.namespace) {
    return opts.namespace;
  }

  if (process.env.KUBECTL_NAMESPACE?.trim()) {
    return process.env.KUBECTL_NAMESPACE.trim();
  }

  const proc = Bun.spawn({
    cmd: [
      "kubectl",
      "config",
      "view",
      "--minify",
      "-o",
      "jsonpath={..namespace}",
    ],
    stdout: "pipe",
    stderr: "pipe",
  });

  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);

  if (exitCode !== 0) {
    throw new Error(
      `Could not determine kubectl namespace: ${stderr.trim() || stdout.trim()}`,
    );
  }

  const namespace = stdout.trim();
  return namespace || undefined;
}

async function writeCsv(path: string, rows: BenchmarkRow[]): Promise<void> {
  const header = "appdef,environment,startedEpochMs,durationMs,strategy";
  const lines = rows.map((row) =>
    [
      csvEscape(row.appdef),
      csvEscape(row.environment),
      String(row.startedEpochMs),
      String(row.durationMs),
      row.strategy,
    ].join(","),
  );

  await Bun.write(
    path,
    `${header}\n${lines.join("\n")}${lines.length > 0 ? "\n" : ""}`,
  );
}

function csvEscape(value: string): string {
  if (/[",\n]/.test(value)) {
    return `"${value.replaceAll('"', '""')}"`;
  }
  return value;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function log(message: string): void {
  console.log(`[${new Date().toISOString()}] ${message}`);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function printHelp(): void {
  console.log(`Theia Cloud session benchmark

Required:
  --appDefinition <name>
  --user <email-or-id>
  --number <count>

Optional:
  --serviceUrl <url>         Override default service URL
  --appId <id>               Override default app ID
  --parallelIntervalMs <ms>  Start all sessions in parallel with random offsets inside the interval
  --cleanup <true|false>     Delete each created session after launch resolution
  --environment <name>       Override derived environment name
  --output <path>            CSV output path (default: session-benchmark-<timestamp>.csv)
  --timeoutMinutes <min>     Launch timeout sent to the service (default: 3)
  --namespace <name>         Namespace used for kubectl cleanup
  --tokenUrl <url>           OIDC token endpoint for refresh_token grant
  --clientId <id>            OIDC client ID used for refresh
  --clientSecret <secret>    OIDC client secret if the client is confidential
  --refreshSkewMs <ms>       Refresh shortly before expiry (default: 30000)
  --env KEY=VALUE            Add env.fromMap entries, can be repeated. THEIA=true is always set.

Auth:
  AUTH_TOKEN=<token> bun run index.ts ...
  REFRESH_TOKEN=<token> OIDC_TOKEN_URL=<url> OIDC_CLIENT_ID=<id> bun run index.ts ...

Cleanup:
  If --cleanup=true is set, the script resolves the created session via the API
  and deletes the Session CR using kubectl.

Defaults:
  serviceUrl=${DEFAULT_SERVICE_URL}
  appId=${DEFAULT_APP_ID}
  tokenUrl=${DEFAULT_OIDC_TOKEN_URL}
  clientId=${DEFAULT_OIDC_CLIENT_ID}
`);
}

await main();
