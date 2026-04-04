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
        children: const [
          _VenuesManagement(),
          _UsersManagement(),
        ],
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
      data: (venues) => ListView.builder(
        itemCount: venues.length,
        itemBuilder: (context, index) {
          final venue = venues[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(venue.name),
              subtitle: Text('Current Commission: ${venue.commissionRate}%'),
              trailing: DropdownButton<int>(
                value: venue.commissionRate == 0 ? 3 : venue.commissionRate,
                items: [3, 5, 8].map((rate) {
                  return DropdownMenuItem(value: rate, child: Text('$rate%'));
                }).toList(),
                onChanged: (newRate) {
                  if (newRate != null) {
                    ref
                        .read(adminControllerProvider.notifier)
                        .updateCommissionRate(venue.id, newRate);
                  }
                },
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
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
                  child: user.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(user.name),
                subtitle: Text('${user.email}\nRoles: ${user.roles.map((r) => r.name).join(', ')}'),
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
                        ref.read(authRepositoryProvider).updateUser(
                              user.copyWith(roles: newRoles),
                            );
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
