import 'dart:math';

import 'spinner_parts.dart';

enum UpgradeType {
  maxHp,
  damageBoost,
  spinReserve,
  gyroBearing,
  launchCoil,
  guardPlating,
  fortuneSigil,
  emergencyGrapple,
  flightStabilizer,
}

enum DungeonAbility { tether, fireball, needles }

/// One finished run stored for local high scores (sorted by score).
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.score,
    required this.deepestLevel,
    required this.enemiesKilled,
    required this.recordedAtMs,
    this.seed,
    this.maxSpinChain = 0,
    this.build,
    this.weeklyKey,
  });

  final int score;
  final int deepestLevel;
  final int enemiesKilled;
  final int recordedAtMs;
  final int? seed;
  final int maxSpinChain;
  /// The spinner build that achieved this score (null for legacy entries).
  final SpinnerBuild? build;
  /// ISO week tag (e.g. "2026-W16") if this run used the weekly challenge seed.
  final String? weeklyKey;

  static List<LeaderboardEntry> mergeTop(
    List<LeaderboardEntry> existing,
    LeaderboardEntry run, {
    int maxEntries = 10,
  }) {
    final merged = <LeaderboardEntry>[...existing, run];
    merged.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      final byDepth = b.deepestLevel.compareTo(a.deepestLevel);
      if (byDepth != 0) {
        return byDepth;
      }
      return b.recordedAtMs.compareTo(a.recordedAtMs);
    });
    if (merged.length > maxEntries) {
      return merged.sublist(0, maxEntries);
    }
    return merged;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'score': score,
      'deepestLevel': deepestLevel,
      'enemiesKilled': enemiesKilled,
      'recordedAtMs': recordedAtMs,
      if (seed != null) 'seed': seed,
      'maxSpinChain': maxSpinChain,
      if (build != null) 'build': build!.toJson(),
      if (weeklyKey != null) 'weeklyKey': weeklyKey,
    };
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final rawBuild = json['build'];
    SpinnerBuild? parsedBuild;
    if (rawBuild is Map) {
      parsedBuild = SpinnerBuild.fromJson(Map<String, dynamic>.from(rawBuild));
    }
    return LeaderboardEntry(
      score: max(0, (json['score'] as num?)?.toInt() ?? 0),
      deepestLevel: max(0, (json['deepestLevel'] as num?)?.toInt() ?? 0),
      enemiesKilled: max(0, (json['enemiesKilled'] as num?)?.toInt() ?? 0),
      recordedAtMs: max(0, (json['recordedAtMs'] as num?)?.toInt() ?? 0),
      seed: (json['seed'] as num?)?.toInt(),
      maxSpinChain: max(0, (json['maxSpinChain'] as num?)?.toInt() ?? 0),
      build: parsedBuild,
      weeklyKey: (json['weeklyKey'] as String?)?.trim().isNotEmpty == true
          ? json['weeklyKey'] as String
          : null,
    );
  }
}

class UpgradeDefinition {
  const UpgradeDefinition({
    required this.type,
    required this.label,
    required this.costs,
  });

  final UpgradeType type;
  final String label;
  final List<int> costs;

  int get maxTier => costs.length;
}

class MetaProgress {
  MetaProgress({
    required this.version,
    required this.bankedCoins,
    required this.bestScore,
    required this.tiers,
    required this.totalRuns,
    required this.deepestLevelReached,
    required this.unlockedPartIds,
    required this.selectedBuild,
    required this.unlockedAbilities,
    required this.totalCoinsCollected,
    required this.totalEnemiesDefeated,
    required this.bossClears,
    required this.completedGearTasks,
    required this.leaderboard,
    required this.tutorialSeen,
  });

  factory MetaProgress.defaults() {
    return MetaProgress(
      version: 1,
      bankedCoins: 0,
      bestScore: 0,
      tiers: <UpgradeType, int>{},
      totalRuns: 0,
      deepestLevelReached: 0,
      unlockedPartIds: SpinnerPartCatalog.defaultUnlockedPartIds,
      selectedBuild: SpinnerPartCatalog.defaultBuild,
      unlockedAbilities: <DungeonAbility>{DungeonAbility.tether},
      totalCoinsCollected: 0,
      totalEnemiesDefeated: 0,
      bossClears: 0,
      completedGearTasks: <String>{},
      leaderboard: const <LeaderboardEntry>[],
      tutorialSeen: false,
    );
  }

