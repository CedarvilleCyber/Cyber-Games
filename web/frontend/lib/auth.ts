import { apiFetch } from "./api";

export function saveToken(token: string) {
  if (typeof window == "undefined") return;
  localStorage.setItem("token", token);
}

export function getToken(): string | null {
  if (typeof window == "undefined") return null;
  return localStorage.getItem("token");
}

export function logout() {
  if (typeof window == "undefined") return;
  localStorage.removeItem("token");
  window.location.href = "/login";
}

export function decodeToken(token: string): any {
  try {
    const base64 = token.split(".")[1];
    return JSON.parse(atob(base64));
  } catch {
    return null;
  }
}

export function getCurrentUser(): any {
  const token = getToken();
  if (!token) return null;
  return decodeToken(token);
}

export async function loginUser(username: string, password: string) {
  const data = await apiFetch("/auth/login", {
    method: "POST",
    body: JSON.stringify({ username, password }),
  });
  saveToken(data.access_token);
  return decodeToken(data.access_token);
}

export async function registerUser(payload: {
  username: string;
  password: string;
  email: string;
  full_name: string;
}) {
  return apiFetch("/auth/register", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}