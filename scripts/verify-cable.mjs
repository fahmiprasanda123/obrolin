#!/usr/bin/env node
// Proves that a message posted through the REST API reaches WebSocket clients
// connected to *different* cable servers (pods), i.e. that ActionCable
// broadcasts travel through Redis pub/sub.
//
// Usage: node scripts/verify-cable.mjs [baseUrl] [connections]
//   node scripts/verify-cable.mjs http://localhost:5173 6
//   node scripts/verify-cable.mjs http://obrolin.local 8
// Requires Node 22+ (built-in WebSocket) and the seed data.

const baseUrl = (process.argv[2] || "http://localhost:5173").replace(/\/$/, "");
const connections = Number(process.argv[3] || 6);
const wsUrl = baseUrl.replace(/^http/, "ws") + "/cable";
const TIMEOUT_MS = 10000;

async function api(path, { method = "GET", token, body } = {}) {
  const res = await fetch(`${baseUrl}/api/v1${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${await res.text()}`);
  return res.status === 204 ? null : res.json();
}

function openSubscriber(token, channelId, index) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`${wsUrl}?token=${encodeURIComponent(token)}`, {
      headers: { Origin: baseUrl },
    });
    const identifier = JSON.stringify({ channel: "ConversationChannel", channel_id: channelId });
    const sub = { index, ws, server: null, received: null };
    const timer = setTimeout(() => reject(new Error(`connection ${index} timed out`)), TIMEOUT_MS);

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.type === "welcome") ws.send(JSON.stringify({ command: "subscribe", identifier }));
      if (data.type === "reject_subscription") reject(new Error("subscription rejected"));
      const msg = data.message;
      if (!msg || data.identifier !== identifier) return;
      if (msg.type === "subscribed") {
        sub.server = msg.server;
        clearTimeout(timer);
        resolve(sub);
      }
      if (msg.type === "message.created") sub.received = msg.message;
    };
    ws.onerror = () => reject(new Error(`connection ${index} failed (check ALLOWED_ORIGINS and the URL)`));
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const { token } = await api("/auth/login", { method: "POST", body: { login: "alice", password: "password123" } });
const [workspace] = await api("/workspaces", { token });
const channels = await api(`/workspaces/${workspace.id}/channels`, { token });
const general = channels.find((c) => c.name === "general");

console.log(`Opening ${connections} WebSocket connections to ${wsUrl} ...`);
const subs = await Promise.all(Array.from({ length: connections }, (_, i) => openSubscriber(token, general.id, i + 1)));

const marker = `cable check ${new Date().toISOString()}`;
const posted = await api(`/channels/${general.id}/messages`, { method: "POST", token, body: { message: { body: marker } } });

const deadline = Date.now() + TIMEOUT_MS;
while (Date.now() < deadline && subs.some((s) => s.received?.body !== marker)) await sleep(100);

const byServer = {};
for (const s of subs) {
  const ok = s.received?.body === marker;
  console.log(`  connection ${s.index}: server=${s.server}  received=${ok ? "yes" : "NO"}`);
  byServer[s.server] ??= { total: 0, ok: 0 };
  byServer[s.server].total += 1;
  byServer[s.server].ok += ok ? 1 : 0;
  s.ws.close();
}

// Clean up the test message (soft delete, also broadcast to clients).
await api(`/messages/${posted.id}`, { method: "DELETE", token }).catch(() => {});

const servers = Object.keys(byServer);
const allOk = subs.every((s) => s.received?.body === marker);
console.log(`\nCable servers seen: ${servers.length} (${servers.join(", ")})`);
if (servers.length < 2) console.log("Note: only one server seen. With 2+ cable pods, rerun with more connections.");
console.log(allOk ? "PASS: every connection received the broadcast." : "FAIL: some connections missed the broadcast.");
process.exit(allOk ? 0 : 1);