  factory MetaProgress.fromJson(Map<String, dynamic> json) {
    try {
      final rawTiers = (json['tiers'] as Map?) ?? const <String, dynamic>{};
      final parsedTiers = <UpgradeType, int>{};

      for (final type in UpgradeType.values) {
        final rawValue = rawTiers[type.name];
        if (rawValue is num) {
          parsedTiers[type] = rawValue.toInt();
        }
      }

      final unlockedRaw = json['unlockedPartIds'];
      final unlockedIds = <String>{};
      if (unlockedRaw is List) {
        for (final id in unlockedRaw) {
          if (id is String && id.isNotEmpty) {
            unlockedIds.add(id);
          }
        }
      }

      final selectedBuildRaw = json['selectedBuild'];
      final selectedBuild = selectedBuildRaw is Map
          ? SpinnerBuild.fromJson(Map<String, dynamic>.from(selectedBuildRaw))
          : SpinnerPartCatalog.defaultBuild;

      final bankedCoins = max(0, (json['bankedCoins'] as num?)?.toInt() ?? 0);
      final totalRuns = max(0, (json['totalRuns'] as num?)?.toInt() ?? 0);
      final deepestLevelReached = max(
        0,
        (json['deepestLevelReached'] as num?)?.toInt() ?? 0,
      );
      final completedTasksRaw = json['completedGearTasks'];
      final completedTasks = <String>{};
      if (completedTasksRaw is List) {
        for (final value in completedTasksRaw) {
          if (value is String && value.isNotEmpty) {
            completedTasks.add(value);
          }
        }
      }
      final bossClears = max(0, (json['bossClears'] as num?)?.toInt() ?? 0);
      final unlocked = SpinnerPartCatalog.unlockedPartsForProgress(
        bankedCoins: bankedCoins,
        totalRuns: totalRuns,
        deepestLevelReached: deepestLevelReached,
        bossClears: bossClears,
        completedTaskIds: completedTasks,
        existingUnlocked: unlockedIds,
      );
      final sanitizedBuild = SpinnerPartCatalog.sanitizeBuild(
        build: selectedBuild,
        unlockedIds: unlocked,
      );

      final leaderboardRaw = json['leaderboard'];
      final leaderboard = <LeaderboardEntry>[];
      if (leaderboardRaw is List) {
        for (final item in leaderboardRaw) {
          if (item is Map) {
            leaderboard.add(
              LeaderboardEntry.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      leaderboard.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) {
          return byScore;
        }
        return b.deepestLevel.compareTo(a.deepestLevel);
      });

      final abilitiesRaw = json['unlockedAbilities'];
      final unlockedAbilities = <DungeonAbility>{DungeonAbility.tether};
      if (abilitiesRaw is List) {
        for (final value in abilitiesRaw) {
          if (value is String) {
            for (final ability in DungeonAbility.values) {
              if (ability.name == value) {
                unlockedAbilities.add(ability);
              }
            }
          }
        }
      }

      final tutorialSeenRaw = json['tutorialSeen'];
      final tutorialSeen = tutorialSeenRaw is bool
          ? tutorialSeenRaw
          : totalRuns > 0;

      return MetaProgress(
        version: (json['version'] as num?)?.toInt() ?? 1,
        bankedCoins: bankedCoins,
        bestScore: max(0, (json['bestScore'] as num?)?.toInt() ?? 0),
        tiers: UpgradeSystem.clampTiers(parsedTiers),
        totalRuns: totalRuns,
        deepestLevelReached: deepestLevelReached,
        unlockedPartIds: unlocked,
        selectedBuild: sanitizedBuild,
        unlockedAbilities: unlockedAbilities,
        totalCoinsCollected: max(
          0,
          (json['totalCoinsCollected'] as num?)?.toInt() ?? 0,
        ),
        totalEnemiesDefeated: max(
          0,
          (json['totalEnemiesDefeated'] as num?)?.toInt() ?? 0,
        ),
        bossClears: bossClears,
        completedGearTasks: completedTasks,
        leaderboard: leaderboard,
        tutorialSeen: tutorialSeen,
      );
    } catch (_) {
      return MetaProgress.defaults();
    }
  }

  final int version;
  final int bankedCoins;
  final int bestScore;
  final Map<UpgradeType, int> tiers;
  final int totalRuns;
  final int deepestLevelReached;
  final Set<String> unlockedPartIds;
  final SpinnerBuild selectedBuild;
  final Set<DungeonAbility> unlockedAbilities;
  final int totalCoinsCollected;
  final int totalEnemiesDefeated;
  final int bossClears;
  final Set<String> completedGearTasks;
  final List<LeaderboardEntry> leaderboard;
  final bool tutorialSeen;

  MetaProgress copyWith({
    int? version,
    int? bankedCoins,
    int? bestScore,
    Map<UpgradeType, int>? tiers,
    int? totalRuns,
    int? deepestLevelReached,
    Set<String>? unlockedPartIds,
    SpinnerBuild? selectedBuild,
    Set<DungeonAbility>? unlockedAbilities,
    int? totalCoinsCollected,
    int? totalEnemiesDefeated,
    int? bossClears,
    Set<String>? completedGearTasks,
    List<LeaderboardEntry>? leaderboard,
    bool? tutorialSeen,
  }) {
    final nextBankedCoins = bankedCoins ?? this.bankedCoins;
    final nextTotalRuns = totalRuns ?? this.totalRuns;
    final nextDeepestLevel = deepestLevelReached ?? this.deepestLevelReached;
    final nextBossClears = bossClears ?? this.bossClears;
    final nextUnlocked = SpinnerPartCatalog.unlockedPartsForProgress(
      bankedCoins: nextBankedCoins,
      totalRuns: nextTotalRuns,
      deepestLevelReached: nextDeepestLevel,
      bossClears: nextBossClears,
      completedTaskIds: completedGearTasks ?? this.completedGearTasks,
      existingUnlocked: unlockedPartIds ?? this.unlockedPartIds,
    );
    final nextBuild = SpinnerPartCatalog.sanitizeBuild(
      build: selectedBuild ?? this.selectedBuild,
      unlockedIds: nextUnlocked,
    );

    return MetaProgress(
      version: version ?? this.version,
      bankedCoins: nextBankedCoins,
      bestScore: bestScore ?? this.bestScore,
      tiers: tiers ?? this.tiers,
      totalRuns: nextTotalRuns,
      deepestLevelReached: nextDeepestLevel,
      unlockedPartIds: nextUnlocked,
      selectedBuild: nextBuild,
      unlockedAbilities: <DungeonAbility>{
        DungeonAbility.tether,
        ...(unlockedAbilities ?? this.unlockedAbilities),
      },
      totalCoinsCollected: totalCoinsCollected ?? this.totalCoinsCollected,
      totalEnemiesDefeated: totalEnemiesDefeated ?? this.totalEnemiesDefeated,
      bossClears: nextBossClears,
      completedGearTasks: completedGearTasks ?? this.completedGearTasks,
      leaderboard: leaderboard ?? this.leaderboard,
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'bankedCoins': bankedCoins,
      'bestScore': bestScore,
      'tiers': <String, int>{
        for (final entry in tiers.entries) entry.key.name: entry.value,
      },
      'totalRuns': totalRuns,
      'deepestLevelReached': deepestLevelReached,
      'unlockedPartIds': unlockedPartIds.toList()..sort(),
      'selectedBuild': selectedBuild.toJson(),
      'unlockedAbilities': unlockedAbilities.map((entry) => entry.name).toList()
        ..sort(),
      'totalCoinsCollected': totalCoinsCollected,
      'totalEnemiesDefeated': totalEnemiesDefeated,
      'bossClears': bossClears,
      'completedGearTasks': completedGearTasks.toList()..sort(),
      'leaderboard': leaderboard.map((e) => e.toJson()).toList(),
      'tutorialSeen': tutorialSeen,
    };
  }
}

class AppliedUpgrades {
  const AppliedUpgrades({
    this.maxHp = 80,
    this.damageMultiplier = 1,
    this.startingSpinsBonus = 0,
    this.frictionRetention = 0.86,
    this.launchSpeedMultiplier = 0.5,
    this.incomingDamageMultiplier = 1,
    this.coinMultiplier = 1,
    this.pitSaves = 0,
    this.pitPenaltyMultiplier = 1,
    this.pitSkimMinSpeed = double.infinity,
    this.pitSkimMaxRadius = 0,
    this.pitHoverSeconds = 0.1,
  });

