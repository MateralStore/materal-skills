#!/usr/bin/env node

import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const HOST = '127.0.0.1';
const DEFAULT_PORT = 9222;
const DEFAULT_TIMEOUT_MS = 15000;
const DEFAULT_STATE_ROOT = path.join(
  process.env.CODEX_CDP_HOME || process.env.LOCALAPPDATA || os.tmpdir(),
  process.env.CODEX_CDP_HOME ? '' : 'codex-cdp',
);

function parseArgs(argv) {
  const positionals = [];
  const flags = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('--')) {
      positionals.push(arg);
      continue;
    }
    const equalIndex = arg.indexOf('=');
    if (equalIndex !== -1) {
      flags[arg.slice(2, equalIndex)] = arg.slice(equalIndex + 1);
      continue;
    }
    const name = arg.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith('--')) {
      flags[name] = next;
      i += 1;
    } else {
      flags[name] = true;
    }
  }
  return { positionals, flags };
}

function numberFlag(flags, name, fallback, min, max) {
  const value = flags[name] === undefined ? fallback : Number(flags[name]);
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new Error('--' + name + ' must be an integer between ' + min + ' and ' + max + '.');
  }
  return value;
}

function stringFlag(flags, name, fallback) {
  const value = flags[name];
  return value === undefined || value === true ? fallback : String(value);
}

function boolFlag(flags, name, fallback = false) {
  const value = flags[name];
  if (value === undefined) {
    return fallback;
  }
  if (value === true) {
    return true;
  }
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function readStdin() {
  let value = '';
  for await (const chunk of process.stdin) {
    value += String(chunk);
  }
  return value;
}

async function fetchJson(url, timeoutMs = 2000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) {
      throw new Error('HTTP ' + response.status + ' from ' + url);
    }
    return await response.json();
  } finally {
    clearTimeout(timer);
  }
}

async function readJsonFile(filePath) {
  try {
    return JSON.parse(await fs.readFile(filePath, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') {
      return null;
    }
    throw error;
  }
}

async function writeJsonFile(filePath, value) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, JSON.stringify(value, null, 2) + '\n', 'utf8');
}

function processIsAlive(processId) {
  if (!processId) {
    return false;
  }
  try {
    process.kill(Number(processId), 0);
    return true;
  } catch {
    return false;
  }
}

function stateMatchesConfig(state, config) {
  return Boolean(
    state
      && state.endpoint === config.endpoint
      && Number(state.port) === config.port
      && path.resolve(state.profilePath || '') === config.profilePath,
  );
}

function normalizeSessionId(value) {
  const normalized = String(value ?? 'default').trim();
  return normalized || 'default';
}

function sessionFileId(sessionId) {
  const safe = sessionId.replace(/[^a-zA-Z0-9._-]+/g, '_');
  if (safe === sessionId && safe.length <= 120) {
    return safe;
  }
  const hash = createHash('sha256').update(sessionId).digest('hex').slice(0, 12);
  return (safe.slice(0, 100) || 'session') + '-' + hash;
}

function sessionMatchesConfig(state, config, version = null) {
  return Boolean(
    state
      && state.sessionId === config.sessionId
      && state.endpoint === config.endpoint
      && Number(state.port) === config.port
      && path.resolve(state.profilePath || '') === config.profilePath
      && (!version || state.browserWebSocketUrl === version.webSocketDebuggerUrl),
  );
}

async function terminateProcess(processId) {
  if (process.platform !== 'win32') {
    try {
      process.kill(Number(processId), 'SIGTERM');
    } catch (error) {
      if (error.code !== 'ESRCH') {
        throw error;
      }
    }
    return;
  }

  await new Promise((resolve, reject) => {
    const child = spawn('taskkill', ['/PID', String(processId), '/T', '/F'], {
      stdio: ['ignore', 'ignore', 'pipe'],
      windowsHide: true,
    });
    let stderr = '';
    child.stderr.on('data', (chunk) => {
      stderr += String(chunk);
    });
    child.once('error', reject);
    child.once('close', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error('taskkill failed for process ' + processId + (stderr.trim() ? ': ' + stderr.trim() : '.')));
    });
  });
}

async function requestBrowserClose(config) {
  const version = await endpointVersion(config);
  if (!version) {
    return false;
  }
  try {
    const connection = await new CdpConnection(version.webSocketDebuggerUrl).connect();
    try {
      await connection.call('Browser.close', {});
    } finally {
      connection.close();
    }
    return true;
  } catch {
    return false;
  }
}

function chromeCandidates() {
  const candidates = [
    process.env.CODEX_CDP_CHROME,
    process.env.ProgramFiles && path.join(process.env.ProgramFiles, 'Google', 'Chrome', 'Application', 'chrome.exe'),
    process.env['ProgramFiles(x86)'] && path.join(process.env['ProgramFiles(x86)'], 'Google', 'Chrome', 'Application', 'chrome.exe'),
    process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'Google', 'Chrome', 'Application', 'chrome.exe'),
  ];
  return candidates.filter(Boolean);
}

async function findChrome(explicitPath) {
  const candidates = explicitPath ? [explicitPath] : chromeCandidates();
  for (const candidate of candidates) {
    try {
      const stat = await fs.stat(candidate);
      if (stat.isFile()) {
        return path.resolve(candidate);
      }
    } catch {
      // Try the next standard installation path.
    }
  }
  throw new Error('Chrome not found. Pass --chrome <path-to-chrome.exe> or set CODEX_CDP_CHROME.');
}

function runCommand(command, args, timeoutMs = 5000) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    timeout: timeoutMs,
    windowsHide: true,
  });
  if (result.error) {
    return { ok: false, output: '', error: result.error.message };
  }
  return {
    ok: result.status === 0,
    output: String(result.stdout || '').trim(),
    error: String(result.stderr || '').trim() || (result.status === 0 ? null : 'exit code ' + result.status),
  };
}

function mcpConfigPath(flags) {
  const explicitPath = stringFlag(flags, 'mcp-config', null);
  if (explicitPath) {
    return path.resolve(explicitPath);
  }
  const codexHome = process.env.CODEX_HOME || path.join(process.env.USERPROFILE || os.homedir(), '.codex');
  return path.join(codexHome, 'config.toml');
}

