class Venue {
  final String id;
  final String ownerId;
  final String name;
  final String location;
  final String city;
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
  final int commissionRate; // platform commission %, default 5

  // Owner bank details for weekly settlement payouts
  final String? ownerBankAccountNumber;
  final String? ownerBankIfsc;
  final String? ownerBankName;         // account holder name
  // Razorpay Payout IDs (created once during onboarding, reused for payouts)
  final String? razorpayContactId;
  final String? razorpayFundAccountId;

  List<String> get imageUrls => images;
  String get address => location;
  List<String> get sports => sportsTypes;

  const Venue({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.location,
    required this.city,
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
    this.ownerBankAccountNumber,
    this.ownerBankIfsc,
    this.ownerBankName,
    this.razorpayContactId,
    this.razorpayFundAccountId,
  });

  Venue copyWith({
    String? ownerId,
    String? name,
    String? location,
    String? city,
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
    String? ownerBankAccountNumber,
    String? ownerBankIfsc,
    String? ownerBankName,
    String? razorpayContactId,
    String? razorpayFundAccountId,
  }) {
    return Venue(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      location: location ?? this.location,
      city: city ?? this.city,
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
      ownerBankAccountNumber: ownerBankAccountNumber ?? this.ownerBankAccountNumber,
      ownerBankIfsc: ownerBankIfsc ?? this.ownerBankIfsc,
      ownerBankName: ownerBankName ?? this.ownerBankName,
      razorpayContactId: razorpayContactId ?? this.razorpayContactId,
      razorpayFundAccountId: razorpayFundAccountId ?? this.razorpayFundAccountId,
    );
  }
}
