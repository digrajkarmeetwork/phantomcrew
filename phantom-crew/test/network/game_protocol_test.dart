import 'package:flutter_test/flutter_test.dart';
import 'package:phantom_crew/game/network/game_protocol.dart';

void main() {
  group('PhantomMessage serialization', () {
    test('hostRoom round-trip', () {
      final msg = PhantomMessage.hostRoom('TestRoom', 'host1', maxPlayers: 6, phantomCount: 1);
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.hostRoom);
      expect(parsed.room, 'TestRoom');
      expect(parsed.sender, 'host1');
      expect(parsed.data['maxPlayers'], 6);
      expect(parsed.data['phantomCount'], 1);
    });

    test('joinRoom round-trip', () {
      final msg = PhantomMessage.joinRoom('TestRoom', 'p1', 'Alice', 'cyan');
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.joinRoom);
      expect(parsed.data['playerName'], 'Alice');
      expect(parsed.data['colorKey'], 'cyan');
    });

    test('playerMove round-trip', () {
      final msg = PhantomMessage.playerMove('Room1', 'p1', 0.3, 0.7, 'walk_left');
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.playerMove);
      expect(parsed.data['x'], 0.3);
      expect(parsed.data['y'], 0.7);
      expect(parsed.data['anim'], 'walk_left');
    });

    test('kill round-trip', () {
      final msg = PhantomMessage.kill('Room1', 'killer1', 'victim1', 0.4, 0.5);
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.kill);
      expect(parsed.sender, 'killer1');
      expect(parsed.data['victim'], 'victim1');
      expect(parsed.data['x'], 0.4);
      expect(parsed.data['y'], 0.5);
    });

    test('vent with destination round-trip', () {
      final msg = PhantomMessage.vent('Room1', 'p1', 'travel', 'eng_vent',
          destinationVentId: 'maint_vent', destX: 0.5, destY: 0.65);
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.ventAction);
      expect(parsed.data['action'], 'travel');
      expect(parsed.data['ventId'], 'eng_vent');
      expect(parsed.data['destinationVentId'], 'maint_vent');
      expect(parsed.data['destX'], 0.5);
      expect(parsed.data['destY'], 0.65);
    });

    test('vent without destination omits optional fields', () {
      final msg = PhantomMessage.vent('Room1', 'p1', 'enter', 'eng_vent');
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.data['action'], 'enter');
      expect(parsed.data.containsKey('destinationVentId'), false);
    });

    test('sabotage round-trip', () {
      final msg = PhantomMessage.sabotage('Room1', 'p1', 'reactorCascade');
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.sabotage);
      expect(parsed.data['sabotageType'], 'reactorCascade');
    });

    test('fixSabotage round-trip', () {
      final msg = PhantomMessage.fixSabotage('Room1', 'p1', 'reactorCascade', 'reactor_panel_a');
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.fixSabotage);
      expect(parsed.data['sabotageType'], 'reactorCascade');
      expect(parsed.data['panel'], 'reactor_panel_a');
    });

    test('taskComplete round-trip', () {
      final msg = PhantomMessage.taskComplete('Room1', 'p1', 'reactor_alignment', 0.6);
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.taskComplete);
      expect(parsed.data['taskId'], 'reactor_alignment');
      expect(parsed.data['progress'], 0.6);
    });

    test('emergencyMeeting round-trip', () {
      final msg = PhantomMessage.emergencyMeeting('Room1', 'p1');
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.emergencyMeeting);
      expect(parsed.data['reason'], 'button');
    });

    test('chat round-trip', () {
      final msg = PhantomMessage.chat('Room1', 'p1', 'Alice', 'Hello there!');
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.chatMessage);
      expect(parsed.data['senderName'], 'Alice');
      expect(parsed.data['text'], 'Hello there!');
    });

    test('vote round-trip', () {
      final msg = PhantomMessage.vote('Room1', 'p1', 'p2');
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.vote);
      expect(parsed.data['target'], 'p2');
    });

    test('reportBody round-trip', () {
      final msg = PhantomMessage.reportBody('Room1', 'p1', 'v1');
      final json = msg.toJsonString();
      final parsed = PhantomMessage.fromJsonString(json);

      expect(parsed.type, MsgType.reportBody);
      expect(parsed.data['victim'], 'v1');
    });

    test('unknown type parses as error', () {
      final parsed = PhantomMessage.fromJsonString('{"type":"unknown_garbage"}');
      expect(parsed.type, MsgType.error);
    });
  });
}
