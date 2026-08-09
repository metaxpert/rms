#!/usr/bin/env node
/**
 * MetaXperts RMS — thermal print agent.
 *
 * Runs on the restaurant's own network (a till PC, a Raspberry Pi in the kitchen) and is the only
 * thing that ever touches a printer. It polls the ERP for print jobs addressed to its printer, pushes
 * the ESC/POS bytes to the device, and reports the result back so the job leaves the spool.
 *
 * Why an agent instead of the API printing directly: a cloud API cannot reach 192.168.x.x, and a
 * printer that is off, jammed or out of paper must delay a slip — never fail an order. Jobs stay
 * QUEUED until this agent succeeds, and a crash mid-print is re-offered automatically.
 *
 * No dependencies — plain Node (>=18) using the built-in net/fs/fetch.
 *
 * Usage:
 *   API_URL=http://localhost:3399 \
 *   RMS_EMAIL=chef@karahipoint.test RMS_PASSWORD='Password123!' \
 *   PRINTER_KEY=till-1 \
 *   node scripts/print-agent.js
 *
 * Environment:
 *   API_URL         ERP base url (default http://localhost:3399)
 *   RMS_EMAIL/RMS_PASSWORD   login used to obtain a token (needs the `restaurant:print` permission)
 *   RMS_TOKEN       use a pre-issued access token instead of logging in
 *   PRINTER_KEY     which printer this agent serves (matches the key in the printer registry)
 *   POLL_MS         poll interval, default 2000
 *   TARGET          override the device: `tcp://192.168.1.50:9100`, `file:///dev/usb/lp0`,
 *                   or `stdout:` to print to the terminal (dry run — the default when unset)
 *   AGENT_NAME      identity recorded on each claim (default: hostname)
 */

const net = require('node:net');
const fs = require('node:fs');
const os = require('node:os');

const API = (process.env.API_URL || 'http://localhost:3399').replace(/\/$/, '');
const PRINTER_KEY = process.env.PRINTER_KEY;
const POLL_MS = Number(process.env.POLL_MS || 2000);
const AGENT = process.env.AGENT_NAME || os.hostname();
const TARGET = process.env.TARGET || 'stdout:';

if (!PRINTER_KEY) {
  console.error('PRINTER_KEY is required (the key of the printer this agent serves).');
  process.exit(1);
}

let token = process.env.RMS_TOKEN || '';
let stopping = false;

const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);

async function login() {
  const email = process.env.RMS_EMAIL;
  const password = process.env.RMS_PASSWORD;
  if (!email || !password) throw new Error('Set RMS_TOKEN, or RMS_EMAIL + RMS_PASSWORD');
  const res = await fetch(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) throw new Error(`login failed: ${res.status} ${await res.text()}`);
  const body = await res.json();
  token = body.data.accessToken;
  log(`authenticated as ${email}`);
}

/** Call the API, re-authenticating once if the token has expired. */
async function api(path, options = {}, retry = true) {
  if (!token) await login();
  const res = await fetch(`${API}${path}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, ...(options.headers || {}) },
  });
  if (res.status === 401 && retry) {
    token = '';
    return api(path, options, false);
  }
  if (!res.ok) throw new Error(`${options.method || 'GET'} ${path} → ${res.status} ${await res.text()}`);
  const body = await res.json();
  return body.data;
}

/** Push raw bytes to the configured device. Rejects if the printer is unreachable. */
function send(bytes) {
  if (TARGET.startsWith('stdout:')) {
    // Dry run: show the human-readable rendering rather than dumping control codes at a terminal.
    return Promise.resolve('stdout');
  }
  if (TARGET.startsWith('file://')) {
    const path = TARGET.slice('file://'.length);
    return new Promise((resolve, reject) => {
      fs.writeFile(path, bytes, (err) => (err ? reject(err) : resolve(path)));
    });
  }
  const m = /^tcp:\/\/([^:/]+)(?::(\d+))?/.exec(TARGET);
  if (!m) return Promise.reject(new Error(`Unsupported TARGET "${TARGET}"`));
  const host = m[1];
  const port = Number(m[2] || 9100);
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host, port });
    // A thermal printer that accepted the bytes but never closes must not hang the agent forever.
    socket.setTimeout(10000);
    socket.on('connect', () => socket.end(bytes));
    socket.on('close', () => resolve(`${host}:${port}`));
    socket.on('timeout', () => {
      socket.destroy();
      reject(new Error(`timeout talking to ${host}:${port}`));
    });
    socket.on('error', reject);
  });
}

async function tick() {
  const job = await api('/restaurant/print-jobs/claim', {
    method: 'POST',
    body: JSON.stringify({ printerKey: PRINTER_KEY, agent: AGENT }),
  });
  if (!job) return false; // nothing queued

  const label = `${job.kind}${job.docNo ? ` ${job.docNo}` : ''} (job ${job.id.slice(0, 8)})`;
  try {
    const bytes = Buffer.from(job.escposBase64, 'base64');
    for (let copy = 0; copy < Math.max(1, job.copies); copy++) {
      const where = await send(bytes);
      if (where === 'stdout') console.log(`\n${job.text}`);
    }
    await api(`/restaurant/print-jobs/${job.id}/complete`, { method: 'POST', body: JSON.stringify({ ok: true }) });
    log(`✓ printed ${label} → ${TARGET}`);
  } catch (err) {
    // Report the failure rather than swallowing it: the job returns to the queue and is retried, and
    // the error surfaces on the spool screen so someone can go look at the paper tray.
    await api(`/restaurant/print-jobs/${job.id}/complete`, {
      method: 'POST',
      body: JSON.stringify({ ok: false, error: String(err.message || err) }),
    }).catch(() => {});
    log(`✗ failed ${label}: ${err.message || err}`);
  }
  return true;
}

async function main() {
  log(`print agent for "${PRINTER_KEY}" → ${TARGET} (api ${API}, poll ${POLL_MS}ms)`);
  while (!stopping) {
    try {
      // Drain the queue before sleeping, so a burst of tickets prints back to back.
      while (!stopping && (await tick())) { /* keep going */ }
    } catch (err) {
      log(`poll error: ${err.message || err}`);
    }
    await new Promise((r) => setTimeout(r, POLL_MS));
  }
}

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    stopping = true;
    log('stopping…');
    process.exit(0);
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
