import 'package:flutter_test/flutter_test.dart';
import 'package:phantom_crew/game/models/game_state.dart';
import 'package:phantom_crew/game/models/player_model.dart';
import 'package:phantom_crew/game/models/room_model.dart';

void main() {
  late GameState state;

  setUp(() {
    state = GameState();
    state.localPlayerId = 'local';
    state.localPlayerName = 'LocalPlayer';
    state.room = RoomModel(name: 'TestRoom', hostId: 'local');
  });

  group('player management', () {
    test('updatePlayer adds a new player', () {
      state.updatePlayer(PlayerModel(id: 'p1', name: 'Alice', colorKey: 'cyan'));
      expect(state.players.containsKey('p1'), true);
      expect(state.players['p1']!.name, 'Alice');
    });

    test('updatePlayerPosition updates position', () {
      state.updatePlayer(PlayerModel(id: 'p1', name: 'Alice', colorKey: 'cyan'));
      state.updatePlayerPosition('p1', 0.3, 0.7, 'walk_left');
      expect(state.players['p1']!.x, 0.3);
      expect(state.players['p1']!.y, 0.7);
      expect(state.players['p1']!.animation, 'walk_left');
    });

    test('markPlayerDead creates ghost and dead body', () {
      state.updatePlayer(PlayerModel(id: 'p1', name: 'Alice', colorKey: 'cyan'));
      state.markPlayerDead('p1', 0.4, 0.6);

      expect(state.players['p1']!.state, PlayerState.ghost);
      expect(state.deadBodies, hasLength(1));
      expect(state.deadBodies.first.victimId, 'p1');
      expect(state.deadBodies.first.x, 0.4);
      expect(state.deadBodies.first.y, 0.6);
    });

    test('ejectPlayer sets state to dead', () {
      state.updatePlayer(PlayerModel(id: 'p1', name: 'Alice', colorKey: 'cyan'));
      state.ejectPlayer('p1');
      expect(state.players['p1']!.state, PlayerState.dead);
    });
  });

  group('meetings', () {
    test('startMeeting sets meeting state', () {
      state.startMeeting('p1', 'button');
      expect(state.meetingActive, true);
      expect(state.meetingCallerId, 'p1');
      expect(state.meetingReason, 'button');
      expect(state.meetingStartTime, isNotNull);
    });

    test('endMeeting clears meeting state', () {
      state.startMeeting('p1', 'body');
      state.endMeeting();
      expect(state.meetingActive, false);
      expect(state.meetingCallerId, isNull);
      expect(state.meetingStartTime, isNull);
    });

    test('recordVote tracks votes', () {
      state.updatePlayer(PlayerModel(id: 'p1', name: 'Alice', colorKey: 'cyan'));
      state.updatePlayer(PlayerModel(id: 'p2', name: 'Bob', colorKey: 'red'));
      state.recordVote('p1', 'p2');
      expect(state.players['p1']!.hasVoted, true);
      expect(state.players['p1']!.votedFor, 'p2');
      expect(state.room!.voteResults['p2'], 1);
    });

    test('recordVote ignores double vote', () {
      state.updatePlayer(PlayerModel(id: 'p1', name: 'Alice', colorKey: 'cyan'));
      state.recordVote('p1', 'p2');
      state.recordVote('p1', 'p3'); // Should be ignored
      expect(state.players['p1']!.votedFor, 'p2');
      expect(state.room!.voteResults['p2'], 1);
      expect(state.room!.voteResults.containsKey('p3'), false);
    });

    test('startMeeting resets all votes', () {
      state.updatePlayer(PlayerModel(id: 'p1', name: 'Alice', colorKey: 'cyan', hasVoted: true, votedFor: 'p2'));
      state.startMeeting('p1', 'button');
      expect(state.players['p1']!.hasVoted, false);
      expect(state.players['p1']!.votedFor, isNull);
    });
  });

  group('tasks', () {
    test('completeTask increments counters', () {
      state.updatePlayer(PlayerModel(
        id: 'p1', name: 'Alice', colorKey: 'cyan',
        assignedTasks: ['a', 'b', 'c'],
      ));
      state.totalTasks = 6;
      state.completedTasks = 0;

      state.completeTask('p1', 'a');
      expect(state.completedTasks, 1);
      expect(state.players['p1']!.completedTasks, contains('a'));
    });

    test('taskProgress tracks global progress', () {
      state.totalTasks = 4;
      state.completedTasks = 2;
      expect(state.taskProgress, 0.5);
    });

    test('taskProgress is 0 when no tasks', () {
      state.totalTasks = 0;
      expect(state.taskProgress, 0);
    });
  });

  group('sabotage', () {
    test('setSabotage sets sabotage type and timestamp', () {
      state.setSabotage(SabotageType.reactorCascade);
      expect(state.room!.activeSabotage, SabotageType.reactorCascade);
      expect(state.room!.sabotageStartTime, isNotNull);
    });

    test('clearSabotage resets to none', () {
      state.setSabotage(SabotageType.blackoutProtocol);
      state.clearSabotage();
      expect(state.room!.activeSabotage, SabotageType.none);
      expect(state.room!.sabotageStartTime, isNull);
    });

    test('setSabotage with airlock breach sets sealedZone', () {
      state.setSabotage(SabotageType.airlockBreach, sealedZone: 'Engineering Bay');
      expect(state.room!.activeSabotage, SabotageType.airlockBreach);
      expect(state.room!.sealedZone, 'Engineering Bay');
    });

    test('clearSabotage clears sealedZone', () {
      state.setSabotage(SabotageType.airlockBreach, sealedZone: 'Engineering Bay');
      state.clearSabotage();
      expect(state.room!.sealedZone, isNull);
    });
  });

  group('computed properties', () {
    test('alivePlayers filters correctly', () {
      state.updatePlayer(PlayerModel(id: 'p1', name: 'A', colorKey: 'cyan', state: PlayerState.alive));
      state.updatePlayer(PlayerModel(id: 'p2', name: 'B', colorKey: 'red', state: PlayerState.ghost));
      state.updatePlayer(PlayerModel(id: 'p3', name: 'C', colorKey: 'green', state: PlayerState.alive));
      expect(state.alivePlayers, hasLength(2));
    });

    test('aliveGuardians and alivePhantoms filter correctly', () {
      state.updatePlayer(PlayerModel(id: 'p1', name: 'A', colorKey: 'cyan', role: PlayerRole.guardian));
      state.updatePlayer(PlayerModel(id: 'p2', name: 'B', colorKey: 'red', role: PlayerRole.phantomAgent));
      state.updatePlayer(PlayerModel(id: 'p3', name: 'C', colorKey: 'green', role: PlayerRole.guardian));
      expect(state.aliveGuardians, hasLength(2));
      expect(state.alivePhantoms, hasLength(1));
    });

    test('isPhantom reflects local player role', () {
      state.updatePlayer(PlayerModel(id: 'local', name: 'Me', colorKey: 'cyan', role: PlayerRole.phantomAgent));
      expect(state.isPhantom, true);
    });
  });

  group('connection', () {
    test('setConnected updates state', () {
      state.setConnected(false, error: 'timeout');
      expect(state.connected, false);
      expect(state.connectionError, 'timeout');
    });
  });

  group('reset', () {
    test('reset clears everything', () {
      state.updatePlayer(PlayerModel(id: 'p1', name: 'A', colorKey: 'cyan'));
      state.totalTasks = 10;
      state.completedTasks = 5;
      state.reset();

      expect(state.room, isNull);
      expect(state.players, isEmpty);
      expect(state.deadBodies, isEmpty);
      expect(state.totalTasks, 0);
      expect(state.completedTasks, 0);
      expect(state.meetingActive, false);
    });
  });
}
