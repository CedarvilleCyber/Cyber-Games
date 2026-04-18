import Link from "next/link";
import Image from "next/image";

export default function Home() {
  return (
    <main className="min-h-screen bg-brand-primary flex flex-col">
      {/* Nav */}
      <nav className="flex items-center justify-between px-10 py-5">
        <div className="flex items-center gap-3">
          <div className="bg-white p-2 rounded-lg">
            <Image
              src="/sentinel_national_logo.png"
              alt="Sentinel National Bank"
              width={50}
              height={50}
              className="h-10 w-auto"
            />
          </div>
          <span className="text-white font-bold text-xl tracking-tight">Sentinel National Bank</span>
        </div>
        <div className="flex gap-4">
          <Link href="/login" className="bg-white/10 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-white/20 transition backdrop-blur-sm border border-white/10">Sign In</Link>
          <Link href="/register" className="bg-brand-accent text-brand-primary px-4 py-2 rounded-lg text-sm font-semibold hover:bg-brand-accent/90 transition shadow-lg">Open Account</Link>
        </div>
      </nav>

      {/* Hero */}
      <section className="flex-1 flex flex-col items-center justify-center text-center px-6 gap-6 pb-20">
        <div className="bg-white p-5 rounded-2xl shadow-2xl mb-4">
          <Image
            src="/sentinel_national_logo.png"
            alt="Sentinel National Bank"
            width={500}
            height={500}
            className="h-50 w-auto"
            priority
          />
        </div>
        <h1 className="text-5xl font-bold text-white leading-tight max-w-2xl">
          Banking You Can <span className="text-brand-accent">Trust</span>
        </h1>
        <p className="text-white/60 text-lg max-w-xl">
          Sentinel National Bank offers secure, reliable banking services. Manage your accounts, transfer funds, and track your finances — all in one place.
        </p>
        <div className="flex gap-4 mt-2">
          <Link href="/register" className="bg-brand-accent text-brand-primary px-8 py-3 rounded-lg font-bold hover:bg-brand-accent/90 transition text-lg shadow-xl">
            Get Started
          </Link>
          <Link href="/login" className="border border-white/30 text-white px-8 py-3 rounded-lg font-bold hover:bg-white hover:text-brand-primary transition text-lg">
            Sign In
          </Link>
        </div>
      </section>

      {/* Features */}
      <section className="bg-white py-16 px-10">
        <div className="max-w-5xl mx-auto grid grid-cols-3 gap-8 text-center">
          {[
            { icon: "🔒", title: "Secure Transfers", desc: "Send money instantly to any account with our state-of-the-art security." },
            { icon: "📊", title: "Transaction History", desc: "Full visibility into your account activity with powerful search tools." },
            { icon: "🏦", title: "Multiple Accounts", desc: "Manage checking, savings, and more from one unified dashboard." },
          ].map((f) => (
            <div key={f.title} className="flex flex-col items-center gap-3">
              <div className="text-4xl">{f.icon}</div>
              <h3 className="font-bold text-gray-800 text-lg">{f.title}</h3>
              <p className="text-gray-500 text-sm">{f.desc}</p>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}