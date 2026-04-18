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
  });

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    // Robust image parsing: check both fields and merge them to avoid data loss
    final List<String> images = [];
    if (json['images'] is List) {
      images.addAll((json['images'] as List).cast<String>());
    }
    if (json['imageUrls'] is List) {
      for (final url in (json['imageUrls'] as List).cast<String>()) {
        if (!images.contains(url)) images.add(url);
      }
    }

    if (images.isEmpty) {
      debugPrint('[VenueModel] WARNING: No images found for venue ${json['id']}');
    } else {
      debugPrint('[VenueModel] Found ${images.length} images for venue ${json['id']}');
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
  };
}
