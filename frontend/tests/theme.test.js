import { afterEach, describe, expect, it } from "vitest";
import { applyTheme, setTheme, storedTheme } from "../src/utils/theme";

afterEach(() => {
  localStorage.clear();
  delete document.documentElement.dataset.theme;
});

describe("theme", () => {
  it("defaults to following the device", () => {
    expect(storedTheme()).toBe("system");
  });

  it("ignores unknown stored values", () => {
    localStorage.setItem("obrolin.theme", "neon");
    expect(storedTheme()).toBe("system");
  });

  it("pins light or dark on the root element and remembers it", () => {
    setTheme("dark");
    expect(document.documentElement.dataset.theme).toBe("dark");
    expect(storedTheme()).toBe("dark");
  });

  it("removes the attribute for system so the media query decides", () => {
    applyTheme("light");
    applyTheme("system");
    expect(document.documentElement.dataset.theme).toBeUndefined();
  });
});
