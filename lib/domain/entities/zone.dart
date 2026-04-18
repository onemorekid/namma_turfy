class Zone {
  final String id;
  final String venueId;
  final String name;
  final String type;
  final List<String> images;

  const Zone({
    required this.id,
    required this.venueId,
    required this.name,
    required this.type,
    this.images = const [],
  });

  Zone copyWith({String? name, String? type, List<String>? images}) {
    return Zone(
      id: id,
      venueId: venueId,
      name: name ?? this.name,
      type: type ?? this.type,
      images: images ?? this.images,
    );
  }
}