async function inspectMcp(flags, npxAvailable) {
  const configPath = mcpConfigPath(flags);
  let configText = '';
  let configExists = true;
  try {
    configText = await fs.readFile(configPath, 'utf8');
  } catch (error) {
    if (error.code === 'ENOENT') {
      configExists = false;
    } else {
      throw error;
    }
  }
  const serverSections = [];
  let currentSection = null;
  for (const line of configText.split(/\r?\n/)) {
    const sectionMatch = /^\s*\[([^\]\r\n]+)\]\s*$/.exec(line);
    if (sectionMatch) {
      if (currentSection) {
        serverSections.push(currentSection);
      }
      const nameMatch = /^mcp_servers\.(.+)$/.exec(sectionMatch[1].trim());
      currentSection = nameMatch
        ? {
          name: nameMatch[1].replace(/^(?:"|')|(?:"|')$/g, ''),
          lines: [],
        }
        : null;
      continue;
    }
    if (currentSection) {
      currentSection.lines.push(line);
    }
  }
  if (currentSection) {
    serverSections.push(currentSection);
  }
  const sectionBody = (section) => section.lines
    .map((line) => line.trimStart().startsWith('#') ? '' : line.replace(/\s+#.*$/, ''))
    .join('\n');
  const configuredServers = serverSections
    .filter((section) => /chrome-devtools-mcp/i.test(sectionBody(section)))
    .map((section) => section.name);
  const configuredBodies = serverSections
    .filter((section) => configuredServers.includes(section.name))
    .map(sectionBody)
    .join('\n');
  const serverConfigured = configuredServers.length > 0;
  const packageReferenced = serverConfigured;
  const browserUrlConfigured = /--browser-url(?:=|\s)/i.test(configuredBodies) || /browserUrl/i.test(configuredBodies);
  const isolatedConfigured = /(?:^|[\s"'\[,])--isolated(?:[\s"'=\],]|$)/i.test(configuredBodies);
  return {
    configPath,
    configExists,
    serverConfigured,
    packageReferenced,
    configuredServers,
    runnerAvailable: npxAvailable,
    packageAvailability: 'unknown',
    packageAvailabilityNote: 'The configured npx command may use an existing cache or download the package when the MCP server starts. Doctor does not run the package or access the network.',
    browserUrlConfigured,
    isolatedConfigured,
    toolExposure: 'unknown',
    toolExposureNote: 'CLI cannot inspect the tools exposed to the current Codex task. Verify that mcp__chrome_devtools__list_pages (or an equivalent chrome-devtools MCP tool) is present in the tool list.',
  };
}

class CdpConnection {
  constructor(url) {
    this.url = url;
    this.nextId = 1;
    this.pending = new Map();
    this.handlers = new Map();
    this.socket = null;
  }

  async connect() {
    if (typeof WebSocket !== 'function') {
      throw new Error('This CLI requires Node.js 22 or newer with the built-in WebSocket client.');
    }
    await new Promise((resolve, reject) => {
      const socket = new WebSocket(this.url);
      this.socket = socket;
      const timer = setTimeout(() => {
        socket.close();
        reject(new Error('Timed out connecting to ' + this.url));
      }, DEFAULT_TIMEOUT_MS);
      socket.addEventListener('open', () => {
        clearTimeout(timer);
        resolve();
      }, { once: true });
      socket.addEventListener('error', () => {
        clearTimeout(timer);
        reject(new Error('WebSocket connection failed: ' + this.url));
      }, { once: true });
      socket.addEventListener('message', (event) => this.handleMessage(event.data));
      socket.addEventListener('close', () => {
        for (const pending of this.pending.values()) {
          pending.reject(new Error('CDP WebSocket closed.'));
        }
        this.pending.clear();
      });
    });
    return this;
  }

  handleMessage(data) {
    try {
      const message = JSON.parse(typeof data === 'string' ? data : String(data));
      if (message.id !== undefined) {
        const pending = this.pending.get(message.id);
        if (!pending) {
          return;
        }
        this.pending.delete(message.id);
        if (message.error) {
          pending.reject(new Error(message.error.message || 'CDP command failed.'));
        } else {
          pending.resolve(message.result);
        }
        return;
      }
      if (message.method) {
        const handlers = [...(this.handlers.get(message.method) || []), ...(this.handlers.get('*') || [])];
        for (const handler of handlers) {
          handler(message);
        }
      }
    } catch {
      // Ignore malformed unsolicited frames; command responses are rejected by timeout.
    }
  }

  on(method, handler) {
    const handlers = this.handlers.get(method) || [];
    handlers.push(handler);
    this.handlers.set(method, handlers);
  }

  call(method, params = {}, sessionId) {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      return Promise.reject(new Error('CDP WebSocket is not open.'));
    }
    const id = this.nextId;
    this.nextId += 1;
    const message = { id, method, params };
    if (sessionId) {
      message.sessionId = sessionId;
    }
    this.socket.send(JSON.stringify(message));
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error('Timed out waiting for CDP command ' + method + '.'));
      }, DEFAULT_TIMEOUT_MS);
      this.pending.set(id, {
        resolve: (value) => {
          clearTimeout(timer);
          resolve(value);
        },
        reject: (error) => {
          clearTimeout(timer);
          reject(error);
        },
      });
    });
  }

  close() {
    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.close();
    }
  }
}

function simplifyTarget(target) {
  return {
    id: target.id,
    type: target.type,
    title: target.title || '',
    url: target.url || '',
    openerId: target.openerId || null,
    webSocketDebuggerUrl: target.webSocketDebuggerUrl || null,
  };
}

function configFrom(flags) {
  const port = numberFlag(flags, 'port', Number(process.env.CODEX_CDP_PORT || DEFAULT_PORT), 1, 65535);
  const stateRoot = path.resolve(stringFlag(flags, 'home', DEFAULT_STATE_ROOT));
  const profilePath = path.resolve(stringFlag(flags, 'profile', path.join(stateRoot, 'profile')));
  const sessionFlag = flags.session !== undefined && flags.session !== true;
  const sessionEnv = Boolean(process.env.CODEX_SESSION_ID || process.env.CODEX_THREAD_ID);
  const sessionId = normalizeSessionId(stringFlag(
    flags,
    'session',
    process.env.CODEX_SESSION_ID || process.env.CODEX_THREAD_ID || 'default',
  ));
  const endpoint = 'http://' + HOST + ':' + port;
  return {
    port,
    endpoint,
    versionUrl: endpoint + '/json/version',
    listUrl: endpoint + '/json/list',
    stateRoot,
    stateFile: path.join(stateRoot, 'state.json'),
    sessionsDir: path.join(stateRoot, 'sessions'),
    sessionId,
    sessionSource: sessionFlag ? 'flag' : sessionEnv ? 'environment' : 'implicit-default',
    sessionStateFile: path.join(stateRoot, 'sessions', sessionFileId(sessionId) + '.json'),
    profilePath,
    chromePath: stringFlag(flags, 'chrome', null),
  };
}

async function endpointVersion(config) {
  try {
    const value = await fetchJson(config.versionUrl);
    if (!value.webSocketDebuggerUrl) {
      throw new Error('CDP version response has no webSocketDebuggerUrl.');
    }
    return value;
  } catch (error) {
    if (error.name === 'AbortError' || error.cause || error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
      return null;
    }
    return null;
  }
}

async function endpointTargets(config) {
  const targets = await fetchJson(config.listUrl);
  return Array.isArray(targets) ? targets.map(simplifyTarget) : [];
}

async function managedInfo(config, version = null) {
  const state = await readJsonFile(config.stateFile);
  const processIdMatches = state && state.processId && processIsAlive(state.processId);
  const configMatches = stateMatchesConfig(state, config);
  const browserMatches = Boolean(
    state
      && state.browserWebSocketUrl
      && version
      && state.browserWebSocketUrl === version.webSocketDebuggerUrl,
  );
  return {
    managed: Boolean(version && processIdMatches && configMatches && browserMatches),
    browserMatches,
    configMatches,
    state,
  };
}

async function readSessionState(config) {
  const state = await readJsonFile(config.sessionStateFile);
  const version = await endpointVersion(config);
  if (!state || !sessionMatchesConfig(state, config, version)) {
    return null;
  }
  return state;
}

