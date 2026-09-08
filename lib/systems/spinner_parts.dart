import 'dart:math';

import 'package:flutter/material.dart';

enum SpinnerPartSlot { core, ring, blade, glow }

/// Visual + combat profile for a blade set. Drives both how blades are drawn
/// around the spinner and how damage scales when an enemy is hit in the
/// "blade zone" (outside the spinner body radius).
///
/// Gameplay contract:
/// - `standard`: balanced rectangular fins. Small extra reach.
/// - `curved`: sickle / halo arcs. Medium reach, slightly better speed retention feel.
/// - `hook`: comet-style thin hooked tips. Longest reach, glancing blows.
/// - `spiky`: triangular spurs. Medium reach, higher damage.
/// - `extruded`: chunky extended rectangles (forge / anchor). Long reach, heavy damage.
enum BladeShape { standard, curved, hook, spiky, extruded }

class SpinnerPartDefinition {
  const SpinnerPartDefinition({
    required this.id,
    required this.slot,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    this.previewUrl,
    this.unlockBankedCoins = 0,
    this.unlockRuns = 0,
    this.unlockDepth = 0,
    this.unlockBossClears = 0,
    this.requiredTaskId,
    this.depthRewardLabel,
    this.power = 0,
    this.speed = 0,
    this.control = 0,
    this.endurance = 0,
    this.damageMultiplier = 1,
    this.frictionBonus = 0,
    this.launchSpeedMultiplier = 1,
    this.incomingDamageMultiplier = 1,
    this.maxHpBonus = 0,
    this.startingSpinsBonus = 0,
    this.gyroStabilityBonus = 0,
    this.spinRetentionBonus = 0,
    this.bladeShape = BladeShape.standard,
    this.bladeReach = 0,
    this.bladeDamageBonus = 1,
  });

  final String id;
  final SpinnerPartSlot slot;
  final String name;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String? previewUrl;
  final int unlockBankedCoins;
  final int unlockRuns;
  final int unlockDepth;
  final int unlockBossClears;
  final String? requiredTaskId;
  /// Optional headline shown in the "depth reward" toast (e.g. "Depth 5 reward").
  final String? depthRewardLabel;
  final int power;
  final int speed;
  final int control;
  final int endurance;
  final double damageMultiplier;
  final double frictionBonus;
  final double launchSpeedMultiplier;
  final double incomingDamageMultiplier;
  final int maxHpBonus;
  final int startingSpinsBonus;
  /// Extra gyroscopic stability (less precession/wobble). Typical −0.05…0.06.
  final double gyroStabilityBonus;
  /// Extra spin retention (slower decay of |angularVelocity|). Typical −0.05…0.05.
  final double spinRetentionBonus;

  /// Visual silhouette for the blade slot. Only meaningful when
  /// `slot == SpinnerPartSlot.blade`; other slots leave this at `standard`.
  final BladeShape bladeShape;

  /// How far the blade tips extend past the body radius, in world units.
  /// Drives both how blades are drawn and the extra collision reach that
  /// lets blades hit enemies before the core body can.
  final double bladeReach;

  /// Multiplier applied on top of base spinner damage when an enemy is hit
  /// in the blade zone (outside the body radius). 1.0 = no bonus.
  final double bladeDamageBonus;
}

class SpinnerBuild {
  const SpinnerBuild({
    required this.coreId,
    required this.ringId,
    required this.bladeId,
    required this.glowId,
  });

  factory SpinnerBuild.defaults() {
    return const SpinnerBuild(
      coreId: 'core_sunforge',
      ringId: 'ring_guardian',
      bladeId: 'blade_swift',
      glowId: 'glow_ember',
    );
  }

  factory SpinnerBuild.fromJson(Map<String, dynamic> json) {
    final defaults = SpinnerBuild.defaults();
    return SpinnerBuild(
      coreId: json['coreId'] as String? ?? defaults.coreId,
      ringId: json['ringId'] as String? ?? defaults.ringId,
      bladeId: json['bladeId'] as String? ?? defaults.bladeId,
      glowId: json['glowId'] as String? ?? defaults.glowId,
    );
  }

