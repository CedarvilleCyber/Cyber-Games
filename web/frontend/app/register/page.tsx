"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
import { registerUser } from "@/lib/auth";

export default function RegisterPage() {
  const router = useRouter();
  const [form, setForm] = useState({ username: "", password: "", email: "", full_name: "" });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      await registerUser(form);
      router.push("/login");
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-brand-bg flex items-center justify-center px-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-8">
        <div className="flex justify-center mb-8">
          <Image
            src="/sentinel_national_logo.png"
            alt="Sentinel National Bank"
            width={200}
            height={60}
            className="h-24 w-auto"
          />
        </div>
        <h2 className="text-2xl font-bold text-gray-800 mb-1">Open an account</h2>
        <p className="text-gray-500 text-sm mb-6">Get started with $1,000 welcome bonus</p>

        {error && <div className="bg-brand-error/10 border border-brand-error/20 text-brand-error rounded-lg p-3 mb-4 text-sm">{error}</div>}

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          {[
            { key: "full_name", label: "Full Name", type: "text" },
            { key: "email", label: "Email Address", type: "email" },
            { key: "username", label: "Username", type: "text" },
            { key: "password", label: "Password", type: "password" },
          ].map(({ key, label, type }) => (
            <div key={key}>
              <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
              <input
                type={type}
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-accent"
                value={(form as any)[key]}
                onChange={e => setForm({ ...form, [key]: e.target.value })}
                required
              />
            </div>
          ))}
          <button
            type="submit"
            disabled={loading}
            className="bg-brand-primary text-white rounded-lg py-2.5 font-semibold hover:bg-brand-primary/90 transition disabled:opacity-50 shadow-md"
          >
            {loading ? "Creating account..." : "Create Account"}
          </button>
        </form>
        <p className="text-center text-sm text-gray-500 mt-4">
          Already have an account?{" "}
          <Link href="/login" className="text-brand-primary font-semibold hover:underline">Sign in</Link>
        </p>
      </div>
    </div>
  );
}