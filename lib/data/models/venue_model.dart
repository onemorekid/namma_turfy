import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:namma_turfy/domain/entities/venue.dart';

class VenueModel extends Venue {
  const VenueModel({
    required super.id,
    required super.ownerId,
    required super.name,
    required super.location,
    required super.city,
    required super.latitude,
    required super.longitude,
    required super.type,
    required super.rating,
    required super.description,
    required super.pricePerHour,
    super.images,
    super.features,
    super.sportsTypes,
    super.availableHours,
    super.isSuspended,
    super.commissionRate,
    super.generalInstructions,
    super.cancellationPolicy,
    super.rules,
    super.ownerBankAccountNumber,
    super.ownerBankIfsc,
    super.ownerBankName,
    super.razorpayContactId,
    super.razorpayFundAccountId,
    super.openTimeHour,
    super.openTimeMinute,
    super.closeTimeHour,
    super.closeTimeMinute,
    super.morningPeakStartHour,
    super.morningPeakStartMinute,
    super.morningPeakEndHour,
    super.morningPeakEndMinute,
    super.eveningPeakStartHour,
    super.eveningPeakStartMinute,
    super.eveningPeakEndHour,
    super.eveningPeakEndMinute,
    super.peakMultiplier,
    super.minSlotPrice,
    super.availableSlotHours,
  });

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    final List<String> images = [];

    // Check various common field names for images
    final imageFields = ['images', 'imageUrls', 'image_urls'];
    for (final field in imageFields) {
      if (json[field] is List) {
        for (final item in (json[field] as List)) {
          if (item is String && item.isNotEmpty && !images.contains(item)) {
            images.add(item);
          }
        }
      }
    }

    if (images.isEmpty) {
      debugPrint(
        '[VenueModel] WARNING: No images found for venue ${json['id']}',
      );
    }

    return VenueModel(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      city: json['city'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'Cricket',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      description: json['description'] as String? ?? '',
      pricePerHour: (json['pricePerHour'] as num?)?.toDouble() ?? 0.0,
      images: images,
      features: (json['features'] as List?)?.cast<String>() ?? [],
      sportsTypes: (json['sportsTypes'] as List?)?.cast<String>() ?? [],
      availableHours: (json['availableHours'] as List?)?.cast<String>() ?? [],
      isSuspended: json['isSuspended'] as bool? ?? false,
      commissionRate: (json['commissionRate'] as num?)?.toInt() ?? 5,
      generalInstructions: json['generalInstructions'] as String?,
      cancellationPolicy: json['cancellationPolicy'] as String?,
      rules: (json['rules'] as List?)?.cast<String>() ?? [],
      ownerBankAccountNumber: json['ownerBankAccountNumber'] as String?,
      ownerBankIfsc: json['ownerBankIfsc'] as String?,
      ownerBankName: json['ownerBankName'] as String?,
      razorpayContactId: json['razorpayContactId'] as String?,
      razorpayFundAccountId: json['razorpayFundAccountId'] as String?,
      openTimeHour: (json['openTimeHour'] as num?)?.toInt(),
      openTimeMinute: (json['openTimeMinute'] as num?)?.toInt(),
      closeTimeHour: (json['closeTimeHour'] as num?)?.toInt(),
      closeTimeMinute: (json['closeTimeMinute'] as num?)?.toInt(),
      morningPeakStartHour:
          (json['morningPeakStartHour'] as num?)?.toInt() ?? 6,
      morningPeakStartMinute:
          (json['morningPeakStartMinute'] as num?)?.toInt() ?? 0,
      morningPeakEndHour: (json['morningPeakEndHour'] as num?)?.toInt() ?? 10,
      morningPeakEndMinute:
          (json['morningPeakEndMinute'] as num?)?.toInt() ?? 0,
      eveningPeakStartHour:
          (json['eveningPeakStartHour'] as num?)?.toInt() ?? 17,
      eveningPeakStartMinute:
          (json['eveningPeakStartMinute'] as num?)?.toInt() ?? 0,
      eveningPeakEndHour: (json['eveningPeakEndHour'] as num?)?.toInt() ?? 22,
      eveningPeakEndMinute:
          (json['eveningPeakEndMinute'] as num?)?.toInt() ?? 0,
      peakMultiplier: (json['peakMultiplier'] as num?)?.toDouble() ?? 1.2,
      minSlotPrice: (json['minSlotPrice'] as num?)?.toDouble(),
      availableSlotHours:
          (json['availableSlotHours'] as List?)?.cast<int>() ?? [],
    );
  }

  factory VenueModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    data['id'] = snap.id;
    return VenueModel.fromJson(data);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'name': name,
    'location': location,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'type': type,
    'rating': rating,
    'description': description,
    'pricePerHour': pricePerHour,
    'images': images,
    'features': features,
    'sportsTypes': sportsTypes,
    'availableHours': availableHours,
    'isSuspended': isSuspended,
    'commissionRate': commissionRate,
    if (generalInstructions != null) 'generalInstructions': generalInstructions,
    if (cancellationPolicy != null) 'cancellationPolicy': cancellationPolicy,
    if (rules.isNotEmpty) 'rules': rules,
    if (ownerBankAccountNumber != null)
      'ownerBankAccountNumber': ownerBankAccountNumber,
    if (ownerBankIfsc != null) 'ownerBankIfsc': ownerBankIfsc,
    if (ownerBankName != null) 'ownerBankName': ownerBankName,
    if (razorpayContactId != null) 'razorpayContactId': razorpayContactId,
    if (razorpayFundAccountId != null)
      'razorpayFundAccountId': razorpayFundAccountId,
    if (openTimeHour != null) 'openTimeHour': openTimeHour,
    if (openTimeMinute != null) 'openTimeMinute': openTimeMinute,
    if (closeTimeHour != null) 'closeTimeHour': closeTimeHour,
    if (closeTimeMinute != null) 'closeTimeMinute': closeTimeMinute,
    'morningPeakStartHour': morningPeakStartHour,
    'morningPeakStartMinute': morningPeakStartMinute,
    'morningPeakEndHour': morningPeakEndHour,
    'morningPeakEndMinute': morningPeakEndMinute,
    'eveningPeakStartHour': eveningPeakStartHour,
    'eveningPeakStartMinute': eveningPeakStartMinute,
    'eveningPeakEndHour': eveningPeakEndHour,
    'eveningPeakEndMinute': eveningPeakEndMinute,
    'peakMultiplier': peakMultiplier,
    if (minSlotPrice != null) 'minSlotPrice': minSlotPrice,
    'availableSlotHours': availableSlotHours,
  };
}
