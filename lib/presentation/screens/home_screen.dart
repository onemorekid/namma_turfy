import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namma_turfy/core/services/location_service.dart';
import 'package:namma_turfy/core/utils/proximity_helper.dart';
import 'package:namma_turfy/domain/entities/user.dart';
import 'package:namma_turfy/domain/entities/venue.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/providers/discovery_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:namma_turfy/presentation/widgets/app_drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesAsync = ref.watch(allVenuesProvider);
    final userPos = ref.watch(userPositionProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedHour = ref.watch(selectedHourProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Namma Turfy',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF35CA67),
                fontSize: 20,
              ),
            ),
            _CityPicker(user: user),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              final pos = await ref
                  .read(locationServiceProvider)
                  .getCurrentPosition();
              ref.read(userPositionProvider.notifier).value = pos;
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _TimeDiscovery(selectedHour: selectedHour),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search venues or areas...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) =>
                  ref.read(searchQueryProvider.notifier).value = val,
            ),
          ),
          Expanded(
            child: venuesAsync.when(
              data: (venues) {
                // Derive categories dynamically from data
                final allSports = {'All', ...venues.expand((v) => v.sportsTypes)};
                final categories = [
                  'All',
                  ...allSports.where((s) => s != 'All').toList()..sort(),
                ];

                var filtered = venues.where((v) => !v.isSuspended).toList();

                if (selectedCategory != 'All') {
                  filtered = filtered
                      .where((v) => v.sportsTypes.contains(selectedCategory))
                      .toList();
                }

                if (searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where(
                        (v) =>
                            v.name.toLowerCase().contains(
                              searchQuery.toLowerCase(),
                            ) ||
                            v.location.toLowerCase().contains(
                              searchQuery.toLowerCase(),
                            ),
                      )
                      .toList();
                }

                if (selectedHour != null) {
                  filtered = filtered.where((v) {
                    // No hours listed → treat as always open, always show.
                    if (v.availableHours.isEmpty) return true;
                    // Supports formats like "09:00", "9:00", "9", "21:00".
                    final hours = v.availableHours
                        .map((h) => int.tryParse(h.split(':').first))
                        .whereType<int>()
                        .toSet();
                    return hours.contains(selectedHour);
                  }).toList();
                }

                if (userPos != null) {
                  filtered.sort((a, b) {
                    final distA = ProximityHelper.calculateDistance(
                      userPos.latitude,
                      userPos.longitude,
                      a.latitude,
                      a.longitude,
                    );
                    final distB = ProximityHelper.calculateDistance(
                      userPos.latitude,
                      userPos.longitude,
                      b.latitude,
                      b.longitude,
                    );
                    return distA.compareTo(distB);
                  });
                }

                return Column(
                  children: [
                    _CategoryFilter(
                      categories: categories,
                      selectedCategory: selectedCategory,
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'No venues found in this city.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  if (user?.preferredCity != null) ...[
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      onPressed: () {
                                        ref
                                            .read(authRepositoryProvider)
                                            .updateProfile(
                                              name: user?.name ?? 'User',
                                              preferredCity: '',
                                            );
                                      },
                                      icon: const Icon(Icons.location_off),
                                      label: const Text('Show all cities'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final venue = filtered[index];
                                double? distance;
                                if (userPos != null) {
                                  distance = ProximityHelper.calculateDistance(
                                    userPos.latitude,
                                    userPos.longitude,
                                    venue.latitude,
                                    venue.longitude,
                                  );
                                }
                                return _VenueCard(venue: venue, distance: distance);
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeDiscovery extends ConsumerWidget {
  final int? selectedHour;
  const _TimeDiscovery({required this.selectedHour});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 16,
        itemBuilder: (context, index) {
          final hour = index + 6;
          final isSelected = selectedHour == hour;
          final timeStr = hour > 12
              ? '${hour - 12}:00 PM'
              : '$hour:00 ${hour == 12 ? 'PM' : 'AM'}';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(timeStr),
              selected: isSelected,
              onSelected: (val) {
                ref.read(selectedHourProvider.notifier).value = val
                    ? hour
                    : null;
              },
            ),
          );
        },
      ),
    );
  }
}

class _CategoryFilter extends ConsumerWidget {
  final List<String> categories;
  final String selectedCategory;
  const _CategoryFilter({required this.categories, required this.selectedCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(cat),
              selected: selectedCategory == cat,
              onSelected: (_) =>
                  ref.read(selectedCategoryProvider.notifier).value = cat,
            ),
          );
        },
      ),
    );
  }
}

class _CityPicker extends ConsumerWidget {
  final UserEntity? user;
  const _CityPicker({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ['Vijayapura', 'Bagalakote', 'Kalaburagi'];
    final selectedCity = user?.preferredCity;

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Select Your City',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...cities.map(
                  (city) => ListTile(
                    title: Text(city),
                    trailing: selectedCity == city
                        ? const Icon(Icons.check, color: Color(0xFF35CA67))
                        : null,
                    onTap: () {
                      ref.read(authRepositoryProvider).updateProfile(
                            name: user?.name ?? 'User',
                            preferredCity: city,
                          );
                      Navigator.pop(context);
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Show All Cities'),
                  onTap: () {
                    ref.read(authRepositoryProvider).updateProfile(
                          name: user?.name ?? 'User',
                          preferredCity: '',
                        );
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selectedCity ?? 'Select City',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final Venue venue;
  final double? distance;
  const _VenueCard({required this.venue, this.distance});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/venue/${venue.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (venue.images.isNotEmpty)
              CachedNetworkImage(
                imageUrl: venue.images.first,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 180,
                  color: Colors.grey[100],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, size: 60),
                ),
              )
            else
              Container(
                height: 180,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.stadium, size: 60, color: Colors.grey),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          Text(
                            ' ${venue.rating}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    venue.location,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Starts ₹${venue.pricePerHour.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (distance != null)
                        Text(
                          '${distance!.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
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
