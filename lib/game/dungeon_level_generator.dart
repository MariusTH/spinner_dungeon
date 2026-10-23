import 'dart:math';

typedef DungeonGenerationLog = void Function(String message);

/// Options for [DungeonLevelGenerator.generate]. For the same dungeons the
/// shipped game builds, use [DungeonLevelGenerator.generateCampaignLevel]
/// (or match campaign helpers on [DungeonLevelGenerator]).
class DungeonGenerationOptions {
  const DungeonGenerationOptions({
    required this.levelNumber,
    required this.seed,
    this.width,
    this.height,
    this.targetRooms,
    this.includeMonsters = true,
    this.includeItems = true,
    this.log,
  });

  final int levelNumber;
  final int seed;

  /// Tile dimensions of the whole map. When null they are derived from
  /// [targetRooms] (portrait-biased so levels read tall on phones).
  final int? width;
  final int? height;
  final int? targetRooms;
  final bool includeMonsters;
  final bool includeItems;
  final DungeonGenerationLog? log;
}

/// Bundled [RoomTemplate] id for semantic combat rooms (see `assets/levels/room_templates/`).
const String kDefaultCombatRoomTemplateId = 'band_arena';

/// Whether combat rooms get [kDefaultCombatRoomTemplateId] applied.
const bool kCombatRoomTemplatesEnabled = false;

/// Generates a dungeon floor by Binary Space Partitioning a tile grid into
/// variable-sized rooms, then connecting them with L-shaped corridors. The
/// connection pass builds a spanning tree (every room reachable) and then adds
/// extra short edges so there is always at least one looping route.
///
/// Coordinates in the produced [DungeonLevel] are **tiles**; the game scales
/// them to world units when it lays the level out.
class DungeonLevelGenerator {
  const DungeonLevelGenerator();

  /// Smallest a BSP leaf may become before it stops splitting (tiles).
  static const int _minLeaf = 14;

  /// Smallest a carved room may be (tiles).
  static const int _minRoom = 6;

  /// Corridor width in tiles.
  static const int _corridorWidth = 3;

  /// Floors in a campaign run. Clearing the last one (the Warden's floor)
  /// wins the run.
  static const int campaignFloorCount = 5;

  /// The Warden boss room appears on the final campaign floor (and on any
  /// deeper level the CLI tool is asked for).
  static bool isWardenFloor(int levelNumber) =>
      levelNumber >= campaignFloorCount;

  /// Room count used for campaign level [levelNumber] in a normal run.
  static int campaignTargetRoomCount(int levelNumber) =>
      max(2, max(1, levelNumber) + 1);

  /// Campaign level 1 has no dungeon items; level 2+ do (matches a normal run).
  static bool campaignIncludeItemsForLevel(int levelNumber) => levelNumber > 1;

  /// Same [DungeonLevel] as a campaign floor for [levelNumber] and [seed].
  DungeonLevel generateCampaignLevel({
    required int levelNumber,
    required int seed,
    DungeonGenerationLog? log,
  }) {
    return generateLevel(
      levelNumber: levelNumber,
      seed: seed,
      targetRooms: campaignTargetRoomCount(levelNumber),
      includeMonsters: true,
      includeItems: campaignIncludeItemsForLevel(levelNumber),
      log: log,
    );
  }