async function saveCurrentTarget(config, target, options = {}) {
  const version = await endpointVersion(config);
  const state = (await readSessionState(config)) || {
    sessionId: config.sessionId,
    endpoint: config.endpoint,
    port: config.port,
    profilePath: config.profilePath,
    ownedTargetIds: [],
  };
  state.browserWebSocketUrl = version?.webSocketDebuggerUrl || state.browserWebSocketUrl || null;
  state.ownedTargetIds = Array.isArray(state.ownedTargetIds) ? state.ownedTargetIds : [];
  state.currentTargetId = target ? target.id : null;
  state.currentTargetUrl = target ? target.url : null;
  state.currentTargetTitle = target ? target.title : null;
  if (options.owned && target && !state.ownedTargetIds.includes(target.id)) {
    state.ownedTargetIds.push(target.id);
  }
  await writeJsonFile(config.sessionStateFile, state);
}

function targetFlagsFromState(state) {
  if (!state) {
    return {};
  }
  if (state.currentTargetId) {
    return { 'target-id': state.currentTargetId };
  }
  return {};
}

async function ensure(config, flags) {
  let version = await endpointVersion(config);
  const current = await managedInfo(config, version);
  if (version) {
    if (current.managed || flags['reuse-existing']) {
      return { status: current.managed ? 'reused' : 'reused-existing', version, state: current.state };
    }
    throw new Error('A CDP endpoint is already active at ' + config.endpoint + ' but is not managed by this CLI. Stop it, choose --port, or pass --reuse-existing explicitly.');
  }

  const chromePath = await findChrome(config.chromePath);
  await fs.mkdir(config.profilePath, { recursive: true });
  const chromeArgs = [
    '--remote-debugging-address=' + HOST,
    '--remote-debugging-port=' + config.port,
    '--user-data-dir=' + config.profilePath,
    '--no-first-run',
    '--no-default-browser-check',
  ];
  const child = spawn(chromePath, chromeArgs, {
    detached: true,
    stdio: 'ignore',
    windowsHide: true,
  });
  let spawnError = null;
  child.once('error', (error) => {
    spawnError = error;
  });
  child.unref();
  const state = {
    processId: child.pid,
    chromePath,
    profilePath: config.profilePath,
    endpoint: config.endpoint,
    port: config.port,
    startedAt: new Date().toISOString(),
  };
  await writeJsonFile(config.stateFile, state);

  try {
    const deadline = Date.now() + numberFlag(flags, 'timeout-ms', DEFAULT_TIMEOUT_MS, 1000, 120000);
    while (Date.now() < deadline) {
      await sleep(250);
      if (spawnError) {
        throw new Error('Unable to start Chrome: ' + spawnError.message);
      }
      version = await endpointVersion(config);
      if (version) {
        state.browser = version.Browser || null;
        state.browserWebSocketUrl = version.webSocketDebuggerUrl;
        state.initialPageIds = (await endpointTargets(config))
          .filter((target) => target.type === 'page')
          .map((target) => target.id);
        await writeJsonFile(config.stateFile, state);
        return { status: 'started', version, state };
      }
      if (child.exitCode !== null) {
        throw new Error('Chrome exited before the CDP endpoint became available. Exit code: ' + child.exitCode + '.');
      }
    }
    throw new Error('Chrome started, but the CDP endpoint did not become available within the timeout.');
  } catch (error) {
    if (child.pid && processIsAlive(child.pid)) {
      try {
        await terminateProcess(child.pid);
      } catch {
        // Preserve the startup error; the state file is still removed below.
      }
    }
    await fs.rm(config.stateFile, { force: true });
    throw error;
  }
}

async function closeTargets(config, targetIds) {
  const version = await endpointVersion(config);
  if (!version || targetIds.length === 0) {
    return { closedTargetIds: [], failedTargets: [] };
  }
  const connection = await new CdpConnection(version.webSocketDebuggerUrl).connect();
  const closedTargetIds = [];
  const failedTargets = [];
  try {
    for (const targetId of targetIds) {
      try {
        const result = await connection.call('Target.closeTarget', { targetId });
        if (result.success !== false) {
          closedTargetIds.push(targetId);
        } else {
          failedTargets.push({ targetId, error: 'Target.closeTarget returned success=false.' });
        }
      } catch (error) {
        failedTargets.push({ targetId, error: error.message });
      }
    }
  } finally {
    connection.close();
  }
  return { closedTargetIds, failedTargets };
}

async function stop(config, flags) {
  const endpointState = await endpointVersion(config);
  if (config.sessionSource === 'implicit-default') {
    const sessionStates = await listSessionStates(config, endpointState);
    const nonDefaultSessions = sessionStates.filter((state) => state.sessionId !== 'default');
    if (nonDefaultSessions.length > 0) {
      throw new Error('A session id is required because this browser has pages owned by other sessions. Pass --session <id> (or set CODEX_SESSION_ID/CODEX_THREAD_ID) so stop cannot guess page ownership.');
    }
  }
  const sessionState = await readSessionState(config);
  if (!sessionState) {
    return {
      status: 'no-session-pages',
      sessionId: config.sessionId,
      endpoint: config.endpoint,
      closedTargetIds: [],
    };
  }

  const version = endpointState;
  if (!version) {
    return {
      status: 'endpoint-unavailable',
      sessionId: config.sessionId,
      endpoint: config.endpoint,
      closedTargetIds: [],
      retainedTargetIds: sessionState.ownedTargetIds || [],
    };
  }

  const info = await managedInfo(config, version);
  if (!info.managed && !flags['reuse-existing']) {
    throw new Error('The endpoint is not managed by this CLI. Refusing to close session pages unless --reuse-existing confirms the intended browser.');
  }
  const targets = await endpointTargets(config);
  const ownedTargetIds = Array.isArray(sessionState.ownedTargetIds) ? sessionState.ownedTargetIds : [];
  const existingIds = new Set(targets.map((target) => target.id));
  const closeIds = ownedTargetIds.filter((targetId) => existingIds.has(targetId));
  const { closedTargetIds, failedTargets } = await closeTargets(config, closeIds);
  if (failedTargets.length > 0) {
    const failedIds = new Set(failedTargets.map((item) => item.targetId));
    sessionState.ownedTargetIds = ownedTargetIds.filter((targetId) => failedIds.has(targetId));
    if (!sessionState.ownedTargetIds.includes(sessionState.currentTargetId)) {
      sessionState.currentTargetId = null;
      sessionState.currentTargetUrl = null;
      sessionState.currentTargetTitle = null;
    }
    await writeJsonFile(config.sessionStateFile, sessionState);
  } else {
    await fs.rm(config.sessionStateFile, { force: true });
  }
  return {
    status: failedTargets.length > 0 ? 'partial-close' : 'session-pages-closed',
    sessionId: config.sessionId,
    endpoint: config.endpoint,
    closedTargetIds,
    failedTargets,
    alreadyClosedTargetIds: ownedTargetIds.filter((targetId) => !existingIds.has(targetId)),
    browserClosed: false,
  };
}

async function listSessionStates(config, version = null) {
  let entries = [];
  try {
    entries = await fs.readdir(config.sessionsDir, { withFileTypes: true });
  } catch (error) {
    if (error.code === 'ENOENT') {
      return [];
    }
    throw error;
  }
  const states = [];
  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith('.json')) {
      continue;
    }
    const state = await readJsonFile(path.join(config.sessionsDir, entry.name));
    if (state
      && state.endpoint === config.endpoint
      && path.resolve(state.profilePath || '') === config.profilePath
      && (!version || state.browserWebSocketUrl === version.webSocketDebuggerUrl)) {
      states.push(state);
    }
  }
  return states;
}

