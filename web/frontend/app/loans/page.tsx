"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { apiFetch } from "@/lib/api";
import { getToken } from "@/lib/auth";

interface LoanResult {
  principal: string;
  annual_rate: string;
  years: string;
  monthly_payment: number;
  total_payment: number;
  total_interest: number;
}

export default function LoansPage() {
  const router = useRouter();
  const [form, setForm] = useState({
    principal: "200000",
    annual_rate: "5.5",
    years: "30",
  });
  const [result, setResult] = useState<LoanResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  // Preferences restore state
  const [savedPrefs, setSavedPrefs] = useState("");
  const [restoreData, setRestoreData] = useState("");
  const [prefsResult, setPrefsResult] = useState<any>(null);
  const [prefsError, setPrefsError] = useState("");

  useEffect(() => {
    if (!getToken()) router.push("/login");
  }, []);

  async function handleCalculate() {
    setLoading(true);
    setError("");
    setResult(null);
    try {
      const data = await apiFetch("/loans/calculate", {
        method: "POST",
        body: JSON.stringify({
          principal: form.principal,
          annual_rate: form.annual_rate,
          years: form.years,
        }),
      });
      setResult(data);
    } catch (err: any) {
      setError(err.message || JSON.stringify(err));
    } finally {
      setLoading(false);
    }
  }

  async function handleSavePrefs() {
    try {
      const data = await apiFetch("/loans/preferences/save");
      setSavedPrefs(data.data);
      setRestoreData(data.data);
    } catch (err: any) {
      setPrefsError(err.message);
    }
  }

  async function handleRestorePrefs() {
    setPrefsError("");
    setPrefsResult(null);
    try {
      const data = await apiFetch("/loans/preferences/restore", {
        method: "POST",
        body: JSON.stringify({ data: restoreData }),
      });
      if (data.preferences) {
        setPrefsResult(data.preferences);
        setForm({
          principal: String(data.preferences.default_principal || form.principal),
          annual_rate: String(data.preferences.default_rate || form.annual_rate),
          years: String(data.preferences.default_years || form.years),
        });
      }
    } catch (err: any) {
      setPrefsError(err.message);
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <main className="max-w-4xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-800">Loan Calculator</h1>
          <p className="text-gray-500 text-sm">Estimate your monthly payments and total interest.</p>
        </div>

        <div className="grid grid-cols-2 gap-6">
          {/* Calculator */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
            <h2 className="font-semibold text-gray-800 mb-4">Calculate Payment</h2>

            {error && (
              <div className="bg-red-50 border border-red-200 text-red-600 rounded-lg p-3 mb-4 text-sm">{error}</div>
            )}

            <div className="flex flex-col gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Loan Amount ($)
                </label>
                <input
                  type="text"      // changed from number to text to allow expressions
                  className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  value={form.principal}
                  onChange={e => setForm({ ...form, principal: e.target.value })}
                />
                <p className="text-xs text-gray-400 mt-1">Tip: supports expressions e.g. 200000*1.1</p>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Annual Interest Rate (%)</label>
                <input
                  type="text"
                  step="0.1"
                  className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  value={form.annual_rate}
                  onChange={e => setForm({ ...form, annual_rate: e.target.value })}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Loan Term (years)</label>
                <input
                  type="text"
                  className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  value={form.years}
                  onChange={e => setForm({ ...form, years: e.target.value })}
                />
              </div>
              <button
                onClick={handleCalculate}
                disabled={loading}
                className="bg-blue-700 text-white rounded-lg py-2.5 font-semibold hover:bg-blue-800 transition disabled:opacity-50"
              >
                {loading ? "Calculating..." : "Calculate"}
              </button>
            </div>

            {/* Results */}
            {result && (
              <div className="mt-6 pt-6 border-t border-gray-100">
                <h3 className="font-semibold text-gray-700 mb-3 text-sm uppercase tracking-wide">Results</h3>
                <div className="flex flex-col gap-2">
                  {[
                    { label: "Monthly Payment", value: `$${result.monthly_payment.toLocaleString()}`, highlight: true },
                    { label: "Total Payment", value: `$${result.total_payment.toLocaleString()}` },
                    { label: "Total Interest", value: `$${result.total_interest.toLocaleString()}` },
                    { label: "Principal", value: `$${result.principal.toLocaleString()}` },
                    { label: "Rate", value: `${result.annual_rate}%` },
                    { label: "Term", value: `${result.years} years` },
                  ].map(({ label, value, highlight }) => (
                    <div key={label} className={`flex justify-between items-center py-2 ${highlight ? "bg-blue-50 rounded-lg px-3" : ""}`}>
                      <span className="text-sm text-gray-500">{label}</span>
                      <span className={`font-semibold ${highlight ? "text-blue-700 text-lg" : "text-gray-800"}`}>{value}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* Preferences */}
          <div className="flex flex-col gap-4">
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
              <h2 className="font-semibold text-gray-800 mb-1">Saved Preferences</h2>
              <p className="text-gray-400 text-xs mb-4">Save and restore your default calculator settings.</p>

              {prefsError && (
                <div className="bg-red-50 border border-red-200 text-red-600 rounded-lg p-3 mb-4 text-sm">{prefsError}</div>
              )}

              <button
                onClick={handleSavePrefs}
                className="w-full border border-blue-200 text-blue-700 rounded-lg py-2 text-sm font-semibold hover:bg-blue-50 transition mb-3"
              >
                Save Current as Default
              </button>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Restore from saved data</label>
                <textarea
                  rows={4}
                  className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-xs font-mono focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Paste your saved preferences data here..."
                  value={restoreData}
                  onChange={e => setRestoreData(e.target.value)}
                />
              </div>

              <button
                onClick={handleRestorePrefs}
                className="w-full bg-blue-700 text-white rounded-lg py-2 text-sm font-semibold hover:bg-blue-800 transition mt-2"
              >
                Restore Preferences
              </button>

              {prefsResult && (
                <div className="mt-3 bg-green-50 border border-green-200 rounded-lg p-3">
                  <p className="text-xs text-green-700 font-medium mb-1">Preferences restored:</p>
                  <pre className="text-xs text-green-800">{JSON.stringify(prefsResult, null, 2)}</pre>
                </div>
              )}
            </div>

            {/* Info box */}
            <div className="bg-blue-50 border border-blue-100 rounded-xl p-4">
              <p className="text-xs font-semibold text-blue-700 mb-1">💡 How preferences work</p>
              <p className="text-xs text-blue-600">
                Click "Save Current as Default" to generate your preferences token.
                Copy it and paste it back anytime to restore your settings across devices.
              </p>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}