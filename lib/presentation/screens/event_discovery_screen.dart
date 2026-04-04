import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namma_turfy/domain/entities/sport_event.dart';
import 'package:namma_turfy/presentation/providers/auth_providers.dart';
import 'package:namma_turfy/presentation/providers/event_providers.dart';

class EventDiscoveryScreen extends ConsumerWidget {
  const EventDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsState = ref.watch(eventsProvider);
    final userState = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Event Discovery')),
      body: eventsState.when(
        data: (events) => events.isEmpty
            ? const Center(
                child: Text('No events found. Be the first to host one!'),
              )
            : ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final isJoined = event.participants.contains(
                    userState.value?.id,
                  );

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text(
                        event.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${event.sport} • ${event.type}'),
                          Text('${event.date} at ${event.time}'),
                          Text('Participants: ${event.participants.length}'),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: isJoined || userState.value == null
                            ? null
                            : () {
                                ref
                                    .read(eventControllerProvider.notifier)
                                    .joinEvent(event.id, userState.value!.id);
                              },
                        child: Text(isJoined ? 'Joined' : 'Join'),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showCreateEventDialog(context, ref, userState.value!.id),
        label: const Text('Host Event'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateEventDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final sportController = TextEditingController();
    final typeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Host New Event'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: sportController,
                decoration: const InputDecoration(labelText: 'Sport'),
              ),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Type (e.g. Tournament)',
                ),
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
            onPressed: () {
              final event = SportEvent(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text,
                description: descController.text,
                venueId: '',
                date: '2026-04-01', // Placeholder
                time: '18:00', // Placeholder
                organizerId: userId,
                participants: [userId],
                sport: sportController.text,
                type: typeController.text,
              );
              ref.read(eventControllerProvider.notifier).createEvent(event);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