  DungeonLevel generate(DungeonGenerationOptions options) {
    final log = options.log;
    final levelNumber = max(1, options.levelNumber);
    final requestedTargetRooms = options.targetRooms ?? max(2, levelNumber + 1);
    final targetRooms = max(1, requestedTargetRooms);

    // Derive a portrait-biased tile map sized to host ~targetRooms leaves of
    // roughly [_minLeaf]-sized tiles. Explicit overrides win.
    const avgLeaf = 19;
    final area = targetRooms * avgLeaf * avgLeaf;
    final autoWidth = max(2 * _minLeaf, sqrt(area / 1.4).round());
    final autoHeight = max((2.6 * _minLeaf).round(), (autoWidth * 1.4).round());
    final width = (options.width ?? autoWidth).clamp(2 * _minLeaf, 240).toInt();
    final height = (options.height ?? autoHeight)
        .clamp(2 * _minLeaf, 320)
        .toInt();

    final random = Random(options.seed ^ (levelNumber * 10007));
    log?.call(
      'seed=${options.seed} level=$levelNumber map=${width}x$height '
      'targetRooms=$targetRooms',
    );

    // 1. Partition the map into leaves.
    final root = _BspNode(0, 0, width, height);
    _partition(root, random, targetRooms);
    final leaves = <_BspNode>[];
    root.collectLeaves(leaves);
    log?.call('bsp leaves=${leaves.length}');

    // 2. Carve a padded room inside each leaf.
    var nextId = 0;
    for (final leaf in leaves) {
      leaf.room = _carveRoom(leaf, random, id: 'r${nextId++}');
    }
    final rooms = <String, _MutableRoom>{
      for (final leaf in leaves) leaf.room!.id: leaf.room!,
    };

    // 3. Connect sibling subtrees (spanning tree) + add loop edges.
    final corridors = <_MutableCorridor>[];
    final connected = <String>{};
    final roomList = rooms.values.toList();
    _connect(root, random, roomList, corridors, connected);
    _addLoops(
      random: random,
      levelNumber: levelNumber,
      rooms: roomList,
      corridors: corridors,
      connected: connected,
    );
    log?.call('corridors=${corridors.length}');

    // 4. Pick start, compute distances, assign room types.
    final start = _pickStartRoom(rooms, width: width, height: height);
    final adjacency = _adjacency(rooms.keys, corridors);
    final distances = _distanceFromStart(start: start, adjacency: adjacency);
    _assignRoomTypes(
      random: random,
      levelNumber: levelNumber,
      start: start,
      rooms: rooms,
      distances: distances,
    );

    final roomTypeCounts = <DungeonRoomType, int>{};
    for (final room in rooms.values) {
      roomTypeCounts[room.type] = (roomTypeCounts[room.type] ?? 0) + 1;
    }
    log?.call(
      'room-types '
      'start=${roomTypeCounts[DungeonRoomType.start] ?? 0} '
      'combat=${roomTypeCounts[DungeonRoomType.combat] ?? 0} '
      'treasure=${roomTypeCounts[DungeonRoomType.treasure] ?? 0} '
      'boss=${roomTypeCounts[DungeonRoomType.boss] ?? 0}',
    );

    // 5. Materialize content + immutable model (rooms sorted top-to-bottom).
    final ordered = rooms.values.toList()
      ..sort((a, b) => a.y == b.y ? a.x.compareTo(b.x) : a.y.compareTo(b.y));

    var generatedRooms = ordered.map((room) {
      final distance = distances[room.id] ?? 0;
      final monsters = options.includeMonsters
          ? _generateMonsters(
              random: random,
              levelNumber: levelNumber,
              roomType: room.type,
              distanceFromStart: distance,
            )
          : null;
      final items = options.includeItems
          ? _generateItems(
              random: random,
              levelNumber: levelNumber,
              roomType: room.type,
              distanceFromStart: distance,
            )
          : null;

      String? templateId;
      var templateRot = 0;
      var templateFlipH = false;
      var templateFlipV = false;
      // Semantic templates are stretched over the whole room, so a template
      // must be authored with open doorways before it is assigned here. The
      // only bundled one (band_arena) walls off a third of the room on each
      // side and blocked corridor entrances, so none are assigned for now.
      if (room.type == DungeonRoomType.combat && kCombatRoomTemplatesEnabled) {
        templateId = kDefaultCombatRoomTemplateId;
        templateRot = random.nextInt(4);
        templateFlipH = random.nextBool();
        templateFlipV = random.nextBool();
      }

      return DungeonRoom(
        id: room.id,
        x: room.x,
        y: room.y,
        width: room.w,
        height: room.h,
        type: room.type,
        monsters: monsters,
        items: items,
        roomTemplateId: templateId,
        templateRotationQuarterTurns: templateRot,
        templateFlipH: templateFlipH,
        templateFlipV: templateFlipV,
      );
    }).toList();

    // Safety nets: never ship a content-free floor when content is requested.
    if (options.includeMonsters &&
        generatedRooms.length > 1 &&
        generatedRooms.every((room) => room.monsters!.isEmpty)) {
      final candidateIndex = generatedRooms.indexWhere(
        (room) => room.type != DungeonRoomType.start,
      );
      if (candidateIndex != -1) {
        generatedRooms[candidateIndex] = generatedRooms[candidateIndex]
            .copyWith(
              monsters: <DungeonMonster>[
                DungeonMonster(type: 'walker', threat: max(1, levelNumber)),
              ],
            );
      }
    }
    if (options.includeItems &&
        levelNumber > 1 &&
        generatedRooms.isNotEmpty &&
        generatedRooms.every((room) => room.items!.isEmpty)) {
      final candidateIndex = generatedRooms.indexWhere(
        (room) => room.type == DungeonRoomType.start,
      );
      final safeIndex = candidateIndex == -1 ? 0 : candidateIndex;
      generatedRooms[safeIndex] = generatedRooms[safeIndex].copyWith(
        items: <DungeonItem>[
          DungeonItem(type: 'coins', amount: 6 + (levelNumber * 2)),
        ],
      );
    }

    final generatedCorridors = corridors
        .map(
          (c) => DungeonCorridor(
            fromRoomId: c.from,
            toRoomId: c.to,
            ax: c.ax,
            ay: c.ay,
            bx: c.bx,
            by: c.by,
            horizontalFirst: c.horizontalFirst,
            width: _corridorWidth,
          ),
        )
        .toList();

    final monsterCount = generatedRooms.fold<int>(
      0,
      (sum, room) => sum + (room.monsters?.length ?? 0),
    );
    final itemCount = generatedRooms.fold<int>(
      0,
      (sum, room) => sum + (room.items?.length ?? 0),
    );
    log?.call(
      'content monsters=$monsterCount items=$itemCount '
      'includeMonsters=${options.includeMonsters} includeItems=${options.includeItems}',
    );

    return DungeonLevel(
      levelNumber: levelNumber,
      seed: options.seed,
      width: width,
      height: height,
      targetRooms: targetRooms,
      includeMonsters: options.includeMonsters,
      includeItems: options.includeItems,
      startRoomId: start,
      rooms: generatedRooms,
      corridors: generatedCorridors,
    );
  }

