import { afterEach, describe, expect, it, vi } from "vitest";
import { ApiError, api, configureApi } from "../src/api/client";

afterEach(() => configureApi({ getToken: () => null, onUnauthorized: () => {} }));

describe("api client", () => {
  it("sends the bearer token and JSON body", async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({ ok: true, status: 201, json: async () => ({ id: 1 }) });
    configureApi({ getToken: () => "tok" });

    await api("/workspaces", { method: "POST", body: { workspace: { name: "X" } } });

    const [url, options] = fetch.mock.calls[0];
    expect(url.pathname).toBe("/api/v1/workspaces");
    expect(options.headers.Authorization).toBe("Bearer tok");
    expect(JSON.parse(options.body)).toEqual({ workspace: { name: "X" } });
  });

  it("turns Rails validation errors into a readable message", async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 422,
      json: async () => ({ errors: { email: ["Email has already been taken"] } }),
    });

    const error = await api("/auth/register", { method: "POST", body: {} }).catch((e) => e);

    expect(error).toBeInstanceOf(ApiError);
    expect(error.message).toBe("Email has already been taken");
    expect(error.fieldErrors.email).toHaveLength(1);
  });

  it("calls the unauthorized hook on 401 when a token was sent", async () => {
    const onUnauthorized = vi.fn();
    configureApi({ getToken: () => "expired", onUnauthorized });
    globalThis.fetch = vi.fn().mockResolvedValue({ ok: false, status: 401, json: async () => ({ error: "Token has been revoked" }) });

    await expect(api("/me")).rejects.toThrow("Token has been revoked");
    expect(onUnauthorized).toHaveBeenCalled();
  });

  it("reports network failures clearly", async () => {
    globalThis.fetch = vi.fn().mockRejectedValue(new TypeError("Failed to fetch"));

    await expect(api("/me")).rejects.toThrow("Cannot reach the server");
  });
});
