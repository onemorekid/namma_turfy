import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namma_turfy/domain/entities/user.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/providers/venue_providers.dart';
import 'package:namma_turfy/presentation/widgets/app_drawer.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super-Admin Dashboard'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [_VenuesManagement(), _UsersManagement()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.red[800],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.stadium), label: 'Venues'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
        ],
      ),
    );
  }
}

class _VenuesManagement extends ConsumerWidget {
  const _VenuesManagement();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesState = ref.watch(venuesProvider);

    return venuesState.when(
      data: (venues) {
        if (venues.isEmpty) {
          return const Center(child: Text('No venues found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: venues.length,
          itemBuilder: (context, index) {
            final venue = venues[index];
            final rate = venue.commissionRate;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                venue.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                venue.location,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Owner ID: ${venue.ownerId.substring(0, 8)}...',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Commission badge
                        GestureDetector(
                          onTap: () => _showRateDialog(
                            context,
                            ref,
                            venue.id,
                            venue.name,
                            rate,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _rateColor(rate).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _rateColor(rate)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$rate%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _rateColor(rate),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: _rateColor(rate),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Suspension toggle
                        const Text('Active', style: TextStyle(fontSize: 13)),
                        Switch(
                          value: !venue.isSuspended,
                          activeThumbColor: const Color(0xFF35CA67),
                          activeTrackColor: const Color(
                            0xFF35CA67,
                          ).withValues(alpha: 0.5),
                          onChanged: (active) {
                            ref
                                .read(venueRepositoryProvider)
                                .saveVenue(
                                  venue.copyWith(isSuspended: !active),
                                );
                          },
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _showRateDialog(
                            context,
                            ref,
                            venue.id,
                            venue.name,
                            rate,
                          ),
                          icon: const Icon(Icons.percent, size: 16),
                          label: const Text('Set Commission'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  /// Color coding: green ≤10%, orange ≤20%, red >20%
  Color _rateColor(int rate) {
    if (rate <= 10) return Colors.green;
    if (rate <= 20) return Colors.orange;
    return Colors.red;
  }

  void _showRateDialog(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    String venueName,
    int currentRate,
  ) {
    final controller = TextEditingController(text: currentRate.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commission Rate — $venueName'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set the platform commission % for this venue.\n'
                'This rate is applied on every booking.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Commission %',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                  helperText: 'Minimum 1% · Maximum 50%',
                ),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null) return 'Enter a whole number';
                  if (n < 1) return 'Minimum is 1%';
                  if (n > 50) return 'Maximum is 50%';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Quick preset chips
              Wrap(
                spacing: 8,
                children: [5, 8, 10, 12, 15, 20].map((preset) {
                  return ActionChip(
                    label: Text('$preset%'),
                    onPressed: () => controller.text = preset.toString(),
                    backgroundColor: preset == currentRate
                        ? const Color(0xFFE8F5E9)
                        : null,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final newRate = int.parse(controller.text);
              ref
                  .read(adminControllerProvider.notifier)
                  .updateCommissionRate(venueId, newRate);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$venueName commission updated to $newRate%'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save Rate'),
          ),
        ],
      ),
    );
  }
}

class _UsersManagement extends ConsumerWidget {
  const _UsersManagement();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) return const Center(child: Text('No users found'));

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final isOwner = user.roles.contains(UserRole.owner);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(user.name),
                subtitle: Text(
                  '${user.email}\nRoles: ${user.roles.map((r) => r.name).join(', ')}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Owner: '),
                    Switch(
                      value: isOwner,
                      onChanged: (value) {
                        final newRoles = List<UserRole>.from(user.roles);
                        if (value) {
                          if (!newRoles.contains(UserRole.owner)) {
                            newRoles.add(UserRole.owner);
                          }
                        } else {
                          newRoles.remove(UserRole.owner);
                        }
                        ref
                            .read(authRepositoryProvider)
                            .updateUser(user.copyWith(roles: newRoles));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
