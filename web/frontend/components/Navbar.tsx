"use client";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { logout, getCurrentUser } from "@/lib/auth";

export default function Navbar() {
  const pathname = usePathname();
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    setUser(getCurrentUser());
  }, []);

  const links = [
    { href: "/dashboard", label: "Dashboard" },
    { href: "/transactions", label: "Transactions" },
    { href: "/transfer", label: "Transfer" },
    { href: "/profile", label: "Profile" },
    { href: "/external", label: "Link Account" },
    { href: "/loans", label: "Loans"},
    ...(user?.is_admin ? [{ href: "/admin", label: "Admin" }] : []),
  ];

  return (
    <nav className="bg-brand-primary text-white px-8 py-4 flex items-center justify-between shadow-lg">
      <div className="flex items-center gap-6">
        <Link href="/dashboard" className="flex items-center gap-3 mr-4 hover:opacity-90 transition-opacity">
          <div className="bg-white p-1 rounded-lg shadow-sm flex items-center justify-center">
            <Image
              src="/sentinel_national_logo.png"
              alt="Sentinel Logo"
              width={32}
              height={32}
              className="h-6 w-auto"
            />
          </div>
          <span className="font-bold text-lg tracking-tight">Sentinel National Bank</span>
        </Link>
        {links.map(l => (
          <Link
            key={l.href}
            href={l.href}
            className={`text-sm font-medium transition hover:text-brand-accent ${pathname === l.href ? "text-brand-accent" : "text-white/80"}`}
          >
            {l.label}
          </Link>
        ))}
      </div>
      <div className="flex items-center gap-4">
        <span className="text-white/60 text-sm">Hello, {user?.username}</span>
        <button onClick={logout} className="text-sm border border-white/20 hover:bg-white/10 px-3 py-1.5 rounded-lg transition">
          Sign Out
        </button>
      </div>
    </nav>
  );
}