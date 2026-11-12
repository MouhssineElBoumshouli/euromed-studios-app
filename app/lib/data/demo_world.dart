/// The demo world: fictional people and bookings, real studios.
///
/// Every number here is consistent: quotas, dates, statuses, who
/// approved what. "Now" is fixed at Wednesday 11 November 2026, 10:05,
/// so the preview always tells the same story.
///
/// All names are invented (CLAUDE.md: no real-looking personal data).
library;

import '../domain/bookings.dart';
import '../domain/people.dart';
import '../domain/policy.dart';
import '../domain/studios.dart';

abstract final class DemoWorld {
  static final now = DateTime(2026, 11, 11, 10, 5);

  static DateTime _at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 11, day, hour, minute);

  static const policy = Policy();

  // ---------------------------------------------------------------- places
  static const establishments = [
    Establishment(
      id: 'eidia',
      short: 'EIDIA',
      name: 'École d’Ingénierie Digitale et d’Intelligence Artificielle',
    ),
    Establishment(
      id: 'emadu',
      short: 'EMADU',
      name: 'École d’Architecture, de Design et d’Urbanisme',
    ),
  ];

  static const rooms = [
    Room(id: 'area1', name: 'Area 1'),
    Room(id: 'area2', name: 'Area 2'),
    Room(id: 'area3', name: 'Area 3'),
    Room(id: 'area4', name: 'Area 4'),
    Room(id: 'montage', name: 'Espace Montage'),
    Room(id: 'ctrl1', name: 'Régie 01'),
    Room(id: 'ctrl2', name: 'Régie 02'),
  ];

  static const studios = [
    Studio(
      id: 'plateau_tv',
      name: 'Plateau TV',
      zone: Zone.production,
      roomId: 'area2',
      photo: 'assets/photos/plateau_tv.jpg',
      description:
          'Le plateau principal : desk lumineux, 4 places, décor UEMF et '
          'tournage multicaméra. Idéal pour émissions, débats et Web TV.',
      capabilities: {
        Capability.audioPro,
        Capability.camerasPro,
        Capability.streaming,
        Capability.multicam,
        Capability.teleprompter,
        Capability.postproduction,
        Capability.teaching,
      },
      isolation: 4,
      capacity: 4,
      included: [
        '4 caméras robotisées',
        'Desk lumineux 4 places',
        'Téléprompteur',
        'Éclairage studio complet',
      ],
    ),
    Studio(
      id: 'radio',
      name: 'Euromed Radio',
      zone: Zone.production,
      roomId: 'area2',
      photo: 'assets/photos/radio.jpg',
      description:
          'Le studio radio, installé sur le plateau TV. Pour émissions '
          'audio en direct ou enregistrées.',
      capabilities: {
        Capability.audioPro,
        Capability.streaming,
        Capability.postproduction,
        Capability.teaching,
      },
      isolation: 5,
      capacity: 4,
      included: ['4 micros broadcast', 'Console audio', 'Retours casque'],
    ),
    Studio(
      id: 'podcast',
      name: 'Studio Podcast',
      zone: Zone.production,
      roomId: 'area1',
      photo: 'assets/photos/podcast.jpg',
      description:
          'Un salon d’enregistrement chaleureux pour podcasts, interviews '
          'et émissions audio filmées. Jusqu’à 4 invités autour de la table.',
      capabilities: {
        Capability.audioPro,
        Capability.camerasPro,
        Capability.streaming,
        Capability.postproduction,
        Capability.teaching,
      },
      isolation: 5,
      capacity: 4,
      included: [
        '4 micros broadcast sur bras articulés',
        '2 caméras robotisées',
        'Éclairage d’ambiance réglable',
      ],
    ),
    Studio(
      id: 'chroma',
      name: 'Chroma Key Studio',
      zone: Zone.production,
      roomId: 'area3',
      photo: 'assets/photos/photo.jpg',
      description: 'Fond vert et éclairage studio pour incrustation, tournages '
          'multicaméra et contenus créatifs.',
      capabilities: {
        Capability.audioPro,
        Capability.camerasPro,
        Capability.streaming,
        Capability.multicam,
        Capability.greenScreen,
        Capability.postproduction,
        Capability.teaching,
      },
      isolation: 4,
      capacity: 3,
      included: ['Fond vert', '4 projecteurs LED', 'Caméra Canon XA'],
    ),
    Studio(
      id: 'photo',
      name: 'Studio Photographie',
      zone: Zone.production,
      roomId: 'area3',
      photo: 'assets/photos/photo.jpg',
      description:
          'Fonds papier, boîtes à lumière et mobilier pour portraits et '
          'photos produit.',
      capabilities: {
        Capability.camerasPro,
        Capability.greenScreen,
        Capability.postproduction,
      },
      isolation: 3,
      capacity: 3,
      included: ['3 fonds papier', '2 softbox', '2 boules lumineuses'],
    ),
    Studio(
      id: 'pedago',
      name: 'Studio Pédagogique',
      zone: Zone.pedagogy,
      roomId: 'area4',
      photo: 'assets/photos/pedago.jpg',
      description:
          'Pour enregistrer des cours, capsules et MOOC face caméra, avec '
          'téléprompteur et écran interactif. Priorité aux enseignants.',
      capabilities: {
        Capability.audioPro,
        Capability.camerasPro,
        Capability.streaming,
        Capability.teleprompter,
        Capability.postproduction,
        Capability.teaching,
      },
      isolation: 4,
      capacity: 2,
      included: ['Téléprompteur', 'Écran interactif 86"', 'Micro-cravate'],
      professorPriority: true,
    ),
    Studio(
      id: 'speedmooc',
      name: 'SpeedMOOC',
      zone: Zone.pedagogy,
      roomId: 'area4',
      photo: 'assets/photos/speedmooc.jpg',
      description:
          'Captation rapide de cours : vous enseignez, la régie produit la '
          'vidéo en direct. Priorité aux enseignants.',
      capabilities: {
        Capability.audioPro,
        Capability.camerasPro,
        Capability.streaming,
        Capability.teleprompter,
        Capability.postproduction,
        Capability.teaching,
      },
      isolation: 3,
      capacity: 1,
      included: ['Réalisation en direct', 'Téléprompteur'],
      professorPriority: true,
    ),
    Studio(
      id: 'montage',
      name: 'Espace Montage',
      zone: Zone.postproduction,
      roomId: 'montage',
      photo: 'assets/photos/regie.jpg',
      description: 'Postes de montage vidéo et de mixage audio.',
      capabilities: {
        Capability.audioPro,
        Capability.camerasPro,
        Capability.postproduction,
      },
      isolation: 4,
      capacity: 2,
      included: ['Station de montage', 'Casque de mixage'],
    ),
    Studio(
      id: 'regie_tv',
      name: 'Régie TV',
      zone: Zone.postproduction,
      roomId: 'ctrl1',
      photo: 'assets/photos/regie.jpg',
      description:
          'Régie du Plateau TV. Réservée automatiquement avec le studio.',
      capabilities: {
        Capability.audioPro,
        Capability.camerasPro,
        Capability.streaming,
        Capability.multicam,
        Capability.postproduction,
      },
      isolation: 4,
      capacity: 3,
      included: [],
      bookable: false,
    ),
    Studio(
      id: 'salon_vip',
      name: 'Salon VIP',
      zone: Zone.production,
      roomId: 'area1',
      photo: 'assets/photos/salon_wide.jpg',
      description: 'Espace d’accueil des invités. Non réservable.',
      capabilities: {},
      isolation: 1,
      capacity: 4,
      included: [],
      bookable: false,
    ),
  ];

  // ---------------------------------------------------------------- people
  static const clubs = [
    Club(id: 'club_av', name: 'Club Audiovisuel UEMF'),
    Club(id: 'club_debat', name: 'Club Débats & Éloquence'),
  ];

  static const people = [
    Person(
      id: 'yasmine',
      firstName: 'Yasmine',
      lastName: 'Mansouri',
      roles: {Role.student},
      establishmentId: 'eidia',
      title: 'Étudiante · EIDIA',
    ),
    Person(
      id: 'adam',
      firstName: 'Adam',
      lastName: 'Kettani',
      roles: {Role.student, Role.clubRepresentative},
      establishmentId: 'emadu',
      title: 'Étudiant · EMADU · Club Audiovisuel',
      clubIds: ['club_av'],
    ),
    Person(
      id: 'rami',
      firstName: 'Driss',
      lastName: 'Rami',
      roles: {Role.professor},
      establishmentId: 'eidia',
      title: 'Enseignant-chercheur · EIDIA',
    ),
    Person(
      id: 'nadia',
      firstName: 'Nadia',
      lastName: 'Ennaji',
      roles: {Role.communication},
      title: 'Équipe Communication',
    ),
    Person(
      id: 'omar',
      firstName: 'Omar',
      lastName: 'Berrada',
      roles: {Role.externalClient},
      title: 'Atlas Média · client externe',
    ),
    Person(
      id: 'amrani',
      firstName: 'Karim',
      lastName: 'Amrani',
      roles: {Role.entityApprover},
      title: 'Responsable Vie Étudiante',
      approverScopes: [
        ApproverScope(RequesterType.student),
        ApproverScope(RequesterType.club),
      ],
    ),
    Person(
      id: 'benjelloun',
      firstName: 'Hind',
      lastName: 'Benjelloun',
      roles: {Role.entityApprover, Role.professor},
      establishmentId: 'eidia',
      title: 'Directrice · EIDIA',
      approverScopes: [
        ApproverScope(RequesterType.professor, establishmentId: 'eidia'),
      ],
    ),
    Person(
      id: 'lahlou',
      firstName: 'Youssef',
      lastName: 'Lahlou',
      roles: {Role.entityApprover},
      title: 'Direction de la Communication',
      approverScopes: [ApproverScope(RequesterType.communication)],
    ),
    Person(
      id: 'fassi',
      firstName: 'Leila',
      lastName: 'Fassi',
      roles: {Role.entityApprover},
      title: 'Vice-Présidence Exécutive',
      approverScopes: [ApproverScope(RequesterType.external)],
    ),
    Person(
      id: 'tazi',
      firstName: 'Mehdi',
      lastName: 'Tazi',
      roles: {Role.studioManager},
      title: 'Responsable des Studios',
    ),
    Person(
      id: 'haddad',
      firstName: 'Samir',
      lastName: 'Haddad',
      roles: {Role.regisseur},
      title: 'Régisseur · Euromed Studios',
    ),
    Person(
      id: 'idrissi',
      firstName: 'Sara',
      lastName: 'Idrissi',
      roles: {Role.admin},
      title: 'Administratrice · Euromed Studios',
    ),
  ];

  // ------------------------------------------------------------- equipment
  static const equipment = [
    EquipmentItem(
      id: 'kit_cam',
      name: 'Kit caméra mobile',
      detail: 'Canon XA · trépied · 2 batteries',
      icon: 'camera',
      stock: 3,
    ),
    EquipmentItem(
      id: 'lav_mic',
      name: 'Micro-cravate sans fil',
      detail: 'Récepteur inclus',
      icon: 'mic',
      stock: 3,
    ),
    EquipmentItem(
      id: 'hand_mic',
      name: 'Micro main',
      detail: 'Dynamique, avec pied',
      icon: 'mic',
      stock: 4,
    ),
    EquipmentItem(
      id: 'led_kit',
      name: 'Kit éclairage LED',
      detail: '2 panneaux + softbox',
      icon: 'light',
      stock: 2,
    ),
  ];

  // --------------------------------------------------------------- bookings
  static final bookings = <Booking>[
    // Yasmine: this week 1 h used out of 2 h.
    Booking(
      id: 'b1',
      reference: 'ES-2026-0138',
      requesterId: 'yasmine',
      requesterType: RequesterType.student,
      establishmentId: 'eidia',
      studioId: 'plateau_tv',
      start: _at(12, 14),
      end: _at(12, 15),
      activity: Activity.filming,
      status: BookingStatus.approved,
      technicianId: 'haddad',
      equipment: const [
        EquipmentRequest(
          itemId: 'kit_cam',
          quantity: 1,
          required: true,
          outcome: EquipmentOutcome.confirmed,
        ),
      ],
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(9, 18, 20),
          actorId: 'yasmine',
        ),
        BookingEvent(
          type: BookingEventType.entityApproved,
          at: _at(10, 9, 15),
          actorId: 'amrani',
        ),
        BookingEvent(
          type: BookingEventType.studioApproved,
          at: _at(10, 16, 40),
          actorId: 'tazi',
          comment: 'S. Haddad sera en régie.',
        ),
      ],
    ),
    // Next week: 2 h requested out of 2 h (quota full next week).
    Booking(
      id: 'b2',
      reference: 'ES-2026-0142',
      requesterId: 'yasmine',
      requesterType: RequesterType.student,
      establishmentId: 'eidia',
      studioId: 'podcast',
      start: _at(16, 10),
      end: _at(16, 11),
      activity: Activity.recording,
      status: BookingStatus.pendingStudio,
      projectId: 'p1',
      note: 'Enregistrement avec deux invités.',
      equipment: const [
        EquipmentRequest(itemId: 'lav_mic', quantity: 2, required: false),
      ],
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(10, 19, 42),
          actorId: 'yasmine',
        ),
        BookingEvent(
          type: BookingEventType.entityApproved,
          at: _at(11, 9, 15),
          actorId: 'amrani',
          comment: 'Projet pertinent, bon courage.',
        ),
      ],
    ),
    Booking(
      id: 'b3',
      reference: 'ES-2026-0145',
      requesterId: 'yasmine',
      requesterType: RequesterType.student,
      establishmentId: 'eidia',
      studioId: 'chroma',
      start: _at(18, 9),
      end: _at(18, 10),
      activity: Activity.filming,
      status: BookingStatus.pendingEntity,
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(11, 8, 30),
          actorId: 'yasmine',
        ),
      ],
    ),
    Booking(
      id: 'b4',
      reference: 'ES-2026-0121',
      requesterId: 'yasmine',
      requesterType: RequesterType.student,
      establishmentId: 'eidia',
      studioId: 'podcast',
      start: _at(2, 14),
      end: _at(2, 15),
      activity: Activity.recording,
      status: BookingStatus.completed,
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(-1, 11),
          actorId: 'yasmine',
        ),
        BookingEvent(
          type: BookingEventType.entityApproved,
          at: _at(0, 10),
          actorId: 'amrani',
        ),
        BookingEvent(
          type: BookingEventType.studioApproved,
          at: _at(1, 9, 30),
          actorId: 'tazi',
        ),
        BookingEvent(
          type: BookingEventType.completed,
          at: _at(2, 15),
          actorId: 'haddad',
        ),
      ],
    ),
    Booking(
      id: 'b5',
      reference: 'ES-2026-0127',
      requesterId: 'yasmine',
      requesterType: RequesterType.student,
      establishmentId: 'eidia',
      studioId: 'speedmooc',
      start: _at(6, 10),
      end: _at(6, 11),
      activity: Activity.filming,
      status: BookingStatus.refused,
      refusalReason:
          'Créneau réservé à un tournage MOOC prioritaire. Le Studio '
          'Pédagogique est libre le même jour à 14:00.',
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(3, 16),
          actorId: 'yasmine',
        ),
        BookingEvent(
          type: BookingEventType.entityApproved,
          at: _at(4, 9),
          actorId: 'amrani',
        ),
        BookingEvent(
          type: BookingEventType.refused,
          at: _at(4, 15, 10),
          actorId: 'tazi',
          comment: 'Créneau réservé à un tournage MOOC prioritaire. Le Studio '
              'Pédagogique est libre le même jour à 14:00.',
        ),
      ],
    ),
    // Communication team is on the Plateau right now.
    Booking(
      id: 'b6',
      reference: 'ES-2026-0131',
      requesterId: 'nadia',
      requesterType: RequesterType.communication,
      studioId: 'plateau_tv',
      start: _at(11, 9),
      end: _at(11, 12),
      activity: Activity.filming,
      status: BookingStatus.approved,
      technicianId: 'haddad',
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(5, 10),
          actorId: 'nadia',
        ),
        BookingEvent(
          type: BookingEventType.entityApproved,
          at: _at(5, 14),
          actorId: 'lahlou',
        ),
        BookingEvent(
          type: BookingEventType.studioApproved,
          at: _at(6, 9),
          actorId: 'tazi',
        ),
        BookingEvent(
          type: BookingEventType.checkedIn,
          at: _at(11, 8, 58),
          actorId: 'haddad',
        ),
      ],
    ),
    Booking(
      id: 'b7',
      reference: 'ES-2026-0133',
      requesterId: 'rami',
      requesterType: RequesterType.professor,
      establishmentId: 'eidia',
      studioId: 'pedago',
      start: _at(12, 9),
      end: _at(12, 12),
      activity: Activity.recording,
      status: BookingStatus.approved,
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(6, 11),
          actorId: 'rami',
        ),
        BookingEvent(
          type: BookingEventType.entityApproved,
          at: _at(6, 17),
          actorId: 'benjelloun',
        ),
        BookingEvent(
          type: BookingEventType.studioApproved,
          at: _at(9, 10),
          actorId: 'tazi',
        ),
      ],
    ),
    Booking(
      id: 'b8',
      reference: 'ES-2026-0140',
      requesterId: 'adam',
      requesterType: RequesterType.club,
      clubId: 'club_av',
      establishmentId: 'emadu',
      studioId: 'plateau_tv',
      start: _at(13, 15),
      end: _at(13, 17),
      activity: Activity.filming,
      status: BookingStatus.pendingStudio,
      note: 'Tournage du talk-show du club, 3 invités.',
      equipment: const [
        EquipmentRequest(itemId: 'hand_mic', quantity: 2, required: true),
        EquipmentRequest(itemId: 'led_kit', quantity: 1, required: false),
      ],
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(10, 11, 5),
          actorId: 'adam',
        ),
        BookingEvent(
          type: BookingEventType.entityApproved,
          at: _at(10, 17, 30),
          actorId: 'amrani',
        ),
      ],
    ),
    Booking(
      id: 'b9',
      reference: 'ES-2026-0143',
      requesterId: 'omar',
      requesterType: RequesterType.external,
      studioId: 'plateau_tv',
      start: _at(17, 10),
      end: _at(17, 12),
      activity: Activity.filming,
      status: BookingStatus.pendingEntity,
      note: 'Interview pour un documentaire. Devis demandé.',
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(10, 21, 10),
          actorId: 'omar',
        ),
      ],
    ),
    Booking(
      id: 'b10',
      reference: 'ES-2026-0144',
      requesterId: 'rami',
      requesterType: RequesterType.professor,
      establishmentId: 'eidia',
      studioId: 'speedmooc',
      start: _at(13, 9),
      end: _at(13, 11),
      activity: Activity.recording,
      status: BookingStatus.pendingEntity,
      projectId: 'p2',
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(11, 7, 50),
          actorId: 'rami',
        ),
      ],
    ),
    Booking(
      id: 'b11',
      reference: 'ES-2026-0141',
      requesterId: 'nadia',
      requesterType: RequesterType.communication,
      studioId: 'podcast',
      start: _at(12, 10),
      end: _at(12, 12),
      activity: Activity.recording,
      status: BookingStatus.pendingEntity,
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(10, 15, 20),
          actorId: 'nadia',
        ),
      ],
    ),
    Booking(
      id: 'b12',
      reference: 'ES-2026-0146',
      requesterId: 'adam',
      requesterType: RequesterType.student,
      establishmentId: 'emadu',
      studioId: 'photo',
      start: _at(17, 14),
      end: _at(17, 15),
      activity: Activity.filming,
      status: BookingStatus.pendingEntity,
      history: [
        BookingEvent(
          type: BookingEventType.submitted,
          at: _at(11, 9, 40),
          actorId: 'adam',
        ),
      ],
    ),
  ];

  static final maintenance = [
    MaintenanceBlock(
      roomId: 'area4',
      start: _at(11, 14),
      end: _at(11, 17),
      reason: 'Remplacement du téléprompteur',
    ),
  ];
}