  DungeonLevel generateLevel({
    required int levelNumber,
    required int seed,
    int? width,
    int? height,
    int? targetRooms,
    bool includeMonsters = true,
    bool includeItems = true,
    DungeonGenerationLog? log,
  }) {
    return generate(
      DungeonGenerationOptions(
        levelNumber: levelNumber,
        seed: seed,
        width: width,
        height: height,
        targetRooms: targetRooms,
        includeMonsters: includeMonsters,
        includeItems: includeItems,
        log: log,
      ),
    );
  }

  // --- BSP partitioning -----------------------------------------------------

  /// Greedily splits the largest leaves until there are [targetRooms] of them
  /// (or none can be split further), keeping the binary tree for sibling
  /// connection. Reaching the target exactly keeps small floors small.
  void _partition(_BspNode root, Random random, int targetRooms) {
    final leaves = <_BspNode>[root];
    while (leaves.length < targetRooms) {
      final splittable =
          leaves
              .where((n) => n.w >= 2 * _minLeaf || n.h >= 2 * _minLeaf)
              .toList()
            ..sort((a, b) => (b.w * b.h).compareTo(a.w * a.h));
      if (splittable.isEmpty) {
        break;
      }
      // Bias toward the largest couple of leaves for size variety.
      final node = splittable[random.nextInt(min(2, splittable.length))];
      if (!_splitNode(node, random)) {
        break;
      }
      leaves
        ..remove(node)
        ..add(node.left!)
        ..add(node.right!);
    }
  }

  bool _splitNode(_BspNode node, Random random) {
    final canSplitW = node.w >= 2 * _minLeaf;
    final canSplitH = node.h >= 2 * _minLeaf;
    if (!canSplitW && !canSplitH) {
      return false;
    }

    // Split the longer axis (with a little randomness when roughly square).
    bool splitVertical;
    if (node.w > node.h * 1.25 && canSplitW) {
      splitVertical = true;
    } else if (node.h > node.w * 1.25 && canSplitH) {
      splitVertical = false;
    } else if (canSplitW && canSplitH) {
      splitVertical = random.nextBool();
    } else {
      splitVertical = canSplitW;
    }

    if (splitVertical) {
      final cut = _minLeaf + random.nextInt(node.w - 2 * _minLeaf + 1);
      node.left = _BspNode(node.x, node.y, cut, node.h);
      node.right = _BspNode(node.x + cut, node.y, node.w - cut, node.h);
    } else {
      final cut = _minLeaf + random.nextInt(node.h - 2 * _minLeaf + 1);
      node.left = _BspNode(node.x, node.y, node.w, cut);
      node.right = _BspNode(node.x, node.y + cut, node.w, node.h - cut);
    }
    return true;
  }

  _MutableRoom _carveRoom(_BspNode leaf, Random random, {required String id}) {
    // Inset the room from its leaf by random padding, leaving gaps that
    // corridors bridge. Clamp so the room never drops below [_minRoom].
    // Pads of 2..4 tiles per side leave 4+ tile gaps between neighbours, so
    // rooms read as separate chambers joined by real corridors.
    final maxPadX = max(1, (leaf.w - _minRoom) ~/ 2 - 1).clamp(1, 3);
    final maxPadY = max(1, (leaf.h - _minRoom) ~/ 2 - 1).clamp(1, 3);
    final padL = 2 + random.nextInt(maxPadX);
    final padR = 2 + random.nextInt(maxPadX);
    final padT = 2 + random.nextInt(maxPadY);
    final padB = 2 + random.nextInt(maxPadY);

    var rx = leaf.x + padL;
    var ry = leaf.y + padT;
    var rw = leaf.w - padL - padR;
    var rh = leaf.h - padT - padB;
    if (rw < _minRoom) {
      rw = min(leaf.w, _minRoom);
      rx = leaf.x + (leaf.w - rw) ~/ 2;
    }
    if (rh < _minRoom) {
      rh = min(leaf.h, _minRoom);
      ry = leaf.y + (leaf.h - rh) ~/ 2;
    }
    return _MutableRoom(id: id, x: rx, y: ry, w: rw, h: rh);
  }

