class Zone {
  final String id;
  final String venueId;
  final String name;
  final String type;

  const Zone({
    required this.id,
    required this.venueId,
    required this.name,
    required this.type,
  });

  Zone copyWith({String? name, String? type}) {
    return Zone(
      id: id,
      venueId: venueId,
      name: name ?? this.name,
      type: type ?? this.type,
    );
  }
}
