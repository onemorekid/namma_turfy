import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/domain/entities/booking.dart';
import 'package:namma_turfy/presentation/providers/booking_providers.dart';

class PlayerBookingsScreen extends ConsumerWidget {
  const PlayerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(playerBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return const Center(child: Text('You have no bookings yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final shortId = booking.id.length > 6
                  ? booking.id.substring(booking.id.length - 6)
                  : booking.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: booking.status == BookingStatus.confirmed
                        ? const Color(0xFF35CA67)
                        : Colors.orange,
                    child: const Icon(
                      Icons.sports_soccer,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    'Booking #$shortId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat(
                          'MMM dd, yyyy • hh:mm a',
                        ).format(booking.date),
                      ),
                      Text(
                        booking.status.name.toUpperCase(),
                        style: TextStyle(
                          color: booking.status == BookingStatus.confirmed
                              ? Colors.green
                              : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${(booking.discountedPrice ?? booking.totalPrice).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.qr_code, size: 16, color: Colors.grey),
                    ],
                  ),
                  onTap: () => context.push('/receipt/${booking.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