  // --- Corridor connection --------------------------------------------------

  /// Connects the two child subtrees of every internal node with a corridor
  /// between their closest pair of rooms. This yields a spanning tree.
  void _connect(
    _BspNode node,
    Random random,
    List<_MutableRoom> allRooms,
    List<_MutableCorridor> corridors,
    Set<String> connected,
  ) {
    if (node.isLeaf) {
      return;
    }
    _connect(node.left!, random, allRooms, corridors, connected);
    _connect(node.right!, random, allRooms, corridors, connected);

    final leftLeaves = <_BspNode>[];
    final rightLeaves = <_BspNode>[];
    node.left!.collectLeaves(leftLeaves);
    node.right!.collectLeaves(rightLeaves);
    final pairs = <({_MutableRoom a, _MutableRoom b, int gap})>[
      for (final l in leftLeaves)
        for (final r in rightLeaves)
          (a: l.room!, b: r.room!, gap: _roomGap(l.room!, r.room!)),
    ]..sort((p, q) => p.gap.compareTo(q.gap));

    // Prefer the closest pair that admits a clean corridor; fall back to the
    // closest pair with a centre-to-centre corridor so the tree stays whole.
    for (final pair in pairs) {
      final plan = _planCorridor(pair.a, pair.b, random, allRooms, corridors);
      if (plan != null) {
        _commitCorridor(plan, corridors, connected);
        return;
      }
    }
    final best = pairs.first;
    _commitCorridor(
      _centreCorridor(best.a, best.b, random),
      corridors,
      connected,
    );
  }

  void _addLoops({
    required Random random,
    required int levelNumber,
    required List<_MutableRoom> rooms,
    required List<_MutableCorridor> corridors,
    required Set<String> connected,
  }) {
    if (rooms.length < 4) {
      return;
    }
    final loopChance = (0.18 + levelNumber * 0.03).clamp(0.18, 0.5);
    // Threshold for "nearby" rooms, scaled to typical room spacing.
    final avgSpan =
        rooms.map((r) => (r.w + r.h) / 2).reduce((a, b) => a + b) /
        rooms.length;
    final loopGap = avgSpan * 1.5;

    var added = 0;
    final pairs = <({_MutableRoom a, _MutableRoom b, int gap})>[];
    for (var i = 0; i < rooms.length; i++) {
      for (var j = i + 1; j < rooms.length; j++) {
        final a = rooms[i];
        final b = rooms[j];
        if (connected.contains(_edgeKey(a.id, b.id))) {
          continue;
        }
        final gap = _roomGap(a, b);
        if (gap <= loopGap) {
          pairs.add((a: a, b: b, gap: gap));
        }
      }
    }
    pairs.sort((p, q) => p.gap.compareTo(q.gap));
    _MutableCorridor? firstClean;
    for (final pair in pairs) {
      final plan = _planCorridor(pair.a, pair.b, random, rooms, corridors);
      if (plan == null) {
        continue;
      }
      firstClean ??= plan;
      if (random.nextDouble() <= loopChance) {
        _commitCorridor(plan, corridors, connected);
        added++;
      }
    }
    // Guarantee at least one loop: prefer a clean candidate, else force the
    // closest pair.
    if (added == 0 && pairs.isNotEmpty) {
      _commitCorridor(
        firstClean ?? _centreCorridor(pairs.first.a, pairs.first.b, random),
        corridors,
        connected,
      );
    }
  }

  void _commitCorridor(
    _MutableCorridor corridor,
    List<_MutableCorridor> corridors,
    Set<String> connected,
  ) {
    if (connected.add(_edgeKey(corridor.from, corridor.to))) {
      corridors.add(corridor);
    }
  }

  /// Chebyshev-style gap between two room rects in tiles (0 when touching).
  int _roomGap(_MutableRoom a, _MutableRoom b) {
    final dx = max(0, max(a.x - (b.x + b.w), b.x - (a.x + a.w)));
    final dy = max(0, max(a.y - (b.y + b.h), b.y - (a.y + a.h)));
    return dx + dy;
  }