async function shutdownBrowser(config, flags) {
  const state = await readJsonFile(config.stateFile);
  const version = await endpointVersion(config);
  const info = await managedInfo(config, version);
  const stateIsForConfig = stateMatchesConfig(state, config);

  if (version && !info.managed) {
    throw new Error('The endpoint is not managed by this CLI. Refusing to stop it.');
  }
  if (!state || !stateIsForConfig || !state.processId) {
    return {
      status: version ? 'unmanaged-endpoint' : 'not-running',
      endpoint: config.endpoint,
      profilePath: config.profilePath,
      processId: null,
    };
  }

  const processId = Number(state.processId);
  if (!processIsAlive(processId)) {
    await fs.rm(config.stateFile, { force: true });
    return {
      status: 'not-running',
      endpoint: config.endpoint,
      profilePath: config.profilePath,
      processId,
    };
  }
  if (!version) {
    throw new Error('The saved Chrome process is alive, but its CDP endpoint cannot be verified. Refusing to stop it automatically.');
  }

  const targets = (await endpointTargets(config)).filter((target) => target.type === 'page');
  const targetIds = new Set(targets.map((target) => target.id));
  const sessions = await listSessionStates(config, version);
  const activeSessions = sessions
    .map((session) => ({
      sessionId: session.sessionId,
      targetIds: (Array.isArray(session.ownedTargetIds) ? session.ownedTargetIds : []).filter((id) => targetIds.has(id)),
    }))
    .filter((session) => session.targetIds.length > 0);
  const otherActiveSessions = activeSessions.filter((session) => session.sessionId !== config.sessionId);
  const registeredTargetIds = new Set(activeSessions.flatMap((session) => session.targetIds));
  const unownedTargetIds = targets.map((target) => target.id).filter((targetId) => !registeredTargetIds.has(targetId));
  if ((otherActiveSessions.length > 0 || unownedTargetIds.length > 0) && !boolFlag(flags, 'force')) {
    throw new Error('Other or unowned pages still exist in this browser: ' + JSON.stringify({ otherActiveSessions, unownedTargetIds }) + '. Run stop for the owning sessions, or use shutdown-browser --force only after confirming that every page may be closed.');
  }

  const deadline = Date.now() + numberFlag(flags, 'timeout-ms', DEFAULT_TIMEOUT_MS, 1000, 120000);
  const closeRequested = await requestBrowserClose(config);
  if (!closeRequested) {
    await terminateProcess(processId);
  }
  while (Date.now() < deadline && processIsAlive(processId)) {
    await sleep(100);
  }
  if (processIsAlive(processId)) {
    await terminateProcess(processId);
  }
  const forceDeadline = Date.now() + 5000;
  while (Date.now() < forceDeadline && processIsAlive(processId)) {
    await sleep(100);
  }
  if (processIsAlive(processId)) {
    throw new Error('Chrome process ' + processId + ' did not exit within the timeout.');
  }
  await fs.rm(config.stateFile, { force: true });
  await fs.rm(config.sessionsDir, { recursive: true, force: true });
  return {
    status: 'browser-shutdown',
    endpoint: config.endpoint,
    profilePath: config.profilePath,
    processId,
    closeRequested,
    activeSessions,
    unownedTargetIds,
  };
}

async function requireEndpoint(config, flags) {
  const version = await endpointVersion(config);
  if (!version) {
    throw new Error('No CDP endpoint is available at ' + config.endpoint + '. Run the ensure command first.');
  }
  const info = await managedInfo(config, version);
  if (!info.managed && !flags['reuse-existing']) {
    throw new Error('The endpoint is not managed by this CLI. Pass --reuse-existing only when you have verified the endpoint is the intended browser.');
  }
  return { version, state: info.state, managed: info.managed };
}

function selectTarget(targets, flags) {
  const pages = targets.filter((target) => target.type === 'page' && target.webSocketDebuggerUrl);
  let candidates = pages;
  if (flags['target-id']) {
    candidates = candidates.filter((target) => target.id === flags['target-id']);
  }
  if (flags['target-url']) {
    candidates = candidates.filter((target) => target.url === flags['target-url']);
  }
  if (flags['target-title']) {
    candidates = candidates.filter((target) => target.title === flags['target-title']);
  }
  if (candidates.length === 1) {
    return candidates[0];
  }
  if (candidates.length === 0) {
    throw new Error('No unique page target matched. Use --target-id, --target-url, or --target-title. Current pages:\n' + JSON.stringify(pages, null, 2));
  }
  throw new Error('More than one page target matched. Use --target-id, --target-url, or --target-title:\n' + JSON.stringify(candidates, null, 2));
}

async function connectToTarget(config, flags) {
  const connectionInfo = await requireEndpoint(config, flags);
  const targets = await endpointTargets(config);
  const target = selectTarget(targets, flags);
  const connection = await new CdpConnection(target.webSocketDebuggerUrl).connect();
  return { connectionInfo, target, connection };
}

async function createTarget(config, flags, url) {
  const connectionInfo = await requireEndpoint(config, flags);
  const connection = await new CdpConnection(connectionInfo.version.webSocketDebuggerUrl).connect();
  try {
    const result = await connection.call('Target.createTarget', { url });
    const deadline = Date.now() + DEFAULT_TIMEOUT_MS;
    while (Date.now() < deadline) {
      const targets = await endpointTargets(config);
      const target = targets.find((item) => item.id === result.targetId);
      if (target) {
        await saveCurrentTarget(config, target, { owned: true });
        return target;
      }
      await sleep(100);
    }
    throw new Error('Chrome created target ' + result.targetId + ' but it did not appear in /json/list.');
  } finally {
    connection.close();
  }
}

async function closeStartupPages(config, flags, keepTargetId) {
  const connectionInfo = await requireEndpoint(config, flags);
  const browserState = await readJsonFile(config.stateFile);
  const initialPageIds = new Set(Array.isArray(browserState?.initialPageIds) ? browserState.initialPageIds : []);
  if (initialPageIds.size === 0) {
    return [];
  }
  const protectedTargetIds = new Set((await listSessionStates(config, connectionInfo.version)).flatMap((session) => (
    Array.isArray(session.ownedTargetIds) ? session.ownedTargetIds : []
  )));
  const targets = await endpointTargets(config);
  const startupPages = targets.filter((target) => (
    target.type === 'page'
      && target.id !== keepTargetId
      && initialPageIds.has(target.id)
      && !protectedTargetIds.has(target.id)
      && (target.url === 'about:blank' || target.url === 'chrome://newtab/' || target.url === 'chrome://new-tab-page/')
  ));
  if (startupPages.length === 0) {
    return [];
  }
  const connection = await new CdpConnection(connectionInfo.version.webSocketDebuggerUrl).connect();
  const closed = [];
  try {
    for (const target of startupPages) {
      const result = await connection.call('Target.closeTarget', { targetId: target.id });
      if (result.success !== false) {
        closed.push(target.id);
      }
    }
  } finally {
    connection.close();
  }
  return closed;
}

