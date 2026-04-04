class Venue {
  final String id;
  final String ownerId;
  final String name;
  final String location;
  final double latitude;
  final double longitude;
  final String type;
  final double rating;
  final String description;
  final double pricePerHour;
  final List<String> images;
  final List<String> features;
  final List<String> sportsTypes;
  final List<String> availableHours;
  final bool isSuspended;
  final int commissionRate; // 3, 5, or 8

  List<String> get imageUrls => images;
  String get address => location;
  List<String> get sports => sportsTypes;

  const Venue({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.rating,
    required this.description,
    required this.pricePerHour,
    this.images = const [],
    this.features = const [],
    this.sportsTypes = const [],
    this.availableHours = const [],
    this.isSuspended = false,
    this.commissionRate = 5,
  });

  Venue copyWith({
    String? ownerId,
    String? name,
    String? location,
    double? latitude,
    double? longitude,
    String? type,
    double? rating,
    String? description,
    double? pricePerHour,
    List<String>? images,
    List<String>? features,
    List<String>? sportsTypes,
    List<String>? availableHours,
    bool? isSuspended,
    int? commissionRate,
  }) {
    return Venue(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      rating: rating ?? this.rating,
      description: description ?? this.description,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      images: images ?? this.images,
      features: features ?? this.features,
      sportsTypes: sportsTypes ?? this.sportsTypes,
      availableHours: availableHours ?? this.availableHours,
      isSuspended: isSuspended ?? this.isSuspended,
      commissionRate: commissionRate ?? this.commissionRate,
    );
  }
}