  /// Legacy centre-to-centre L corridor; always valid, may clip other rooms.
  _MutableCorridor _centreCorridor(
    _MutableRoom a,
    _MutableRoom b,
    Random random,
  ) {
    return _MutableCorridor(
      from: a.id,
      to: b.id,
      ax: a.cx,
      ay: a.cy,
      bx: b.cx,
      by: b.cy,
      horizontalFirst: random.nextBool(),
    );
  }

  /// Plans a corridor that leaves [a] and enters [b] through facing walls:
  /// straight when the rooms overlap on an axis, otherwise an L that exits a
  /// side of one room and enters the top/bottom (or side) of the other.
  /// Returns null when every candidate would cut through or hug another room,
  /// or run alongside an existing corridor.
  _MutableCorridor? _planCorridor(
    _MutableRoom a,
    _MutableRoom b,
    Random random,
    List<_MutableRoom> allRooms,
    List<_MutableCorridor> existing,
  ) {
    const half = _corridorWidth ~/ 2;
    // Keep corridor walls off room corners.
    const margin = half + 1;
    // Corridor ends sink this far into each room so the floor bands overlap.
    const sink = 1;

    int pick(int lo, int hi) {
      // Bias toward the middle of the shared span so doors look intentional.
      final mid = (lo + hi) ~/ 2;
      final spread = max(0, (hi - lo) ~/ 3);
      return (mid - spread + random.nextInt(2 * spread + 1)).clamp(lo, hi);
    }

    final candidates = <_MutableCorridor>[];

    // Straight vertical: shared x span.
    final vxLo = max(a.x, b.x) + margin;
    final vxHi = min(a.x + a.w, b.x + b.w) - 1 - margin;
    if (vxLo <= vxHi) {
      final x = pick(vxLo, vxHi);
      final (top, bottom) = a.y < b.y ? (a, b) : (b, a);
      if (top.y + top.h <= bottom.y) {
        candidates.add(
          _MutableCorridor(
            from: top.id,
            to: bottom.id,
            ax: x,
            ay: top.y + top.h - 1 - sink,
            bx: x,
            by: bottom.y + sink,
            horizontalFirst: false,
          ),
        );
      }
    }

    // Straight horizontal: shared y span.
    final hyLo = max(a.y, b.y) + margin;
    final hyHi = min(a.y + a.h, b.y + b.h) - 1 - margin;
    if (hyLo <= hyHi) {
      final y = pick(hyLo, hyHi);
      final (left, right) = a.x < b.x ? (a, b) : (b, a);
      if (left.x + left.w <= right.x) {
        candidates.add(
          _MutableCorridor(
            from: left.id,
            to: right.id,
            ax: left.x + left.w - 1 - sink,
            ay: y,
            bx: right.x + sink,
            by: y,
            horizontalFirst: true,
          ),
        );
      }
    }

    // L-shapes: leave [from] horizontally, enter [to] vertically.
    void addL(_MutableRoom from, _MutableRoom to) {
      if (from.h - 2 * margin < 1 || to.w - 2 * margin < 1) {
        return;
      }
      final y = pick(from.y + margin, from.y + from.h - 1 - margin);
      final x = pick(to.x + margin, to.x + to.w - 1 - margin);
      // Elbow must sit clear of [from] horizontally and of [to] vertically,
      // or the legs would run along a room wall.
      final clearOfFrom =
          x < from.x - margin || x > from.x + from.w - 1 + margin;
      final clearOfTo = y < to.y - margin || y > to.y + to.h - 1 + margin;
      if (!clearOfFrom || !clearOfTo) {
        return;
      }
      candidates.add(
        _MutableCorridor(
          from: from.id,
          to: to.id,
          ax: x < from.x ? from.x + sink : from.x + from.w - 1 - sink,
          ay: y,
          bx: x,
          by: y < to.y ? to.y + sink : to.y + to.h - 1 - sink,
          horizontalFirst: true,
        ),
      );
    }

    if (candidates.isEmpty) {
      final first = random.nextBool();
      addL(first ? a : b, first ? b : a);
      addL(first ? b : a, first ? a : b);
    }

    for (final c in candidates) {
      if (_corridorIsClean(c, allRooms, existing)) {
        return c;
      }
    }
    return null;
  }

