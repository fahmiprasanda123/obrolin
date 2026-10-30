import { createConsumer } from "@rails/actioncable";

// One WebSocket per browser tab. Every subscription (each joined channel,
// presence, notifications) is multiplexed over this single connection.
let consumer = null;

export function connectCable(token) {
  disconnectCable();
  // Browsers cannot send an Authorization header on a WebSocket handshake,
  // so the JWT goes in the query string. Relative URLs resolve to ws(s)://.
  consumer = createConsumer(`/cable?token=${encodeURIComponent(token)}`);
  return consumer;
}

export function getConsumer() {
  return consumer;
}

export function disconnectCable() {
  consumer?.disconnect();
  consumer = null;
}