  final String coreId;
  final String ringId;
  final String bladeId;
  final String glowId;

  SpinnerBuild copyWithSlot(SpinnerPartSlot slot, String id) {
    switch (slot) {
      case SpinnerPartSlot.core:
        return SpinnerBuild(
          coreId: id,
          ringId: ringId,
          bladeId: bladeId,
          glowId: glowId,
        );
      case SpinnerPartSlot.ring:
        return SpinnerBuild(
          coreId: coreId,
          ringId: id,
          bladeId: bladeId,
          glowId: glowId,
        );
      case SpinnerPartSlot.blade:
        return SpinnerBuild(
          coreId: coreId,
          ringId: ringId,
          bladeId: id,
          glowId: glowId,
        );
      case SpinnerPartSlot.glow:
        return SpinnerBuild(
          coreId: coreId,
          ringId: ringId,
          bladeId: bladeId,
          glowId: id,
        );
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'coreId': coreId,
      'ringId': ringId,
      'bladeId': bladeId,
      'glowId': glowId,
    };
  }
}

class SpinnerBuildStats {
  const SpinnerBuildStats({
    required this.power,
    required this.speed,
    required this.control,
    required this.endurance,
    required this.damageMultiplier,
    required this.frictionBonus,
    required this.launchSpeedMultiplier,
    required this.incomingDamageMultiplier,
    required this.maxHpBonus,
    required this.startingSpinsBonus,
    required this.coreColor,
    required this.ringColor,
    required this.bladeColor,
    required this.glowColor,
    required this.gyroStability,
    required this.spinRetention,
    required this.bladeShape,
    required this.bladeReach,
    required this.bladeDamageBonus,
  });

  final int power;
  final int speed;
  final int control;
  final int endurance;
  final double damageMultiplier;
  final double frictionBonus;
  final double launchSpeedMultiplier;
  final double incomingDamageMultiplier;
  final int maxHpBonus;
  final int startingSpinsBonus;
  final Color coreColor;
  final Color ringColor;
  final Color bladeColor;
  final Color glowColor;
  /// 0.18–0.96: resistance to precession/nutation while moving.
  final double gyroStability;
  /// 0.72–1.42: scales how slowly visual spin decays.
  final double spinRetention;
  /// Blade silhouette the active spinner should render with.
  final BladeShape bladeShape;
  /// Extra world-unit reach the blade tips add beyond the body radius.
  /// Drives both visual extent and enemy-collision reach.
  final double bladeReach;
  /// Multiplier applied to base spinner damage when enemies are struck
  /// outside the core body (i.e., connected to by blade tips).
  final double bladeDamageBonus;
}

class SpinnerGearTaskDefinition {
  const SpinnerGearTaskDefinition({
    required this.id,
    required this.title,
    required this.description,
    this.requiredRuns = 0,
    this.requiredCoinsCollected = 0,
    this.requiredEnemiesDefeated = 0,
    this.requiredBossClears = 0,
  });

  final String id;
  final String title;
  final String description;
  final int requiredRuns;
  final int requiredCoinsCollected;
  final int requiredEnemiesDefeated;
  final int requiredBossClears;
}

class SpinnerGearTaskProgress {
  const SpinnerGearTaskProgress({
    required this.definition,
    required this.currentRuns,
    required this.currentCoins,
    required this.currentKills,
    required this.currentBossClears,
  });

  final SpinnerGearTaskDefinition definition;
  final int currentRuns;
  final int currentCoins;
  final int currentKills;
  final int currentBossClears;

  bool get isComplete {
    return currentRuns >= definition.requiredRuns &&
        currentCoins >= definition.requiredCoinsCollected &&
        currentKills >= definition.requiredEnemiesDefeated &&
        currentBossClears >= definition.requiredBossClears;
  }