  /// Tile rects (inclusive-exclusive) covered by the two legs of [c].
  List<({int x0, int y0, int x1, int y1})> _corridorBands(_MutableCorridor c) {
    const half = _corridorWidth ~/ 2;
    ({int x0, int y0, int x1, int y1}) band(int ax, int ay, int bx, int by) {
      if (ay == by) {
        return (
          x0: min(ax, bx),
          y0: ay - half,
          x1: max(ax, bx) + 1,
          y1: ay + half + 1,
        );
      }
      return (
        x0: ax - half,
        y0: min(ay, by),
        x1: ax + half + 1,
        y1: max(ay, by) + 1,
      );
    }

    final ex = c.horizontalFirst ? c.bx : c.ax;
    final ey = c.horizontalFirst ? c.ay : c.by;
    return [band(c.ax, c.ay, ex, ey), band(ex, ey, c.bx, c.by)];
  }

  bool _corridorIsClean(
    _MutableCorridor c,
    List<_MutableRoom> allRooms,
    List<_MutableCorridor> existing,
  ) {
    bool overlaps(
      ({int x0, int y0, int x1, int y1}) band,
      int x,
      int y,
      int w,
      int h,
      int pad,
    ) {
      return band.x0 < x + w + pad &&
          band.x1 > x - pad &&
          band.y0 < y + h + pad &&
          band.y1 > y - pad;
    }

    final bands = _corridorBands(c);
    for (final room in allRooms) {
      if (room.id == c.from || room.id == c.to) {
        continue;
      }
      for (final band in bands) {
        if (overlaps(band, room.x, room.y, room.w, room.h, 2)) {
          return false;
        }
      }
    }
    // Reject corridors that would run beside or on top of an existing one
    // (parallel double-corridors read as a glitch). Crossing is fine only at
    // shared rooms, so any contact outside the endpoint rooms is rejected.
    final endpoints = allRooms
        .where((r) => r.id == c.from || r.id == c.to)
        .toList();
    bool insideEndpoint(int tx, int ty) => endpoints.any(
      (r) => tx >= r.x && tx < r.x + r.w && ty >= r.y && ty < r.y + r.h,
    );
    for (final other in existing) {
      for (final ob in _corridorBands(other)) {
        for (final band in bands) {
          if (!overlaps(band, ob.x0, ob.y0, ob.x1 - ob.x0, ob.y1 - ob.y0, 1)) {
            continue;
          }
          final ix0 = max(band.x0 - 1, ob.x0);
          final iy0 = max(band.y0 - 1, ob.y0);
          final ix1 = min(band.x1 + 1, ob.x1);
          final iy1 = min(band.y1 + 1, ob.y1);
          for (var ty = iy0; ty < iy1; ty++) {
            for (var tx = ix0; tx < ix1; tx++) {
              if (!insideEndpoint(tx, ty)) {
                return false;
              }
            }
          }
        }
      }
    }
    return true;
  }

  String _edgeKey(String a, String b) =>
      (a.compareTo(b) <= 0) ? '$a|$b' : '$b|$a';

  Map<String, List<String>> _adjacency(
    Iterable<String> ids,
    List<_MutableCorridor> corridors,
  ) {
    final adjacency = <String, List<String>>{for (final id in ids) id: []};
    for (final c in corridors) {
      adjacency[c.from]!.add(c.to);
      adjacency[c.to]!.add(c.from);
    }
    return adjacency;
  }

  String _pickStartRoom(
    Map<String, _MutableRoom> rooms, {
    required int width,
    required int height,
  }) {
    // Start near the bottom-centre so a portrait floor reads "upward".
    final targetX = width / 2;
    final targetY = height * 0.82;
    String? best;
    double bestDist = double.infinity;
    for (final room in rooms.values) {
      final dist =
          (room.cx - targetX).abs() + (room.cy - targetY).abs().toDouble();
      if (dist < bestDist) {
        bestDist = dist;
        best = room.id;
      }
    }
    return best ?? rooms.keys.first;
  }

