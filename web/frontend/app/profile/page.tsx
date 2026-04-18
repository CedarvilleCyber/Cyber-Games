"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { apiFetch } from "@/lib/api";
import { getToken } from "@/lib/auth";

export default function ProfilePage() {
  const router = useRouter();
  const [profile, setProfile] = useState<any>(null);
  const [form, setForm] = useState({ email: "", full_name: "", bio: "" });
  const [status, setStatus] = useState<{ type: "success" | "error"; msg: string } | null>(null);

  useEffect(() => {
    if (!getToken()) { router.push("/login"); return; }
    apiFetch("/profile/me").then(p => {
      setProfile(p);
      setForm({ email: p.email || "", full_name: p.full_name || "", bio: p.bio || "" });
    });
  }, []);

  async function handleSave() {
    try {
      await apiFetch("/profile/me", { method: "PUT", body: JSON.stringify(form) });
      setStatus({ type: "success", msg: "Profile updated successfully." });
    } catch (err: any) {
      setStatus({ type: "error", msg: err.message });
    }
  }

  if (!profile) return <div className="min-h-screen bg-brand-bg"><Navbar /><div className="text-center text-brand-muted py-20 font-medium">Loading...</div></div>;

  return (
    <div className="min-h-screen bg-brand-bg">
      <Navbar />
      <main className="max-w-2xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-brand-primary">My Profile</h1>
          <p className="text-brand-muted text-sm">Manage your personal information.</p>
        </div>

        <div className="bg-white rounded-xl shadow-sm border border-brand-muted/10 p-6">
          <div className="flex items-center gap-4 mb-6 pb-6 border-b border-brand-muted/10">
            <div className="w-16 h-16 bg-brand-primary rounded-full flex items-center justify-center text-white text-2xl font-bold shadow-md">
              {profile.full_name?.[0] || profile.username?.[0]}
            </div>
            <div>
              <p className="font-semibold text-brand-primary">{profile.full_name}</p>
              <p className="text-brand-muted text-sm">@{profile.username}</p>
              {profile.is_admin && <span className="text-[10px] bg-brand-accent/20 text-brand-primary px-2 py-0.5 rounded-full font-bold uppercase tracking-wider">Admin</span>}
            </div>
          </div>

          {status && (
            <div className={`rounded-lg p-3 mb-4 text-sm ${status.type === "success" ? "bg-brand-success/10 text-brand-success border border-brand-success/20" : "bg-brand-error/10 text-brand-error border border-brand-error/20"}`}>
              {status.msg}
            </div>
          )}

          <div className="flex flex-col gap-4">
            {[
              { key: "full_name", label: "Full Name", type: "text" },
              { key: "email", label: "Email Address", type: "email" },
            ].map(({ key, label, type }) => (
              <div key={key}>
                <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
                <input
                  type={type}
                  className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-accent"
                  value={(form as any)[key]}
                  onChange={e => setForm({ ...form, [key]: e.target.value })}
                />
              </div>
            ))}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Bio</label>
              <textarea
                rows={3}
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                value={form.bio}
                onChange={e => setForm({ ...form, bio: e.target.value })}
              />
            </div>
            <button
              onClick={handleSave}
              className="bg-brand-primary text-white rounded-lg py-2.5 font-semibold hover:bg-brand-primary/90 transition shadow-sm"
            >
              Save Changes
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}