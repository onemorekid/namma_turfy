enum TransactionType { credit, debit }

class LedgerTransaction {
  final String id;
  final DateTime timestamp;
  final double amount;
  final String description;
  final TransactionType type;

  const LedgerTransaction({
    required this.id,
    required this.timestamp,
    required this.amount,
    required this.description,
    required this.type,
  });
}

class VendorLedger {
  final String ownerId;
  final double balance;
  final List<LedgerTransaction> transactions;

  const VendorLedger({
    required this.ownerId,
    required this.balance,
    required this.transactions,
  });
}
