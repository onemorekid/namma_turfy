import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';

class VenueListScreen extends ConsumerStatefulWidget {
  const VenueListScreen({super.key});

  @override
  ConsumerState<VenueListScreen> createState() => _VenueListScreenState();
}

class _VenueListScreenState extends ConsumerState<VenueListScreen> {
  final _sportController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void dispose() {
    _sportController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _search() {
    ref
        .read(venueSearchControllerProvider.notifier)
        .search(
          sport: _sportController.text,
          location: _locationController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final venuesState = ref.watch(venueSearchControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Discover Venues')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sportController,
                    decoration: const InputDecoration(
                      labelText: 'Sport',
                      prefixIcon: Icon(Icons.sports),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                ),
                IconButton(onPressed: _search, icon: const Icon(Icons.search)),
              ],
            ),
          ),
          Expanded(
            child: venuesState.when(
              data: (venues) => ListView.builder(
                itemCount: venues.length,
                itemBuilder: (context, index) {
                  final venue = venues[index];
                  return VenueCard(venue: venue);
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class VenueCard extends StatelessWidget {
  final Venue venue;
  const VenueCard({super.key, required this.venue});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => context.push('/venue/${venue.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (venue.imageUrls.isNotEmpty)
              Image.network(
                venue.imageUrls.first,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 150,
                  child: Icon(Icons.broken_image),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(venue.address),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${venue.pricePerHour}/hr',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: venue.sports
                            .map(
                              (s) => Chip(
                                label: Text(
                                  s,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
