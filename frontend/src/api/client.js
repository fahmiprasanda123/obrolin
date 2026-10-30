const BASE = "/api/v1";

let getToken = () => null;
let onUnauthorized = () => {};

export function configureApi(options) {
  getToken = options.getToken ?? getToken;
  onUnauthorized = options.onUnauthorized ?? onUnauthorized;
}

export class ApiError extends Error {
  constructor(status, data) {
    super(errorMessage(status, data));
    this.status = status;
    this.data = data;
  }

  // Field errors from Rails: { email: ["Email has already been taken"] }
  get fieldErrors() {
    return this.data?.errors ?? {};
  }
}

export function errorMessage(status, data) {
  if (data?.error) return data.error;
  const first = data?.errors && Object.values(data.errors).flat()[0];
  if (first) return first;
  if (status === 0) return "Cannot reach the server. Is the API running?";
  return `Request failed (${status})`;
}

export async function api(path, { method = "GET", body, params } = {}) {
  const url = new URL(BASE + path, window.location.origin);
  for (const [key, value] of Object.entries(params ?? {})) {
    if (value !== undefined && value !== null && value !== "") url.searchParams.set(key, value);
  }

  const headers = { Accept: "application/json" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  let response;
  try {
    response = await fetch(url, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new ApiError(0, null);
  }

  const data = response.status === 204 ? null : await response.json().catch(() => null);
  if (!response.ok) {
    if (response.status === 401 && token) onUnauthorized();
    throw new ApiError(response.status, data);
  }
  return data;
}