  final int maxHp;
  final double damageMultiplier;
  final int startingSpinsBonus;
  final double frictionRetention;
  final double launchSpeedMultiplier;
  final double incomingDamageMultiplier;
  final double coinMultiplier;
  final int pitSaves;
  final double pitPenaltyMultiplier;
  final double pitSkimMinSpeed;
  final double pitSkimMaxRadius;
  final double pitHoverSeconds;
}

class UpgradeSystem {
  const UpgradeSystem._();

  static const List<UpgradeDefinition> definitions = <UpgradeDefinition>[
    UpgradeDefinition(
      type: UpgradeType.maxHp,
      label: 'Vital Core',
      costs: <int>[20, 35, 55, 80, 110, 145],
    ),
    UpgradeDefinition(
      type: UpgradeType.damageBoost,
      label: 'Impact Forge',
      costs: <int>[25, 40, 65, 95, 130, 170],
    ),
    UpgradeDefinition(
      type: UpgradeType.spinReserve,
      label: 'Spin Reserve',
      costs: <int>[18, 30, 48, 72, 102],
    ),
    UpgradeDefinition(
      type: UpgradeType.gyroBearing,
      label: 'Gyro Bearing',
      costs: <int>[20, 34, 52, 74, 100],
    ),
    UpgradeDefinition(
      type: UpgradeType.launchCoil,
      label: 'Launch Coil',
      costs: <int>[18, 30, 48, 72, 104],
    ),
    UpgradeDefinition(
      type: UpgradeType.guardPlating,
      label: 'Guard Plating',
      costs: <int>[26, 42, 64, 92, 124],
    ),
    UpgradeDefinition(
      type: UpgradeType.fortuneSigil,
      label: 'Fortune Sigil',
      costs: <int>[28, 44, 68, 96, 132],
    ),
    UpgradeDefinition(
      type: UpgradeType.emergencyGrapple,
      label: 'Emergency Grapple',
      costs: <int>[70, 120, 180],
    ),
    UpgradeDefinition(
      type: UpgradeType.flightStabilizer,
      label: 'Flight Stabilizer',
      costs: <int>[45, 80, 130, 195],
    ),
  ];

