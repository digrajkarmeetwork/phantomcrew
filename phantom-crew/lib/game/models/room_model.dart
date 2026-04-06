enum RoomPhase { lobby, roleReveal, playing, meeting, ended }
enum SabotageType { none, reactorCascade, blackoutProtocol, commsJamming, airlockBreach }
enum WinCondition { none, guardiansTasksComplete, guardiansEliminatedPhantoms, phantomsOutnumber, phantomsCascade }

class RoomModel {
  final String name;
  final String hostId;
  int maxPlayers;
  int phantomCount;
  RoomPhase phase;
  SabotageType activeSabotage;
  DateTime? sabotageStartTime;
  int sabotageTimeoutSeconds;
  WinCondition winCondition;
  Map<String, int> voteResults; // playerId -> vote count ('' = skip)
  double totalTaskProgress; // 0.0 to 1.0

  /// Tracks which players are actively holding fix panels.
  /// Key: panel ID (e.g. 'reactor_panel_a'), Value: player ID.
  Map<String, String> fixingPanels;

  /// For airlock breach: which room is sealed off.
  String? sealedZone;

  RoomModel({
    required this.name,
    required this.hostId,
    this.maxPlayers = 8,
    this.phantomCount = 2,
    this.phase = RoomPhase.lobby,
    this.activeSabotage = SabotageType.none,
    this.sabotageStartTime,
    this.sabotageTimeoutSeconds = 45,
    this.winCondition = WinCondition.none,
    Map<String, int>? voteResults,
    this.totalTaskProgress = 0.0,
    Map<String, String>? fixingPanels,
    this.sealedZone,
  }) : voteResults = voteResults ?? {},
       fixingPanels = fixingPanels ?? {};

  bool get hasSabotage => activeSabotage != SabotageType.none;

  Duration? get sabotageTimeRemaining {
    if (sabotageStartTime == null) return null;
    final elapsed = DateTime.now().difference(sabotageStartTime!);
    final remaining = Duration(seconds: sabotageTimeoutSeconds) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'hostId': hostId,
    'maxPlayers': maxPlayers,
    'phantomCount': phantomCount,
    'phase': phase.name,
    'activeSabotage': activeSabotage.name,
    'sabotageStartTime': sabotageStartTime?.toIso8601String(),
    'sabotageTimeoutSeconds': sabotageTimeoutSeconds,
    'winCondition': winCondition.name,
    'voteResults': voteResults,
    'totalTaskProgress': totalTaskProgress,
    'fixingPanels': fixingPanels,
    'sealedZone': sealedZone,
  };

  factory RoomModel.fromJson(Map<String, dynamic> json) => RoomModel(
    name: json['name'] as String,
    hostId: json['hostId'] as String,
    maxPlayers: json['maxPlayers'] as int? ?? 8,
    phantomCount: json['phantomCount'] as int? ?? 2,
    phase: RoomPhase.values.firstWhere((p) => p.name == json['phase'], orElse: () => RoomPhase.lobby),
    activeSabotage: SabotageType.values.firstWhere((s) => s.name == json['activeSabotage'], orElse: () => SabotageType.none),
    sabotageStartTime: json['sabotageStartTime'] != null ? DateTime.parse(json['sabotageStartTime'] as String) : null,
    sabotageTimeoutSeconds: json['sabotageTimeoutSeconds'] as int? ?? 45,
    winCondition: WinCondition.values.firstWhere((w) => w.name == json['winCondition'], orElse: () => WinCondition.none),
    voteResults: (json['voteResults'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {},
    totalTaskProgress: (json['totalTaskProgress'] as num?)?.toDouble() ?? 0.0,
    fixingPanels: (json['fixingPanels'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)) ?? {},
    sealedZone: json['sealedZone'] as String?,
  );
}
