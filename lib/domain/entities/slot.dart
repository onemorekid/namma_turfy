enum SlotStatus { available, locked, booked }

class Slot {
  final String id;
  final String zoneId;
  final DateTime startTime;
  final DateTime? endTime;
  final double price;
  final SlotStatus status;
  final DateTime? holdExpiry;
  final String? lockedBy; // userId who currently holds the lock

  const Slot({
    required this.id,
    required this.zoneId,
    required this.startTime,
    this.endTime,
    required this.price,
    required this.status,
    this.holdExpiry,
    this.lockedBy,
  });

  bool get isHoldExpired =>
      holdExpiry != null && holdExpiry!.isBefore(DateTime.now());

  Slot copyWith({
    SlotStatus? status,
    DateTime? holdExpiry,
    DateTime? endTime,
    String? lockedBy,
    bool clearLock = false,
  }) {
    return Slot(
      id: id,
      zoneId: zoneId,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      price: price,
      status: status ?? this.status,
      holdExpiry: clearLock ? null : holdExpiry ?? this.holdExpiry,
      lockedBy: clearLock ? null : lockedBy ?? this.lockedBy,
    );
  }
}
