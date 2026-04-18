"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { apiFetch } from "@/lib/api";
import { getToken } from "@/lib/auth";

export default function TransferPage() {
  const router = useRouter();
  const [accounts, setAccounts] = useState<any[]>([]);
  const [form, setForm] = useState({ from_account_id: "", to_account_id: "", amount: "", note: "" });
  const [status, setStatus] = useState<{ type: "success" | "error"; msg: string } | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!getToken()) { router.push("/login"); return; }
    apiFetch("/accounts/me/summary").then(setAccounts);
  }, []);

  async function handleTransfer() {
    setLoading(true);
    setStatus(null);
    try {
      await apiFetch("/transfer/", {
        method: "POST",
        body: JSON.stringify({
          from_account_id: parseInt(form.from_account_id),
          to_account_id: parseInt(form.to_account_id),
          amount: parseFloat(form.amount),
          note: form.note,
        }),
      });
      setStatus({ type: "success", msg: "Transfer completed successfully." });
    } catch (err: any) {
      setStatus({ type: "error", msg: err.message });
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-brand-bg">
      <Navbar />
      <main className="max-w-2xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-brand-primary">Transfer Funds</h1>
          <p className="text-brand-muted text-sm">Send money between accounts instantly.</p>
        </div>

        <div className="bg-white rounded-xl shadow-sm border border-brand-muted/10 p-6">
          {status && (
            <div className={`rounded-lg p-3 mb-4 text-sm ${status.type === "success" ? "bg-brand-success/10 text-brand-success border border-brand-success/20" : "bg-brand-error/10 text-brand-error border border-brand-error/20"}`}>
              {status.msg}
            </div>
          )}

          <div className="flex flex-col gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">From Account</label>
              <select
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-accent"
                value={form.from_account_id}
                onChange={e => setForm({ ...form, from_account_id: e.target.value })}
              >
                <option value="">Select account</option>
                {accounts.map(a => (
                  <option key={a.id} value={a.id}>{a.account_number} — ${a.balance.toFixed(2)}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">To Account ID</label>
              <input
                type="number"
                placeholder="Enter destination account ID"
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-accent"
                value={form.to_account_id}
                onChange={e => setForm({ ...form, to_account_id: e.target.value })}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Amount ($)</label>
              <input
                type="number"
                placeholder="0.00"
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-accent"
                value={form.amount}
                onChange={e => setForm({ ...form, amount: e.target.value })}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Note (optional)</label>
              <input
                type="text"
                placeholder="e.g. Rent payment"
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                value={form.note}
                onChange={e => setForm({ ...form, note: e.target.value })}
              />
            </div>

            <button
              onClick={handleTransfer}
              disabled={loading}
              className="bg-brand-primary text-white rounded-lg py-2.5 font-semibold hover:bg-brand-primary/90 transition disabled:opacity-50 mt-2 shadow-sm"
            >
              {loading ? "Processing..." : "Send Transfer"}
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}