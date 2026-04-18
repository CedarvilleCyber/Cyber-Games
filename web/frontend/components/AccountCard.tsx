import Image from "next/image";

interface Props {
  accountNumber: string;
  balance: number;
  id: number;
}

export default function AccountCard({ accountNumber, balance, id }: Props) {
  return (
    <div className="bg-brand-primary text-white rounded-2xl p-6 shadow-lg w-full max-w-sm border border-white/5">
      <div className="flex justify-between items-start mb-8">
        <div>
          <p className="text-white/60 text-[10px] uppercase tracking-[0.2em] font-medium">Sentinel National Bank</p>
          <p className="text-sm text-white/40 mt-1">Checking Account</p>
        </div>
        <div className="bg-white p-1 rounded-full shadow-sm">
          <Image
            src="/sentinel_national_logo.png"
            alt="Sentinel Logo"
            width={24}
            height={24}
            className="h-5 w-auto"
          />
        </div>
      </div>
      <div className="mb-4">
        <p className="text-white/60 text-xs mb-1">Available Balance</p>
        <p className="text-3xl font-bold tracking-tight">${balance.toLocaleString("en-US", { minimumFractionDigits: 2 })}</p>
      </div>
      <p className="text-white/40 text-sm tracking-[0.25em] font-mono">{accountNumber}</p>
    </div>
  );
}