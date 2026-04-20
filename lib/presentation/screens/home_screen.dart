import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namma_turfy/core/services/location_service.dart';
import 'package:namma_turfy/core/theme/app_colors.dart';
import 'package:namma_turfy/core/theme/app_spacing.dart';
import 'package:namma_turfy/core/theme/app_text_styles.dart';
import 'package:namma_turfy/core/utils/proximity_helper.dart';
import 'package:namma_turfy/domain/entities/user.dart';
import 'package:intl/intl.dart';
import 'package:namma_turfy/domain/entities/booking.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/providers/booking_providers.dart';
import 'package:namma_turfy/presentation/providers/discovery_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:namma_turfy/presentation/widgets/offer_banner_widget.dart';
import 'package:namma_turfy/presentation/widgets/venue_card_widget.dart';

// ── Bottom nav index state ─────────────────────────────────────────────────────
final _navIndexProvider = NotifierProvider<_NavIndexNotifier, int>(_NavIndexNotifier.new);
class _NavIndexNotifier extends Notifier<int> {
  @override int build() => 0;
  void set(int v) => state = v;
}

final _offerVisibleProvider = NotifierProvider<_OfferVisibleNotifier, bool>(_OfferVisibleNotifier.new);
class _OfferVisibleNotifier extends Notifier<bool> {
  @override bool build() => true;
  void hide() => state = false;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(_navIndexProvider);

    // When not on the Home tab, delegate to the appropriate screen.
    // Bookings and Profile route via GoRouter; Tournaments is placeholder.
    final body = switch (navIndex) {
      1 => _BookingsTab(),
      2 => _TournamentsTab(),
      3 => _ProfileTab(),
      _ => const _HomeTab(),
    };

    return Scaffold(
      body: body,
      bottomNavigationBar: _AppBottomNav(
        currentIndex: navIndex,
        onTap: (i) => ref.read(_navIndexProvider.notifier).set(i),
      ),
    );
  }
}

// ── Bottom Navigation Bar ──────────────────────────────────────────────────────

class _AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _AppBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFloat, // 8% black
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_outlined,          label: 'Home',        index: 0, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.calendar_today_outlined, label: 'Bookings',   index: 1, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.emoji_events_outlined,   label: 'Tournaments', index: 2, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.person_outline,          label: 'Profile',     index: 3, current: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;
  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: isActive ? AppColors.primary : AppColors.outlineVariant),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isActive ? AppColors.primary : AppColors.onSurfaceVar,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home Tab ───────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesAsync = ref.watch(allVenuesProvider);
    final userPos = ref.watch(userPositionProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedHour = ref.watch(selectedHourProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final user = ref.watch(currentUserProvider);
    final offerVisible = ref.watch(_offerVisibleProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _HomeAppBar(user: user, ref: ref),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Offer banner
          if (offerVisible)
            OfferBannerWidget(
              onDismiss: () =>
                  ref.read(_offerVisibleProvider.notifier).hide(),
            ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search venues or areas…',
                prefixIcon: Icon(Icons.search, color: AppColors.outlineVariant),
              ),
              onChanged: (val) =>
                  ref.read(searchQueryProvider.notifier).value = val,
            ),
          ),

          // Time chips
          _TimeDiscovery(selectedHour: selectedHour),

          // Venue list
          Expanded(
            child: venuesAsync.when(
              data: (venues) {
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
                            v.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                            v.location.toLowerCase().contains(searchQuery.toLowerCase()),
                      )
                      .toList();
                }
                if (selectedHour != null) {
                  filtered = filtered.where((v) {
                    if (v.availableHours.isEmpty) return true;
                    final hours = v.availableHours
                        .map((h) => int.tryParse(h.split(':').first))
                        .whereType<int>()
                        .toSet();
                    return hours.contains(selectedHour);
                  }).toList();
                }
                if (userPos != null) {
                  filtered.sort((a, b) {
                    final dA = ProximityHelper.calculateDistance(
                        userPos.latitude, userPos.longitude, a.latitude, a.longitude);
                    final dB = ProximityHelper.calculateDistance(
                        userPos.latitude, userPos.longitude, b.latitude, b.longitude);
                    return dA.compareTo(dB);
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryFilter(
                      categories: categories,
                      selectedCategory: selectedCategory,
                    ),

                    // Section header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm,
                      ),
                      child: Text('Popular Turfs', style: AppTextStyles.titleMedium),
                    ),

                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_off,
                                      size: 48, color: AppColors.outlineVariant),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'No venues found',
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(color: AppColors.onSurfaceVar),
                                  ),
                                  if (user?.preferredCity != null) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    TextButton.icon(
                                      onPressed: () => ref
                                          .read(authRepositoryProvider)
                                          .updateProfile(
                                            name: user?.name ?? 'User',
                                            preferredCity: '',
                                          ),
                                      icon: const Icon(Icons.location_off),
                                      label: const Text('Show all cities'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final venue = filtered[index];
                                double? distance;
                                if (userPos != null) {
                                  distance = ProximityHelper.calculateDistance(
                                    userPos.latitude, userPos.longitude,
                                    venue.latitude, venue.longitude,
                                  );
                                }
                                return VenueCardWidget(
                                  venue: venue,
                                  distanceKm: distance,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App Bar with location picker ───────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserEntity? user;
  final WidgetRef ref;
  const _HomeAppBar({required this.user, required this.ref});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Namma Turfy',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary)),
          _LocationPicker(user: user, ref: ref),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Use my location',
          icon: const Icon(Icons.my_location, color: AppColors.onSurface),
          onPressed: () async {
            final pos =
                await ref.read(locationServiceProvider).getCurrentPosition();
            ref.read(userPositionProvider.notifier).value = pos;
          },
        ),
      ],
    );
  }
}

