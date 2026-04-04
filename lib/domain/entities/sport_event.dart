class SportEvent {
  final String id;
  final String title;
  final String description;
  final String venueId; // Optional link to a venue
  final String date;
  final String time;
  final String organizerId;
  final List<String> participants;
  final String sport;
  final String type; // Tournament, Friendly Match, Fitness Event

  const SportEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.venueId,
    required this.date,
    required this.time,
    required this.organizerId,
    required this.participants,
    required this.sport,
    required this.type,
  });
}
