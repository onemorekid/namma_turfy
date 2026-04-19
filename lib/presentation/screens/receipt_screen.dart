import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/booking_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiptScreen extends ConsumerWidget {
  final String bookingId;
  const ReceiptScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingByIdProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Receipt')),
      body: bookingAsync.when(
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Booking not found'));
          }
          final venueAsync = ref.watch(venueProvider(booking.venueId));

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF35CA67),
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Booking Confirmed!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.venueName ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (booking.venueLocation != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          booking.venueLocation!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Show this QR code at the venue',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: 'https://nammaturfy.web.app/verify/${booking.id}',
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Booking details card ──────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _ReceiptRow(
                            label: 'Booking ID',
                            value:
                                '#${booking.id.substring(booking.id.length > 6 ? booking.id.length - 6 : 0)}',
                          ),
                          _ReceiptRow(
                            label: 'Date',
                            value: DateFormat(
                              'EEE, MMM dd, yyyy',
                            ).format(booking.startTime),
                          ),
                          _ReceiptRow(
                            label: 'Time',
                            value:
                                '${DateFormat('hh:mm a').format(booking.startTime)} - ${DateFormat('hh:mm a').format(booking.endTime)}',
                          ),
                          if (booking.sportType != null)
                            _ReceiptRow(
                              label: 'Sport',
                              value: booking.sportType!,
                            ),
                          if (booking.zoneName != null)
                            _ReceiptRow(
                              label: 'Zone',
                              value: booking.zoneName!,
                            ),
                          _ReceiptRow(
                            label: 'Slots Booked',
                            value: '${booking.slotIds.length}',
                          ),
                          _ReceiptRow(
                            label: 'Payment',
                            value: 'Online (Razorpay)',
                          ),
                          const Divider(),
                          _ReceiptRow(
                            label: 'Total Paid',
                            value:
                                '₹${(booking.discountedPrice ?? booking.totalPrice).toStringAsFixed(0)}',
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Venue info (instructions, policy, rules) ──────────
                  venueAsync.when(
                    data: (venue) => venue == null
                        ? const SizedBox.shrink()
                        : _VenueInfoSection(venue: venue),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home),
                      label: const Text('Back to Home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF35CA67),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => context.push('/my-bookings'),
                    icon: const Icon(Icons.history),
                    label: const Text('View All Bookings'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── Venue policy section ───────────────────────────────────────────────────────

class _VenueInfoSection extends StatelessWidget {
  final Venue venue;
  const _VenueInfoSection({required this.venue});

  @override
  Widget build(BuildContext context) {
    final hasAny =
        venue.generalInstructions != null ||
        venue.cancellationPolicy != null ||
        venue.rules.isNotEmpty;

    if (!hasAny) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (venue.generalInstructions != null)
            _InfoCard(
              icon: Icons.info_outline,
              title: 'General Instructions',
              body: venue.generalInstructions!,
            ),
          if (venue.cancellationPolicy != null)
            _InfoCard(
              icon: Icons.cancel_outlined,
              title: 'Cancellation Policy',
              body: venue.cancellationPolicy!,
            ),
          if (venue.rules.isNotEmpty) _RulesCard(rules: venue.rules),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  final List<String> rules;
  const _RulesCard({required this.rules});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rule, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 8),
                const Text(
                  'Venue Rules',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...rules.map(
              (rule) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    Expanded(
                      child: Text(
                        rule,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared row widget ─────────────────────────────────────────────────────────

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