async function connectToCurrentTarget(config, flags) {
  const state = await readSessionState(config);
  const hasExplicitTarget = Boolean(flags['target-id'] || flags['target-url'] || flags['target-title']);
  if (!hasExplicitTarget && !state?.currentTargetId) {
    throw new Error('No current page is selected for session ' + config.sessionId + '. Run list, then pass --target-id, --target-url, or --target-title once; or create a session-owned page with open/ensure --url.');
  }
  const mergedFlags = hasExplicitTarget ? { ...flags } : { ...targetFlagsFromState(state), ...flags };
  try {
    const result = await connectToTarget(config, mergedFlags);
    await saveCurrentTarget(config, result.target);
    return result;
  } catch (error) {
    if (state && state.currentTargetId && !flags['target-id'] && !flags['target-url'] && !flags['target-title']) {
      throw new Error(error.message + ' The saved current target is no longer available; run list and choose a new target.');
    }
    throw error;
  }
}

async function evaluateExpression(connection, expression, options = {}) {
  const result = await connection.call('Runtime.evaluate', {
    expression,
    awaitPromise: options.awaitPromise !== false,
    returnByValue: options.returnByValue !== false,
    userGesture: options.userGesture !== false,
  });
  if (result.exceptionDetails) {
    const description = result.result?.description
      || result.exceptionDetails.exception?.description
      || result.exceptionDetails.text
      || 'JavaScript evaluation failed.';
    throw new Error(description);
  }
  return result;
}

async function waitForExpression(connection, expression, timeoutMs, intervalMs) {
  const deadline = Date.now() + timeoutMs;
  let lastValue = null;
  while (Date.now() <= deadline) {
    const result = await evaluateExpression(connection, expression);
    lastValue = result.result?.value ?? null;
    if (lastValue && lastValue.ok) {
      return lastValue;
    }
    await sleep(intervalMs);
  }
  throw new Error('Wait condition timed out after ' + timeoutMs + ' ms. Last result: ' + JSON.stringify(lastValue));
}

function selectorLookupExpression(selector) {
  return `(function(){
    const nodes = Array.from(document.querySelectorAll(${JSON.stringify(selector)}));
    if (nodes.length !== 1) return {ok:false,count:nodes.length};
    const node = nodes[0];
    node.scrollIntoView({block:'center',inline:'center'});
    const style = getComputedStyle(node);
    const rect = node.getBoundingClientRect();
    const visible = style.display !== 'none' && style.visibility !== 'hidden' && Number(style.opacity) !== 0 && rect.width > 0 && rect.height > 0;
    return {ok:visible,count:1,visible,tagName:node.tagName.toLowerCase(),id:node.id || null,text:(node.innerText || node.textContent || '').trim().slice(0,500)};
  })()`;
}

async function queryNodeId(connection, selector) {
  await connection.call('DOM.enable');
  const documentResult = await connection.call('DOM.getDocument', { depth: 0, pierce: true });
  const queryResult = await connection.call('DOM.querySelectorAll', {
    nodeId: documentResult.root.nodeId,
    selector,
  });
  if (queryResult.nodeIds.length !== 1) {
    throw new Error('Selector must match exactly one element; matched ' + queryResult.nodeIds.length + ': ' + selector);
  }
  return queryResult.nodeIds[0];
}

async function clickSelector(connection, selector) {
  const lookup = await evaluateExpression(connection, selectorLookupExpression(selector));
  const summary = lookup.result?.value;
  if (!summary || summary.count !== 1) {
    throw new Error('Selector must match exactly one element; matched ' + (summary?.count ?? 0) + ': ' + selector);
  }
  if (!summary.visible) {
    throw new Error('The selected element is not visible: ' + selector);
  }
  const nodeId = await queryNodeId(connection, selector);
  const box = await connection.call('DOM.getBoxModel', { nodeId });
  const quad = box.model.content;
  const x = (quad[0] + quad[2] + quad[4] + quad[6]) / 4;
  const y = (quad[1] + quad[3] + quad[5] + quad[7]) / 4;
  await connection.call('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  await connection.call('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
  await connection.call('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
  return { selector, x, y, element: summary };
}

async function refreshTarget(config, targetId) {
  const targets = await endpointTargets(config);
  const target = targets.find((item) => item.id === targetId) || null;
  if (target) {
    await saveCurrentTarget(config, target);
  }
  return target;
}

function createLoadWaiter(connection, timeoutMs) {
  let settled = false;
  let timer = null;
  const promise = new Promise((resolve, reject) => {
    timer = setTimeout(() => {
      settled = true;
      reject(new Error('Page did not fire Page.loadEventFired within ' + timeoutMs + ' ms.'));
    }, timeoutMs);
    connection.on('Page.loadEventFired', (event) => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timer);
      resolve(event.params);
    });
  });
  return {
    promise,
    cancel() {
      if (!settled) {
        settled = true;
        clearTimeout(timer);
      }
    },
  };
}

async function captureScreenshot(connection, flags) {
  const format = stringFlag(flags, 'format', 'png').toLowerCase();
  if (!['png', 'jpeg'].includes(format)) {
    throw new Error('--format must be png or jpeg.');
  }
  const params = {
    format,
    quality: flags.quality === undefined ? undefined : numberFlag(flags, 'quality', 80, 0, 100),
    captureBeyondViewport: boolFlag(flags, 'full-page', false),
  };
  if (params.quality === undefined) {
    delete params.quality;
  }
  const selector = stringFlag(flags, 'selector', null);
  if (selector) {
    const nodeId = await queryNodeId(connection, selector);
    await connection.call('DOM.scrollIntoViewIfNeeded', { nodeId });
    const box = await connection.call('DOM.getBoxModel', { nodeId });
    const quad = box.model.border;
    const x = Math.min(quad[0], quad[2], quad[4], quad[6]);
    const y = Math.min(quad[1], quad[3], quad[5], quad[7]);
    const right = Math.max(quad[0], quad[2], quad[4], quad[6]);
    const bottom = Math.max(quad[1], quad[3], quad[5], quad[7]);
    params.clip = { x, y, width: right - x, height: bottom - y, scale: 1 };
    params.captureBeyondViewport = true;
  } else if (params.captureBeyondViewport) {
    const metrics = await connection.call('Page.getLayoutMetrics');
    const content = metrics.cssContentSize || metrics.contentSize;
    if (content) {
      params.clip = { x: 0, y: 0, width: content.width, height: content.height, scale: 1 };
    }
  }
  const result = await connection.call('Page.captureScreenshot', params);
  if (!result.data) {
    throw new Error('Page.captureScreenshot returned no image data.');
  }
  return result.data;
}

function domOutput(value, format) {
  if (format === 'text') {
    return value.nodes.map((node) => node.text);
  }
  if (format === 'html') {
    return value.nodes.map((node) => node.html);
  }
  if (format === 'attributes') {
    return value.nodes.map((node) => node.attributes);
  }
  return value;
}

function consoleArgumentValue(argument) {
  if (Object.hasOwn(argument, 'value')) {
    return argument.value;
  }
  if (argument.unserializableValue) {
    return argument.unserializableValue;
  }
  return argument.description || argument.className || argument.type || null;
}

