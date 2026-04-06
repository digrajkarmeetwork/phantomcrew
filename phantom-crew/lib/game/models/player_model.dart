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

  PlayerModel({
    required this.id,
    required this.name,
    required this.colorKey,
    this.role = PlayerRole.guardian,
    this.state = PlayerState.alive,
    this.isHost = false,
    this.isLocal = false,
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
  })  : assignedTasks = assignedTasks ?? [],
        completedTasks = completedTasks ?? {};

  Color get color => PhantomTheme.playerColors[colorKey] ?? PhantomTheme.teal;

  bool get isPhantom => role == PlayerRole.phantomAgent;
  bool get isAlive => state == PlayerState.alive;
  bool get isGhost => state == PlayerState.ghost;

  double get taskProgress {
    if (assignedTasks.isEmpty) return 0;
    return completedTasks.length / assignedTasks.length;
  }

  PlayerModel copyWith({
    String? name,
    String? colorKey,
    PlayerRole? role,
    PlayerState? state,
    bool? isHost,
    bool? isLocal,
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
    String? votedFor,
  }) {
    return PlayerModel(
      id: id,
      name: name ?? this.name,
      colorKey: colorKey ?? this.colorKey,
      role: role ?? this.role,
      state: state ?? this.state,
      isHost: isHost ?? this.isHost,
      isLocal: isLocal ?? this.isLocal,
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
      votedFor: votedFor ?? this.votedFor,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorKey': colorKey,
    'role': role.name,
    'state': state.name,
    'isHost': isHost,
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
  };

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      colorKey: json['colorKey'] as String,
      role: PlayerRole.values.firstWhere((r) => r.name == json['role'], orElse: () => PlayerRole.guardian),
      state: PlayerState.values.firstWhere((s) => s.name == json['state'], orElse: () => PlayerState.alive),
      isHost: json['isHost'] as bool? ?? false,
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
