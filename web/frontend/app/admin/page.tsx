"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Navbar from "@/components/Navbar";
import { apiFetch } from "@/lib/api";
import { getToken, getCurrentUser } from "@/lib/auth";

export default function AdminPage() {
  const router = useRouter();
  const [users, setUsers] = useState<any[]>([]);
  const [flag, setFlag] = useState("");
  const [error, setError] = useState("");
  const [cmd, setCmd] = useState("");
  const [cmdResult, setCmdResult] = useState<any>(null);

  const [currentPage, setCurrentPage] = useState(1);
  const usersPerPage = 10;

  const [showAddModal, setShowAddModal] = useState(false);
  const [newUser, setNewUser] = useState({
    username: "",
    password: "",
    email: "",
    full_name: "",
    is_admin: false,
  });

  async function loadUsers() {
    apiFetch("/admin/users")
      .then(data => {
        setUsers(data.users || []);
        setFlag(data.flag || "");
      })
      .catch(err => setError(err.message));
  }

  useEffect(() => {
    if (!getToken()) { router.push("/login"); return; }
    const current = getCurrentUser();
    if (!current?.is_admin) { router.push("/dashboard"); return; }
    loadUsers();
  }, []);

  async function handleDelete(user_id: number, username: string) {
    if (!confirm(`Are you sure you want to delete user "${username}"?`)) return;
    try {
      await apiFetch(`/admin/users/${user_id}`, { method: "DELETE" });
      await loadUsers();
    } catch (err: any) {
      setError(err.message);
    }
  }

  async function runDiagnostic() {
    const data = await apiFetch("/admin/diagnostic", {
      method: "POST",
      body: JSON.stringify({ command: cmd }),
    });
    setCmdResult(data);
  }

  async function handleAddUser(e: any) {
    e.preventDefault();
    try {
      await apiFetch("/admin/user/add_user", {
        method: "POST",
        body: JSON.stringify(newUser),
      });
      setShowAddModal(false);
      setNewUser({ username: "", password: "", email: "", full_name: "", is_admin: false });
      await loadUsers();
    } catch (err: any) {
      setError(err.message);
    }
  }

  const totalPages = Math.ceil(users.length / usersPerPage);
  const displayedUsers = [...users]
    .sort((a, b) => a.id - b.id)
    .slice((currentPage - 1) * usersPerPage, currentPage * usersPerPage);

  return (
    <div className="min-h-screen bg-gray-50">
      <Navbar />
      <main className="max-w-5xl mx-auto px-6 py-10">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-800">Admin Panel</h1>
          <p className="text-gray-500 text-sm">Manage users and accounts.</p>
        </div>

        {flag && (
          <div className="bg-yellow-50 border border-yellow-300 rounded-xl p-4 mb-6">
            <p className="text-xs text-yellow-600 uppercase font-semibold tracking-wide mb-1">🚩 System Flag</p>
            <p className="font-mono text-yellow-800 font-bold">{flag}</p>
          </div>
        )}

        {error && (
          <div className="bg-red-50 border border-red-200 text-red-600 rounded-lg p-3 mb-4 text-sm">{error}</div>
        )}

        {/* Users Table */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
          <div className="flex justify-between items-center mb-4">
            <h2 className="font-semibold text-gray-800">All Users</h2>
            <button
              onClick={() => setShowAddModal(true)}
              className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition"
            >
              + Add User
            </button>
          </div>
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 text-gray-500 text-left">
                <th className="pb-3 font-medium">ID</th>
                <th className="pb-3 font-medium">Username</th>
                <th className="pb-3 font-medium">Full Name</th>
                <th className="pb-3 font-medium">Email</th>
                <th className="pb-3 font-medium">Admin</th>
                <th className="pb-3 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {displayedUsers.map(u => (
                <tr key={u.id} className="border-b border-gray-50 hover:bg-gray-50">
                  <td className="py-3 text-gray-500">{u.id}</td>
                  <td className="py-3 font-medium text-gray-800">{u.username}</td>
                  <td className="py-3 text-gray-600">{u.full_name}</td>
                  <td className="py-3 text-gray-500">{u.email}</td>
                  <td className="py-3">
                    {u.is_admin
                      ? <span className="bg-yellow-100 text-yellow-700 px-2 py-0.5 rounded-full text-xs font-medium">Admin</span>
                      : "—"}
                  </td>
                  <td className="py-3">
                    <div className="flex gap-2">
                      <button
                        onClick={() => router.push(`/admin/users/${u.id}`)}
                        className="text-xs bg-blue-50 text-blue-700 px-3 py-1 rounded-lg hover:bg-blue-100 transition font-medium"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDelete(u.id, u.username)}
                        className="text-xs bg-red-50 text-red-600 px-3 py-1 rounded-lg hover:bg-red-100 transition font-medium"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Pagination Controls */}
          {totalPages > 1 && (
            <div className="flex justify-between items-center mt-6">
              <button
                disabled={currentPage === 1}
                onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                className="px-4 py-2 bg-gray-50 text-gray-600 rounded-lg hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition text-sm font-medium"
              >
                Previous
              </button>
              <span className="text-sm font-medium text-gray-500">
                Page {currentPage} of {totalPages}
              </span>
              <button
                disabled={currentPage === totalPages}
                onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
                className="px-4 py-2 bg-gray-50 text-gray-600 rounded-lg hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition text-sm font-medium"
              >
                Next
              </button>
            </div>
          )}
        </div>

        {/* Diagnostics */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
          <h2 className="font-semibold text-gray-800 mb-1">System Diagnostics</h2>
          <p className="text-gray-400 text-xs mb-4">Run server diagnostics for troubleshooting purposes.</p>
          <div className="flex gap-3 mb-4">
            <input
              type="text"
              placeholder="e.g. ping 8.8.8.8 -c 1"
              className="flex-1 border border-gray-300 rounded-lg px-4 py-2.5 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-blue-500"
              value={cmd}
              onChange={e => setCmd(e.target.value)}
              onKeyDown={e => e.key === "Enter" && runDiagnostic()}
            />
            <button
              onClick={runDiagnostic}
              className="bg-blue-700 text-white px-6 py-2.5 rounded-lg text-sm font-semibold hover:bg-blue-800 transition"
            >
              Run
            </button>
          </div>
          {cmdResult && (
            <div className="bg-gray-950 rounded-lg p-4 font-mono text-xs">
              {cmdResult.stdout && <pre className="text-green-400 whitespace-pre-wrap">{cmdResult.stdout}</pre>}
              {cmdResult.stderr && <pre className="text-red-400 whitespace-pre-wrap">{cmdResult.stderr}</pre>}
              {cmdResult.error && <pre className="text-yellow-400 whitespace-pre-wrap">{cmdResult.error}</pre>}
            </div>
          )}
        </div>
      </main>

      {/* Add User Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-gray-900/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white p-6 rounded-2xl shadow-xl w-full max-w-md">
            <h2 className="text-xl font-bold text-gray-800 mb-6">Add New User</h2>
            <form onSubmit={handleAddUser}>
              <div className="space-y-4 mb-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Username</label>
                  <input
                    type="text"
                    required
                    className="w-full border border-gray-300 px-4 py-2.5 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                    value={newUser.username}
                    onChange={e => setNewUser({ ...newUser, username: e.target.value })}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
                  <input
                    type="password"
                    required
                    className="w-full border border-gray-300 px-4 py-2.5 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                    value={newUser.password}
                    onChange={e => setNewUser({ ...newUser, password: e.target.value })}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                  <input
                    type="email"
                    required
                    className="w-full border border-gray-300 px-4 py-2.5 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                    value={newUser.email}
                    onChange={e => setNewUser({ ...newUser, email: e.target.value })}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                  <input
                    type="text"
                    required
                    className="w-full border border-gray-300 px-4 py-2.5 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                    value={newUser.full_name}
                    onChange={e => setNewUser({ ...newUser, full_name: e.target.value })}
                  />
                </div>
                <div className="flex items-center gap-2 pt-2">
                  <input
                    type="checkbox"
                    id="is_admin"
                    className="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                    checked={newUser.is_admin}
                    onChange={e => setNewUser({ ...newUser, is_admin: e.target.checked })}
                  />
                  <label htmlFor="is_admin" className="text-sm font-medium text-gray-700 select-none">
                    Grant Administrator Privileges
                  </label>
                </div>
              </div>
              <div className="flex justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-5 py-2.5 text-sm font-semibold text-gray-700 hover:bg-gray-100 rounded-lg transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2.5 text-sm font-semibold bg-blue-600 text-white rounded-lg hover:bg-blue-700 shadow-sm transition"
                >
                  Create User
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}