function simplifyConsoleEvent(event) {
  if (event.method === 'Runtime.consoleAPICalled') {
    const frame = event.params.stackTrace?.callFrames?.[0] || null;
    const level = event.params.type === 'warning' ? 'warn' : event.params.type;
    return {
      source: 'console',
      level,
      text: event.params.args.map(consoleArgumentValue).map((value) => typeof value === 'string' ? value : JSON.stringify(value)).join(' '),
      args: event.params.args.map(consoleArgumentValue),
      timestamp: event.params.timestamp,
      url: frame?.url || null,
      line: frame ? frame.lineNumber + 1 : null,
      column: frame ? frame.columnNumber + 1 : null,
    };
  }
  if (event.method === 'Runtime.exceptionThrown') {
    const details = event.params.exceptionDetails;
    return {
      source: 'exception',
      level: 'error',
      text: details.exception?.description || details.text || 'Uncaught exception',
      timestamp: event.params.timestamp,
      url: details.url || null,
      line: details.lineNumber === undefined ? null : details.lineNumber + 1,
      column: details.columnNumber === undefined ? null : details.columnNumber + 1,
    };
  }
  const entry = event.params.entry;
  return {
    source: 'log',
    level: entry.level === 'warning' ? 'warn' : entry.level,
    text: entry.text,
    timestamp: entry.timestamp,
    url: entry.url || null,
    line: entry.lineNumber || null,
  };
}

function expressionForDom(flags) {
  const selector = stringFlag(flags, 'selector', null);
  const format = stringFlag(flags, 'format', 'summary');
  const maxChars = numberFlag(flags, 'max-chars', 20000, 1, 2000000);
  const limit = numberFlag(flags, 'limit', 20, 1, 1000);
  const selectorText = selector ? JSON.stringify(selector) : 'null';
  return `(function(){
    const selector = ${selectorText};
    const nodes = selector ? Array.from(document.querySelectorAll(selector)) : [document.documentElement];
    const visible = (node) => {
      if (!(node instanceof Element)) return true;
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      return style.display !== 'none' && style.visibility !== 'hidden' && Number(style.opacity) !== 0 && rect.width > 0 && rect.height > 0;
    };
    const summarize = (node) => ({
      tagName: node.tagName ? node.tagName.toLowerCase() : null,
      id: node.id || null,
      className: typeof node.className === 'string' ? node.className : null,
      text: (node.innerText || node.textContent || '').trim().slice(0, ${maxChars}),
      html: node.outerHTML ? node.outerHTML.slice(0, ${maxChars}) : null,
      attributes: node instanceof Element ? Object.fromEntries(Array.from(node.attributes, (attr) => [attr.name, attr.value])) : {},
      visible: visible(node),
      rect: node instanceof Element ? (() => { const r = node.getBoundingClientRect(); return {x:r.x,y:r.y,width:r.width,height:r.height}; })() : null,
    });
    return { selector, count: nodes.length, returned: Math.min(nodes.length, ${limit}), truncated: nodes.length > ${limit}, format: ${JSON.stringify(format)}, nodes: nodes.slice(0, ${limit}).map(summarize) };
  })()`;
}

function expressionForWait(flags, positionals) {
  const selector = stringFlag(flags, 'selector', null);
  const text = stringFlag(flags, 'text', positionals.join(' ') || null);
  const state = stringFlag(flags, 'state', 'present');
  if (!selector && !text) {
    throw new Error('wait requires --selector SELECTOR or --text TEXT.');
  }
  if (!['present', 'visible', 'hidden'].includes(state)) {
    throw new Error('--state must be present, visible, or hidden.');
  }
  return `(function(){
    const selector = ${JSON.stringify(selector)};
    const text = ${JSON.stringify(text)};
    const state = ${JSON.stringify(state)};
    const matches = selector ? Array.from(document.querySelectorAll(selector)) : [];
    const visible = (node) => { const style = getComputedStyle(node); const rect = node.getBoundingClientRect(); return style.display !== 'none' && style.visibility !== 'hidden' && Number(style.opacity) !== 0 && rect.width > 0 && rect.height > 0; };
    const found = selector ? matches.length > 0 : (document.body?.innerText || '').includes(text);
    const isVisible = selector ? matches.some(visible) : found;
    const ok = state === 'visible' ? isVisible : state === 'hidden' ? !isVisible : found;
    return {ok, selector, text, state, count: matches.length, visible: isVisible};
  })()`;
}

async function commandStatus(config) {
  const version = await endpointVersion(config);
  const info = await managedInfo(config, version);
  const sessionState = await readSessionState(config);
  let targets = [];
  if (version) {
    try {
      targets = await endpointTargets(config);
    } catch {
      targets = [];
    }
  }
  return {
    ok: Boolean(version),
    status: version ? (info.managed ? 'ready' : 'unmanaged-endpoint') : 'endpoint-unavailable',
    usable: Boolean(version && info.managed),
    managed: info.managed,
    endpoint: config.endpoint,
    profilePath: config.profilePath,
    stateFile: config.stateFile,
    sessionId: config.sessionId,
    sessionStateFile: config.sessionStateFile,
    browser: version ? version.Browser || null : null,
    browserWebSocketUrl: version ? version.webSocketDebuggerUrl : null,
    currentTarget: sessionState?.currentTargetId
      ? targets.find((target) => target.id === sessionState.currentTargetId) || {
        id: sessionState.currentTargetId,
        title: sessionState.currentTargetTitle || null,
        url: sessionState.currentTargetUrl || null,
        available: false,
      }
      : null,
    ownedTargetIds: sessionState?.ownedTargetIds || [],
    targets,
  };
}

