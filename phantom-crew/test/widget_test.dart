import 'package:flutter_test/flutter_test.dart';
import 'package:phantom_crew/game/models/player_model.dart';
import 'package:phantom_crew/game/models/game_state.dart';
import 'package:phantom_crew/game/models/room_model.dart';

void main() {
  group('PlayerModel', () {
    test('starts alive as guardian', () {
      final p = PlayerModel(id: '1', name: 'Test', colorKey: 'cyan');
      expect(p.isAlive, isTrue);
      expect(p.isPhantom, isFalse);
    });

    test('taskProgress is 0 with no tasks assigned', () {
      final p = PlayerModel(id: '1', name: 'Test', colorKey: 'cyan');
      expect(p.taskProgress, 0.0);
    });

    test('taskProgress calculates correctly', () {
      final p = PlayerModel(
        id: '1', name: 'Test', colorKey: 'cyan',
        assignedTasks: ['a', 'b', 'c'],
        completedTasks: {'a', 'b'},
      );
      expect(p.taskProgress, closeTo(0.666, 0.01));
    });

    test('toJson / fromJson roundtrip', () {
      final p = PlayerModel(
        id: 'x', name: 'Alice', colorKey: 'red',
        role: PlayerRole.phantomAgent, isHost: true,
      );
      final back = PlayerModel.fromJson(p.toJson());
      expect(back.id, 'x');
      expect(back.name, 'Alice');
      expect(back.isPhantom, isTrue);
      expect(back.isHost, isTrue);
    });
  });

  group('GameState', () {
    test('task progress updates correctly', () {
      final gs = GameState()
        ..localPlayerId = 'p1'
        ..totalTasks = 6;
      gs.updatePlayer(PlayerModel(
        id: 'p1', name: 'Alice', colorKey: 'cyan', isLocal: true,
        assignedTasks: ['t1', 't2', 't3'],
      ));
      gs.completeTask('p1', 't1');
      expect(gs.completedTasks, 1);
      expect(gs.taskProgress, closeTo(1 / 6, 0.01));
    });

    test('markPlayerDead adds dead body', () {
      final gs = GameState()..localPlayerId = 'p1';
      gs.updatePlayer(PlayerModel(id: 'p2', name: 'Bob', colorKey: 'red'));
      gs.markPlayerDead('p2', 0.5, 0.5);
      expect(gs.players['p2']?.isGhost, isTrue);
      expect(gs.deadBodies.length, 1);
    });

    test('alivePlayers excludes ghosts', () {
      final gs = GameState()..localPlayerId = 'p1';
      gs.updatePlayer(PlayerModel(id: 'p1', name: 'A', colorKey: 'cyan'));
      gs.updatePlayer(PlayerModel(id: 'p2', name: 'B', colorKey: 'red'));
      gs.markPlayerDead('p2', 0.5, 0.5);
      expect(gs.alivePlayers.length, 1);
      expect(gs.alivePlayers.first.id, 'p1');
    });
  });

  group('RoomModel', () {
    test('hasSabotage is false by default', () {
      final r = RoomModel(name: 'TEST', hostId: 'h1');
      expect(r.hasSabotage, isFalse);
    });

    test('toJson / fromJson roundtrip', () {
      final r = RoomModel(name: 'R1', hostId: 'h', maxPlayers: 6, phantomCount: 1);
      final back = RoomModel.fromJson(r.toJson());
      expect(back.name, 'R1');
      expect(back.maxPlayers, 6);
      expect(back.phantomCount, 1);
    });
  });
}