  static UpgradeDefinition definitionFor(UpgradeType type) {
    return definitions.firstWhere((entry) => entry.type == type);
  }

  static int tierFor(Map<UpgradeType, int> tiers, UpgradeType type) {
    final tier = tiers[type] ?? 0;
    final maxTier = definitionFor(type).maxTier;
    return tier.clamp(0, maxTier).toInt();
  }

  static Map<UpgradeType, int> clampTiers(Map<UpgradeType, int> tiers) {
    final normalized = <UpgradeType, int>{};
    for (final type in UpgradeType.values) {
      normalized[type] = tierFor(tiers, type);
    }
    return normalized;
  }

  static int? costForNextTier(MetaProgress progress, UpgradeType type) {
    final definition = definitionFor(type);
    final tier = tierFor(progress.tiers, type);
    if (tier >= definition.maxTier) {
      return null;
    }

    return definition.costs[tier];
  }

  static bool canPurchase(MetaProgress progress, UpgradeType type) {
    final cost = costForNextTier(progress, type);
    return cost != null && progress.bankedCoins >= cost;
  }

  static MetaProgress purchase(MetaProgress progress, UpgradeType type) {
    final cost = costForNextTier(progress, type);
    if (cost == null || progress.bankedCoins < cost) {
      return progress;
    }

    final nextTiers = Map<UpgradeType, int>.from(clampTiers(progress.tiers));
    nextTiers[type] = tierFor(nextTiers, type) + 1;

    return progress.copyWith(
      bankedCoins: progress.bankedCoins - cost,
      tiers: clampTiers(nextTiers),
    );
  }

