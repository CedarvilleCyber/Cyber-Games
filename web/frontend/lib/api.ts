const BASE_URL = process.env.NEXT_PUBLIC_API_URL;

if (!BASE_URL) {
  console.error("NEXT_PUBLIC_API_URL is not set!");
}

export async function apiFetch(path: string, options: RequestInit = {}) {
  const token = localStorage.getItem("token");
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch(`${BASE_URL}${path}`, { ...options, headers });

  // Guard against non-JSON responses (HTML error pages, proxy errors, etc.)
  const contentType = res.headers.get("content-type") || "";
  if (!contentType.includes("application/json")) {
    throw new Error(
      `Unexpected response (HTTP ${res.status}): expected JSON but got ${contentType || "unknown content type"}. Check that NEXT_PUBLIC_API_URL is set correctly.`
    );
  }

  const data = await res.json();

  if (!res.ok) {
    throw new Error(
      typeof data.detail === "string"
        ? data.detail
        : JSON.stringify(data.detail)
    );
  }

  return data;
}