  Map<String, int> _distanceFromStart({
    required String start,
    required Map<String, List<String>> adjacency,
  }) {
    final distance = <String, int>{start: 0};
    final queue = <String>[start];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final d = distance[current] ?? 0;
      for (final next in adjacency[current] ?? const <String>[]) {
        if (!distance.containsKey(next)) {
          distance[next] = d + 1;
          queue.add(next);
        }
      }
    }
    return distance;
  }

  void _assignRoomTypes({
    required Random random,
    required int levelNumber,
    required String start,
    required Map<String, _MutableRoom> rooms,
    required Map<String, int> distances,
  }) {
    rooms[start]?.type = DungeonRoomType.start;

    final nonStart = rooms.values.where((room) => room.id != start).toList()
      ..sort((a, b) => (distances[b.id] ?? 0).compareTo(distances[a.id] ?? 0));
    if (nonStart.isEmpty) {
      return;
    }

    final treasureCount = levelNumber < 2
        ? 0
        : min(nonStart.length, 1 + ((levelNumber - 2) ~/ 4));
    for (var i = 0; i < treasureCount && i < nonStart.length; i += 1) {
      nonStart[i].type = DungeonRoomType.treasure;
    }

    if (isWardenFloor(levelNumber)) {
      nonStart.first.type = DungeonRoomType.boss;
    }
  }

  // --- Content --------------------------------------------------------------

  List<DungeonMonster> _generateMonsters({
    required Random random,
    required int levelNumber,
    required DungeonRoomType roomType,
    required int distanceFromStart,
  }) {
    if (roomType == DungeonRoomType.start) {
      return <DungeonMonster>[];
    }

    if (levelNumber == 1) {
      return <DungeonMonster>[const DungeonMonster(type: 'walker', threat: 1)];
    }

    if (roomType == DungeonRoomType.boss) {
      return <DungeonMonster>[
        DungeonMonster(type: 'boss', threat: levelNumber + 6),
      ];
    }

    if (roomType == DungeonRoomType.treasure) {
      if (levelNumber >= 5 && random.nextDouble() < 0.35) {
        return <DungeonMonster>[
          DungeonMonster(type: 'paddle', threat: levelNumber + 2),
        ];
      }
      return <DungeonMonster>[];
    }

    var typePool = <String>['walker', 'walker', 'turret', 'hedgehog'];
    if (levelNumber >= 4) {
      typePool = List<String>.from(typePool)..add('pulser');
    }

    final baseCount = 1 + (levelNumber ~/ 5);
    final distanceBonus = distanceFromStart >= 4 ? 1 : 0;
    final randomBonus = random.nextInt(2);
    final count = (baseCount + distanceBonus + randomBonus).clamp(1, 4);

    final monsters = <DungeonMonster>[];
    for (var i = 0; i < count; i += 1) {
      final type = typePool[random.nextInt(typePool.length)];
      final threat = max(
        1,
        levelNumber + (distanceFromStart ~/ 2) + random.nextInt(3),
      );
      monsters.add(DungeonMonster(type: type, threat: threat));
    }
    return monsters;
  }

  List<DungeonItem> _generateItems({
    required Random random,
    required int levelNumber,
    required DungeonRoomType roomType,
    required int distanceFromStart,
  }) {
    if (levelNumber == 1) {
      return <DungeonItem>[];
    }

    if (roomType == DungeonRoomType.boss) {
      return <DungeonItem>[
        DungeonItem(type: 'boss_relic', amount: 1),
        DungeonItem(type: 'coins', amount: 40 + (levelNumber * 6)),
      ];
    }

    if (roomType == DungeonRoomType.treasure) {
      final items = <DungeonItem>[
        DungeonItem(
          type: 'coins',
          amount: 20 + (levelNumber * 5) + random.nextInt(24),
        ),
      ];
      if (random.nextDouble() < 0.55) {
        items.add(
          DungeonItem(type: 'coins', amount: 12 + random.nextInt(2) * 6),
        );
      }
      if (levelNumber >= 4 && random.nextDouble() < 0.25) {
        items.add(const DungeonItem(type: 'relic_shard', amount: 1));
      }
      return items;
    }

    if (roomType == DungeonRoomType.start) {
      return <DungeonItem>[DungeonItem(type: 'coins', amount: 4 + levelNumber)];
    }

    const dropChance = 0.24;
    if (random.nextDouble() > dropChance) {
      return <DungeonItem>[];
    }

    final value =
        5 + levelNumber + min(distanceFromStart, 6).toInt() + random.nextInt(6);
    return <DungeonItem>[DungeonItem(type: 'coins', amount: value)];
  }
}

// --- Immutable model --------------------------------------------------------

class DungeonLevel {
  const DungeonLevel({
    required this.levelNumber,
    required this.seed,
    required this.width,
    required this.height,
    required this.targetRooms,
    required this.includeMonsters,
    required this.includeItems,
    required this.startRoomId,
    required this.rooms,
    required this.corridors,
  });

  final int levelNumber;
  final int seed;

  /// Tile dimensions of the whole map.
  final int width;
  final int height;
  final int targetRooms;
  final bool includeMonsters;
  final bool includeItems;
  final String startRoomId;
  final List<DungeonRoom> rooms;
  final List<DungeonCorridor> corridors;

