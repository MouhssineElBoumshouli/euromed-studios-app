/// Rooms and studios (R-01). Several studios can share one physical
/// room, as the floor plan shows: booking one blocks the others.
library;

enum Zone {
  production('Production'),
  pedagogy('Pédagogie numérique'),
  postproduction('Postproduction');

  const Zone(this.label);
  final String label;
}

/// A physical room on the floor plan.
class Room {
  const Room({required this.id, required this.name});
  final String id;
  final String name;
}

/// Capabilities from the brochure's technical matrix.
enum Capability {
  audioPro('Audio pro'),
  camerasPro('Caméras pro'),
  streaming('Streaming live'),
  multicam('MultiCam'),
  greenScreen('Fond vert'),
  teleprompter('Téléprompteur'),
  postproduction('Postproduction'),
  teaching('Usage pédagogique');

  const Capability(this.label);
  final String label;
}

class Studio {
  const Studio({
    required this.id,
    required this.name,
    required this.zone,
    required this.roomId,
    required this.photo,
    required this.description,
    required this.capabilities,
    required this.isolation,
    required this.capacity,
    required this.included,
    this.bookable = true,
    this.professorPriority = false,
  });

  final String id;
  final String name;
  final Zone zone;
  final String roomId;

  /// Asset path of the photo.
  final String photo;
  final String description;
  final Set<Capability> capabilities;

  /// Acoustic isolation rating from the technical matrix (1–5).
  final int isolation;
  final int capacity;

  /// Equipment that comes with the studio.
  final List<String> included;
  final bool bookable;

  /// Professors get priority here (R-04).
  final bool professorPriority;
}