async function commandDoctor(config, flags) {
  const checks = [];
  const addCheck = (name, status, details) => checks.push({ name, status, ...details });

  const nodeMajor = Number(process.versions.node.split('.')[0]);
  addCheck('node', nodeMajor >= 22 ? 'pass' : 'fail', {
    version: process.version,
    required: '>=22',
    message: nodeMajor >= 22 ? 'Node.js built-in WebSocket support is available.' : 'Install Node.js 22 or newer.',
  });

  const npx = runCommand('npx', ['--version']);
  addCheck('npx', npx.ok ? 'pass' : 'fail', {
    version: npx.ok ? npx.output : null,
    message: npx.ok ? 'npx is available on PATH.' : 'Install npm/Node.js and ensure npx is on PATH.',
    error: npx.ok ? null : npx.error,
  });

  let chromePath = null;
  try {
    chromePath = await findChrome(config.chromePath);
    addCheck('chrome', 'pass', {
      path: chromePath,
      message: 'A Chrome executable was found.' ,
    });
  } catch (error) {
    addCheck('chrome', 'fail', {
      path: config.chromePath || null,
      message: error.message,
    });
  }

  const status = await commandStatus(config);
  addCheck('cdp_endpoint', status.ok ? 'pass' : 'warn', {
    endpoint: status.endpoint,
    endpointStatus: status.status,
    managed: status.managed,
    usable: status.usable,
    currentTarget: status.currentTarget,
    message: status.ok
      ? (status.usable ? 'Endpoint is online and managed by this CLI.' : 'Endpoint is online but is not managed by this CLI; use --reuse-existing only after verifying it.')
      : 'Endpoint is offline. This is expected before ensure; run ensure when a CLI-managed browser is needed.',
  });

  const profileExists = await fs.access(config.profilePath).then(() => true).catch(() => false);
  const stateExists = await fs.access(config.stateFile).then(() => true).catch(() => false);
  addCheck('paths', 'pass', {
    stateRoot: config.stateRoot,
    profilePath: config.profilePath,
    stateFile: config.stateFile,
    profileExists,
    stateExists,
    message: 'Configured paths are resolved; missing profile/state files are created by ensure.',
  });

  const mcp = await inspectMcp(flags, npx.ok);
  addCheck('chrome_devtools_mcp', mcp.serverConfigured && mcp.packageReferenced && mcp.runnerAvailable ? 'pass' : 'warn', mcp);
  const mcpCheck = checks[checks.length - 1];
  if (mcpCheck.status === 'pass') {
    mcpCheck.status = 'warn';
    mcpCheck.message = 'MCP server configuration is present, but package startup and tool exposure are not verifiable from the CLI. Confirm mcp__chrome_devtools__list_pages in the current Codex task.';
  }

  addCheck('session', config.sessionSource === 'implicit-default' ? 'warn' : 'pass', {
    sessionId: config.sessionId,
    source: config.sessionSource,
    message: config.sessionSource === 'implicit-default'
      ? 'No session id was supplied. Use --session (or CODEX_SESSION_ID/CODEX_THREAD_ID) when multiple Codex tasks share a browser.'
      : 'Session ownership is explicitly scoped.' ,
  });

  const failures = checks.filter((check) => check.status === 'fail');
  const warnings = checks.filter((check) => check.status === 'warn');
  const nextSteps = [];
  if (!mcp.serverConfigured || !mcp.packageReferenced || !mcp.runnerAvailable) {
    nextSteps.push('If Chrome DevTools MCP is needed, install/configure it with: codex mcp add chrome-devtools -- npx chrome-devtools-mcp@latest, then reload the Codex task.');
  } else {
    nextSteps.push('MCP configuration is present; verify mcp__chrome_devtools__list_pages (or an equivalent tool) in the current Codex task.');
  }
  if (!status.ok) {
    nextSteps.push('If CLI control is needed, run ensure [--url URL].');
  }
  if (config.sessionSource === 'implicit-default') {
    nextSteps.push('When more than one Codex task shares a browser, pass an explicit --session id before using stop.');
  }
  return {
    ok: failures.length === 0,
    status: failures.length > 0 ? 'action-required' : warnings.length > 0 ? 'ready-with-warnings' : 'ready',
    platform: process.platform,
    cli: {
      endpoint: config.endpoint,
      stateRoot: config.stateRoot,
      profilePath: config.profilePath,
      chromePath,
    },
    checks,
    nextSteps,
  };
}

function print(value) {
  process.stdout.write(JSON.stringify(value, null, 2) + '\n');
}

function assertSafeBrowserCall(method) {
  if (method === 'Browser.close') {
    throw new Error('browser-call Browser.close is blocked because it bypasses session ownership checks. Use shutdown-browser [--force] after confirming every page may be closed.');
  }
}

function printHelp() {
  process.stdout.write([
    'Deterministic local Chrome CDP CLI',
    '',
    'Commands:',
    '  ensure [--port 9222] [--url URL] [--reuse-existing] [--chrome PATH]',
    '  stop [--port 9222] [--session ID] [--reuse-existing]',
    '  shutdown-browser [--port 9222] [--force] [--timeout-ms 15000]',
    '  status',
    '  doctor [--mcp-config PATH] [--chrome PATH] [--port PORT]',
    '  list [--home PATH] [--port 9222] [--reuse-existing]',
    '  open URL [--home PATH] [--port 9222] [--reuse-existing]',
    '  navigate URL [--target-id ID] [--wait load|none]',
    '  reload [--target-id ID] [--wait load|none]',
    '  dom [--selector CSS] [--format summary|text|html|attributes] [--max-chars N]',
    '  script (--file PATH | --stdin | EXPRESSION) [--target-id ID]',
    '  wait (--selector CSS | --text TEXT) [--state present|visible|hidden] [--timeout-ms N]',
    '  click --selector CSS [--wait-navigation] [--target-id ID]',
    '  screenshot [--output PATH] [--selector CSS] [--full-page] [--format png|jpeg]',
    '  eval EXPRESSION --target-id ID [--target-url URL] [--target-title TITLE] [--reuse-existing]',
    '  call METHOD [--params JSON | --params-file PATH | --params-stdin] [--target-id ID] [--target-url URL] [--target-title TITLE] [--reuse-existing]',
    '  browser-call METHOD [--params JSON | --params-file PATH | --params-stdin] [--reuse-existing]',
    '  console [--duration-ms 5000] [--level LEVELS] [--reload] [--live-only] [--raw]',
    '',
    'Common options:',
    '  --home PATH       State directory (default: %LOCALAPPDATA%\\codex-cdp)',
    '  --profile PATH    Chrome user-data directory (default: <home>\\profile)',
    '  --port PORT       Local CDP port (default: 9222)',
    '  --session ID      Page ownership scope (default: CODEX_SESSION_ID/CODEX_THREAD_ID)',
    '  --timeout-ms MS   Startup/stop timeout (default: 15000)',
    '',
    'Defaults:',
    '  endpoint: http://127.0.0.1:9222',
    '  profile: %LOCALAPPDATA%\\codex-cdp\\profile',
    '',
  ].join('\n'));
}