  String get progressLabel {
    final segments = <String>[];
    if (definition.requiredRuns > 0) {
      segments.add(
        '${currentRuns.clamp(0, definition.requiredRuns)}/${definition.requiredRuns} runs',
      );
    }
    if (definition.requiredCoinsCollected > 0) {
      segments.add(
        '${currentCoins.clamp(0, definition.requiredCoinsCollected)}/${definition.requiredCoinsCollected} coins',
      );
    }
    if (definition.requiredEnemiesDefeated > 0) {
      segments.add(
        '${currentKills.clamp(0, definition.requiredEnemiesDefeated)}/${definition.requiredEnemiesDefeated} kills',
      );
    }
    if (definition.requiredBossClears > 0) {
      segments.add(
        '${currentBossClears.clamp(0, definition.requiredBossClears)}/${definition.requiredBossClears} boss clears',
      );
    }
    return segments.join(' • ');
  }
}

class SpinnerPartCatalog {
  const SpinnerPartCatalog._();

  static const List<SpinnerGearTaskDefinition> gearTasks =
      <SpinnerGearTaskDefinition>[
        SpinnerGearTaskDefinition(
          id: 'task_coin_collector',
          title: 'Treasure Courier',
          description: 'Collect 400 total coins across all runs.',
          requiredCoinsCollected: 400,
        ),
        SpinnerGearTaskDefinition(
          id: 'task_hunter',
          title: 'Temple Hunter',
          description: 'Defeat 120 enemies total.',
          requiredEnemiesDefeated: 120,
        ),
        SpinnerGearTaskDefinition(
          id: 'task_veteran',
          title: 'Dungeon Veteran',
          description: 'Complete 12 runs.',
          requiredRuns: 12,
        ),
        SpinnerGearTaskDefinition(
          id: 'task_boss_slayer',
          title: 'Boss Slayer',
          description: 'Defeat the final boss once.',
          requiredBossClears: 1,
        ),
      ];

