import 'package:flutter_test/flutter_test.dart';
import 'package:phantom_crew/game/models/station_map.dart';

void main() {
  group('StationMap.isWalkable', () {
    test('point inside Command Bridge is walkable', () {
      expect(StationMap.isWalkable(0.2, 0.15), true);
    });

    test('point inside Research Lab is walkable', () {
      expect(StationMap.isWalkable(0.5, 0.47), true);
    });

    test('point outside all areas is not walkable', () {
      expect(StationMap.isWalkable(0.5, 0.3), false); // Gap between rooms
    });

    test('point in top corridor is walkable', () {
      expect(StationMap.isWalkable(0.5, 0.14), true);
    });

    test('point in left corridor is walkable', () {
      expect(StationMap.isWalkable(0.19, 0.3), true);
    });

    test('sealed zone excludes room', () {
      // Point in Command Bridge
      expect(StationMap.isWalkable(0.2, 0.15), true);
      expect(StationMap.isWalkable(0.2, 0.15, sealedZone: 'Command Bridge'), false);
    });

    test('sealed zone does not affect other rooms', () {
      // Point in Comms Array
      expect(StationMap.isWalkable(0.75, 0.15, sealedZone: 'Command Bridge'), true);
    });
  });

  group('StationMap.nearestVent', () {
    test('returns vent when near enough', () {
      // eng_vent is at (0.20, 0.82)
      expect(StationMap.nearestVent(0.20, 0.82), 'eng_vent');
    });

    test('returns null when too far', () {
      expect(StationMap.nearestVent(0.5, 0.5), isNull);
    });

    test('returns nearest of multiple vents', () {
      // comms_vent at (0.75, 0.12), cmd_vent at (0.20, 0.12)
      expect(StationMap.nearestVent(0.74, 0.12), 'comms_vent');
    });
  });

  group('StationMap.ventDestinations', () {
    test('eng_vent connects to maint_vent', () {
      expect(StationMap.ventDestinations('eng_vent'), ['maint_vent']);
    });

    test('maint_vent connects to eng and life', () {
      final dests = StationMap.ventDestinations('maint_vent');
      expect(dests, containsAll(['eng_vent', 'life_vent']));
    });

    test('cmd_vent connects to comms_vent', () {
      expect(StationMap.ventDestinations('cmd_vent'), ['comms_vent']);
    });

    test('unknown vent returns empty', () {
      expect(StationMap.ventDestinations('nonexistent'), isEmpty);
    });
  });

  group('StationMap.nearestFixPanel', () {
    test('returns panel when near reactor fix', () {
      // reactor_panel_a is at (0.12, 0.78)
      expect(StationMap.nearestFixPanel('reactorCascade', 0.12, 0.78), 'reactor_panel_a');
    });

    test('returns null when far from panel', () {
      expect(StationMap.nearestFixPanel('reactorCascade', 0.5, 0.5), isNull);
    });

    test('returns null for unknown sabotage type', () {
      expect(StationMap.nearestFixPanel('unknown', 0.12, 0.78), isNull);
    });

    test('comms terminal fix panel works', () {
      // comms_terminal at (0.70, 0.10)
      expect(StationMap.nearestFixPanel('commsJamming', 0.70, 0.10), 'comms_terminal');
    });
  });

  group('StationMap constants', () {
    test('has 5 rooms', () {
      expect(StationMap.rooms.length, 5);
    });

    test('has 4 corridors', () {
      expect(StationMap.corridors.length, 4);
    });

    test('has 10 task zones', () {
      expect(StationMap.taskZones.length, 10);
    });

    test('has 5 vents', () {
      expect(StationMap.ventPositions.length, 5);
    });

    test('has 4 sabotage types with fix panels', () {
      expect(StationMap.fixPanels.length, 4);
    });

    test('walkableAreas includes rooms and corridors', () {
      expect(StationMap.walkableAreas.length, 9); // 5 rooms + 4 corridors
    });
  });
}