async function main() {
  const { positionals, flags } = parseArgs(process.argv.slice(2));
  const command = positionals.shift() || 'help';
  const config = configFrom(flags);

  if (command === 'help' || command === '--help' || command === '-h') {
    printHelp();
    return;
  }
  if (command === 'status') {
    print(await commandStatus(config));
    return;
  }
  if (command === 'doctor') {
    const result = await commandDoctor(config, flags);
    print(result);
    if (!result.ok) {
      process.exitCode = 1;
    }
    return;
  }
  if (command === 'ensure') {
    const result = await ensure(config, flags);
    let target = null;
    let closedStartupPages = [];
    if (flags.url) {
      target = await createTarget(config, { ...flags, 'reuse-existing': true }, String(flags.url));
      if (result.status === 'started') {
        closedStartupPages = await closeStartupPages(config, { ...flags, 'reuse-existing': true }, target.id);
      }
    }
    print({
      status: result.status,
      endpoint: config.endpoint,
      profilePath: config.profilePath,
      processId: result.state ? result.state.processId : null,
      browser: result.version.Browser || null,
      target,
      closedStartupPages,
    });
    return;
  }
  if (command === 'stop') {
    print(await stop(config, flags));
    return;
  }
  if (command === 'shutdown-browser') {
    print(await shutdownBrowser(config, flags));
    return;
  }
  if (command === 'list') {
    await requireEndpoint(config, flags);
    const pages = (await endpointTargets(config)).filter((target) => target.type === 'page');
    print(pages);
    return;
  }
  if (command === 'open') {
    const url = positionals.shift();
    if (!url) {
      throw new Error('open requires a URL.');
    }
    print(await createTarget(config, flags, url));
    return;
  }
  if (command === 'navigate' || command === 'reload') {
    const url = command === 'reload' ? null : positionals.shift();
    if (command === 'navigate' && !url) {
      throw new Error('navigate requires a URL.');
    }
    const { connection, target } = await connectToCurrentTarget(config, flags);
    let loadWaiter = null;
    try {
      const waitMode = stringFlag(flags, 'wait', 'load');
      if (waitMode !== 'none') {
        await connection.call('Page.enable');
      }
      loadWaiter = waitMode === 'none' ? null : createLoadWaiter(connection, numberFlag(flags, 'timeout-ms', DEFAULT_TIMEOUT_MS, 250, 120000));
      const result = command === 'reload'
        ? await connection.call('Page.reload', {})
        : await connection.call('Page.navigate', { url });
      if (result.errorText) {
        loadWaiter?.cancel();
        throw new Error(result.errorText);
      }
      if (loadWaiter) {
        await loadWaiter.promise;
      }
      const targets = await endpointTargets(config);
      const updatedTarget = targets.find((item) => item.id === target.id) || target;
      await saveCurrentTarget(config, updatedTarget);
      print({ target: updatedTarget, method: command === 'reload' ? 'Page.reload' : 'Page.navigate', result });
    } finally {
      loadWaiter?.cancel();
      connection.close();
    }
    return;
  }
  if (command === 'dom') {
    const { connection, target } = await connectToCurrentTarget(config, flags);
    try {
      const result = await evaluateExpression(connection, expressionForDom(flags));
      const value = result.result?.value || { selector: null, count: 0, nodes: [] };
      const format = stringFlag(flags, 'format', 'summary');
      print(format === 'summary'
        ? { target, ...value }
        : { target, selector: value.selector, count: value.count, format, value: domOutput(value, format) });
    } finally {
      connection.close();
    }
    return;
  }
  if (command === 'script') {
    let expression = null;
    if (flags.file) {
      expression = await fs.readFile(path.resolve(String(flags.file)), 'utf8');
    } else if (boolFlag(flags, 'stdin')) {
      expression = await readStdin();
    } else {
      expression = positionals.join(' ');
    }
    if (!expression || !expression.trim()) {
      throw new Error('script requires an expression, --file PATH, or --stdin.');
    }
    const { connection, target } = await connectToCurrentTarget(config, flags);
    try {
      const result = await evaluateExpression(connection, expression);
      print({ target, result });
    } finally {
      connection.close();
    }
    return;
  }
  if (command === 'wait') {
    const timeoutMs = numberFlag(flags, 'timeout-ms', DEFAULT_TIMEOUT_MS, 250, 120000);
    const { connection, target } = await connectToCurrentTarget(config, flags);
    try {
      const result = await waitForExpression(connection, expressionForWait(flags, positionals), timeoutMs, 100);
      print({ target, timeoutMs, result });
    } finally {
      connection.close();
    }
    return;
  }
  if (command === 'click') {
    const selector = stringFlag(flags, 'selector', null);
    if (!selector) {
      throw new Error('click requires --selector SELECTOR.');
    }
    const { connection, target } = await connectToCurrentTarget(config, flags);
    let loadWaiter = null;
    try {
      if (boolFlag(flags, 'wait-navigation')) {
        await connection.call('Page.enable');
      }
      loadWaiter = boolFlag(flags, 'wait-navigation') ? createLoadWaiter(connection, numberFlag(flags, 'timeout-ms', DEFAULT_TIMEOUT_MS, 250, 120000)) : null;
      const result = await clickSelector(connection, selector);
      if (loadWaiter) {
        await loadWaiter.promise;
      }
      print({ target: await refreshTarget(config, target.id) || target, result });
    } finally {
      loadWaiter?.cancel();
      connection.close();
    }
    return;
  }
  if (command === 'screenshot') {
    const outputPath = path.resolve(stringFlag(flags, 'output', 'screenshot.png'));
    const format = stringFlag(flags, 'format', path.extname(outputPath).toLowerCase() === '.jpg' || path.extname(outputPath).toLowerCase() === '.jpeg' ? 'jpeg' : 'png');
    const { connection, target } = await connectToCurrentTarget(config, flags);
    try {
      const data = await captureScreenshot(connection, { ...flags, format });
      await fs.mkdir(path.dirname(outputPath), { recursive: true });
      await fs.writeFile(outputPath, Buffer.from(data, 'base64'));
      print({ target, path: outputPath, format, bytes: (await fs.stat(outputPath)).size });
    } finally {
      connection.close();
    }
    return;
  }
  if (command === 'eval') {
    const expression = positionals.join(' ');
    if (!expression) {
      throw new Error('eval requires a JavaScript expression.');
    }
    const { connection, target } = await connectToCurrentTarget(config, flags);
    try {
      const result = await evaluateExpression(connection, expression);
      print({ target, result });
    } finally {
      connection.close();
    }
    return;
  }
  if (command === 'call') {
    const method = positionals.shift();
    if (!method) {
      throw new Error('call requires a CDP method name.');
    }
    let paramsText = stringFlag(flags, 'params', '{}');
    if (flags['params-file']) {
      paramsText = await fs.readFile(path.resolve(String(flags['params-file'])), 'utf8');
    } else if (boolFlag(flags, 'params-stdin')) {
      paramsText = await readStdin();
    }
    let params;
    try {
      params = JSON.parse(paramsText);
    } catch {
      throw new Error('--params must contain valid JSON.');
    }
    const { connection, target } = await connectToCurrentTarget(config, flags);
    try {
      print({ target, method, result: await connection.call(method, params) });
    } finally {
      connection.close();
    }
    return;
  }
  if (command === 'browser-call') {
    const method = positionals.shift();
    if (!method) {
      throw new Error('browser-call requires a CDP method name.');
    }
    assertSafeBrowserCall(method);
    let paramsText = stringFlag(flags, 'params', '{}');
    if (flags['params-file']) {
      paramsText = await fs.readFile(path.resolve(String(flags['params-file'])), 'utf8');
    } else if (boolFlag(flags, 'params-stdin')) {
      paramsText = await readStdin();
    }
    let params;
    try {
      params = JSON.parse(paramsText);
    } catch {
      throw new Error('Browser call parameters must contain valid JSON.');
    }
    const connectionInfo = await requireEndpoint(config, flags);
    const connection = await new CdpConnection(connectionInfo.version.webSocketDebuggerUrl).connect();
    try {
      print({ method, result: await connection.call(method, params) });
    } finally {
      connection.close();
    }
    return;
  }
  if (command === 'console') {
    const durationMs = numberFlag(flags, 'duration-ms', 5000, 250, 120000);
    const { connection, target } = await connectToCurrentTarget(config, flags);
    const events = [];
    const levels = stringFlag(flags, 'level', '').split(',').map((value) => value.trim()).filter(Boolean);
    const raw = boolFlag(flags, 'raw');
    const liveOnly = boolFlag(flags, 'live-only');
    let captureLiveEvents = !liveOnly;
    const eventNames = [
      'Runtime.consoleAPICalled',
      'Runtime.exceptionThrown',
      'Log.entryAdded',
    ];
    for (const eventName of eventNames) {
      connection.on(eventName, (event) => {
        if (captureLiveEvents) {
          events.push(event);
        }
      });
    }
    try {
      await connection.call('Runtime.enable');
      await connection.call('Log.enable');
      captureLiveEvents = true;
      if (boolFlag(flags, 'reload')) {
        await connection.call('Page.reload', {});
      }
      await sleep(durationMs);
      const selected = events
        .map((event) => ({ event, simplified: simplifyConsoleEvent(event) }))
        .filter(({ simplified }) => levels.length === 0 || levels.includes(simplified.level))
        .map(({ event, simplified }) => raw ? event : simplified);
      print({ target, durationMs, events: selected });
    } finally {
      connection.close();
    }
    return;
  }
  throw new Error('Unknown command: ' + command + '. Run with help for usage.');
}

main().catch((error) => {
  process.stderr.write('cdp-cli: ' + (error && error.message ? error.message : String(error)) + '\n');
  process.exitCode = 1;
});
