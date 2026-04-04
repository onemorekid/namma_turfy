class VenueAnalytics {
  final String venueId;
  final double totalRevenue;
  final int totalBookings;
  final Map<String, int> bookingsByHour;
  final List<String> peakHours;

  const VenueAnalytics({
    required this.venueId,
    required this.totalRevenue,
    required this.totalBookings,
    this.bookingsByHour = const {},
    this.peakHours = const [],
  });
}