// ── Location Picker ────────────────────────────────────────────────────────────

class _LocationPicker extends StatelessWidget {
  final UserEntity? user;
  final WidgetRef ref;
  const _LocationPicker({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cities = ['Vijayapura', 'Bagalakote', 'Kalaburagi'];
    final selectedCity = user?.preferredCity;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('Select Your City',
                    style: AppTextStyles.titleMedium),
              ),
              const Divider(height: 1),
              ...cities.map((city) => ListTile(
                    leading: const Icon(Icons.location_on,
                        color: AppColors.primary),
                    title: Text(city, style: AppTextStyles.bodyLarge),
                    trailing: selectedCity == city
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      ref.read(authRepositoryProvider).updateProfile(
                            name: user?.name ?? 'User',
                            preferredCity: city,
                          );
                      Navigator.pop(context);
                    },
                  )),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.location_off,
                    color: AppColors.onSurfaceVar),
                title: Text('Show All Cities',
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.onSurfaceVar)),
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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 12, color: AppColors.primary),
          const SizedBox(width: 2),
          Text(
            selectedCity?.isNotEmpty == true ? selectedCity! : 'Select City',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.onSurfaceVar),
          ),
          const Icon(Icons.arrow_drop_down,
              size: 14, color: AppColors.onSurfaceVar),
        ],
      ),
    );
  }
}

// ── Time discovery chips ───────────────────────────────────────────────────────

class _TimeDiscovery extends ConsumerWidget {
  final int? selectedHour;
  const _TimeDiscovery({required this.selectedHour});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        itemCount: 16,
        itemBuilder: (context, index) {
          final hour = index + 6;
          final isSelected = selectedHour == hour;
          final timeStr = hour > 12
              ? '${hour - 12}pm'
              : '$hour${hour == 12 ? 'pm' : 'am'}';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(timeStr),
              selected: isSelected,
              selectedColor: AppColors.primary,
              labelStyle: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.onSurface,
              ),
              onSelected: (val) =>
                  ref.read(selectedHourProvider.notifier).value =
                      val ? hour : null,
            ),
          );
        },
      ),
    );
  }
}

// ── Category filter chips ──────────────────────────────────────────────────────

class _CategoryFilter extends ConsumerWidget {
  final List<String> categories;
  final String selectedCategory;
  const _CategoryFilter({required this.categories, required this.selectedCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 6),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: AppColors.primary,
              labelStyle: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.onSurface,
              ),
              onSelected: (_) =>
                  ref.read(selectedCategoryProvider.notifier).value = cat,
            ),
          );
        },
      ),
    );
  }
}

// ── Placeholder tabs (Tournaments, Profile) ────────────────────────────────────

