import 'dart:ui';

/// Single source of truth for all spatial data on CMC Horizon Station.
class StationMap {
  StationMap._();

  // ── Rooms ───────────────────────────────────────────────────────────────

  static const rooms = <String, Rect>{
    'Command Bridge': Rect.fromLTWH(0.05, 0.05, 0.35, 0.20),
    'Comms Array': Rect.fromLTWH(0.60, 0.05, 0.35, 0.20),
    'Research Lab': Rect.fromLTWH(0.20, 0.35, 0.60, 0.25),
    'Engineering Bay': Rect.fromLTWH(0.05, 0.70, 0.35, 0.25),
    'Life Support': Rect.fromLTWH(0.60, 0.70, 0.35, 0.25),
  };

  // ── Corridors ───────────────────────────────────────────────────────────

  static const corridors = <Rect>[
    Rect.fromLTWH(0.38, 0.10, 0.24, 0.08), // Top horizontal
    Rect.fromLTWH(0.38, 0.55, 0.24, 0.20), // Bottom horizontal
    Rect.fromLTWH(0.15, 0.25, 0.08, 0.12), // Left vertical
    Rect.fromLTWH(0.77, 0.25, 0.08, 0.12), // Right vertical
  ];

  /// All walkable areas (rooms + corridors). Used for collision detection.
  static final walkableAreas = <Rect>[
    ...rooms.values,
    ...corridors,
  ];

  /// Returns true if the normalised point (x, y) is inside any walkable area.
  /// [padding] adds a small buffer around the player radius.
  /// [sealedZone] is the name of a room sealed by airlock breach (excluded from walkable).
  static bool isWalkable(double x, double y, {double padding = 0.01, String? sealedZone}) {
    for (final rect in walkableAreas) {
      if (x >= rect.left - padding &&
          x <= rect.right + padding &&
          y >= rect.top - padding &&
          y <= rect.bottom + padding) {
        // Check if this area is a sealed room
        if (sealedZone != null) {
          final sealedRect = rooms[sealedZone];
          if (sealedRect != null && sealedRect == rect) {
            continue; // Skip sealed room
          }
        }
        return true;
      }
    }
    return false;
  }

  // ── Task zones ──────────────────────────────────────────────────────────

  /// Maps task ID → normalised position on the map.
  static const taskZones = <String, Offset>{
    'navigation_calibration': Offset(0.12, 0.12),
    'id_verification': Offset(0.25, 0.12),
    'signal_boost': Offset(0.68, 0.12),
    'satellite_align': Offset(0.80, 0.12),
    'sample_analysis': Offset(0.35, 0.47),
    'data_upload': Offset(0.55, 0.47),
    'reactor_alignment': Offset(0.15, 0.80),
    'power_routing': Offset(0.28, 0.80),
    'air_scrubber': Offset(0.68, 0.80),
    'filter_replace': Offset(0.82, 0.80),
  };

  // ── Vent network ────────────────────────────────────────────────────────

  static const ventPositions = <String, Offset>{
    'eng_vent': Offset(0.20, 0.82),
    'maint_vent': Offset(0.50, 0.65),
    'life_vent': Offset(0.75, 0.82),
    'cmd_vent': Offset(0.20, 0.12),
    'comms_vent': Offset(0.75, 0.12),
  };

  static const ventNames = <String, String>{
    'eng_vent': 'Engineering Bay',
    'maint_vent': 'Maintenance Tunnels',
    'life_vent': 'Life Support',
    'cmd_vent': 'Command Bridge',
    'comms_vent': 'Comms Array',
  };

  /// Bidirectional vent connections.
  static const ventConnections = <String, List<String>>{
    'eng_vent': ['maint_vent'],
    'maint_vent': ['eng_vent', 'life_vent'],
    'life_vent': ['maint_vent'],
    'cmd_vent': ['comms_vent'],
    'comms_vent': ['cmd_vent'],
  };

  static const double ventInteractRadius = 0.06;

  /// Returns the nearest vent ID if the player is within [ventInteractRadius],
  /// or null if no vent is close enough.
  static String? nearestVent(double px, double py) {
    String? closest;
    double closestDist = double.infinity;
    for (final entry in ventPositions.entries) {
      final dx = entry.value.dx - px;
      final dy = entry.value.dy - py;
      final dist = dx * dx + dy * dy;
      if (dist < closestDist) {
        closestDist = dist;
        closest = entry.key;
      }
    }
    if (closestDist < ventInteractRadius * ventInteractRadius) {
      return closest;
    }
    return null;
  }

  /// Returns the list of vent IDs reachable from [ventId].
  static List<String> ventDestinations(String ventId) {
    return ventConnections[ventId] ?? [];
  }

  // ── Sabotage fix panels ─────────────────────────────────────────────────

  /// Each sabotage type has one or more fix panel locations.
  static const fixPanels = <String, Map<String, Offset>>{
    'reactorCascade': {
      'reactor_panel_a': Offset(0.12, 0.78),
      'reactor_panel_b': Offset(0.30, 0.78),
    },
    'blackoutProtocol': {
      'breaker_a': Offset(0.15, 0.55),
      'breaker_b': Offset(0.75, 0.55),
    },
    'commsJamming': {
      'comms_terminal': Offset(0.70, 0.10),
    },
    'airlockBreach': {
      'airlock_console': Offset(0.15, 0.10),
    },
  };

  /// Number of simultaneous fixers required to clear each sabotage.
  static const fixRequirements = <String, int>{
    'reactorCascade': 2,
    'blackoutProtocol': 2,
    'commsJamming': 1,
    'airlockBreach': 1,
  };

  static const double fixInteractRadius = 0.06;

  /// Returns the nearest fix panel ID for the given sabotage type, or null.
  static String? nearestFixPanel(String sabotageType, double px, double py) {
    final panels = fixPanels[sabotageType];
    if (panels == null) return null;
    String? closest;
    double closestDist = double.infinity;
    for (final entry in panels.entries) {
      final dx = entry.value.dx - px;
      final dy = entry.value.dy - py;
      final dist = dx * dx + dy * dy;
      if (dist < closestDist) {
        closestDist = dist;
        closest = entry.key;
      }
    }
    if (closestDist < fixInteractRadius * fixInteractRadius) {
      return closest;
    }
    return null;
  }
}
