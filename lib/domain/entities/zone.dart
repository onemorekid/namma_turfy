class Zone {
  final String id;
  final String venueId;
  final String name;
  final String type;
  final List<String> images;
  final int? capacity;

  const Zone({
    required this.id,
    required this.venueId,
    required this.name,
    required this.type,
    this.images = const [],
    this.capacity,
  });

  Zone copyWith({
    String? name,
    String? type,
    List<String>? images,
    int? capacity,
  }) {
    return Zone(
      id: id,
      venueId: venueId,
      name: name ?? this.name,
      type: type ?? this.type,
      images: images ?? this.images,
      capacity: capacity ?? this.capacity,
    );
  }
}
