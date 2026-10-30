const HTML_ESCAPES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };

export function escapeHtml(text) {
  return String(text ?? "").replace(/[&<>"']/g, (ch) => HTML_ESCAPES[ch]);
}

const URL_PATTERN = /\bhttps?:\/\/[^\s<]+[^\s<.,:;"')\]]/g;
const MENTION_PATTERN = /(^|[^\w@])@([a-z0-9_]{3,30})\b/gi;

// Turns a plain-text message body into safe HTML: everything is escaped
// first, then only our own markup (links, mention spans) is added.
export function renderMessageBody(body, { currentUsername, knownUsernames } = {}) {
  let html = escapeHtml(body);
  html = html.replace(URL_PATTERN, (url) => `<a href="${url}" target="_blank" rel="noopener noreferrer">${url}</a>`);
  html = html.replace(MENTION_PATTERN, (match, prefix, username) => {
    const name = username.toLowerCase();
    if (knownUsernames && !knownUsernames.has(name)) return match;
    const cls = name === currentUsername ? "mention mention--me" : "mention";
    return `${prefix}<span class="${cls}">@${username}</span>`;
  });
  return html;
}

export function initials(name) {
  return String(name ?? "?")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0].toUpperCase())
    .join("");
}

// Stable, muted hue per user so avatars are distinguishable.
export function avatarHue(id) {
  return (Number(id) * 47) % 360;
}

export function formatTime(iso) {
  return new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

export function dayLabel(iso, now = new Date()) {
  const date = new Date(iso);
  const startOf = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const diffDays = Math.round((startOf(now) - startOf(date)) / 86400000);
  if (diffDays === 0) return "Today";
  if (diffDays === 1) return "Yesterday";
  return date.toLocaleDateString([], { weekday: "long", month: "long", day: "numeric" });
}

const GROUP_WINDOW_MS = 5 * 60 * 1000;

// Adds display hints to an ascending list of messages: a day separator when
// the date changes, and `compact` when the same author posts again shortly.
export function decorateMessages(messages) {
  let previous = null;
  return messages.map((message) => {
    const day = dayLabel(message.created_at);
    const newDay = !previous || dayLabel(previous.created_at) !== day;
    const compact =
      !newDay &&
      previous &&
      !previous.deleted_at &&
      !message.deleted_at &&
      previous.user?.id === message.user?.id &&
      new Date(message.created_at) - new Date(previous.created_at) < GROUP_WINDOW_MS;
    previous = message;
    return { message, dayLabel: newDay ? day : null, compact: Boolean(compact) };
  });
}

export function typingText(users) {
  const names = users.map((u) => u.display_name);
  if (names.length === 0) return "";
  if (names.length === 1) return `${names[0]} is typing…`;
  if (names.length === 2) return `${names[0]} and ${names[1]} are typing…`;
  return "Several people are typing…";
}
