import { beforeEach, describe, expect, it, vi } from "vitest";
import { createPinia, setActivePinia } from "pinia";
import { useMessagesStore } from "../src/stores/messages";

const message = (id, createdAt, extra = {}) => ({
  id,
  channel_id: 1,
  parent_message_id: null,
  user: { id: 7, display_name: "Budi" },
  body: `message ${id}`,
  reply_count: 0,
  deleted_at: null,
  created_at: createdAt,
  ...extra,
});

function mockFetch(payload) {
  globalThis.fetch = vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => payload });
}

describe("messages store", () => {
  let store;

  beforeEach(() => {
    setActivePinia(createPinia());
    store = useMessagesStore();
  });

  it("loads the newest page and keeps messages oldest-first", async () => {
    mockFetch({ messages: [message("b", "2026-01-01T10:01:00Z"), message("a", "2026-01-01T10:00:00Z")], next_cursor: "a" });

    await store.loadInitial(1);

    expect(store.byChannel[1].messages.map((m) => m.id)).toEqual(["a", "b"]);
    expect(store.byChannel[1].nextCursor).toBe("a");
  });

  it("prepends older pages using the cursor", async () => {
    mockFetch({ messages: [message("c", "2026-01-01T10:02:00Z")], next_cursor: "c" });
    await store.loadInitial(1);
    mockFetch({ messages: [message("b", "2026-01-01T10:01:00Z"), message("a", "2026-01-01T10:00:00Z")], next_cursor: null });

    const added = await store.loadOlder(1);

    expect(added).toBe(2);
    expect(fetch.mock.calls[0][0].searchParams.get("before")).toBe("c");
    expect(store.byChannel[1].messages.map((m) => m.id)).toEqual(["a", "b", "c"]);
    expect(store.byChannel[1].nextCursor).toBeNull();
  });

  it("upserts idempotently (HTTP response and WebSocket event for the same message)", async () => {
    mockFetch({ messages: [], next_cursor: null });
    await store.loadInitial(1);
    const m = message("x", "2026-01-01T10:00:00Z");

    store.upsert(m);
    store.upsert({ ...m });

    expect(store.byChannel[1].messages).toHaveLength(1);
  });

  it("removes deleted messages unless they have replies", async () => {
    mockFetch({ messages: [message("b", "2026-01-01T10:01:00Z", { reply_count: 2 }), message("a", "2026-01-01T10:00:00Z")], next_cursor: null });
    await store.loadInitial(1);

    store.upsert(message("a", "2026-01-01T10:00:00Z", { deleted_at: "now", body: null }));
    store.upsert(message("b", "2026-01-01T10:01:00Z", { deleted_at: "now", body: null, reply_count: 2 }));

    expect(store.byChannel[1].messages.map((m) => m.id)).toEqual(["b"]);
  });

  it("routes thread replies to the open thread, not the channel list", async () => {
    mockFetch({ messages: [], next_cursor: null });
    await store.loadInitial(1);
    const parent = message("p", "2026-01-01T10:00:00Z");
    mockFetch({ parent, replies: [] });
    await store.openThread(parent);

    store.upsert(message("r", "2026-01-01T10:05:00Z", { parent_message_id: "p" }));

    expect(store.thread.replies.map((m) => m.id)).toEqual(["r"]);
    expect(store.byChannel[1].messages).toHaveLength(0);
  });

  it("tracks typing users and clears them after a timeout", () => {
    vi.useFakeTimers();
    store.setTyping(1, { id: 3, display_name: "Citra" });

    expect(store.typingUsers(1).map((u) => u.id)).toEqual([3]);
    vi.advanceTimersByTime(5000);
    expect(store.typingUsers(1)).toEqual([]);
    vi.useRealTimers();
  });
});