  static const List<SpinnerPartDefinition>
  definitions = <SpinnerPartDefinition>[
    SpinnerPartDefinition(
      id: 'core_sunforge',
      slot: SpinnerPartSlot.core,
      name: 'Sunforge Core',
      description: 'Balanced bronze core with stable spin.',
      primaryColor: Color(0xFFE4A956),
      secondaryColor: Color(0xFF915A2C),
      accentColor: Color(0xFFFFDD8A),
      previewUrl:
          'https://api.pixellab.ai/mcp/map-objects/8c8225d7-db98-4432-bca9-3d80fd943fa0/download',
      power: 1,
      control: 1,
      endurance: 1,
      maxHpBonus: 4,
      gyroStabilityBonus: 0.015,
    ),
    SpinnerPartDefinition(
      id: 'core_temple',
      slot: SpinnerPartSlot.core,
      name: 'Temple Core',
      description: 'Dense stone core with extra durability.',
      primaryColor: Color(0xFFDFC79A),
      secondaryColor: Color(0xFF8A6D43),
      accentColor: Color(0xFF7BD9D9),
      unlockBankedCoins: 60,
      unlockRuns: 2,
      endurance: 3,
      control: 1,
      incomingDamageMultiplier: 0.93,
      maxHpBonus: 12,
      gyroStabilityBonus: 0.045,
      spinRetentionBonus: 0.035,
    ),
    SpinnerPartDefinition(
      id: 'core_warden_heart',
      slot: SpinnerPartSlot.core,
      name: "Warden's Heart",
      description:
          'Black-iron core lit by a single yellow ember. Defeat the Warden once to claim.',
      primaryColor: Color(0xFF1B1208),
      secondaryColor: Color(0xFF000000),
      accentColor: Color(0xFFFFE100),
      unlockDepth: 10,
      unlockBossClears: 1,
      depthRewardLabel: 'Warden trophy',
      power: 2,
      endurance: 2,
      maxHpBonus: 8,
      damageMultiplier: 1.04,
      gyroStabilityBonus: 0.025,
      spinRetentionBonus: 0.02,
    ),
    SpinnerPartDefinition(
      id: 'core_aurora',
      slot: SpinnerPartSlot.core,
      name: 'Aurora Core',
      description: 'Luminous crystal core with high launch response.',
      primaryColor: Color(0xFF71D9D8),
      secondaryColor: Color(0xFF2B7486),
      accentColor: Color(0xFFFFE18A),
      unlockBankedCoins: 120,
      unlockRuns: 4,
      unlockDepth: 3,
      requiredTaskId: 'task_coin_collector',
      speed: 2,
      power: 1,
      launchSpeedMultiplier: 1.12,
      startingSpinsBonus: 1,
      spinRetentionBonus: 0.02,
    ),
    SpinnerPartDefinition(
      id: 'ring_guardian',
      slot: SpinnerPartSlot.ring,
      name: 'Guardian Ring',
      description: 'Reliable shield ring for balanced runs.',
      primaryColor: Color(0xFFC69A57),
      secondaryColor: Color(0xFF6C4D28),
      accentColor: Color(0xFFDFF4FF),
      previewUrl:
          'https://api.pixellab.ai/mcp/map-objects/256eb510-322c-4109-a75e-588af4ffc8e9/download',
      control: 1,
      endurance: 1,
      gyroStabilityBonus: 0.03,
    ),
    SpinnerPartDefinition(
      id: 'ring_sunburst',
      slot: SpinnerPartSlot.ring,
      name: 'Sunburst Ring',
      description: 'Aggressive ring with strong impact edges.',
      primaryColor: Color(0xFFEA9A3F),
      secondaryColor: Color(0xFF8D3D1D),
      accentColor: Color(0xFFFFD188),
      previewUrl:
          'https://api.pixellab.ai/mcp/map-objects/a771433c-7fe4-4a11-9e54-271d42e7c2d7/download',
      unlockBankedCoins: 40,
      power: 2,
      damageMultiplier: 1.08,
    ),
    SpinnerPartDefinition(
      id: 'ring_bastion',
      slot: SpinnerPartSlot.ring,
      name: 'Bastion Ring',
      description: 'Heavy protection ring for temple dives.',
      primaryColor: Color(0xFFE4C99D),
      secondaryColor: Color(0xFF80613A),
      accentColor: Color(0xFF9AD2FF),
      unlockBankedCoins: 85,
      unlockRuns: 2,
      endurance: 3,
      incomingDamageMultiplier: 0.94,
      maxHpBonus: 8,
      speed: -1,
      gyroStabilityBonus: 0.038,
      spinRetentionBonus: 0.025,
    ),
    SpinnerPartDefinition(
      id: 'ring_scout',
      slot: SpinnerPartSlot.ring,
      name: 'Scout Ring',
      description: 'Light ring focused on agility.',
      primaryColor: Color(0xFFC8D6E8),
      secondaryColor: Color(0xFF4C5B6C),
      accentColor: Color(0xFF5ED6FF),
      previewUrl:
          'https://api.pixellab.ai/mcp/map-objects/6c080fc2-bd30-4fcb-9f2c-428e2c1806f3/download',
      unlockBankedCoins: 110,
      unlockRuns: 3,
      speed: 3,
      launchSpeedMultiplier: 1.08,
      endurance: -1,
      gyroStabilityBonus: -0.042,
      spinRetentionBonus: -0.025,
    ),
    SpinnerPartDefinition(
      id: 'ring_relic',
      slot: SpinnerPartSlot.ring,
      name: 'Relic Ring',
      description: 'Ancient relic ring that keeps momentum.',
      primaryColor: Color(0xFFD6B17A),
      secondaryColor: Color(0xFF6B4A28),
      accentColor: Color(0xFFB3F2D3),
      unlockBankedCoins: 150,
      unlockRuns: 4,
      unlockDepth: 3,
      control: 2,
      frictionBonus: 0.03,
      startingSpinsBonus: 1,
    ),
    SpinnerPartDefinition(
      id: 'ring_obsidian_rune',
      slot: SpinnerPartSlot.ring,
      name: 'Obsidian Rune Ring',
      description:
          'Depth-forged ring etched with magenta sigils. Reach Lv 5 to claim.',
      primaryColor: Color(0xFF221032),
      secondaryColor: Color(0xFF120618),
      accentColor: Color(0xFFEBC7FF),
      unlockDepth: 5,
      depthRewardLabel: 'Depth 5 reward',
      control: 1,
      gyroStabilityBonus: 0.02,
    ),
    SpinnerPartDefinition(
      id: 'ring_oracle',
      slot: SpinnerPartSlot.ring,
      name: 'Oracle Ring',
      description: 'Crystal-guided ring for advanced builds.',
      primaryColor: Color(0xFF86C5D7),
      secondaryColor: Color(0xFF2F586C),
      accentColor: Color(0xFFFDEAA7),
      unlockBankedCoins: 210,
      unlockRuns: 6,
      unlockDepth: 5,
      requiredTaskId: 'task_hunter',
      power: 1,
      speed: 1,
      control: 2,
      frictionBonus: 0.02,
      damageMultiplier: 1.04,
    ),
    SpinnerPartDefinition(
      id: 'blade_swift',
      slot: SpinnerPartSlot.blade,
      name: 'Swift Blades',
      description: 'Starter fins with smooth handling and a short reach.',
      primaryColor: Color(0xFF74C2E8),
      secondaryColor: Color(0xFF2D5A7B),
      accentColor: Color(0xFFDFF9FF),
      speed: 1,
      control: 1,
      bladeShape: BladeShape.standard,
      bladeReach: 3,
      bladeDamageBonus: 1.05,
    ),
    SpinnerPartDefinition(
      id: 'blade_forge',
      slot: SpinnerPartSlot.blade,
      name: 'Forge Blades',
      description: 'Heavy extruded iron bars that slam enemies at range.',
      primaryColor: Color(0xFFE89E4E),
      secondaryColor: Color(0xFF7A4021),
      accentColor: Color(0xFFFFD98E),
      unlockBankedCoins: 70,
      power: 2,
      damageMultiplier: 1.06,
      bladeShape: BladeShape.extruded,
      bladeReach: 7,
      bladeDamageBonus: 1.18,
    ),
    SpinnerPartDefinition(
      id: 'blade_sickle',
      slot: SpinnerPartSlot.blade,
      name: 'Sickle Blades',
      description: 'Curved scything edges that slice while preserving speed.',
      primaryColor: Color(0xFFA6D9DE),
      secondaryColor: Color(0xFF3A6D76),
      accentColor: Color(0xFFEDFAFF),
      unlockBankedCoins: 95,
      unlockRuns: 3,
      speed: 2,
      launchSpeedMultiplier: 1.07,
      bladeShape: BladeShape.curved,
      bladeReach: 5,
      bladeDamageBonus: 1.10,
    ),
    SpinnerPartDefinition(
      id: 'blade_anchor',
      slot: SpinnerPartSlot.blade,
      name: 'Anchor Blades',
      description: 'Chunky extruded anchor bars. Slow, heavy, unstoppable.',
      primaryColor: Color(0xFFD9BF93),
      secondaryColor: Color(0xFF6F5431),
      accentColor: Color(0xFFB9E6FF),
      unlockBankedCoins: 130,
      unlockRuns: 4,
      control: 2,
      endurance: 2,
      incomingDamageMultiplier: 0.96,
      speed: -1,
      gyroStabilityBonus: 0.048,
      spinRetentionBonus: 0.032,
      bladeShape: BladeShape.extruded,
      bladeReach: 9,
      bladeDamageBonus: 1.22,
    ),
    SpinnerPartDefinition(
      id: 'blade_comet',
      slot: SpinnerPartSlot.blade,
      name: 'Comet Blades',
      description: 'Long hooked tails that strike first, hard, and far.',
      primaryColor: Color(0xFFB3D7F5),
      secondaryColor: Color(0xFF3F6485),
      accentColor: Color(0xFF7AF7FF),
      unlockBankedCoins: 180,
      unlockRuns: 5,
      unlockDepth: 4,
      speed: 3,
      launchSpeedMultiplier: 1.12,
      endurance: -1,
      gyroStabilityBonus: -0.035,
      spinRetentionBonus: -0.03,
      bladeShape: BladeShape.hook,
      bladeReach: 11,
      bladeDamageBonus: 1.08,
    ),
    SpinnerPartDefinition(
      id: 'blade_voidedge',
      slot: SpinnerPartSlot.blade,
      name: 'Voidedge Spurs',
      description:
          'Purple-tipped triangular spurs cut from temple shadow. Reach Lv 7 to claim.',
      primaryColor: Color(0xFF3C1E5C),
      secondaryColor: Color(0xFF160A26),
      accentColor: Color(0xFFEBC7FF),
      unlockDepth: 7,
      depthRewardLabel: 'Depth 7 reward',
      power: 1,
      damageMultiplier: 1.02,
      bladeShape: BladeShape.spiky,
      bladeReach: 8,
      bladeDamageBonus: 1.28,
    ),
    SpinnerPartDefinition(
      id: 'blade_halo',
      slot: SpinnerPartSlot.blade,
      name: 'Halo Blades',
      description: 'Premium curved arc blades for all-round pressure.',
      primaryColor: Color(0xFFF2C77A),
      secondaryColor: Color(0xFF875927),
      accentColor: Color(0xFF89DFFF),
      unlockBankedCoins: 240,
      unlockRuns: 7,
      unlockDepth: 6,
      requiredTaskId: 'task_veteran',
      power: 2,
      speed: 1,
      control: 1,
      damageMultiplier: 1.07,
      bladeShape: BladeShape.curved,
      bladeReach: 6,
      bladeDamageBonus: 1.15,
    ),
    SpinnerPartDefinition(
      id: 'glow_ember',
      slot: SpinnerPartSlot.glow,
      name: 'Ember Glow',
      description: 'Warm ember bloom for clean readability.',
      primaryColor: Color(0xFFFFC05B),
      secondaryColor: Color(0xFFB36A21),
      accentColor: Color(0xFFFFE9AF),
      power: 1,
    ),
    SpinnerPartDefinition(
      id: 'glow_cyan',
      slot: SpinnerPartSlot.glow,
      name: 'Cyan Pulse',
      description: 'Cool cyan pulse for speed builds.',
      primaryColor: Color(0xFF67E0FF),
      secondaryColor: Color(0xFF2A6F9E),
      accentColor: Color(0xFFDDF7FF),
      unlockBankedCoins: 80,
      speed: 1,
      launchSpeedMultiplier: 1.04,
    ),
    SpinnerPartDefinition(
      id: 'glow_emberforge',
      slot: SpinnerPartSlot.glow,
      name: 'Emberforge Halo',
      description:
          'Brighter ember bloom forged in the third deep. Reach Lv 3 to claim.',
      primaryColor: Color(0xFFFF7A1E),
      secondaryColor: Color(0xFFB23A07),
      accentColor: Color(0xFFFFE100),
      unlockDepth: 3,
      depthRewardLabel: 'Depth 3 reward',
      power: 1,
    ),
    SpinnerPartDefinition(
      id: 'glow_solar',
      slot: SpinnerPartSlot.glow,
      name: 'Solar Halo',
      description: 'Temple gold halo with defensive focus.',
      primaryColor: Color(0xFFF5D178),
      secondaryColor: Color(0xFF8A632D),
      accentColor: Color(0xFFFFF0C9),
      unlockBankedCoins: 140,
      unlockRuns: 4,
      endurance: 2,
      incomingDamageMultiplier: 0.97,
      maxHpBonus: 6,
    ),
    SpinnerPartDefinition(
      id: 'glow_relic',
      slot: SpinnerPartSlot.glow,
      name: 'Relic Prism',
      description: 'High-end prismatic glow for elite runs.',
      primaryColor: Color(0xFF82E2CF),
      secondaryColor: Color(0xFF2C6D66),
      accentColor: Color(0xFFFFE8A9),
      unlockBankedCoins: 220,
      unlockRuns: 6,
      unlockDepth: 5,
      requiredTaskId: 'task_boss_slayer',
      control: 2,
      startingSpinsBonus: 1,
    ),
  ];

