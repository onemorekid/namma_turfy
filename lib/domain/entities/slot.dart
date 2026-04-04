enum SlotStatus { available, locked, booked }

class Slot {
  final String id;
  final String zoneId;
  final DateTime startTime;
  final DateTime? endTime;
  final double price;
  final SlotStatus status;
  final DateTime? holdExpiry;

  const Slot({
    required this.id,
    required this.zoneId,
    required this.startTime,
    this.endTime,
    required this.price,
    required this.status,
    this.holdExpiry,
  });

  Slot copyWith({SlotStatus? status, DateTime? holdExpiry, DateTime? endTime}) {
    return Slot(
      id: id,
      zoneId: zoneId,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      price: price,
      status: status ?? this.status,
      holdExpiry: holdExpiry ?? this.holdExpiry,
    );
  }
}
