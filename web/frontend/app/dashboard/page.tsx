"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import AccountCard from "@/components/AccountCard";
import TransactionTable from "@/components/TransactionTable";
import { apiFetch } from "@/lib/api";
import { getToken } from "@/lib/auth";

export default function DashboardPage() {
  const router = useRouter();
  const [accounts, setAccounts] = useState<any[]>([]);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!getToken()) { router.push("/login"); return; }
    async function load() {
      try {
        const accs = await apiFetch("/accounts/me/summary");
        setAccounts(accs);
        if (accs.length > 0) {
          const txs = await apiFetch(`/transactions/history/${accs[0].id}`);
          setTransactions(txs);
        }
      } catch {
        router.push("/login");
      } finally {
        setLoading(false);
      }
    }
    load();
  }, []);

  const totalBalance = accounts.reduce((sum, a) => sum + a.balance, 0);

  return (
    <div className="min-h-screen bg-brand-bg">
      <Navbar />
      <main className="max-w-5xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-brand-primary">Dashboard</h1>
          <p className="text-brand-muted text-sm">Welcome back. Here's your financial overview.</p>
        </div>

        {loading ? (
          <div className="text-center text-brand-muted py-20 font-medium">Loading...</div>
        ) : (
          <>
            {/* Summary bar */}
            <div className="grid grid-cols-3 gap-4 mb-8">
              <div className="bg-white rounded-xl p-5 shadow-sm border border-brand-muted/10">
                <p className="text-brand-muted text-xs uppercase tracking-wide mb-1">Total Balance</p>
                <p className="text-2xl font-bold text-brand-primary">${totalBalance.toLocaleString("en-US", { minimumFractionDigits: 2 })}</p>
              </div>
              <div className="bg-white rounded-xl p-5 shadow-sm border border-brand-muted/10">
                <p className="text-brand-muted text-xs uppercase tracking-wide mb-1">Accounts</p>
                <p className="text-2xl font-bold text-brand-primary">{accounts.length}</p>
              </div>
              <div className="bg-white rounded-xl p-5 shadow-sm border border-brand-muted/10">
                <p className="text-brand-muted text-xs uppercase tracking-wide mb-1">Recent Transactions</p>
                <p className="text-2xl font-bold text-brand-primary">{transactions.length}</p>
              </div>
            </div>

            {/* Account cards */}
            <div className="flex gap-4 mb-8 flex-wrap">
              {accounts.map(a => (
                <AccountCard key={a.id} id={a.id} accountNumber={a.account_number} balance={a.balance} />
              ))}
            </div>

            {/* Recent transactions */}
            <div className="bg-white rounded-xl shadow-sm border border-brand-muted/10 p-6">
              <h2 className="font-semibold text-brand-primary mb-4">Recent Transactions</h2>
              <TransactionTable transactions={transactions.slice(0, 10)} currentAccountId={accounts[0]?.id} />
            </div>
          </>
        )}
      </main>
    </div>
  );
}