  static final Map<String, SpinnerPartDefinition> _byId =
      <String, SpinnerPartDefinition>{
        for (final part in definitions) part.id: part,
      };

  static SpinnerBuild get defaultBuild => SpinnerBuild.defaults();

  static Set<String> get defaultUnlockedPartIds => <String>{
    defaultBuild.coreId,
    defaultBuild.ringId,
    defaultBuild.bladeId,
    defaultBuild.glowId,
  };

  static SpinnerPartDefinition partById(String id) {
    return _byId[id] ?? _byId[defaultBuild.coreId]!;
  }

  static List<SpinnerPartDefinition> partsForSlot(SpinnerPartSlot slot) {
    return definitions.where((part) => part.slot == slot).toList();
  }

  static Set<String> unlockedPartsForProgress({
    required int bankedCoins,
    required int totalRuns,
    required int deepestLevelReached,
    int bossClears = 0,
    Set<String>? completedTaskIds,
    Set<String>? existingUnlocked,
  }) {
    final unlocked = <String>{
      ...defaultUnlockedPartIds,
      ...(existingUnlocked ?? const <String>{}),
    };
    for (final part in definitions) {
      final meetsCoins = bankedCoins >= part.unlockBankedCoins;
      final meetsRuns = totalRuns >= part.unlockRuns;
      final meetsDepth = deepestLevelReached >= part.unlockDepth;
      final meetsBoss = bossClears >= part.unlockBossClears;
      final meetsTask =
          part.requiredTaskId == null ||
          (completedTaskIds ?? const <String>{}).contains(part.requiredTaskId);
      if (meetsCoins && meetsRuns && meetsDepth && meetsBoss && meetsTask) {
        unlocked.add(part.id);
      }
    }
    return unlocked;
  }

