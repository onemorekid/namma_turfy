import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namma_turfy/domain/entities/user.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  user?.name ?? 'Guest',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home / Player Mode'),
            selected: user?.activeRole == UserRole.player,
            onTap: () {
              if (user?.activeRole != UserRole.player) {
                ref.read(authRepositoryProvider).switchRole(UserRole.player);
              }
              Navigator.pop(context);
              context.go('/');
            },
          ),
          if (user?.activeRole == UserRole.player)
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('My Bookings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/my-bookings');
              },
            ),
          if (user?.activeRole == UserRole.player)
            ListTile(
              leading: const Icon(Icons.sports),
              title: const Text('Events'),
              onTap: () {
                Navigator.pop(context);
                context.push('/events');
              },
            ),
          if (user != null && user.roles.length > 1) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Switch Mode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            if (user.roles.contains(UserRole.owner))
              ListTile(
                leading: const Icon(Icons.store),
                title: const Text('Owner Mode'),
                selected: user.activeRole == UserRole.owner,
                onTap: () {
                  if (user.activeRole != UserRole.owner) {
                    ref.read(authRepositoryProvider).switchRole(UserRole.owner);
                  }
                  Navigator.pop(context);
                  context.go('/owner');
                },
              ),
            if (user.roles.contains(UserRole.admin))
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Admin Mode'),
                selected: user.activeRole == UserRole.admin,
                onTap: () {
                  if (user.activeRole != UserRole.admin) {
                    ref.read(authRepositoryProvider).switchRole(UserRole.admin);
                  }
                  Navigator.pop(context);
                  context.go('/admin');
                },
              ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}
