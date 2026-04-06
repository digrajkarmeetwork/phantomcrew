import 'package:flutter_test/flutter_test.dart';
import 'package:phantom_crew/game/models/player_model.dart';

void main() {
  group('PlayerModel', () {
    test('default values', () {
      final p = PlayerModel(id: 'p1', name: 'Alice', colorKey: 'cyan');
      expect(p.role, PlayerRole.guardian);
      expect(p.state, PlayerState.alive);
      expect(p.isAlive, true);
      expect(p.isPhantom, false);
      expect(p.isGhost, false);
      expect(p.x, 0.5);
      expect(p.y, 0.5);
      expect(p.animation, 'idle');
      expect(p.inVent, false);
      expect(p.assignedTasks, isEmpty);
      expect(p.completedTasks, isEmpty);
      expect(p.meetingUsesLeft, 1);
      expect(p.hasVoted, false);
      expect(p.canKill, true); // No cooldown initially
      expect(p.canVent, true);
      expect(p.canSabotage, true);
    });

    test('copyWith preserves unchanged fields', () {
      final p = PlayerModel(id: 'p1', name: 'Alice', colorKey: 'cyan');
      final p2 = p.copyWith(name: 'Bob');
      expect(p2.name, 'Bob');
      expect(p2.id, 'p1');
      expect(p2.colorKey, 'cyan');
    });

    test('toJson / fromJson round-trip', () {
      final p = PlayerModel(
        id: 'p1',
        name: 'Alice',
        colorKey: 'red',
        role: PlayerRole.phantomAgent,
        state: PlayerState.ghost,
        isHost: true,
        x: 0.3,
        y: 0.7,
        animation: 'walk_left',
        inVent: true,
        assignedTasks: ['reactor_alignment', 'data_upload'],
        completedTasks: {'reactor_alignment'},
        meetingUsesLeft: 0,
        hasVoted: true,
        votedFor: 'p2',
        lastKillTime: DateTime(2026, 1, 1, 12, 0, 0),
      );

      final json = p.toJson();
      final p2 = PlayerModel.fromJson(json);

      expect(p2.id, p.id);
      expect(p2.name, p.name);
      expect(p2.colorKey, p.colorKey);
      expect(p2.role, p.role);
      expect(p2.state, p.state);
      expect(p2.isHost, p.isHost);
      expect(p2.x, p.x);
      expect(p2.y, p.y);
      expect(p2.animation, p.animation);
      expect(p2.inVent, p.inVent);
      expect(p2.assignedTasks, p.assignedTasks);
      expect(p2.completedTasks, p.completedTasks);
      expect(p2.meetingUsesLeft, p.meetingUsesLeft);
      expect(p2.hasVoted, p.hasVoted);
      expect(p2.votedFor, p.votedFor);
      expect(p2.lastKillTime, p.lastKillTime);
    });

    test('taskProgress calculation', () {
      final p = PlayerModel(
        id: 'p1', name: 'Alice', colorKey: 'cyan',
        assignedTasks: ['a', 'b', 'c'],
        completedTasks: {'a'},
      );
      expect(p.taskProgress, closeTo(1 / 3, 0.01));
    });

    test('taskProgress is 0 when no tasks assigned', () {
      final p = PlayerModel(id: 'p1', name: 'Alice', colorKey: 'cyan');
      expect(p.taskProgress, 0);
    });

    group('cooldowns', () {
      test('canKill returns false during cooldown', () {
        final p = PlayerModel(
          id: 'p1', name: 'Alice', colorKey: 'cyan',
          lastKillTime: DateTime.now(),
        );
        expect(p.canKill, false);
        expect(p.killCooldownRemaining, greaterThan(0));
      });

      test('canKill returns true after cooldown expires', () {
        final p = PlayerModel(
          id: 'p1', name: 'Alice', colorKey: 'cyan',
          lastKillTime: DateTime.now().subtract(const Duration(seconds: 31)),
        );
        expect(p.canKill, true);
        expect(p.killCooldownRemaining, 0);
      });

      test('canVent returns false during cooldown', () {
        final p = PlayerModel(
          id: 'p1', name: 'Alice', colorKey: 'cyan',
          lastVentTime: DateTime.now(),
        );
        expect(p.canVent, false);
      });

      test('canSabotage returns false during cooldown', () {
        final p = PlayerModel(
          id: 'p1', name: 'Alice', colorKey: 'cyan',
          lastSabotageTime: DateTime.now(),
        );
        expect(p.canSabotage, false);
      });
    });
  });

  group('DeadBodyModel', () {
    test('toJson / fromJson round-trip', () {
      final b = DeadBodyModel(
        victimId: 'v1',
        victimName: 'Alice',
        victimColorKey: 'red',
        x: 0.4,
        y: 0.6,
        reported: true,
      );
      final json = b.toJson();
      final b2 = DeadBodyModel.fromJson(json);
      expect(b2.victimId, b.victimId);
      expect(b2.victimName, b.victimName);
      expect(b2.x, b.x);
      expect(b2.y, b.y);
      expect(b2.reported, b.reported);
    });
  });
}