  static List<SpinnerGearTaskProgress> taskProgresses({
    required int totalRuns,
    required int totalCoinsCollected,
    required int totalEnemiesDefeated,
    required int bossClears,
  }) {
    return gearTasks
        .map(
          (task) => SpinnerGearTaskProgress(
            definition: task,
            currentRuns: totalRuns,
            currentCoins: totalCoinsCollected,
            currentKills: totalEnemiesDefeated,
            currentBossClears: bossClears,
          ),
        )
        .toList();
  }

  static SpinnerBuild sanitizeBuild({
    required SpinnerBuild build,
    required Set<String> unlockedIds,
  }) {
    String validate(
      SpinnerPartSlot slot,
      String requestedId,
      String fallbackId,
    ) {
      final requested = _byId[requestedId];
      if (requested != null &&
          requested.slot == slot &&
          unlockedIds.contains(requestedId)) {
        return requestedId;
      }
      if (unlockedIds.contains(fallbackId)) {
        return fallbackId;
      }
      final firstUnlocked = partsForSlot(slot).firstWhere(
        (part) => unlockedIds.contains(part.id),
        orElse: () => partsForSlot(slot).first,
      );
      return firstUnlocked.id;
    }

    final defaults = defaultBuild;
    return SpinnerBuild(
      coreId: validate(SpinnerPartSlot.core, build.coreId, defaults.coreId),
      ringId: validate(SpinnerPartSlot.ring, build.ringId, defaults.ringId),
      bladeId: validate(SpinnerPartSlot.blade, build.bladeId, defaults.bladeId),
      glowId: validate(SpinnerPartSlot.glow, build.glowId, defaults.glowId),
    );
  }