class _BookingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(playerBookingsProvider);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('My Bookings'),
          floating: true,
          snap: true,
          automaticallyImplyLeading: false,
        ),
        bookingsAsync.when(
          data: (bookings) {
            if (bookings.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sports_soccer,
                          size: 64, color: AppColors.outlineVariant),
                      const SizedBox(height: 16),
                      Text('No bookings yet',
                          style: AppTextStyles.titleMedium
                              .copyWith(color: AppColors.onSurfaceVar)),
                      const SizedBox(height: 8),
                      Text('Book a venue to get started!',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.onSurfaceVar)),
                    ],
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList.separated(
                itemCount: bookings.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) =>
                    _BookingCard(booking: bookings[i]),
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (e, _) => SliverFillRemaining(
            child: Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final status = booking.displayStatus;
    final Color statusColor = switch (status) {
      'Upcoming'  => const Color(0xFF1E88E5),
      'Ongoing'   => AppColors.primary,
      'Completed' => AppColors.outlineVariant,
      'Cancelled' => AppColors.error,
      _           => AppColors.peakTime,
    };
    final shortId = booking.id.length > 6
        ? booking.id.substring(booking.id.length - 6)
        : booking.id;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/receipt/${booking.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Venue name + status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(booking.venueName ?? 'Venue',
                        style: AppTextStyles.titleMedium),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (booking.venueLocation != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 14, color: AppColors.onSurfaceVar),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(booking.venueLocation!,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              // Date + price
              Row(children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppColors.onSurfaceVar),
                const SizedBox(width: 6),
                Text(DateFormat('EEE, MMM dd, yyyy').format(booking.startTime),
                    style: AppTextStyles.bodySmall),
                const Spacer(),
                Text(
                  '₹${(booking.discountedPrice ?? booking.totalPrice).toStringAsFixed(0)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
              ]),
              const SizedBox(height: 4),
              // Time + slots
              Row(children: [
                const Icon(Icons.access_time,
                    size: 14, color: AppColors.onSurfaceVar),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${DateFormat('hh:mm a').format(booking.startTime)} – '
                    '${DateFormat('hh:mm a').format(booking.endTime)}  •  '
                    '${booking.slotIds.length} slot${booking.slotIds.length > 1 ? 's' : ''}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                Text('Booking #$shortId',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.onSurfaceVar)),
                if (booking.couponCode != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.offerBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(booking.couponCode!,
                        style: const TextStyle(
                            color: AppColors.offer,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
                const Spacer(),
                Text('View receipt',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _TournamentsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: Center(
        child: Text('Coming soon!', style: AppTextStyles.bodyLarge),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final hasMultipleRoles = (user?.roles.length ?? 0) > 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: AppSpacing.lg),

          // ── Avatar + name ──────────────────────────────────────────────────
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null
                  ? Text(
                      (user != null && user.name.isNotEmpty)
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: AppTextStyles.displayLarge
                          .copyWith(color: AppColors.primary),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(user?.name ?? 'User', style: AppTextStyles.titleLarge),
          ),
          Center(
            child: Text(
              user?.email ?? '',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVar),
            ),
          ),
          // Active role badge
          if (user != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(child: _RoleBadge(role: user.activeRole)),
          ],

          // ── Mode switcher (only for multi-role accounts) ──────────────────
          if (hasMultipleRoles) ...[
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text('Switch Mode',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.onSurfaceVar)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ModeCard(
              icon: Icons.sports_soccer,
              label: 'Player Mode',
              subtitle: 'Browse and book venues',
              role: UserRole.player,
              isActive: user?.activeRole == UserRole.player,
              onTap: () {
                ref.read(authRepositoryProvider).switchRole(UserRole.player);
                ref.read(_navIndexProvider.notifier).set(0);
                context.go('/');
              },
            ),
            if (user?.roles.contains(UserRole.owner) == true)
              _ModeCard(
                icon: Icons.store_outlined,
                label: 'Owner Mode',
                subtitle: 'Manage your venues',
                role: UserRole.owner,
                isActive: user?.activeRole == UserRole.owner,
                onTap: () {
                  ref.read(authRepositoryProvider).switchRole(UserRole.owner);
                  context.go('/owner');
                },
              ),
            if (user?.roles.contains(UserRole.admin) == true)
              _ModeCard(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Admin Mode',
                subtitle: 'Platform administration',
                role: UserRole.admin,
                isActive: user?.activeRole == UserRole.admin,
                onTap: () {
                  ref.read(authRepositoryProvider).switchRole(UserRole.admin);
                  context.go('/admin');
                },
              ),
          ],

          // ── Actions ────────────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history_outlined,
                color: AppColors.onSurfaceVar),
            title: Text('My Bookings', style: AppTextStyles.bodyLarge),
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.outlineVariant),
            onTap: () => context.push('/my-bookings'),
          ),
          ListTile(
            leading: const Icon(Icons.headset_mic_outlined,
                color: AppColors.onSurfaceVar),
            title: Text('Contact Us', style: AppTextStyles.bodyLarge),
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.outlineVariant),
            onTap: () => context.push('/contact'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: Text('Sign Out',
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error)),
            onTap: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}

// ── Role badge ─────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg) = switch (role) {
      UserRole.admin => ('Admin', Icons.admin_panel_settings, AppColors.error),
      UserRole.owner => ('Owner', Icons.store, AppColors.peakTime),
      UserRole.player => ('Player', Icons.sports_soccer, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: bg),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                  color: bg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Mode switch card ───────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final UserRole role;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.role,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.outline,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 20,
                  color: isActive ? Colors.white : AppColors.onSurfaceVar),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.titleMedium.copyWith(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.onSurface)),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle,
                  color: AppColors.primary, size: 20)
            else
              const Icon(Icons.chevron_right,
                  color: AppColors.outlineVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
