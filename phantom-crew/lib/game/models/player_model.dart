import 'package:flutter/material.dart';
import '../../ui/theme.dart';

enum PlayerRole { guardian, phantomAgent }
enum PlayerState { alive, dead, ghost }

class PlayerModel {
  final String id;
  String name;
  String colorKey;
  PlayerRole role;
  PlayerState state;
  bool isHost;
  bool isLocal;
  bool isBot;
  double x;
  double y;
  String animation; // idle, walk_left, walk_right, vent_enter, vent_exit
  bool inVent;
  String? cosmeticVisor;
  String? cosmeticEmblem;
  List<String> assignedTasks;
  Set<String> completedTasks;
  int meetingUsesLeft;
  bool hasVoted;
  String? votedFor; // player id or 'skip'

  // Cooldowns
  DateTime? lastKillTime;
  DateTime? lastVentTime;
  DateTime? lastSabotageTime;

  static const int killCooldownSeconds = 30;
  static const int ventCooldownSeconds = 15;
  static const int sabotageCooldownSeconds = 30;

  PlayerModel({
    required this.id,
    required this.name,
    required this.colorKey,
    this.role = PlayerRole.guardian,
    this.state = PlayerState.alive,
    this.isHost = false,
    this.isLocal = false,
    this.isBot = false,
    this.x = 0.5,
    this.y = 0.5,
    this.animation = 'idle',
    this.inVent = false,
    this.cosmeticVisor,
    this.cosmeticEmblem,
    List<String>? assignedTasks,
    Set<String>? completedTasks,
    this.meetingUsesLeft = 1,
    this.hasVoted = false,
    this.votedFor,
    this.lastKillTime,
    this.lastVentTime,
    this.lastSabotageTime,
  })  : assignedTasks = assignedTasks ?? [],
        completedTasks = completedTasks ?? {};

  Color get color => PhantomTheme.playerColors[colorKey] ?? PhantomTheme.teal;

  bool get isPhantom => role == PlayerRole.phantomAgent;
  bool get isAlive => state == PlayerState.alive;
  bool get isGhost => state == PlayerState.ghost;

  bool get canKill => _cooldownRemaining(lastKillTime, killCooldownSeconds) == 0;
  bool get canVent => _cooldownRemaining(lastVentTime, ventCooldownSeconds) == 0;
  bool get canSabotage => _cooldownRemaining(lastSabotageTime, sabotageCooldownSeconds) == 0;

  int get killCooldownRemaining => _cooldownRemaining(lastKillTime, killCooldownSeconds);
  int get ventCooldownRemaining => _cooldownRemaining(lastVentTime, ventCooldownSeconds);
  int get sabotageCooldownRemaining => _cooldownRemaining(lastSabotageTime, sabotageCooldownSeconds);