  static SpinnerBuildStats computeStats(SpinnerBuild build) {
    final selected = <SpinnerPartDefinition>[
      partById(build.coreId),
      partById(build.ringId),
      partById(build.bladeId),
      partById(build.glowId),
    ];

    var power = 10;
    var speed = 10;
    var control = 10;
    var endurance = 10;
    var damageMultiplier = 1.0;
    var frictionBonus = 0.0;
    var launchSpeedMultiplier = 1.0;
    var incomingDamageMultiplier = 1.0;
    var maxHpBonus = 0;
    var startingSpinsBonus = 0;
    var gyroStabilityBonusSum = 0.0;
    var spinRetentionBonusSum = 0.0;

    for (final part in selected) {
      power += part.power;
      speed += part.speed;
      control += part.control;
      endurance += part.endurance;
      damageMultiplier *= part.damageMultiplier;
      frictionBonus += part.frictionBonus;
      launchSpeedMultiplier *= part.launchSpeedMultiplier;
      incomingDamageMultiplier *= part.incomingDamageMultiplier;
      maxHpBonus += part.maxHpBonus;
      startingSpinsBonus += part.startingSpinsBonus;
      gyroStabilityBonusSum += part.gyroStabilityBonus;
      spinRetentionBonusSum += part.spinRetentionBonus;
    }

    final core = partById(build.coreId);
    final ring = partById(build.ringId);
    final blade = partById(build.bladeId);
    final glow = partById(build.glowId);

    final cNorm = ((control.clamp(1, 40) - 1) / 39.0).clamp(0.0, 1.0);
    final eNorm = ((endurance.clamp(1, 40) - 1) / 39.0).clamp(0.0, 1.0);
    final pNorm = ((power.clamp(1, 40) - 1) / 39.0).clamp(0.0, 1.0);
    final sNorm = ((speed.clamp(1, 40) - 1) / 39.0).clamp(0.0, 1.0);

    var gyroStability =
        0.32 + 0.56 * cNorm + gyroStabilityBonusSum - 0.07 * sNorm;
    gyroStability = gyroStability.clamp(0.18, 0.96);

    var spinRetention =
        0.82 + 0.38 * eNorm + 0.07 * pNorm + spinRetentionBonusSum;
    spinRetention = spinRetention.clamp(0.72, 1.42);

    return SpinnerBuildStats(
      power: power.clamp(1, 40),
      speed: speed.clamp(1, 40),
      control: control.clamp(1, 40),
      endurance: endurance.clamp(1, 40),
      damageMultiplier: damageMultiplier.clamp(0.72, 1.45),
      frictionBonus: frictionBonus.clamp(-0.05, 0.06),
      launchSpeedMultiplier: launchSpeedMultiplier.clamp(0.82, 1.5),
      incomingDamageMultiplier: incomingDamageMultiplier.clamp(0.7, 1.25),
      maxHpBonus: max(-10, maxHpBonus),
      startingSpinsBonus: max(-3, startingSpinsBonus),
      coreColor: core.primaryColor,
      ringColor: ring.primaryColor,
      bladeColor: blade.primaryColor,
      glowColor: glow.primaryColor,
      gyroStability: gyroStability,
      spinRetention: spinRetention,
      bladeShape: blade.bladeShape,
      bladeReach: blade.bladeReach.clamp(0.0, 14.0).toDouble(),
      bladeDamageBonus: blade.bladeDamageBonus.clamp(1.0, 1.6).toDouble(),
    );
  }
}
