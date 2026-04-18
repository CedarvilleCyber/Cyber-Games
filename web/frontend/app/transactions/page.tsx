"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import TransactionTable from "@/components/TransactionTable";
import { apiFetch } from "@/lib/api";
import { getToken } from "@/lib/auth";

export default function TransactionsPage() {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<any[]>([]);
  const [searched, setSearched] = useState(false);

  useEffect(() => {
    if (!getToken()) router.push("/login");
  }, []);

  async function handleSearch() {
    const data = await apiFetch(`/transactions/search?q=${query}`);
    setResults(data);
    setSearched(true);
  }

  return (
    <div className="min-h-screen bg-brand-bg">
      <Navbar />
      <main className="max-w-5xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-brand-primary">Transaction Search</h1>
          <p className="text-brand-muted text-sm">Search through your transaction history by note or description.</p>
        </div>

        <div className="bg-white rounded-xl shadow-sm border border-brand-muted/10 p-6 mb-6">
          <div className="flex gap-3">
            <input
              type="text"
              placeholder="Search by note (e.g. 'Rent', 'Lunch')..."
              className="flex-1 border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-accent"
              value={query}
              onChange={e => setQuery(e.target.value)}
              onKeyDown={e => e.key === "Enter" && handleSearch()}
            />
            <button
              onClick={handleSearch}
              className="bg-brand-primary text-white px-6 py-2.5 rounded-lg text-sm font-semibold hover:bg-brand-primary/90 transition shadow-sm"
            >
              Search
            </button>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm border border-brand-muted/10 p-6">
          {searched
            ? <TransactionTable transactions={results} />
            : <p className="text-brand-muted text-sm text-center py-8">Enter a search term above to find transactions.</p>
          }
        </div>
      </main>
    </div>
  );
}