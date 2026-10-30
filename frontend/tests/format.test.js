import { describe, expect, it } from "vitest";
import { dayLabel, decorateMessages, initials, renderMessageBody, typingText } from "../src/utils/format";

describe("renderMessageBody", () => {
  it("escapes HTML so message bodies cannot inject markup", () => {
    const html = renderMessageBody('<img src=x onerror="alert(1)"> & <b>hi</b>');

    expect(html).not.toContain("<img");
    expect(html).toContain("&lt;img src=x onerror=&quot;alert(1)&quot;&gt; &amp; &lt;b&gt;hi&lt;/b&gt;");
  });

  it("highlights mentions and marks the current user's mention", () => {
    const html = renderMessageBody("hi @budi and @alice", { currentUsername: "alice" });

    expect(html).toContain('<span class="mention">@budi</span>');
    expect(html).toContain('<span class="mention mention--me">@alice</span>');
  });

  it("only highlights known usernames when a list is given", () => {
    const html = renderMessageBody("@budi @ghost", { knownUsernames: new Set(["budi"]) });

    expect(html).toContain('<span class="mention">@budi</span>');
    expect(html).toContain("@ghost");
    expect(html).not.toContain(">@ghost<");
  });

  it("does not treat email addresses as mentions", () => {
    expect(renderMessageBody("mail me at a@budi.com")).not.toContain("mention");
  });

  it("links URLs without swallowing trailing punctuation", () => {
    const html = renderMessageBody("see https://example.com/docs.");

    expect(html).toContain('<a href="https://example.com/docs" target="_blank" rel="noopener noreferrer">');
    expect(html.endsWith("</a>.")).toBe(true);
  });
});

describe("decorateMessages", () => {
  const msg = (id, userId, iso, extra = {}) => ({ id, user: { id: userId }, created_at: iso, ...extra });

  it("groups consecutive messages by the same author within 5 minutes", () => {
    const rows = decorateMessages([
      msg("1", 1, "2026-01-01T10:00:00Z"),
      msg("2", 1, "2026-01-01T10:03:00Z"),
      msg("3", 2, "2026-01-01T10:04:00Z"),
      msg("4", 2, "2026-01-01T10:20:00Z"),
    ]);

    expect(rows.map((r) => r.compact)).toEqual([false, true, false, false]);
  });

  it("adds a day label when the date changes", () => {
    const rows = decorateMessages([msg("1", 1, "2026-01-01T10:00:00"), msg("2", 1, "2026-01-02T10:00:00")]);

    expect(rows[0].dayLabel).toBeTruthy();
    expect(rows[1].dayLabel).toBeTruthy();
    expect(rows[1].compact).toBe(false);
  });
});

describe("small helpers", () => {
  it("builds initials", () => {
    expect(initials("Budi Santoso Putra")).toBe("BS");
  });

  it("labels today and yesterday", () => {
    const now = new Date(2026, 4, 10, 12);
    expect(dayLabel(new Date(2026, 4, 10, 8).toISOString(), now)).toBe("Today");
    expect(dayLabel(new Date(2026, 4, 9, 23).toISOString(), now)).toBe("Yesterday");
  });

  it("describes who is typing", () => {
    expect(typingText([])).toBe("");
    expect(typingText([{ display_name: "Budi" }])).toBe("Budi is typing…");
    expect(typingText([{ display_name: "A" }, { display_name: "B" }, { display_name: "C" }])).toBe(
      "Several people are typing…",
    );
  });
});