  static AppliedUpgrades apply(Map<UpgradeType, int> tiers) {
    final normalized = clampTiers(tiers);

    final maxHpTier = normalized[UpgradeType.maxHp] ?? 0;
    final damageTier = normalized[UpgradeType.damageBoost] ?? 0;
    final spinTier = normalized[UpgradeType.spinReserve] ?? 0;
    final gyroTier = normalized[UpgradeType.gyroBearing] ?? 0;
    final launchTier = normalized[UpgradeType.launchCoil] ?? 0;
    final guardTier = normalized[UpgradeType.guardPlating] ?? 0;
    final fortuneTier = normalized[UpgradeType.fortuneSigil] ?? 0;
    final grappleTier = normalized[UpgradeType.emergencyGrapple] ?? 0;
    final flightTier = normalized[UpgradeType.flightStabilizer] ?? 0;

    final pitSaves = switch (grappleTier) {
      0 => 0,
      1 => 1,
      2 => 1,
      _ => 2,
    };

    final pitPenalty = switch (grappleTier) {
      0 => 1.0,
      1 => 1.0,
      2 => 0.7,
      _ => 0.55,
    };

    final incomingMultiplier = max(0.45, 1.0 - guardTier * 0.08);
    final launchSpeed = (0.5 + launchTier * 0.3).clamp(0.5, 2.0).toDouble();
    final frictionRetention = (0.86 + gyroTier * 0.02)
        .clamp(0.82, 0.97)
        .toDouble();

    final pitSkimMinSpeed = switch (flightTier) {
      <= 0 => double.infinity,
      1 => 680.0,
      2 => 600.0,
      3 => 520.0,
      _ => 450.0,
    };

    final pitSkimRadius = switch (flightTier) {
      <= 0 => 0.0,
      1 => 16.0,
      2 => 20.0,
      3 => 24.0,
      _ => 28.0,
    };

    final pitHoverSeconds = switch (flightTier) {
      <= 0 => 0.10,
      1 => 0.14,
      2 => 0.18,
      3 => 0.22,
      _ => 0.28,
    };

    return AppliedUpgrades(
      maxHp: 80 + (maxHpTier * 15),
      damageMultiplier: 1 + (damageTier * 0.1),
      startingSpinsBonus: spinTier,
      frictionRetention: frictionRetention,
      launchSpeedMultiplier: launchSpeed,
      incomingDamageMultiplier: incomingMultiplier,
      coinMultiplier: 1 + (fortuneTier * 0.12),
      pitSaves: pitSaves,
      pitPenaltyMultiplier: pitPenalty,
      pitSkimMinSpeed: pitSkimMinSpeed,
      pitSkimMaxRadius: pitSkimRadius,
      pitHoverSeconds: pitHoverSeconds,
    );
  }

  static String effectSummary(UpgradeType type, int tier) {
    final safeTier = max(0, tier);
    switch (type) {
      case UpgradeType.maxHp:
        return '+${safeTier * 15} max HP';
      case UpgradeType.damageBoost:
        return '+${safeTier * 10}% impact damage';
      case UpgradeType.spinReserve:
        return '+$safeTier starting spins';
      case UpgradeType.gyroBearing:
        final retention = (0.86 + safeTier * 0.02).clamp(0.82, 0.97);
        return 'friction retention ${retention.toStringAsFixed(2)}';
      case UpgradeType.launchCoil:
        final speedPct = ((0.5 + safeTier * 0.3).clamp(0.5, 2.0) * 100).round();
        return '$speedPct% launch speed';
      case UpgradeType.guardPlating:
        return '-${safeTier * 8}% incoming damage';
      case UpgradeType.fortuneSigil:
        return '+${safeTier * 12}% coin gains';
      case UpgradeType.emergencyGrapple:
        if (safeTier <= 0) {
          return 'No pit saves';
        }
        if (safeTier == 1) {
          return '1 pit save';
        }
        if (safeTier == 2) {
          return '1 pit save, reduced pit penalty';
        }
        return '2 pit saves, reduced pit penalty';
      case UpgradeType.flightStabilizer:
        final hover = switch (safeTier) {
          <= 0 => 0.10,
          1 => 0.14,
          2 => 0.18,
          3 => 0.22,
          _ => 0.28,
        };
        if (safeTier <= 0) {
          return '${hover.toStringAsFixed(2)}s pit hover';
        }
        final speed = switch (safeTier) {
          1 => 680,
          2 => 600,
          3 => 520,
          _ => 450,
        };
        final radius = switch (safeTier) {
          1 => 16,
          2 => 20,
          3 => 24,
          _ => 28,
        };
        return 'Skim pits <=$radius at >=$speed speed, '
            '${hover.toStringAsFixed(2)}s pit hover';
    }
  }
}
