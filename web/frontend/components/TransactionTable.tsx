interface Transaction {
  id: number;
  from: number;
  to: number;
  amount: number;
  note: string;
  date: string;
}

interface Props {
  transactions: Transaction[];
  currentAccountId?: number;
}

export default function TransactionTable({ transactions, currentAccountId }: Props) {
  if (!transactions.length) {
    return <p className="text-brand-muted text-sm text-center py-8">No transactions found.</p>;
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-brand-muted/10 text-brand-muted text-left">
            <th className="pb-3 font-medium">Date</th>
            <th className="pb-3 font-medium">Note</th>
            <th className="pb-3 font-medium">From</th>
            <th className="pb-3 font-medium">To</th>
            <th className="pb-3 font-medium text-right">Amount</th>
          </tr>
        </thead>
        <tbody>
          {transactions.map(tx => {
            const isCredit = tx.to === currentAccountId;
            return (
              <tr key={tx.id} className="border-b border-brand-muted/5 hover:bg-brand-primary/5 transition">
                <td className="py-3 text-brand-muted/80">{new Date(tx.date).toLocaleDateString()}</td>
                <td className="py-3 text-brand-primary" dangerouslySetInnerHTML={{ __html: tx.note }} />
                <td className="py-3 text-brand-muted/80">ACC#{tx.from}</td>
                <td className="py-3 text-brand-muted/80">ACC#{tx.to}</td>
                <td className={`py-3 text-right font-semibold ${isCredit ? "text-brand-success" : "text-brand-error"}`}>
                  {isCredit ? "+" : "-"}${tx.amount}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}