  /// Undirected room-to-room adjacency derived from [corridors].
  Map<String, List<String>> adjacency() {
    final map = <String, List<String>>{
      for (final room in rooms) room.id: <String>[],
    };
    for (final c in corridors) {
      map[c.fromRoomId]?.add(c.toRoomId);
      map[c.toRoomId]?.add(c.fromRoomId);
    }
    return map;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'levelNumber': levelNumber,
      'seed': seed,
      'width': width,
      'height': height,
      'targetRooms': targetRooms,
      'includeMonsters': includeMonsters,
      'includeItems': includeItems,
      'startRoomId': startRoomId,
      'rooms': rooms.map((room) => room.toJson()).toList(),
      'corridors': corridors.map((c) => c.toJson()).toList(),
    };
  }
}

class DungeonRoom {
  const DungeonRoom({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.type,
    this.monsters,
    this.items,
    this.roomTemplateId,
    this.templateRotationQuarterTurns = 0,
    this.templateFlipH = false,
    this.templateFlipV = false,
  });

  final String id;

  /// Top-left tile of the room rect.
  final int x;
  final int y;

  /// Room rect size in tiles.
  final int width;
  final int height;
  final DungeonRoomType type;
  final List<DungeonMonster>? monsters;
  final List<DungeonItem>? items;

  /// Optional semantic layout from `assets/levels/room_templates/<id>.json`.
  final String? roomTemplateId;
  final int templateRotationQuarterTurns;
  final bool templateFlipH;
  final bool templateFlipV;

  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  DungeonRoom copyWith({
    List<DungeonMonster>? monsters,
    List<DungeonItem>? items,
  }) {
    return DungeonRoom(
      id: id,
      x: x,
      y: y,
      width: width,
      height: height,
      type: type,
      monsters: monsters ?? this.monsters,
      items: items ?? this.items,
      roomTemplateId: roomTemplateId,
      templateRotationQuarterTurns: templateRotationQuarterTurns,
      templateFlipH: templateFlipH,
      templateFlipV: templateFlipV,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'type': type.name,
    };
    if (monsters != null) {
      json['monsters'] = monsters!.map((m) => m.toJson()).toList();
    }
    if (items != null) {
      json['items'] = items!.map((item) => item.toJson()).toList();
    }
    if (roomTemplateId != null) {
      json['roomTemplateId'] = roomTemplateId;
      json['templateRotationQuarterTurns'] = templateRotationQuarterTurns;
      json['templateFlipH'] = templateFlipH;
      json['templateFlipV'] = templateFlipV;
    }
    return json;
  }
}

/// An L-shaped corridor between two room centres (tile coordinates). The path
/// runs from (ax, ay) to (bx, by) through one right-angle elbow; when
/// [horizontalFirst] it travels horizontally to (bx, ay) then vertically,
/// otherwise vertically to (ax, by) then horizontally.
class DungeonCorridor {
  const DungeonCorridor({
    required this.fromRoomId,
    required this.toRoomId,
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
    required this.horizontalFirst,
    required this.width,
  });

  final String fromRoomId;
  final String toRoomId;
  final int ax;
  final int ay;
  final int bx;
  final int by;
  final bool horizontalFirst;
  final int width;

  int get elbowX => horizontalFirst ? bx : ax;
  int get elbowY => horizontalFirst ? ay : by;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fromRoomId': fromRoomId,
      'toRoomId': toRoomId,
      'ax': ax,
      'ay': ay,
      'bx': bx,
      'by': by,
      'horizontalFirst': horizontalFirst,
      'width': width,
    };
  }
}

class DungeonMonster {
  const DungeonMonster({required this.type, required this.threat});

  final String type;
  final int threat;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'type': type, 'threat': threat};
  }
}

class DungeonItem {
  const DungeonItem({required this.type, required this.amount});

  final String type;
  final int amount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'type': type, 'amount': amount};
  }
}

enum DungeonRoomType { start, combat, trap, treasure, boss }

// --- Mutable generation scratch types --------------------------------------

class _BspNode {
  _BspNode(this.x, this.y, this.w, this.h);

  final int x;
  final int y;
  final int w;
  final int h;
  _BspNode? left;
  _BspNode? right;
  _MutableRoom? room;

  bool get isLeaf => left == null && right == null;

  void collectLeaves(List<_BspNode> out) {
    if (isLeaf) {
      out.add(this);
      return;
    }
    left!.collectLeaves(out);
    right!.collectLeaves(out);
  }
}

class _MutableRoom {
  _MutableRoom({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final String id;
  final int x;
  final int y;
  final int w;
  final int h;
  DungeonRoomType type = DungeonRoomType.combat;

  int get cx => x + w ~/ 2;
  int get cy => y + h ~/ 2;
}

class _MutableCorridor {
  _MutableCorridor({
    required this.from,
    required this.to,
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
    required this.horizontalFirst,
  });

  final String from;
  final String to;
  final int ax;
  final int ay;
  final int bx;
  final int by;
  final bool horizontalFirst;
}
