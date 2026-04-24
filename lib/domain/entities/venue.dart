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

  // Venue policies (shown to player on receipt + bookings page)
  final String? generalInstructions;
  final String? cancellationPolicy;
  final List<String> rules;

  // Owner bank details for weekly settlement payouts
  final String? ownerBankAccountNumber;
  final String? ownerBankIfsc;
  final String? ownerBankName; // account holder name
  // Razorpay Payout IDs (created once during onboarding, reused for payouts)
  final String? razorpayContactId;
  final String? razorpayFundAccountId;

  // Operating Hours (F-02)
  final int? openTimeHour;
  final int? openTimeMinute;
  final int? closeTimeHour;
  final int? closeTimeMinute;

  // Peak Hours (F-04)
  final int morningPeakStartHour;
  final int morningPeakStartMinute;
  final int morningPeakEndHour;
  final int morningPeakEndMinute;
  final int eveningPeakStartHour;
  final int eveningPeakStartMinute;
  final int eveningPeakEndHour;
  final int eveningPeakEndMinute;
  final double peakMultiplier;

  // Minimum Slot Price (F-05)
  final double? minSlotPrice;

  // Time Filter Fix (F-06)
  final List<int> availableSlotHours;

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
    this.generalInstructions,
    this.cancellationPolicy,
    this.rules = const [],
    this.ownerBankAccountNumber,
    this.ownerBankIfsc,
    this.ownerBankName,
    this.razorpayContactId,
    this.razorpayFundAccountId,
    this.openTimeHour,
    this.openTimeMinute,
    this.closeTimeHour,
    this.closeTimeMinute,
    this.morningPeakStartHour = 6,
    this.morningPeakStartMinute = 0,
    this.morningPeakEndHour = 10,
    this.morningPeakEndMinute = 0,
    this.eveningPeakStartHour = 17,
    this.eveningPeakStartMinute = 0,
    this.eveningPeakEndHour = 22,
    this.eveningPeakEndMinute = 0,
    this.peakMultiplier = 1.2,
    this.minSlotPrice,
    this.availableSlotHours = const [],
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
    String? generalInstructions,
    String? cancellationPolicy,
    List<String>? rules,
    String? ownerBankAccountNumber,
    String? ownerBankIfsc,
    String? ownerBankName,
    String? razorpayContactId,
    String? razorpayFundAccountId,
    int? openTimeHour,
    int? openTimeMinute,
    int? closeTimeHour,
    int? closeTimeMinute,
    int? morningPeakStartHour,
    int? morningPeakStartMinute,
    int? morningPeakEndHour,
    int? morningPeakEndMinute,
    int? eveningPeakStartHour,
    int? eveningPeakStartMinute,
    int? eveningPeakEndHour,
    int? eveningPeakEndMinute,
    double? peakMultiplier,
    double? minSlotPrice,
    List<int>? availableSlotHours,
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
      generalInstructions: generalInstructions ?? this.generalInstructions,
      cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
      rules: rules ?? this.rules,
      ownerBankAccountNumber:
          ownerBankAccountNumber ?? this.ownerBankAccountNumber,
      ownerBankIfsc: ownerBankIfsc ?? this.ownerBankIfsc,
      ownerBankName: ownerBankName ?? this.ownerBankName,
      razorpayContactId: razorpayContactId ?? this.razorpayContactId,
      razorpayFundAccountId:
          razorpayFundAccountId ?? this.razorpayFundAccountId,
      openTimeHour: openTimeHour ?? this.openTimeHour,
      openTimeMinute: openTimeMinute ?? this.openTimeMinute,
      closeTimeHour: closeTimeHour ?? this.closeTimeHour,
      closeTimeMinute: closeTimeMinute ?? this.closeTimeMinute,
      morningPeakStartHour: morningPeakStartHour ?? this.morningPeakStartHour,
      morningPeakStartMinute:
          morningPeakStartMinute ?? this.morningPeakStartMinute,
      morningPeakEndHour: morningPeakEndHour ?? this.morningPeakEndHour,
      morningPeakEndMinute: morningPeakEndMinute ?? this.morningPeakEndMinute,
      eveningPeakStartHour: eveningPeakStartHour ?? this.eveningPeakStartHour,
      eveningPeakStartMinute:
          eveningPeakStartMinute ?? this.eveningPeakStartMinute,
      eveningPeakEndHour: eveningPeakEndHour ?? this.eveningPeakEndHour,
      eveningPeakEndMinute: eveningPeakEndMinute ?? this.eveningPeakEndMinute,
      peakMultiplier: peakMultiplier ?? this.peakMultiplier,
      minSlotPrice: minSlotPrice ?? this.minSlotPrice,
      availableSlotHours: availableSlotHours ?? this.availableSlotHours,
    );
  }
}
