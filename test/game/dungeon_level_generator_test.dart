import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssc/game/dungeon_level_generator.dart';

void main() {
  const generator = DungeonLevelGenerator();

  test('generateCampaignLevel matches explicit campaign generateLevel', () {
    const levelNumber = 4;
    const seed = 501;
    final a = generator.generateCampaignLevel(
      levelNumber: levelNumber,
      seed: seed,
    );
    final b = generator.generateLevel(
      levelNumber: levelNumber,
      seed: seed,
      targetRooms: DungeonLevelGenerator.campaignTargetRoomCount(levelNumber),
      includeMonsters: true,
      includeItems: DungeonLevelGenerator.campaignIncludeItemsForLevel(
        levelNumber,
      ),
    );
    expect(jsonEncode(a.toJson()), equals(jsonEncode(b.toJson())));
  });

  test('generate is deterministic for the same seed and options', () {
    DungeonLevel build() => generator.generateLevel(
          levelNumber: 6,
          seed: 1337,
          targetRooms: 9,
          includeMonsters: true,
          includeItems: true,
        );

    expect(jsonEncode(build().toJson()), equals(jsonEncode(build().toJson())));
  });

  test('level 1 defaults to a single walker encounter', () {
    final level = generator.generateLevel(
      levelNumber: 1,
      seed: 77,
      includeItems: false,
    );

    expect(level.rooms, hasLength(2));
    final nonStart = level.rooms
        .where((room) => room.type != DungeonRoomType.start)
        .toList();
    expect(nonStart, hasLength(1));
    expect(nonStart.first.monsters, isNotNull);
    expect(nonStart.first.monsters, hasLength(1));
    expect(nonStart.first.monsters!.first.type, 'walker');
    expect(nonStart.first.monsters!.first.threat, 1);
  });

  test('rooms stay inside the map and never exceed the target count', () {
    final level = generator.generateLevel(
      levelNumber: 4,
      seed: 99,
      width: 48,
      height: 64,
      targetRooms: 8,
    );

    expect(level.width, 48);
    expect(level.height, 64);
    expect(level.rooms.length, lessThanOrEqualTo(8));
    expect(level.rooms.any((room) => room.id == level.startRoomId), isTrue);

    for (final room in level.rooms) {
      expect(room.x, inInclusiveRange(0, level.width - room.width));
      expect(room.y, inInclusiveRange(0, level.height - room.height));
      expect(room.width, greaterThanOrEqualTo(4));
      expect(room.height, greaterThanOrEqualTo(4));
    }
  });

  test('rooms do not overlap', () {
    final level = generator.generateLevel(
      levelNumber: 8,
      seed: 2026,
      targetRooms: 11,
    );

    final rooms = level.rooms;
    for (var i = 0; i < rooms.length; i++) {
      for (var j = i + 1; j < rooms.length; j++) {
        final a = rooms[i];
        final b = rooms[j];
        final disjoint = a.x + a.width <= b.x ||
            b.x + b.width <= a.x ||
            a.y + a.height <= b.y ||
            b.y + b.height <= a.y;
        expect(disjoint, isTrue, reason: '${a.id} overlaps ${b.id}');
      }
    }
  });

  test('every room is reachable and there is always a looping route', () {
    final level = generator.generateLevel(
      levelNumber: 8,
      seed: 2026,
      targetRooms: 11,
    );

    final ids = level.rooms.map((room) => room.id).toSet();
    for (final corridor in level.corridors) {
      expect(ids.contains(corridor.fromRoomId), isTrue);
      expect(ids.contains(corridor.toRoomId), isTrue);
    }

    // BFS from the start room must reach every room (spanning tree).
    final adjacency = level.adjacency();
    final seen = <String>{level.startRoomId};
    final queue = <String>[level.startRoomId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final next in adjacency[current] ?? const <String>[]) {
        if (seen.add(next)) {
          queue.add(next);
        }
      }
    }
    expect(seen.length, ids.length, reason: 'not all rooms reachable');

    // More corridors than (rooms - 1) means at least one cycle / loop exists.
    expect(
      level.corridors.length,
      greaterThan(level.rooms.length - 1),
      reason: 'expected at least one looping route',
    );
  });

  test('includeMonsters=false removes monsters from model and JSON output', () {
    final level = generator.generateLevel(
      levelNumber: 7,
      seed: 42,
      targetRooms: 12,
      includeMonsters: false,
      includeItems: true,
    );

    for (final room in level.rooms) {
      expect(room.monsters, isNull);
    }

    final roomsJson = (level.toJson()['rooms'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final roomJson in roomsJson) {
      expect(roomJson.containsKey('monsters'), isFalse);
    }
  });

  test('includeItems=false removes items from model and JSON output', () {
    final level = generator.generateLevel(
      levelNumber: 7,
      seed: 42,
      targetRooms: 12,
      includeMonsters: true,
      includeItems: false,
    );

    for (final room in level.rooms) {
      expect(room.items, isNull);
    }

    final roomsJson = (level.toJson()['rooms'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final roomJson in roomsJson) {
      expect(roomJson.containsKey('items'), isFalse);
    }
  });
}
