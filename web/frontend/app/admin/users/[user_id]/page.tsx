"use client";
import { useState, useEffect } from "react";
import { useRouter, useParams } from "next/navigation";
import Navbar from "@/components/Navbar";
import { apiFetch } from "@/lib/api";
import { getToken, getCurrentUser } from "@/lib/auth";

export default function EditUserPage() {
  const router = useRouter();
  const params = useParams();
  const user_id = params.user_id;

  const [form, setForm] = useState({ username: "", is_admin: false });
  const [original, setOriginal] = useState<any>(null);
  const [status, setStatus] = useState<{ type: "success" | "error"; msg: string } | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!getToken()) { router.push("/login"); return; }
    const current = getCurrentUser();
    if (!current?.is_admin) { router.push("/dashboard"); return; }

    apiFetch("/admin/users")
      .then(data => {
        const user = data.users.find((u: any) => u.id === parseInt(user_id as string));
        if (!user) { router.push("/admin"); return; }
        setOriginal(user);
        setForm({ username: user.username, is_admin: user.is_admin });
      })
      .finally(() => setLoading(false));
  }, []);

  async function handleSave() {
    setStatus(null);
    try {
      await apiFetch(`/admin/users/${user_id}`, {
        method: "PUT",
        body: JSON.stringify(form),
      });
      setStatus({ type: "success", msg: "User updated successfully." });
      setTimeout(() => router.push("/admin"), 1000);
    } catch (err: any) {
      setStatus({ type: "error", msg: err.message });
    }
  }

  if (loading) return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <div className="text-center text-gray-400 py-20">Loading...</div>
    </div>
  );

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <main className="max-w-lg mx-auto px-6 py-10">
        <div className="mb-8 flex items-center gap-3">
          <button
            onClick={() => router.push("/admin")}
            className="text-gray-400 hover:text-gray-600 transition text-sm"
          >
            ← Back to Admin
          </button>
        </div>

        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
          <h1 className="text-xl font-bold text-gray-800 mb-1">Edit User</h1>
          <p className="text-gray-400 text-sm mb-6">Editing user ID #{user_id}</p>

          {status && (
            <div className={`rounded-lg p-3 mb-4 text-sm ${status.type === "success" ? "bg-green-50 text-green-700 border border-green-200" : "bg-red-50 text-red-600 border border-red-200"}`}>
              {status.msg}
            </div>
          )}

          <div className="flex flex-col gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Username</label>
              <input
                type="text"
                className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                value={form.username}
                onChange={e => setForm({ ...form, username: e.target.value })}
              />
            </div>

            <div className="flex items-center gap-3">
              <input
                type="checkbox"
                id="is_admin"
                checked={form.is_admin}
                onChange={e => setForm({ ...form, is_admin: e.target.checked })}
                className="w-4 h-4 accent-blue-700"
              />
              <label htmlFor="is_admin" className="text-sm font-medium text-gray-700">Admin privileges</label>
            </div>

            <div className="flex gap-3 mt-2">
              <button
                onClick={handleSave}
                className="flex-1 bg-blue-700 text-white rounded-lg py-2.5 font-semibold hover:bg-blue-800 transition"
              >
                Save Changes
              </button>
              <button
                onClick={() => router.push("/admin")}
                className="flex-1 border border-gray-300 text-gray-600 rounded-lg py-2.5 font-semibold hover:bg-gray-50 transition"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}