  int _cooldownRemaining(DateTime? lastTime, int cooldownSeconds) {
    if (lastTime == null) return 0;
    final elapsed = DateTime.now().difference(lastTime).inSeconds;
    final remaining = cooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  double get taskProgress {
    if (assignedTasks.isEmpty) return 0;
    return completedTasks.length / assignedTasks.length;
  }

  // Sentinel used by copyWith to distinguish "not provided" from explicit null.
  static const _absent = Object();

  PlayerModel copyWith({
    String? name,
    String? colorKey,
    PlayerRole? role,
    PlayerState? state,
    bool? isHost,
    bool? isLocal,
    bool? isBot,
    double? x,
    double? y,
    String? animation,
    bool? inVent,
    String? cosmeticVisor,
    String? cosmeticEmblem,
    List<String>? assignedTasks,
    Set<String>? completedTasks,
    int? meetingUsesLeft,
    bool? hasVoted,
    Object? votedFor = _absent, // supports explicit null to clear
    DateTime? lastKillTime,
    DateTime? lastVentTime,
    DateTime? lastSabotageTime,
  }) {
    return PlayerModel(
      id: id,
      name: name ?? this.name,
      colorKey: colorKey ?? this.colorKey,
      role: role ?? this.role,
      state: state ?? this.state,
      isHost: isHost ?? this.isHost,
      isLocal: isLocal ?? this.isLocal,
      isBot: isBot ?? this.isBot,
      x: x ?? this.x,
      y: y ?? this.y,
      animation: animation ?? this.animation,
      inVent: inVent ?? this.inVent,
      cosmeticVisor: cosmeticVisor ?? this.cosmeticVisor,
      cosmeticEmblem: cosmeticEmblem ?? this.cosmeticEmblem,
      assignedTasks: assignedTasks ?? this.assignedTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      meetingUsesLeft: meetingUsesLeft ?? this.meetingUsesLeft,
      hasVoted: hasVoted ?? this.hasVoted,
      votedFor: votedFor == _absent ? this.votedFor : votedFor as String?,
      lastKillTime: lastKillTime ?? this.lastKillTime,
      lastVentTime: lastVentTime ?? this.lastVentTime,
      lastSabotageTime: lastSabotageTime ?? this.lastSabotageTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorKey': colorKey,
    'role': role.name,
    'state': state.name,
    'isHost': isHost,
    'isBot': isBot,
    'x': x,
    'y': y,
    'animation': animation,
    'inVent': inVent,
    'cosmeticVisor': cosmeticVisor,
    'cosmeticEmblem': cosmeticEmblem,
    'assignedTasks': assignedTasks,
    'completedTasks': completedTasks.toList(),
    'meetingUsesLeft': meetingUsesLeft,
    'hasVoted': hasVoted,
    'votedFor': votedFor,
    'lastKillTime': lastKillTime?.toIso8601String(),
    'lastVentTime': lastVentTime?.toIso8601String(),
    'lastSabotageTime': lastSabotageTime?.toIso8601String(),
  };

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      colorKey: json['colorKey'] as String,
      role: PlayerRole.values.firstWhere((r) => r.name == json['role'], orElse: () => PlayerRole.guardian),
      state: PlayerState.values.firstWhere((s) => s.name == json['state'], orElse: () => PlayerState.alive),
      isHost: json['isHost'] as bool? ?? false,
      isBot: json['isBot'] as bool? ?? false,
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.5,
      animation: json['animation'] as String? ?? 'idle',
      inVent: json['inVent'] as bool? ?? false,
      cosmeticVisor: json['cosmeticVisor'] as String?,
      cosmeticEmblem: json['cosmeticEmblem'] as String?,
      assignedTasks: (json['assignedTasks'] as List<dynamic>?)?.cast<String>() ?? [],
      completedTasks: ((json['completedTasks'] as List<dynamic>?)?.cast<String>() ?? []).toSet(),
      meetingUsesLeft: json['meetingUsesLeft'] as int? ?? 1,
      hasVoted: json['hasVoted'] as bool? ?? false,
      votedFor: json['votedFor'] as String?,
      lastKillTime: json['lastKillTime'] != null ? DateTime.parse(json['lastKillTime'] as String) : null,
      lastVentTime: json['lastVentTime'] != null ? DateTime.parse(json['lastVentTime'] as String) : null,
      lastSabotageTime: json['lastSabotageTime'] != null ? DateTime.parse(json['lastSabotageTime'] as String) : null,
    );
  }
}

class DeadBodyModel {
  final String victimId;
  final String victimName;
  final String victimColorKey;
  final double x;
  final double y;
  bool reported;

  DeadBodyModel({
    required this.victimId,
    required this.victimName,
    required this.victimColorKey,
    required this.x,
    required this.y,
    this.reported = false,
  });

  Map<String, dynamic> toJson() => {
    'victimId': victimId,
    'victimName': victimName,
    'victimColorKey': victimColorKey,
    'x': x,
    'y': y,
    'reported': reported,
  };

  factory DeadBodyModel.fromJson(Map<String, dynamic> json) => DeadBodyModel(
    victimId: json['victimId'] as String,
    victimName: json['victimName'] as String,
    victimColorKey: json['victimColorKey'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    reported: json['reported'] as bool? ?? false,
  );
}
