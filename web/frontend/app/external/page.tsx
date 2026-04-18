"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { apiFetch } from "@/lib/api";
import { getToken } from "@/lib/auth";

export default function ExternalPage() {
  const router = useRouter();
  const [url, setUrl] = useState("");
  const [result, setResult] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!getToken()) router.push("/login");
  }, []);

  async function handleLink() {
    setLoading(true);
    setError("");
    setResult("");
    try {
      const data = await apiFetch("/external/link", {
        method: "POST",
        body: JSON.stringify({ bank_url: url }),
      });
      setResult(data.content);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <main className="max-w-2xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-800">Link External Account</h1>
          <p className="text-gray-500 text-sm">Connect accounts from other banks by providing their API endpoint.</p>
        </div>

        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
          {error && <div className="bg-red-50 border border-red-200 text-red-600 rounded-lg p-3 mb-4 text-sm">{error}</div>}

          <div className="flex flex-col gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">External Bank API URL</label>
              <input
                type="text"
                placeholder="https://other-bank.com/api/account"
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                value={url}
                onChange={e => setUrl(e.target.value)}
              />
            </div>
            <button
              onClick={handleLink}
              disabled={loading}
              className="bg-blue-700 text-white rounded-lg py-2.5 font-semibold hover:bg-blue-800 transition disabled:opacity-50"
            >
              {loading ? "Connecting..." : "Link Account"}
            </button>
          </div>

          {result && (
            <div className="mt-4">
              <p className="text-xs text-gray-500 uppercase font-medium mb-1">Response</p>
              <pre className="bg-gray-50 border border-gray-200 rounded-lg p-3 text-xs text-gray-700 overflow-x-auto whitespace-pre-wrap">{result}</pre>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}