import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart' as flame_exp;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../input/spin_gesture_detector.dart';
import '../systems/progression_repository.dart';
import '../systems/run_snapshot_repository.dart';
import '../systems/spinner_parts.dart';
import '../systems/upgrade_system.dart';
import 'bumper_component.dart';
import 'chest_component.dart';
import 'coin_pickup_component.dart';
import 'dungeon_level_generator.dart';
import 'dungeon_theme.dart';
import 'room_template.dart';
import 'room_template_catalog.dart';
import 'semantic_hazard_rect.dart';
import 'semantic_theme_mapping.dart';
import 'tile_semantics.dart';
import 'enemy_component.dart';
import 'enemy_projectile_component.dart';
import 'telegraphed_threat_component.dart';
import 'pit_component.dart';
import 'powerup_component.dart';
import 'spinner_component.dart';
import 'spinner_top_physics.dart';
import 'spinner_shot_component.dart';
import 'tether_link_component.dart';
import 'trap_component.dart';
import 'wall_component.dart';
import 'combat_fx_components.dart';

/// Filled band behind [WallComponent] quads. Collision uses an invisible
/// [RectangleComponent]; the drawn strip must stay legible when the wall
/// upper-terrain sprite is missing, empty, or matches the floor tone.
const Color _kWallVisualBackplate = Color(0xE627367B);

enum RunPhase { startMenu, loadout, playing, runOver, upgrading }

enum RunEndReason { hpDepleted, pitFall, outOfSpins, victory, invasionBreached }

enum SpinnerGameMode { dungeon, invasion }

class RunStats {
  const RunStats({
    this.runCoins = 0,
    this.runScore = 0,
    this.enemiesKilled = 0,
    this.levelsCleared = 0,
    this.maxSpinChain = 0,
  });

  final int runCoins;
  final int runScore;
  final int enemiesKilled;
  final int levelsCleared;

  /// Peak enemies defeated on a single spin this run (while spinner was moving).
  final int maxSpinChain;

  RunStats copyWith({
    int? runCoins,
    int? runScore,
    int? enemiesKilled,
    int? levelsCleared,
    int? maxSpinChain,
  }) {
    return RunStats(
      runCoins: runCoins ?? this.runCoins,
      runScore: runScore ?? this.runScore,
      enemiesKilled: enemiesKilled ?? this.enemiesKilled,
      levelsCleared: levelsCleared ?? this.levelsCleared,
      maxSpinChain: maxSpinChain ?? this.maxSpinChain,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'runCoins': runCoins,
      'runScore': runScore,
      'enemiesKilled': enemiesKilled,
      'levelsCleared': levelsCleared,
      'maxSpinChain': maxSpinChain,
    };
  }

  factory RunStats.fromJson(Map<String, dynamic> json) {
    return RunStats(
      runCoins: (json['runCoins'] as num?)?.toInt() ?? 0,
      runScore: (json['runScore'] as num?)?.toInt() ?? 0,
      enemiesKilled: (json['enemiesKilled'] as num?)?.toInt() ?? 0,
      levelsCleared: (json['levelsCleared'] as num?)?.toInt() ?? 0,
      maxSpinChain: (json['maxSpinChain'] as num?)?.toInt() ?? 0,
    );
  }
}

class SpinnerGame extends FlameGame
    with
        HasCollisionDetection,
        MultiTouchTapDetector,
        ScaleDetector,
        DoubleTapDetector {
  SpinnerGame();

  static const int _campaignLevelCount = 10;

  /// Space-invader layout: spinner near bottom, walkers spawn above this inset.
  static const double _invasionSpinnerBottomInset = 86;
  static const double _invasionWalkerSpawnMaxYInset = 220;
  static const double wallThickness = 28;

  /// World units per dungeon tile (the BSP generator works in tiles).
  static const double _bspTileSize = 48;
  static const double roomWidth = 760;
  static const double roomHeight = 560;

  /// Vertical pitch slightly larger than horizontal so dungeon layouts read
  /// taller on portrait screens (narrow grid + world spacing).
  static const double roomPitchX = 760;
  static const double roomPitchY = 980;
  static const double corridorWidth = 140;
  static const double mapMargin = 280;
  static const double _minRoomScale = 0.5;
  static const double _maxRoomScale = 0.9;

  static const double minLaunchSpeed = 260;
  static const double maxLaunchSpeed = 1180;

  static const double _baseCameraZoom = 0.82;
  static const double _releaseCameraZoom = 0.62;
  static const double _chargeCameraZoom = 1.0;
  static const double _planningMinZoom = 0.42;
  static const double _planningMaxZoom = 1.28;
  static const int _basePlayerHp = 80;
  static const double _damageInvulnerability = 0.45;
  static const double _damageAlertDuration = 1.15;
  static const double _pitPenaltyDamage = 18;
  static const double _floorTileWorldSize = 16;
  static const double _minimumPitHoverSeconds = 0.02;

  /// Floor traps and pits are off for now (poor contrast + low fun).
  static const bool _spawnTrapsAndPits = false;
  static const double _cameraBoundsHorizontalPadding = 220;
  static const double _cameraBoundsTopPadding = 360;
  static const double _cameraBoundsBottomPadding = 180;
  static const double _minLaunchSpeedRatio = 0.14;
  static const double _launchSpeedHardFloorRatio = 0.19;
  static const double _spinStrengthForMaxLaunch = 8.0;
  static const double _launchSpeedCurveExponent = 2.25;

  final Random _random = Random();
  final DungeonLevelGenerator _dungeonLevelGenerator =
      const DungeonLevelGenerator();
  final SpinGestureDetector _spinDetector = SpinGestureDetector();
  final ProgressRepository _progressRepository =
      SharedPreferencesProgressRepository();
  final RunSnapshotRepository _runSnapshotRepository =
      SharedPreferencesRunSnapshotRepository();

  final ValueNotifier<int> hudTick = ValueNotifier<int>(0);

  final List<PositionComponent> _floors = <PositionComponent>[];
  final List<WallComponent> _walls = <WallComponent>[];
  final List<BumperComponent> _bumpers = <BumperComponent>[];
  final List<TrapComponent> _traps = <TrapComponent>[];
  final List<PitComponent> _pits = <PitComponent>[];
  final List<CoinPickupComponent> _coins = <CoinPickupComponent>[];
  final List<PowerupComponent> _powerups = <PowerupComponent>[];
  final List<SpinnerShotComponent> _spinnerShots = <SpinnerShotComponent>[];
  final List<EnemyProjectileComponent> _enemyProjectiles =
      <EnemyProjectileComponent>[];
  final List<ChestComponent> _chests = <ChestComponent>[];
  final List<EnemyComponent> _enemies = <EnemyComponent>[];
  final List<PositionComponent> _wallVisuals = <PositionComponent>[];
  final List<PositionComponent> _decorations = <PositionComponent>[];
  TetherLinkComponent? _tetherLink;
  final Set<String> _floorCellKeys = <String>{};
  final Map<DungeonTheme, _ThemeSprites> _themeSpriteMap =
      <DungeonTheme, _ThemeSprites>{};
  DungeonTheme _activeTheme = DungeonTheme.templeWarm;
  _ThemeSprites? _fallbackTheme;

  SemanticThemeMapping? _semanticThemeMapping;
  final List<PositionComponent> _semanticTileLayers = <PositionComponent>[];
  final List<SemanticHazardRectComponent> _semanticHazards =
      <SemanticHazardRectComponent>[];

  _ThemeSprites? get _activeThemeSprites =>
      _themeSpriteMap[_activeTheme] ?? _fallbackTheme;
  List<Sprite> get _floorTileSprites =>
      _activeThemeSprites?.floorTileSprites ?? const <Sprite>[];
  Map<String, Sprite> get _wangTileSpritesByKey =>
      _activeThemeSprites?.wangTileSpritesByKey ?? const <String, Sprite>{};
  Sprite? get _lowerTerrainSprite => _activeThemeSprites?.lowerTerrainSprite;
  Sprite? get _upperTerrainSprite => _activeThemeSprites?.upperTerrainSprite;
  List<Sprite> get _wallTileSprites =>
      _activeThemeSprites?.wallTileSprites ?? const <Sprite>[];
  List<Sprite> get _openFloorTileSprites =>
      _activeThemeSprites?.openFloorTileSprites ?? const <Sprite>[];

  final Map<EnemyComponent, _GridPos> _enemyRooms =
      <EnemyComponent, _GridPos>{};
  final Map<EnemyComponent, Rect> _enemyBounds = <EnemyComponent, Rect>{};
  final Map<ChestComponent, _GridPos> _chestRooms =
      <ChestComponent, _GridPos>{};
  final List<_LevelPlan> _levels = <_LevelPlan>[];

  SpinnerComponent? _spinner;
  _GridPos? _currentRoomPos;

  bool _ready = false;
  bool _levelComplete = false;
  bool _levelClearAcknowledged = false;
  bool _isCharging = false;
  bool _dungeonComplete = false;
  bool _isCameraGestureActive = false;
  bool _isCameraDragActive = false;
  bool _isCameraFollowingSpinner = false;
  bool _pausedByMenu = false;
  bool _hudDebugOverlayVisible = false;
  bool _progressLoaded = false;
  bool _snapshotLoaded = false;
  bool _bootstrappedRun = false;
  bool _progressSaveInFlight = false;
  bool _runSnapshotSaveInFlight = false;
  double _runSnapshotAutosaveTimer = 0;
  bool _wasSpinnerMoving = false;

  Map<String, dynamic>? _pendingRunSnapshot;
  Map<String, dynamic>? _queuedRunSnapshot;
  int? _configuredRunSeed;
  int? _activeRunSeed;

  int _currentLevelIndex = 0;
  int _currentHp = _basePlayerHp;
  int _maxHp = _basePlayerHp;
  int _pitSavesRemaining = 0;

  double _elapsedSeconds = 0;
  double _targetCameraZoom = _baseCameraZoom;
  double _cameraGestureStartZoom = _baseCameraZoom;
  double _damageInvulnerabilityRemaining = 0;
  final Map<PowerupType, int> _abilityCharges = <PowerupType, int>{};
  PowerupType? _selectedPowerup;
  PowerupType? _activePowerup;
  Vector2? _queuedTetherTarget;
  Vector2? _activeTetherTarget;
  double _fireballCooldown = 0;
  double _needlesCooldown = 0;
  Vector2? _tetherLineStart;
  Vector2? _tetherLineEnd;
  PitComponent? _hoveringPit;
  double _pitHoverSecondsRemaining = 0;
  _PendingDebugSpawnPlacement? _pendingDebugSpawnPlacement;
  final List<_QueuedDebugSpawnPlacement> _queuedDebugSpawnPlacements =
      <_QueuedDebugSpawnPlacement>[];

  Vector2 _levelMin = Vector2.zero();
  Vector2 _levelMax = Vector2.zero();

  RunPhase _runPhase = RunPhase.startMenu;
  RunEndReason? _runEndReason;
  RunStats _runStats = const RunStats();
  int _killsThisSpin = 0;
  MetaProgress _progress = MetaProgress.defaults();
  AppliedUpgrades _appliedUpgrades = const AppliedUpgrades();
  SpinnerBuild _selectedBuild = SpinnerPartCatalog.defaultBuild;
  SpinnerBuildStats _selectedBuildStats = SpinnerPartCatalog.computeStats(
    SpinnerPartCatalog.defaultBuild,
  );
  Set<String> _unlockedPartIds = SpinnerPartCatalog.defaultUnlockedPartIds;
  String _lastDamageSource = '-';
  int _lastDamageAmount = 0;
  double _damageAlertSeconds = 0;
  double _hitStopRemaining = 0;
  double _cameraImpactZoomBump = 0;
  double _screenShakeMagnitude = 0;

  SpinnerGameMode _gameMode = SpinnerGameMode.dungeon;
  double _invasionElapsed = 0;

  // Tutorial state. Each prompt becomes "done" once the player demonstrates the
  // matching action; all three set MetaProgress.tutorialSeen=true.
  bool _tutorialSpinPromptDone = false;
  bool _tutorialGoalPromptDone = false;
  bool _tutorialDepthPromptDone = false;
  int? _runDeepestLevelAtStart;
  bool _newDeepestThisRun = false;

  // Weekly challenge.
  bool _runIsWeekly = false;

  /// Upgrade hub was opened from the main menu (not legacy post-run flow).
  bool _upgradeMenuOpenedFromMain = false;

  // Unlock toast banner (e.g. "Depth 5 reward: Obsidian Rune Ring").
  String _unlockToastText = '';
  String _unlockToastSubtitle = '';
  double _unlockToastSeconds = 0;
  static const double _unlockToastDuration = 4.2;

  @override
  Color backgroundColor() => const Color(0xFF1A1216);

  int get levelNumber => _currentLevelIndex + 1;
  int get totalLevels => _levels.length;
  int get enemiesRemaining => _enemies
      .where((enemy) => !enemy.isDead && enemy.countsTowardRoomClear)
      .length;
  int get zonesInLevel {
    final level = _currentLevel;
    if (level == null) {
      return 0;
    }
    return level.rooms.values
        .where((room) => room.type != RoomType.start)
        .length;
  }

  int get zonesClearedInLevel {
    final level = _currentLevel;
    if (level == null) {
      return 0;
    }

    return level.rooms.values
        .where((room) => room.type != RoomType.start && room.cleared)
        .length;
  }

  bool get levelComplete => _levelComplete;

  /// True once the player has dismissed the full "floor cleared" banner via
  /// [acknowledgeLevelClear]. While false, the full banner + footer show;
  /// once true, only a compact persistent descend button remains so the
  /// player can keep exploring/looting before choosing to descend.
  bool get levelClearAcknowledged => _levelClearAcknowledged;
  bool get isCharging => _isCharging;
  bool get spinnerMoving => _spinner?.isMoving ?? false;
  bool get dungeonComplete => _dungeonComplete;
  bool get cameraPlanningActive =>
      _isCameraGestureActive || _isCameraDragActive;
  bool get cameraFollowingSpinner => _isCameraFollowingSpinner;
  bool get isWorldFrozen {
    if (_pausedByMenu) {
      return true;
    }

    if (_runPhase != RunPhase.playing) {
      return true;
    }

    if (!spinnerMoving) {
      return true;
    }

    return _isCharging || _isCameraGestureActive || _isCameraDragActive;
  }

  double get spinnerSpeed => _spinner?.velocity.length ?? 0;
  double get elapsedSeconds => _elapsedSeconds;
  double get chargeAmount => _spinDetector.currentCharge;
  double get cameraZoom => camera.viewfinder.zoom;
  bool get progressLoaded => _progressLoaded;
  RunPhase get runPhase => _runPhase;
  RunStats get runStats => _runStats;
  MetaProgress get metaProgress => _progress;
  int get currentHp => _currentHp;
  int get maxHp => _maxHp;
  double get hpRatio =>
      _maxHp <= 0 ? 0.0 : (_currentHp / _maxHp).clamp(0, 1).toDouble();
  int get pitSavesRemaining => _pitSavesRemaining;
  int get runScore => _runStats.runScore;
  int get runCoins => _runStats.runCoins;
  int get bankedCoins => _progress.bankedCoins;
  int get bestScore => _progress.bestScore;
  int get totalRuns => _progress.totalRuns;
  int get deepestLevelReached => _progress.deepestLevelReached;
  List<LeaderboardEntry> get leaderboardEntries => _progress.leaderboard;
  int get spinChainKills => _killsThisSpin;
  int get maxSpinChainThisRun => _runStats.maxSpinChain;
  bool get isInvasionMode => _gameMode == SpinnerGameMode.invasion;
  double get invasionElapsedSeconds => _invasionElapsed;
  int get invasionKills => _runStats.enemiesKilled;
  bool get tetherActive => _activePowerup == PowerupType.tether;
  bool get fireballActive => _activePowerup == PowerupType.fireball;
  bool get needlesActive => _activePowerup == PowerupType.needles;
  bool get hasAbilityCharges =>
      _abilityCharges.values.any((count) => count > 0);
  bool get showAbilitySelectionPanel =>
      _runPhase == RunPhase.playing &&
      !_pausedByMenu &&
      !spinnerMoving &&
      !_isCharging &&
      !_levelComplete &&
      hasAbilityCharges;
  PowerupType? get selectedPowerup => _selectedPowerup;
  bool get selectedPowerupReady =>
      _selectedPowerup != PowerupType.tether || _queuedTetherTarget != null;
  List<PowerupType> get availablePowerups {
    final list =
        _abilityCharges.entries
            .where((entry) => entry.value > 0)
            .map((entry) => entry.key)
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    return list;
  }

  String get activePowerupsLabel {
    final labels = <String>[];
    if (_activePowerup != null) {
      labels.add('Active ${powerupLabel(_activePowerup!)}');
    }
    if (_selectedPowerup != null) {
      labels.add('Queued ${powerupLabel(_selectedPowerup!)}');
    }
    final stash = availablePowerups
        .map((type) => '${powerupLabel(type)} x${abilityChargesFor(type)}')
        .join(', ');
    if (stash.isNotEmpty) {
      labels.add('Stash $stash');
    }
    if (labels.isEmpty) {
      return '-';
    }
    return labels.join(' | ');
  }

  bool get showUpgradeMenu => _runPhase == RunPhase.upgrading;
  bool get upgradeMenuOpenedFromMain => _upgradeMenuOpenedFromMain;
  bool? get bladesWideStance => _spinner?.bladesWideStance;

  String get bladeStanceHudHint {
    final s = _spinner;
    if (s == null || !s.isMoving) {
      return '';
    }
    final wide = s.bladesWideStance;
    return wide
        ? 'Blades: full reach — double-tap anywhere to tuck'
        : 'Blades: tucked — double-tap anywhere to extend';
  }

  bool get canStartRunFromHub =>
      _progressLoaded && _runPhase == RunPhase.upgrading;
  bool get pausedByMenu => _pausedByMenu;
  bool get hudDebugOverlayVisible => _hudDebugOverlayVisible;
  bool get showStartMenu => _runPhase == RunPhase.startMenu;
  bool get showLoadoutBuilder => _runPhase == RunPhase.loadout;
  bool get canOpenLoadoutBuilder => _progressLoaded;
  bool get canStartRunFromBuilder =>
      _progressLoaded && _runPhase == RunPhase.loadout;
  bool get canOpenDebugSpawner =>
      _progressLoaded && _runPhase == RunPhase.playing && !_pausedByMenu;
  bool get debugSpawnPlacementArmed => _pendingDebugSpawnPlacement != null;
  String get debugSpawnPlacementLabel {
    final pending = _pendingDebugSpawnPlacement;
    if (pending == null) {
      return '';
    }
    final level = pending.levelIndex + 1;
    return 'Tap map to place ${pending.count} '
        '${enemyArchetypeLabel(pending.archetype)} '
        '${enemyTypeLabel(pending.type)} (Lv $level)';
  }

  int? get configuredRunSeed => _configuredRunSeed;
  String get configuredRunSeedLabel =>
      _configuredRunSeed?.toString() ?? 'Random';
  int? get activeRunSeed => _activeRunSeed;
  String get activeRunSeedLabel => _activeRunSeed?.toString() ?? '-';
  SpinnerBuild get selectedBuild => _selectedBuild;
  SpinnerBuildStats get selectedBuildStats => _selectedBuildStats;
  Set<String> get unlockedPartIds => _unlockedPartIds;
  Iterable<WallComponent> get wallComponents => _walls;
  List<UpgradeDefinition> get upgradeDefinitions => UpgradeSystem.definitions;
  List<DungeonAbility> get dungeonAbilities => DungeonAbility.values;
  List<SpinnerGearTaskProgress> get gearTaskProgress {
    return SpinnerPartCatalog.taskProgresses(
      totalRuns: _progress.totalRuns,
      totalCoinsCollected: _progress.totalCoinsCollected,
      totalEnemiesDefeated: _progress.totalEnemiesDefeated,
      bossClears: _progress.bossClears,
    );
  }

  String get lastDamageSource => _lastDamageSource;
  int get lastDamageAmount => _lastDamageAmount;
  bool get showDamageAlert => _damageAlertSeconds > 0 && _lastDamageAmount > 0;
  double get damageAlertOpacity {
    if (!showDamageAlert) {
      return 0.0;
    }
    return (_damageAlertSeconds / _damageAlertDuration).clamp(0, 1).toDouble();
  }

  String get damageAlertText => '-$lastDamageAmount HP - $lastDamageSource';

  // ----- Tutorial / onboarding -----

  bool get tutorialSeen => _progress.tutorialSeen;
  bool get isFirstRunEver => _progress.totalRuns == 0;
  bool get _shouldShowFirstRunPrompts =>
      !tutorialSeen &&
      _runPhase == RunPhase.playing &&
      _gameMode == SpinnerGameMode.dungeon;

  bool get showTutorialSpinPrompt =>
      _shouldShowFirstRunPrompts && !_tutorialSpinPromptDone;
  bool get showTutorialGoalPrompt =>
      _shouldShowFirstRunPrompts &&
      _tutorialSpinPromptDone &&
      !_tutorialGoalPromptDone;
  bool get showTutorialDepthPrompt =>
      _shouldShowFirstRunPrompts &&
      _tutorialSpinPromptDone &&
      _tutorialGoalPromptDone &&
      !_tutorialDepthPromptDone;

  void dismissTutorialSpinPrompt() {
    if (_tutorialSpinPromptDone) {
      return;
    }
    _tutorialSpinPromptDone = true;
    _maybeFinalizeTutorial();
    _notifyHud();
  }

  void dismissTutorialGoalPrompt() {
    if (_tutorialGoalPromptDone) {
      return;
    }
    _tutorialGoalPromptDone = true;
    _maybeFinalizeTutorial();
    _notifyHud();
  }

  void dismissTutorialDepthPrompt() {
    if (_tutorialDepthPromptDone) {
      return;
    }
    _tutorialDepthPromptDone = true;
    _maybeFinalizeTutorial();
    _notifyHud();
  }

  void _maybeFinalizeTutorial() {
    if (_progress.tutorialSeen) {
      return;
    }
    if (_tutorialSpinPromptDone &&
        _tutorialGoalPromptDone &&
        _tutorialDepthPromptDone) {
      _progress = _progress.copyWith(tutorialSeen: true);
      _persistProgress();
    }
  }

  // ----- Unlock toast -----

  bool get showUnlockToast =>
      _unlockToastSeconds > 0 && _unlockToastText.isNotEmpty;
  String get unlockToastText => _unlockToastText;
  String get unlockToastSubtitle => _unlockToastSubtitle;
  double get unlockToastOpacity {
    if (!showUnlockToast) {
      return 0.0;
    }
    final t = (_unlockToastSeconds / _unlockToastDuration)
        .clamp(0, 1)
        .toDouble();
    return (t * 1.6).clamp(0, 1).toDouble();
  }

  // ----- Run-over -----

  bool get newDeepestThisRun => _newDeepestThisRun;

  // ----- Weekly challenge -----

  /// Deterministic weekly seed derived from the current ISO year+week (UTC).
  int get weeklySeed {
    final now = DateTime.now().toUtc();
    final (year, week) = _isoWeek(now);
    // Mix year and week into a 30-bit non-zero seed.
    final raw = (year * 100 + week) * 2654435761;
    return (raw & 0x3FFFFFFF) ^ 0x5EED;
  }

  /// "2026-W16"-style key.
  String get weeklyKey {
    final now = DateTime.now().toUtc();
    final (year, week) = _isoWeek(now);
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  String get weeklyChallengeName {
    final hex = weeklySeed.toRadixString(16).toUpperCase().padLeft(8, '0');
    return 'Run #${hex.substring(hex.length - 4)}';
  }

  String get weeklyDateRangeLabel {
    final now = DateTime.now().toUtc();
    final monday = now.subtract(Duration(days: (now.weekday + 6) % 7));
    final sunday = monday.add(const Duration(days: 6));
    String fmt(DateTime d) {
      const months = <String>[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}';
    }

    return '${fmt(monday)} - ${fmt(sunday)}';
  }

  /// Best leaderboard entry recorded against the current weekly key, if any.
  LeaderboardEntry? get weeklyBestEntry {
    final key = weeklyKey;
    LeaderboardEntry? best;
    for (final entry in _progress.leaderboard) {
      if (entry.weeklyKey != key) {
        continue;
      }
      if (best == null ||
          entry.score > best.score ||
          (entry.score == best.score &&
              entry.deepestLevel > best.deepestLevel)) {
        best = entry;
      }
    }
    return best;
  }

  bool get currentRunIsWeekly => _runIsWeekly;

  static (int year, int week) _isoWeek(DateTime date) {
    final thursday = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(Duration(days: 4 - ((date.weekday + 6) % 7 + 1)));
    final firstThursday = DateTime.utc(thursday.year, 1, 4);
    final firstMonday = firstThursday.subtract(
      Duration(days: (firstThursday.weekday + 6) % 7),
    );
    final week = ((thursday.difference(firstMonday).inDays) ~/ 7) + 1;
    return (thursday.year, week);
  }

  double get levelProgressRatio {
    if (zonesInLevel <= 0) {
      return 0.0;
    }
    return (zonesClearedInLevel / zonesInLevel).clamp(0, 1).toDouble();
  }

  String get levelClearBannerText =>
      'FLOOR CLEARED\nTap Continue to keep looting — descend whenever you\'re ready.';

  String get runEndReasonLabel {
    switch (_runEndReason) {
      case RunEndReason.hpDepleted:
        return 'HP Depleted';
      case RunEndReason.pitFall:
        return 'Fell Into Pit';
      case RunEndReason.outOfSpins:
        return 'Out of Spins';
      case RunEndReason.victory:
        return 'Dungeon Cleared';
      case RunEndReason.invasionBreached:
        // Legacy reason string retained for backward compatibility with
        // serialized run snapshots. No longer emitted in live play — see
        // `_tickInvasionMode`.
        return 'Invaders Reached You';
      case null:
        return '-';
    }
  }

  String get zoneCoordinateLabel {
    final pos = _currentRoomPos;
    if (pos == null) {
      return '-';
    }

    return '${pos.x + 1},${pos.y + 1}';
  }

  String get zoneTypeLabel {
    final room = _currentRoom;
    if (room == null) {
      return 'Unknown';
    }

    return room.type.label;
  }

  SpinnerComponent? get spinner => _spinner;
  Vector2? get tetherLineStart => _tetherLineStart;
  Vector2? get tetherLineEnd => _tetherLineEnd;

  _LevelPlan? get _currentLevel {
    if (_levels.isEmpty || _currentLevelIndex >= _levels.length) {
      return null;
    }

    return _levels[_currentLevelIndex];
  }

  _RoomPlan? get _currentRoom {
    final level = _currentLevel;
    final pos = _currentRoomPos;
    if (level == null || pos == null) {
      return null;
    }

    return level.rooms[pos];
  }

  double _roomScaleForLevelNumber(int levelNumber) {
    final span = max(1, _campaignLevelCount - 1);
    final t = ((levelNumber - 1) / span).clamp(0, 1).toDouble();
    return _minRoomScale + ((_maxRoomScale - _minRoomScale) * t);
  }

  double _roomHeightForScale(double scale) => roomHeight * scale;
  double _corridorWidthForScale(double scale) =>
      corridorWidth * (0.75 + (scale * 0.25));

  double get _activeRoomScale => _currentLevel?.roomScale ?? 1.0;
  double get _activeRoomHeight => _roomHeightForScale(_activeRoomScale);
  double get _activeCorridorWidth => _corridorWidthForScale(_activeRoomScale);

  bool get _canBootstrapRun {
    return _ready && _progressLoaded && _snapshotLoaded && !_bootstrappedRun;
  }

  void _syncUnlockedAndBuildFromProgress({bool announceNewUnlocks = false}) {
    final previousUnlocked = Set<String>.from(_unlockedPartIds);
    final taskProgress = SpinnerPartCatalog.taskProgresses(
      totalRuns: _progress.totalRuns,
      totalCoinsCollected: _progress.totalCoinsCollected,
      totalEnemiesDefeated: _progress.totalEnemiesDefeated,
      bossClears: _progress.bossClears,
    );
    final completedTasks = <String>{
      ..._progress.completedGearTasks,
      for (final task in taskProgress)
        if (task.isComplete) task.definition.id,
    };
    _unlockedPartIds = SpinnerPartCatalog.unlockedPartsForProgress(
      bankedCoins: _progress.bankedCoins,
      totalRuns: _progress.totalRuns,
      deepestLevelReached: _progress.deepestLevelReached,
      bossClears: _progress.bossClears,
      completedTaskIds: completedTasks,
      existingUnlocked: _progress.unlockedPartIds,
    );
    _selectedBuild = SpinnerPartCatalog.sanitizeBuild(
      build: _progress.selectedBuild,
      unlockedIds: _unlockedPartIds,
    );
    _selectedBuildStats = SpinnerPartCatalog.computeStats(_selectedBuild);
    _progress = _progress.copyWith(
      unlockedPartIds: _unlockedPartIds,
      selectedBuild: _selectedBuild,
      completedGearTasks: completedTasks,
    );

    if (announceNewUnlocks) {
      final newlyUnlocked = _unlockedPartIds.difference(previousUnlocked);
      if (newlyUnlocked.isNotEmpty) {
        _showUnlockToastForParts(newlyUnlocked);
      }
    }
  }

  void _showUnlockToastForParts(Iterable<String> partIds) {
    SpinnerPartDefinition? best;
    for (final id in partIds) {
      final def = SpinnerPartCatalog.partById(id);
      // Prefer parts marked with a depthRewardLabel (intentional reward parts).
      if (best == null ||
          (def.depthRewardLabel != null && best.depthRewardLabel == null) ||
          def.unlockDepth > best.unlockDepth) {
        best = def;
      }
    }
    if (best == null) {
      return;
    }
    final headline = best.depthRewardLabel ?? 'New part unlocked';
    _unlockToastText = '$headline: ${best.name}';
    _unlockToastSubtitle = best.description;
    _unlockToastSeconds = _unlockToastDuration;
    _notifyHud();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadDungeonTiles();
    await RoomTemplateCatalog.instance.ensureLoaded();
    _semanticThemeMapping = await SemanticThemeMapping.load();
    _progress = await _progressRepository.load();
    _pendingRunSnapshot = await _runSnapshotRepository.load();
    _restoreSeedPreferencesFromSnapshot();
    _syncUnlockedAndBuildFromProgress();
    _progressLoaded = true;
    _snapshotLoaded = true;
    _notifyHud();

    if (_ready && _canBootstrapRun) {
      _bootstrapInitialRun();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    if (_ready || size.x <= 0 || size.y <= 0) {
      return;
    }

    _ready = true;
    if (_canBootstrapRun) {
      _bootstrapInitialRun();
    }
  }

  @override
  void update(double dt) {
    if (_hitStopRemaining > 0) {
      _hitStopRemaining = max(0, _hitStopRemaining - dt);
      super.update(0);
      _elapsedSeconds += dt;
      if (_damageInvulnerabilityRemaining > 0) {
        _damageInvulnerabilityRemaining -= dt;
      }
      if (_damageAlertSeconds > 0) {
        final beforeBucket = (_damageAlertSeconds * 12).floor();
        _damageAlertSeconds = max(0, _damageAlertSeconds - dt);
        final afterBucket = (_damageAlertSeconds * 12).floor();
        if (beforeBucket != afterBucket || _damageAlertSeconds == 0) {
          _notifyHud();
        }
      }
      _tickUnlockToast(dt);
      if (_progressLoaded && !_pausedByMenu) {
        _updateSpinPowerups(dt);
        _updatePitHover(dt);
        _syncCurrentRoomFromSpinner();
        _updateCameraZoom(dt);
        _tickRunSnapshotAutosave(dt);
        _tickInvasionMode(dt);
      }
      _applyScreenShake(dt);
      return;
    }

    super.update(dt);
    _elapsedSeconds += dt;
    if (_damageInvulnerabilityRemaining > 0) {
      _damageInvulnerabilityRemaining -= dt;
    }
    if (_damageAlertSeconds > 0) {
      final beforeBucket = (_damageAlertSeconds * 12).floor();
      _damageAlertSeconds = max(0, _damageAlertSeconds - dt);
      final afterBucket = (_damageAlertSeconds * 12).floor();
      if (beforeBucket != afterBucket || _damageAlertSeconds == 0) {
        _notifyHud();
      }
    }
    _tickUnlockToast(dt);

    if (!_progressLoaded) {
      _applyScreenShake(dt);
      return;
    }

    if (_pausedByMenu) {
      _applyScreenShake(dt);
      return;
    }

    _updateSpinPowerups(dt);
    _updatePitHover(dt);
    _syncCurrentRoomFromSpinner();
    _updateCameraZoom(dt);
    _tickRunSnapshotAutosave(dt);
    _tickInvasionMode(dt);
    _applyScreenShake(dt);
  }

  void _tickInvasionMode(double dt) {
    if (_gameMode != SpinnerGameMode.invasion ||
        _runPhase != RunPhase.playing ||
        _pausedByMenu) {
      return;
    }
    _invasionElapsed += dt;
    // In "Infinite Invasion" walkers are harmless on contact (see
    // `onEnemyContact`) and the mode intentionally has no instant-loss
    // breach line. The player fails only by running out of spins — mirror of
    // classic endless arcade: "you survive as long as you can keep spinning".
  }

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    super.onTapDown(pointerId, info);

    if (!_progressLoaded) {
      return;
    }

    if (_runPhase == RunPhase.runOver) {
      returnToMainMenuFromHud();
      return;
    }

    if (_runPhase != RunPhase.playing) {
      return;
    }

    if (_pausedByMenu) {
      return;
    }

    final spinner = _spinner;
    if (spinner != null && spinner.isMoving) {
      final pointer = _widgetToWorld(info.eventPosition.widget);
      if (spinner.containsPoint(pointer)) {
        // Let players interrupt a run and re-spin without waiting for friction.
        spinner.stop();
        _isCharging = false;
        _spinDetector.reset();
        _targetCameraZoom = _baseCameraZoom;
        _notifyHud();
      }
      return;
    }

    if (_pendingDebugSpawnPlacement != null &&
        spinner != null &&
        !spinner.isMoving) {
      final tapPoint = _widgetToWorld(info.eventPosition.widget);
      placeArmedDebugSpawnAt(tapPoint);
      return;
    }

    if (spinner != null &&
        !spinner.isMoving &&
        !_isCharging &&
        _selectedPowerup == PowerupType.tether) {
      final tapPoint = _widgetToWorld(info.eventPosition.widget);
      if (!spinner.containsPoint(tapPoint)) {
        _queuedTetherTarget = tapPoint;
        _notifyHud();
      }
    }
  }

  @override
  void onDoubleTapDown(TapDownInfo info) {
    if (!_progressLoaded) {
      return;
    }
    if (_runPhase != RunPhase.playing || _pausedByMenu) {
      return;
    }
    final s = _spinner;
    // Only while the spinner is actively moving; works anywhere on screen.
    if (s == null || !s.isMoving) {
      return;
    }
    s.toggleBladeStance();
    _notifyHud();
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    super.onScaleStart(info);

    if (_runPhase != RunPhase.playing) {
      return;
    }

    if (_pausedByMenu) {
      return;
    }

    if (info.pointerCount >= 2) {
      if (!spinnerMoving) {
        _beginCameraGesture();
      }
      return;
    }

    if (_isCameraGestureActive) {
      return;
    }

    final spinner = _spinner;
    if (spinner == null) {
      return;
    }

    final pointer = _widgetToWorld(info.eventPosition.widget);
    if (!spinner.containsPoint(pointer)) {
      return;
    }

    if (spinner.isMoving) {
      // Single-touch on spinner while moving: stop immediately, then allow re-spin.
      spinner.stop();
      _isCharging = false;
      _spinDetector.reset();
    }

    if (!canStartCharge) {
      return;
    }

    _beginSpinnerCharge(pointer);
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    super.onScaleUpdate(info);

    if (_runPhase != RunPhase.playing) {
      return;
    }

    if (_pausedByMenu) {
      return;
    }

    if (info.pointerCount >= 2 && !spinnerMoving) {
      _beginCameraGesture();
    }

    if (!_isCameraGestureActive) {
      if (_isCharging) {
        _spinDetector.update(
          pointerPosition: _widgetToWorld(info.eventPosition.widget),
          timestamp: _elapsedSeconds,
        );
        _spinner?.setChargePreview(
          strength: _spinDetector.currentCharge,
          signedAngularVelocity: _spinDetector.currentSignedAngularVelocity,
        );
        _notifyHud();
      }
      return;
    }

    final focalWidget = info.eventPosition.widget;
    final worldBeforeZoom = _widgetToWorld(focalWidget);

    final scaleValue = ((info.scale.global.x + info.scale.global.y) * 0.5)
        .clamp(0.55, 2.6)
        .toDouble();
    final nextZoom = (_cameraGestureStartZoom * scaleValue)
        .clamp(_planningMinZoom, _planningMaxZoom)
        .toDouble();

    camera.viewfinder.zoom = nextZoom;

    final worldAfterZoom = _widgetToWorld(focalWidget);
    camera.viewfinder.position += worldBeforeZoom - worldAfterZoom;

    camera.viewfinder.position -= info.delta.global / camera.viewfinder.zoom;
    _targetCameraZoom = camera.viewfinder.zoom;
    _notifyHud();
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    super.onScaleEnd(info);

    if (_isCameraGestureActive) {
      _isCameraGestureActive = false;
      _targetCameraZoom = camera.viewfinder.zoom;
      _notifyHud();
      return;
    }

    if (!_isCharging) {
      return;
    }

    _finishSpinnerCharge();
    _notifyHud();
  }

  void _beginSpinnerCharge(Vector2 pointer) {
    _isCameraDragActive = false;
    // Re-center and zoom on the spinner so charge gestures stay aligned
    // with the playfield (reduces “miss” launches after panning the map).
    _attachCameraFollow(snap: true);
    _targetCameraZoom = _chargeCameraZoom;
    _isCharging = true;
    _spinDetector.start(
      pointerPosition: pointer,
      center: _spinner!.position,
      timestamp: _elapsedSeconds,
    );
    _spinner?.setChargePreview(strength: 0, signedAngularVelocity: 0);
    _notifyHud();
  }

  void _finishSpinnerCharge() {
    _isCharging = false;
    final launch = _spinDetector.end(timestamp: _elapsedSeconds);
    _spinner?.clearChargePreview();

    if (launch.hasLaunch) {
      final launchScale =
          _appliedUpgrades.launchSpeedMultiplier *
          _selectedBuildStats.launchSpeedMultiplier;
      final speed = _launchSpeedForSpinStrength(
        launch.spinStrength,
        launchScale: launchScale,
      );
      _spinner?.launch(
        launch.launchDirection * speed,
        angularVelocity: launch.signedAngularVelocity * 3.3,
      );
      _activateSelectedPowerupForCurrentSpin();

      if (showTutorialSpinPrompt) {
        dismissTutorialSpinPrompt();
      }
    } else if (!spinnerMoving) {
      _targetCameraZoom = _baseCameraZoom;
    }

    _syncRoomAndLevelState();
  }

  double _launchSpeedForSpinStrength(
    double spinStrength, {
    required double launchScale,
  }) {
    final maxSpeed = maxLaunchSpeed * launchScale;
    final normalizedSpin = (spinStrength / _spinStrengthForMaxLaunch)
        .clamp(0.0, 1.0)
        .toDouble();
    final curvedSpin = pow(
      normalizedSpin,
      _launchSpeedCurveExponent,
    ).toDouble();
    final speedRatio =
        _minLaunchSpeedRatio + ((1.0 - _minLaunchSpeedRatio) * curvedSpin);
    final soft = (maxSpeed * speedRatio)
        .clamp(maxSpeed * _minLaunchSpeedRatio, maxSpeed)
        .toDouble();
    final hardFloor = maxSpeed * _launchSpeedHardFloorRatio;
    return max(soft, hardFloor);
  }

  /// 1.0 on level 4+; up to ~1.24 on level 1 for snappier early TTK.
  double get spinnerContactDamageEarlyFactor {
    final tiers = max(0, 4 - levelNumber);
    return 1.0 + 0.08 * min(3, tiers).toDouble();
  }

  void onSpinnerEnemyImpact({
    required double impactSpeed,
    required double damage,
    required bool enemyDefeated,
    required bool heavyHit,
    required Vector2 impactWorldPos,
  }) {
    if (_runPhase != RunPhase.playing || _pausedByMenu) {
      return;
    }

    final hitStop = heavyHit ? 0.145 : (enemyDefeated ? 0.068 : 0.045);
    _hitStopRemaining = max(_hitStopRemaining, hitStop);

    final punch = min(
      18.0,
      damage * 0.38 + impactSpeed * 0.011,
    ).clamp(4.0, 18.0);
    var bumpAdd = 0.0048 + punch * 0.0011;
    if (heavyHit) {
      bumpAdd *= 1.85;
    }
    _cameraImpactZoomBump = min(0.068, _cameraImpactZoomBump + bumpAdd);

    if (heavyHit) {
      addScreenShake(15);
      spawnKapowAt(impactWorldPos);
      _playCombatHaptics(enemyDefeated: true);
    } else {
      _playCombatHaptics(enemyDefeated: enemyDefeated);
    }

    final sparkIntensity =
        (damage / 40).clamp(0.75, 1.65) * (0.82 + impactSpeed / 1100);
    spawnImpactSparks(impactWorldPos, intensity: sparkIntensity);
  }

  void spawnImpactSparks(Vector2 worldPos, {double intensity = 1}) {
    if (_runPhase != RunPhase.playing) {
      return;
    }
    world.add(
      ImpactSparkBurstComponent(
        position: worldPos.clone(),
        intensity: intensity,
      ),
    );
  }

  void spawnKapowAt(Vector2 worldPos) {
    if (_runPhase != RunPhase.playing) {
      return;
    }
    world.add(KapowEffectComponent(position: worldPos.clone()));
  }

  void addScreenShake(double magnitude) {
    _screenShakeMagnitude = max(_screenShakeMagnitude, magnitude);
  }

  void _applyScreenShake(double dt) {
    if (_screenShakeMagnitude < 0.35) {
      _screenShakeMagnitude = 0;
      return;
    }
    final ox = (_random.nextDouble() * 2 - 1) * _screenShakeMagnitude;
    final oy = (_random.nextDouble() * 2 - 1) * _screenShakeMagnitude;
    camera.viewfinder.position.add(Vector2(ox, oy));
    _screenShakeMagnitude *= pow(0.02, dt * 22).toDouble();
  }

  void _playCombatHaptics({required bool enemyDefeated}) {
    try {
      if (enemyDefeated) {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.alert);
      } else {
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {}
  }

  void _beginCameraGesture() {
    if (_isCameraGestureActive) {
      return;
    }

    _isCameraGestureActive = true;
    _isCameraDragActive = false;
    _cameraGestureStartZoom = camera.viewfinder.zoom;
    _detachCameraFollow();

    if (_isCharging) {
      _isCharging = false;
      _spinDetector.reset();
      _spinner?.clearChargePreview();
    }

    _notifyHud();
  }

  bool get canStartCharge {
    return _runPhase == RunPhase.playing &&
        !_pausedByMenu &&
        !_dungeonComplete &&
        selectedPowerupReady;
  }

  void onSpinnerLaunched() {
    if (_pausedByMenu) {
      return;
    }
    _killsThisSpin = 0;
    _isCameraGestureActive = false;
    _isCameraDragActive = false;
    _attachCameraFollow(snap: false);
    _targetCameraZoom = _releaseCameraZoom;
    _notifyHud();
  }

  void onEnemyDefeated(EnemyComponent enemy) {
    _enemies.remove(enemy);
    _enemyRooms.remove(enemy);
    _enemyBounds.remove(enemy);
    _runStats = _runStats.copyWith(enemiesKilled: _runStats.enemiesKilled + 1);
    if (showTutorialGoalPrompt) {
      dismissTutorialGoalPrompt();
    }
    final killScore = switch (enemy.type) {
      EnemyType.turret => 65,
      EnemyType.walker => 40,
      EnemyType.boss => 520,
      EnemyType.paddle => 52,
      EnemyType.hedgehog => 70,
      EnemyType.pulser => 78,
    };
    var chainMult = 1.0;
    if (spinnerMoving) {
      _killsThisSpin++;
      final chainIndex = (_killsThisSpin - 1).clamp(0, 12);
      chainMult = 1.0 + 0.15 * chainIndex;
      _runStats = _runStats.copyWith(
        maxSpinChain: max(_runStats.maxSpinChain, _killsThisSpin),
      );
    }
    final adjustedKillScore = (killScore * chainMult).round();
    _addScore(adjustedKillScore, depthScaled: true);
    _progress = _progress.copyWith(
      totalEnemiesDefeated: _progress.totalEnemiesDefeated + 1,
    );
    _syncUnlockedAndBuildFromProgress();
    _persistProgress();
    _spawnCoinBurst(enemy.position.clone(), enemy.coinDrop);
    if (_runPhase == RunPhase.playing &&
        _random.nextDouble() < (enemy.type == EnemyType.boss ? 1.0 : 0.18)) {
      _spawnDungeonAbilityDrop(enemy.position.clone());
    }
    _syncRoomAndLevelState();
  }

  void onSpinnerStateChanged() {
    final currentlyMoving = spinnerMoving;
    final justStopped = _wasSpinnerMoving && !currentlyMoving;
    _wasSpinnerMoving = currentlyMoving;

    if (!spinnerMoving && !_isCharging) {
      _targetCameraZoom = _baseCameraZoom;
    }

    if (spinnerMoving && !_isCameraFollowingSpinner) {
      _attachCameraFollow(snap: false);
    }

    if (justStopped) {
      _clearActivePowerupForStop();
    }

    _syncRoomAndLevelState();
    if (justStopped) {
      _persistRunSnapshot(force: true);
    }
  }

  void onTrapTriggered(TrapComponent trap, SpinnerComponent spinner) {
    if (_runPhase != RunPhase.playing || isWorldFrozen) {
      return;
    }

    spinner.applyTrapEffect(speedMultiplier: 0.58, spinMultiplier: 0.7);
    applyPlayerDamage(12, source: 'Trap');
    _syncRoomAndLevelState();
  }

  void _tickUnlockToast(double dt) {
    if (_unlockToastSeconds <= 0) {
      return;
    }
    final before = (_unlockToastSeconds * 10).floor();
    _unlockToastSeconds = max(0, _unlockToastSeconds - dt);
    final after = (_unlockToastSeconds * 10).floor();
    if (before != after || _unlockToastSeconds == 0) {
      if (_unlockToastSeconds == 0) {
        _unlockToastText = '';
        _unlockToastSubtitle = '';
      }
      _notifyHud();
    }
  }

  void onChestOpened(ChestComponent chest) {
    if (_runPhase != RunPhase.playing) {
      return;
    }

    final roomPos = _chestRooms[chest];
    final room = roomPos == null ? null : _currentLevel?.rooms[roomPos];
    if (room == null || room.chestOpened) {
      return;
    }

    room.chestOpened = true;
    _spawnCoinBurst(chest.position.clone(), chest.coinReward);
    _notifyHud();
  }

  void onCoinCollected(CoinPickupComponent coin) {
    if (!_coins.remove(coin)) {
      return;
    }

    final value = max(1, coin.value);
    _runStats = _runStats.copyWith(
      runCoins: _runStats.runCoins + value,
      runScore: _runStats.runScore + (value * 2),
    );
    _progress = _progress.copyWith(
      bankedCoins: _progress.bankedCoins + value,
      bestScore: max(_progress.bestScore, _runStats.runScore),
      totalCoinsCollected: _progress.totalCoinsCollected + value,
    );
    _syncUnlockedAndBuildFromProgress();
    _persistProgress();
    _notifyHud();
  }

  void onPowerupCollected(PowerupComponent powerup) {
    if (!_powerups.remove(powerup)) {
      return;
    }

    if (powerup.type == PowerupType.spinRefill) {
      // Legacy spin orb (spin budget removed) — collect harmlessly.
      return;
    }

    final current = _abilityCharges[powerup.type] ?? 0;
    _abilityCharges[powerup.type] = (current + 1).clamp(0, 99).toInt();

    _addScore(30, depthScaled: false);
    _notifyHud();
  }

  void onSpinnerShotHit(SpinnerShotComponent shot, EnemyComponent enemy) {
    if (!_spinnerShots.remove(shot)) {
      return;
    }

    if (!enemy.isDead) {
      final damage = shot.damage;
      final heavyHit = damage >= enemy.maxHp * 0.75;
      enemy.takeDamage(damage);
      final spinner = _spinner;
      final impactPos = spinner != null
          ? (spinner.position + enemy.position) / 2
          : enemy.position.clone();
      onSpinnerEnemyImpact(
        impactSpeed: 520,
        damage: damage,
        enemyDefeated: enemy.isDead,
        heavyHit: heavyHit,
        impactWorldPos: impactPos,
      );
      if (spinner != null) {
        final away = enemy.position - spinner.position;
        if (away.length2 > 0) {
          enemy.addImpulse(away.normalized() * (damage * 6));
        }
      }
    }

    shot.removeFromParent();
  }

  void onSpinnerShotExpired(SpinnerShotComponent shot) {
    if (!_spinnerShots.remove(shot)) {
      return;
    }

    shot.removeFromParent();
  }

  void onEnemyContact(EnemyComponent enemy) {
    if (_runPhase != RunPhase.playing || isWorldFrozen) {
      return;
    }
    if (isInvasionMode) {
      return;
    }
    final spinner = _spinner;
    if (spinner == null || !enemy.canDamageSpinnerOnContact(spinner.position)) {
      return;
    }

    final scaling =
        1 +
        (_currentLevelIndex * 0.14) +
        (_progress.deepestLevelReached * 0.01).clamp(0, 0.35);
    applyPlayerDamage(
      enemy.contactDamage * scaling,
      source: enemy.contactSourceLabel,
    );
  }

  void spawnEnemyProjectile({
    required Vector2 origin,
    required Vector2 direction,
    required double damage,
    required double speed,
  }) {
    if (_runPhase != RunPhase.playing || direction.length2 == 0) {
      return;
    }

    final projectile = EnemyProjectileComponent(
      position: origin,
      velocity: direction.normalized() * speed,
      damage:
          damage *
          (1 +
              (_currentLevelIndex * 0.14) +
              (_progress.deepestLevelReached * 0.01).clamp(0, 0.35)),
    );
    _enemyProjectiles.add(projectile);
    world.add(projectile);
  }

  /// Beam telegraph fills, then spawns a projectile along [fireDirection].
  void queueTelegraphedEnemyProjectile({
    required Vector2 Function() muzzleWorld,
    required Vector2 fireDirection,
    double beamLength = 440,
    double beamHalfWidth = 12,
    double startDelay = 0,
    double fillDuration = 0.36,
    required double damage,
    required double speed,
    void Function()? onWindupComplete,
    EnemyComponent? telegraphOwner,
  }) {
    if (_runPhase != RunPhase.playing || fireDirection.length2 == 0) {
      return;
    }
    final dir = fireDirection.normalized();
    world.add(
      TelegraphedThreatComponent.beam(
        origin: muzzleWorld(),
        direction: dir,
        beamLength: beamLength,
        beamHalfWidth: beamHalfWidth,
        startDelay: startDelay,
        fillDuration: fillDuration,
        trackMuzzleWorld: muzzleWorld,
        canAdvanceTime: () => _runPhase == RunPhase.playing && !isWorldFrozen,
        priority: -12,
        outlineColor: const Color(0xCCFF5A42),
        fillColor: const Color(0x52FF7A52),
        onComplete: () {
          if (telegraphOwner != null && telegraphOwner.isDead) {
            return;
          }
          onWindupComplete?.call();
          if (_runPhase != RunPhase.playing) {
            return;
          }
          spawnEnemyProjectile(
            origin: muzzleWorld(),
            direction: dir,
            damage: damage,
            speed: speed,
          );
        },
      ),
    );
  }

  /// Short beam telegraph then applies walker dash (no projectile).
  void queueWalkerDashTelegraph({
    required Vector2 Function() muzzleWorld,
    required Vector2 dashDirection,
    required void Function() onComplete,
  }) {
    if (_runPhase != RunPhase.playing || dashDirection.length2 == 0) {
      return;
    }
    final dir = dashDirection.normalized();
    world.add(
      TelegraphedThreatComponent.beam(
        origin: muzzleWorld(),
        direction: dir,
        beamLength: 92,
        beamHalfWidth: 9,
        startDelay: 0,
        fillDuration: 0.22,
        trackMuzzleWorld: muzzleWorld,
        canAdvanceTime: () => _runPhase == RunPhase.playing && !isWorldFrozen,
        priority: -12,
        outlineColor: const Color(0xCCFFB020),
        fillColor: const Color(0x48FFD060),
        onComplete: onComplete,
      ),
    );
  }

  /// Long, obvious circular telegraph; damage if spinner is inside when it detonates.
  void queueEnemyGroundSlam({
    required Vector2 Function() centerWorld,
    required double radius,
    required double damage,
    EnemyComponent? telegraphOwner,
  }) {
    if (_runPhase != RunPhase.playing) {
      return;
    }
    world.add(
      TelegraphedThreatComponent.circle(
        center: centerWorld(),
        arcRadius: radius,
        startDelay: 0.34,
        fillDuration: 1.1,
        trackMuzzleWorld: centerWorld,
        canAdvanceTime: () => _runPhase == RunPhase.playing && !isWorldFrozen,
        priority: 22,
        outlineColor: const Color(0xF5D020FF),
        fillColor: const Color(0x6EFFC8F5),
        onComplete: () {
          if (telegraphOwner != null && telegraphOwner.isDead) {
            return;
          }
          if (_runPhase != RunPhase.playing) {
            return;
          }
          final c = centerWorld();
          final sp = _spinner;
          if (sp == null) {
            return;
          }
          if (c.distanceTo(sp.position) <= radius + sp.radius * 0.92) {
            applyPlayerDamage(damage, source: 'Ground slam');
          }
        },
      ),
    );
  }

  void onEnemyProjectileHit(EnemyProjectileComponent projectile) {
    if (!_enemyProjectiles.remove(projectile)) {
      return;
    }

    applyPlayerDamage(projectile.damage, source: 'Projectile');
    projectile.removeFromParent();
  }

  void onEnemyProjectileExpired(EnemyProjectileComponent projectile) {
    if (!_enemyProjectiles.remove(projectile)) {
      return;
    }

    projectile.removeFromParent();
  }

  void onPitTriggered(PitComponent pit, SpinnerComponent spinner) {
    if (_runPhase != RunPhase.playing || _pausedByMenu) {
      return;
    }

    if (_canSkimPit(pit: pit, spinner: spinner)) {
      _addScore(24, depthScaled: false);
      _clearPitHoverState();
      return;
    }

    _hoveringPit = pit;
    _pitHoverSecondsRemaining = max(
      _minimumPitHoverSeconds,
      _appliedUpgrades.pitHoverSeconds,
    );
  }

  void _updatePitHover(double dt) {
    final pit = _hoveringPit;
    if (pit == null) {
      return;
    }

    if (_runPhase != RunPhase.playing || _pausedByMenu) {
      return;
    }

    final spinner = _spinner;
    if (spinner == null || pit.isRemoving || pit.parent == null) {
      _clearPitHoverState();
      return;
    }

    if (!_spinnerIntersectsPit(spinner: spinner, pit: pit)) {
      _clearPitHoverState();
      return;
    }

    _pitHoverSecondsRemaining -= dt;
    if (_pitHoverSecondsRemaining > 0) {
      return;
    }

    _resolvePitFall(spinner: spinner);
    _clearPitHoverState();
  }

  bool _spinnerIntersectsPit({
    required SpinnerComponent spinner,
    required PitComponent pit,
  }) {
    final limit = spinner.radius + pit.radius;
    return spinner.position.distanceTo(pit.position) <= limit;
  }

  void _resolvePitFall({required SpinnerComponent spinner}) {
    if (_pitSavesRemaining <= 0) {
      _endRun(RunEndReason.pitFall);
      return;
    }

    _pitSavesRemaining = max(0, _pitSavesRemaining - 1);
    spinner.stop();
    spinner.position = _safeRespawnPosition();
    spinner.velocity = Vector2.zero();
    spinner.angularVelocity = 0;
    clampSpinnerToArena(spinner);
    applyPlayerDamage(
      _pitPenaltyDamage * _appliedUpgrades.pitPenaltyMultiplier,
      source: 'Pit Rescue',
      ignoreIFrame: true,
    );
    _notifyHud();
  }

  void _clearPitHoverState() {
    _hoveringPit = null;
    _pitHoverSecondsRemaining = 0;
  }

  void applyPlayerDamage(
    double amount, {
    required String source,
    bool ignoreIFrame = false,
  }) {
    if (_runPhase != RunPhase.playing) {
      return;
    }

    if (!ignoreIFrame && _damageInvulnerabilityRemaining > 0) {
      return;
    }

    final scaled =
        (amount *
                _appliedUpgrades.incomingDamageMultiplier *
                _selectedBuildStats.incomingDamageMultiplier)
            .round();
    final damageTaken = max(1, scaled).toInt();
    final beforeHp = _currentHp;
    final nextHp = max(0, _currentHp - damageTaken).toInt();
    _currentHp = nextHp;
    _lastDamageSource = source;
    _lastDamageAmount = max(0, beforeHp - nextHp).toInt();
    _damageAlertSeconds = _damageAlertDuration;
    _damageInvulnerabilityRemaining = _damageInvulnerability;
    _spinner?.triggerDamageFlash();
    addScreenShake(5.2);
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    final sp = _spinner;
    if (sp != null) {
      spawnImpactSparks(sp.position.clone(), intensity: 0.95);
    }

    if (_currentHp <= 0) {
      _endRun(RunEndReason.hpDepleted);
      return;
    }

    _notifyHud();
  }

  void clampSpinnerToArena(SpinnerComponent spinner) {
    spinner.position.setValues(
      spinner.position.x
          .clamp(_levelMin.x + spinner.radius, _levelMax.x - spinner.radius)
          .toDouble(),
      spinner.position.y
          .clamp(_levelMin.y + spinner.radius, _levelMax.y - spinner.radius)
          .toDouble(),
    );
  }

  void clampEnemyToArena(EnemyComponent enemy) {
    final bounds = _enemyBounds[enemy];
    if (bounds == null) {
      enemy.position.setValues(
        enemy.position.x
            .clamp(_levelMin.x + enemy.radius, _levelMax.x - enemy.radius)
            .toDouble(),
        enemy.position.y
            .clamp(_levelMin.y + enemy.radius, _levelMax.y - enemy.radius)
            .toDouble(),
      );
      return;
    }

    enemy.position.setValues(
      enemy.position.x
          .clamp(bounds.left + enemy.radius, bounds.right - enemy.radius)
          .toDouble(),
      enemy.position.y
          .clamp(bounds.top + enemy.radius, bounds.bottom - enemy.radius)
          .toDouble(),
    );
  }

  void _bootstrapInitialRun() {
    _bootstrappedRun = true;
    _clearActiveComponents();
    _pendingDebugSpawnPlacement = null;
    _queuedDebugSpawnPlacements.clear();
    overlays.remove('upgrade_menu');
    overlays.add('start_flow');
    _runPhase = RunPhase.startMenu;
    _runEndReason = null;
    _notifyHud();
    _persistRunSnapshot(force: true);
  }

  void _tickRunSnapshotAutosave(double dt) {
    if (!_bootstrappedRun || !_progressLoaded || !_snapshotLoaded) {
      return;
    }

    _runSnapshotAutosaveTimer += dt;
    if (_runSnapshotAutosaveTimer < 0.9) {
      return;
    }
    _runSnapshotAutosaveTimer = 0;
    _persistRunSnapshot();
  }

  void persistRunSnapshotNow() {
    _persistRunSnapshot(force: true);
  }

  void _startNewDungeonRun({bool isWeekly = false}) {
    if (!_progressLoaded || !_ready) {
      return;
    }

    _gameMode = SpinnerGameMode.dungeon;
    _runIsWeekly = isWeekly;
    _bootstrappedRun = true;
    overlays.remove('upgrade_menu');
    overlays.remove('start_flow');
    _pausedByMenu = false;
    resumeEngine();

    _runPhase = RunPhase.playing;
    _runEndReason = null;
    _runStats = const RunStats();
    _killsThisSpin = 0;
    _tutorialSpinPromptDone = false;
    _tutorialGoalPromptDone = false;
    _tutorialDepthPromptDone = false;
    _runDeepestLevelAtStart = _progress.deepestLevelReached;
    _newDeepestThisRun = false;
    _unlockToastSeconds = 0;
    _unlockToastText = '';
    _unlockToastSubtitle = '';
    _appliedUpgrades = UpgradeSystem.apply(_progress.tiers);
    _maxHp = max(20, _appliedUpgrades.maxHp + _selectedBuildStats.maxHpBonus);
    _currentHp = _maxHp;
    _pitSavesRemaining = _appliedUpgrades.pitSaves;
    _damageInvulnerabilityRemaining = 0;
    _lastDamageSource = '-';
    _lastDamageAmount = 0;
    _damageAlertSeconds = 0;
    _abilityCharges.clear();
    _selectedPowerup = null;
    _activePowerup = null;
    _queuedTetherTarget = null;
    _activeTetherTarget = null;
    _fireballCooldown = 0;
    _needlesCooldown = 0;
    _clearPitHoverState();
    _pendingDebugSpawnPlacement = null;
    _queuedDebugSpawnPlacements.clear();
    _activeRunSeed = _normalizedSeed(
      isWeekly ? weeklySeed : (_configuredRunSeed ?? _random.nextInt(1 << 30)),
    );

    _levels.clear();

    for (var i = 0; i < _campaignLevelCount; i++) {
      _levels.add(_generateLevel(levelNumber: i + 1));
    }

    _currentLevelIndex = 0;
    _currentRoomPos = _currentLevel?.start;

    _dungeonComplete = false;
    _levelComplete = false;
    _levelClearAcknowledged = false;
    _targetCameraZoom = _baseCameraZoom;
    _isCameraGestureActive = false;
    _isCameraDragActive = false;
    _isCameraFollowingSpinner = false;

    _buildAndSpawnCurrentLevel();
    _persistRunSnapshot(force: true);
  }

  /// Space-invader style drill: spinner at bottom vs walkers drifting down.
  void startInvasionRun() {
    if (!_progressLoaded || !_ready) {
      return;
    }

    _gameMode = SpinnerGameMode.invasion;
    _invasionElapsed = 0;
    _bootstrappedRun = true;
    overlays.remove('upgrade_menu');
    overlays.remove('start_flow');
    _pausedByMenu = false;
    resumeEngine();

    _runPhase = RunPhase.playing;
    _runEndReason = null;
    _runStats = const RunStats();
    _killsThisSpin = 0;
    _runIsWeekly = false;
    _runDeepestLevelAtStart = _progress.deepestLevelReached;
    _newDeepestThisRun = false;
    _unlockToastSeconds = 0;
    _unlockToastText = '';
    _unlockToastSubtitle = '';
    _appliedUpgrades = UpgradeSystem.apply(_progress.tiers);
    _maxHp = max(20, _appliedUpgrades.maxHp + _selectedBuildStats.maxHpBonus);
    _currentHp = _maxHp;
    _pitSavesRemaining = _appliedUpgrades.pitSaves;
    _damageInvulnerabilityRemaining = 0;
    _lastDamageSource = '-';
    _lastDamageAmount = 0;
    _damageAlertSeconds = 0;
    _abilityCharges.clear();
    _selectedPowerup = null;
    _activePowerup = null;
    _queuedTetherTarget = null;
    _activeTetherTarget = null;
    _fireballCooldown = 0;
    _needlesCooldown = 0;
    _clearPitHoverState();
    _pendingDebugSpawnPlacement = null;
    _queuedDebugSpawnPlacements.clear();

    _levels.clear();
    _levels.add(_buildInvasionLevelPlan());

    _currentLevelIndex = 0;
    _currentRoomPos = _currentLevel?.start;

    _dungeonComplete = false;
    _levelComplete = false;
    _levelClearAcknowledged = false;
    _targetCameraZoom = _baseCameraZoom;
    _isCameraGestureActive = false;
    _isCameraDragActive = false;
    _isCameraFollowingSpinner = false;

    _buildAndSpawnCurrentLevel();
    _finalizeInvasionSpawnPlacement();
    _notifyHud();
  }

  _LevelPlan _buildInvasionLevelPlan() {
    const p = _GridPos(1, 1);
    final room = _RoomPlan(position: p, tileW: 16, tileH: 22);
    room.type = RoomType.combat;
    room.dangerTier = 2;
    room.walkerCount = 42;
    return _LevelPlan(
      width: 18,
      height: 24,
      start: p,
      rooms: {p: room},
      roomScale: 0.76,
      tileSize: _bspTileSize,
    );
  }

  void _finalizeInvasionSpawnPlacement() {
    final s = _spinner;
    if (s == null) {
      return;
    }
    final cx = (_levelMin.x + _levelMax.x) * 0.5;
    final y = _levelMax.y - _invasionSpinnerBottomInset;
    s.position.setValues(cx, y);
    s.stop();
    _currentRoomPos = _currentLevel?.start;
    _attachCameraFollow(snap: true);
  }

  void openUpgradesFromMainMenu() {
    if (!_progressLoaded || _runPhase != RunPhase.startMenu) {
      return;
    }

    overlays.remove('start_flow');
    _pausedByMenu = false;
    resumeEngine();
    _upgradeMenuOpenedFromMain = true;
    _runPhase = RunPhase.upgrading;
    overlays.add('upgrade_menu');
    _notifyHud();
    _persistRunSnapshot(force: true);
  }

  void closeUpgradeMenuToMainMenu() {
    if (_runPhase != RunPhase.upgrading) {
      return;
    }
    if (!_upgradeMenuOpenedFromMain) {
      return;
    }

    overlays.remove('upgrade_menu');
    overlays.add('start_flow');
    _upgradeMenuOpenedFromMain = false;
    _runPhase = RunPhase.startMenu;
    _notifyHud();
    _persistRunSnapshot(force: true);
  }

  void startRunFromUpgradeHub() {
    if (!_progressLoaded) {
      return;
    }

    _upgradeMenuOpenedFromMain = false;
    _startNewDungeonRun();
  }

  void pauseFromHud() {
    if (_runPhase != RunPhase.playing || _pausedByMenu) {
      return;
    }
    _pausedByMenu = true;
    pauseEngine();
    _isCharging = false;
    _spinDetector.reset();
    _spinner?.clearChargePreview();
    _notifyHud();
    _persistRunSnapshot(force: true);
  }

  void resumeFromHud() {
    if (!_pausedByMenu) {
      return;
    }
    _pausedByMenu = false;
    resumeEngine();
    _notifyHud();
    _persistRunSnapshot(force: true);
  }

  void toggleHudDebugOverlay() {
    _hudDebugOverlayVisible = !_hudDebugOverlayVisible;
    _notifyHud();
  }

  void returnToMainMenuFromHud() {
    _pausedByMenu = false;
    _hudDebugOverlayVisible = false;
    resumeEngine();
    _gameMode = SpinnerGameMode.dungeon;
    _clearActiveComponents();
    _upgradeMenuOpenedFromMain = false;
    overlays.remove('upgrade_menu');
    overlays.add('start_flow');
    _runPhase = RunPhase.startMenu;
    _runEndReason = null;
    _lastDamageAmount = 0;
    _damageAlertSeconds = 0;
    _levelComplete = false;
    _levelClearAcknowledged = false;
    _dungeonComplete = false;
    _currentRoomPos = null;
    _isCharging = false;
    _spinDetector.reset();
    _targetCameraZoom = _baseCameraZoom;
    _levels.clear();
    _notifyHud();
    _persistRunSnapshot(force: true);
  }

  void tryAdvanceAfterLevelClear() {
    if (!_progressLoaded || _runPhase != RunPhase.playing || _pausedByMenu) {
      return;
    }
    if (!_levelComplete) {
      return;
    }
    _spinner?.stop();
    _advanceToNextLevel();
  }

  /// Dismisses the full "floor cleared" banner so the player can keep
  /// playing on the cleared floor; a compact descend button stays available
  /// via [tryAdvanceAfterLevelClear] until they choose to move on.
  void acknowledgeLevelClear() {
    if (!_levelComplete || _levelClearAcknowledged) {
      return;
    }
    _levelClearAcknowledged = true;
    _notifyHud();
  }

  List<SpinnerPartDefinition> partsForSlot(SpinnerPartSlot slot) {
    return SpinnerPartCatalog.partsForSlot(slot);
  }

  SpinnerPartDefinition partById(String id) {
    return SpinnerPartCatalog.partById(id);
  }

  bool isPartUnlocked(String id) {
    return _unlockedPartIds.contains(id);
  }

  void selectSpinnerPart(SpinnerPartSlot slot, String partId) {
    if (_runPhase != RunPhase.loadout || !_unlockedPartIds.contains(partId)) {
      return;
    }

    _selectedBuild = _selectedBuild.copyWithSlot(slot, partId);
    _selectedBuild = SpinnerPartCatalog.sanitizeBuild(
      build: _selectedBuild,
      unlockedIds: _unlockedPartIds,
    );
    _selectedBuildStats = SpinnerPartCatalog.computeStats(_selectedBuild);
    _progress = _progress.copyWith(selectedBuild: _selectedBuild);
    _persistProgress();
    _notifyHud();
  }

  void openLoadoutBuilder() {
    if (!_progressLoaded) {
      return;
    }

    overlays.remove('upgrade_menu');
    overlays.add('start_flow');
    _upgradeMenuOpenedFromMain = false;
    _runPhase = RunPhase.loadout;
    _notifyHud();
    _persistRunSnapshot(force: true);
  }

  /// Jump straight from the main menu into a campaign run using the
  /// currently-selected build. The build-spinner workbench stays available as
  /// a separate flow; this entry point is the "Play" fast-path.
  void startCampaignRun() {
    if (!_progressLoaded || !_ready) {
      return;
    }
    _startNewDungeonRun();
  }

  void returnToStartMenu() {
    if (!_progressLoaded) {
      return;
    }

    overlays.add('start_flow');
    _runPhase = RunPhase.startMenu;
    _notifyHud();
    _persistRunSnapshot(force: true);
  }

  void setConfiguredRunSeed(int? seed) {
    if (seed == null) {
      _configuredRunSeed = null;
    } else {
      _configuredRunSeed = _normalizedSeed(seed);
    }
    _notifyHud();
    _persistRunSnapshot(force: true);
  }

  void clearConfiguredRunSeed() {
    setConfiguredRunSeed(null);
  }

  int randomizeConfiguredRunSeed() {
    final seed = _random.nextInt(1 << 30);
    setConfiguredRunSeed(seed);
    return _configuredRunSeed ?? seed;
  }

  void startRunFromBuilder() {
    if (!canStartRunFromBuilder) {
      return;
    }
    _startNewDungeonRun();
  }

  /// Begin this week's challenge run with the deterministic [weeklySeed].
  void startWeeklyRun() {
    if (!_progressLoaded || !_ready) {
      return;
    }
    _startNewDungeonRun(isWeekly: true);
  }

  String powerupLabel(PowerupType powerup) {
    switch (powerup) {
      case PowerupType.tether:
        return 'Tether';
      case PowerupType.fireball:
        return 'Fireball';
      case PowerupType.needles:
        return 'Needles';
      case PowerupType.spinRefill:
        return 'Spin orb';
    }
  }

  String enemyTypeLabel(EnemyType type) {
    switch (type) {
      case EnemyType.walker:
        return 'Walker';
      case EnemyType.turret:
        return 'Turret';
      case EnemyType.hedgehog:
        return 'Hedgehog';
      case EnemyType.paddle:
        return 'Paddle';
      case EnemyType.boss:
        return 'Boss';
      case EnemyType.pulser:
        return 'Pulser';
    }
  }

  String enemyArchetypeLabel(EnemyArchetype archetype) {
    switch (archetype) {
      case EnemyArchetype.standard:
        return 'Standard';
      case EnemyArchetype.absorber:
        return 'Absorber';
      case EnemyArchetype.blower:
        return 'Blower';
      case EnemyArchetype.sucker:
        return 'Sucker';
      case EnemyArchetype.blocker:
        return 'Blocker';
      case EnemyArchetype.spiked:
        return 'Spiked';
      case EnemyArchetype.stalker:
        return 'Stalker';
    }
  }

  int abilityChargesFor(PowerupType type) {
    return _abilityCharges[type] ?? 0;
  }

  void selectPowerupForNextSpin(PowerupType? type) {
    if (_runPhase != RunPhase.playing || spinnerMoving || _isCharging) {
      return;
    }

    if (type == PowerupType.spinRefill) {
      return;
    }

    if (type == null || abilityChargesFor(type) <= 0) {
      _selectedPowerup = null;
      _queuedTetherTarget = null;
      _notifyHud();
      return;
    }

    if (_selectedPowerup == type) {
      _selectedPowerup = null;
      _queuedTetherTarget = null;
      _notifyHud();
      return;
    }

    _selectedPowerup = type;
    if (type != PowerupType.tether) {
      _queuedTetherTarget = null;
    }
    _notifyHud();
  }

  String abilityLabel(DungeonAbility ability) {
    switch (ability) {
      case DungeonAbility.tether:
        return 'Tether';
      case DungeonAbility.fireball:
        return 'Fireball';
      case DungeonAbility.needles:
        return 'Needles';
    }
  }

  int? abilityUnlockCost(DungeonAbility ability) {
    switch (ability) {
      case DungeonAbility.tether:
        return null;
      case DungeonAbility.fireball:
        return 120;
      case DungeonAbility.needles:
        return 180;
    }
  }

  bool isAbilityUnlocked(DungeonAbility ability) {
    return _progress.unlockedAbilities.contains(ability);
  }

  bool canUnlockAbility(DungeonAbility ability) {
    final cost = abilityUnlockCost(ability);
    if (cost == null || isAbilityUnlocked(ability)) {
      return false;
    }
    return _progress.bankedCoins >= cost;
  }

  void unlockAbility(DungeonAbility ability) {
    final cost = abilityUnlockCost(ability);
    if (cost == null || !canUnlockAbility(ability)) {
      return;
    }
    final abilities = <DungeonAbility>{..._progress.unlockedAbilities, ability};
    _progress = _progress.copyWith(
      bankedCoins: _progress.bankedCoins - cost,
      unlockedAbilities: abilities,
    );
    _syncUnlockedAndBuildFromProgress();
    _persistProgress();
    _notifyHud();
  }

  int upgradeTier(UpgradeType type) {
    return UpgradeSystem.tierFor(_progress.tiers, type);
  }

  int? upgradeCost(UpgradeType type) {
    return UpgradeSystem.costForNextTier(_progress, type);
  }

  bool canPurchaseUpgrade(UpgradeType type) {
    return UpgradeSystem.canPurchase(_progress, type);
  }

  String upgradeCurrentEffect(UpgradeType type) {
    return UpgradeSystem.effectSummary(type, upgradeTier(type));
  }

  String upgradeNextEffect(UpgradeType type) {
    return UpgradeSystem.effectSummary(type, upgradeTier(type) + 1);
  }

  void purchaseUpgrade(UpgradeType type) {
    if (_runPhase != RunPhase.upgrading) {
      return;
    }

    if (!canPurchaseUpgrade(type)) {
      return;
    }

    _progress = UpgradeSystem.purchase(_progress, type);
    _syncUnlockedAndBuildFromProgress();
    _persistProgress();
    _notifyHud();
  }

  void _endRun(RunEndReason reason) {
    if (_runPhase != RunPhase.playing) {
      return;
    }

    _runPhase = RunPhase.runOver;
    _runEndReason = reason;
    _isCharging = false;
    _spinDetector.reset();
    _spinner?.clearChargePreview();
    _isCameraDragActive = false;
    _isCameraGestureActive = false;
    _clearPitHoverState();
    _pendingDebugSpawnPlacement = null;
    _queuedDebugSpawnPlacements.clear();

    _spinner?.stop();
    _detachCameraFollow();

    _dungeonComplete = reason == RunEndReason.victory;

    _newDeepestThisRun =
        _runDeepestLevelAtStart != null &&
        levelNumber > _runDeepestLevelAtStart!;

    final nextLeaderboard =
        (_runStats.runScore > 0 || _runStats.enemiesKilled > 0)
        ? LeaderboardEntry.mergeTop(
            _progress.leaderboard,
            LeaderboardEntry(
              score: _runStats.runScore,
              deepestLevel: levelNumber,
              enemiesKilled: _runStats.enemiesKilled,
              recordedAtMs: DateTime.now().millisecondsSinceEpoch,
              seed: _activeRunSeed,
              maxSpinChain: _runStats.maxSpinChain,
              build: _selectedBuild,
              weeklyKey: _runIsWeekly ? weeklyKey : null,
            ),
          )
        : _progress.leaderboard;

    _progress = _progress.copyWith(
      bestScore: max(_progress.bestScore, _runStats.runScore),
      totalRuns: _progress.totalRuns + 1,
      deepestLevelReached: max(_progress.deepestLevelReached, levelNumber),
      bossClears:
          _progress.bossClears +
          ((reason == RunEndReason.victory &&
                  _currentLevelIndex >= _levels.length - 1)
              ? 1
              : 0),
      leaderboard: nextLeaderboard,
    );
    // Onboarding ends with the first run regardless of outcome, so a player who
    // bails out doesn't get re-prompted next time.
    if (!_progress.tutorialSeen) {
      _progress = _progress.copyWith(tutorialSeen: true);
    }
    _syncUnlockedAndBuildFromProgress(announceNewUnlocks: true);
    _persistProgress();
    _notifyHud();
    _persistRunSnapshot(force: true);
  }

  _LevelPlan _generateLevel({required int levelNumber}) {
    final roomScale = _roomScaleForLevelNumber(levelNumber);
    final seed = _seedForLevel(levelNumber);
    final generatedLevel = _dungeonLevelGenerator.generateCampaignLevel(
      levelNumber: levelNumber,
      seed: seed,
    );
    final generatedById = <String, DungeonRoom>{
      for (final room in generatedLevel.rooms) room.id: room,
    };
    final generatedStart = generatedById[generatedLevel.startRoomId];
    final start = generatedStart != null
        ? _GridPos(generatedStart.x, generatedStart.y)
        : _GridPos(generatedLevel.width ~/ 2, generatedLevel.height ~/ 2);

    final rooms = <_GridPos, _RoomPlan>{};
    for (final generatedRoom in generatedLevel.rooms) {
      final pos = _GridPos(generatedRoom.x, generatedRoom.y);
      final roomPlan = _RoomPlan(
        position: pos,
        tileW: generatedRoom.width,
        tileH: generatedRoom.height,
      );
      roomPlan.type = _roomTypeFromDungeon(generatedRoom.type);
      for (final monster
          in generatedRoom.monsters ?? const <DungeonMonster>[]) {
        _applyDungeonMonsterToRoom(room: roomPlan, monster: monster);
      }
      for (final item in generatedRoom.items ?? const <DungeonItem>[]) {
        _applyDungeonItemToRoom(
          room: roomPlan,
          item: item,
          levelNumber: levelNumber,
        );
      }
      if (generatedRoom.type == DungeonRoomType.boss) {
        roomPlan.bossCount = max(1, roomPlan.bossCount);
      }
      roomPlan.roomTemplateId = generatedRoom.roomTemplateId;
      roomPlan.templateRotationQuarterTurns =
          generatedRoom.templateRotationQuarterTurns;
      roomPlan.templateFlipH = generatedRoom.templateFlipH;
      roomPlan.templateFlipV = generatedRoom.templateFlipV;
      rooms[pos] = roomPlan;
    }

    final startRoom = rooms.putIfAbsent(
      start,
      () => _RoomPlan(position: start),
    );
    startRoom.type = RoomType.start;
    startRoom.cleared = true;
    startRoom.visited = true;

    final corridorPlans = <_CorridorPlan>[];
    for (final corridor in generatedLevel.corridors) {
      corridorPlans.add(
        _CorridorPlan(
          ax: corridor.ax,
          ay: corridor.ay,
          bx: corridor.bx,
          by: corridor.by,
          horizontalFirst: corridor.horizontalFirst,
          width: corridor.width,
        ),
      );

      final fromGen = generatedById[corridor.fromRoomId];
      final toGen = generatedById[corridor.toRoomId];
      if (fromGen == null || toGen == null) {
        continue;
      }
      final fromPos = _GridPos(fromGen.x, fromGen.y);
      final toPos = _GridPos(toGen.x, toGen.y);
      final fromRoom = rooms[fromPos];
      final toRoom = rooms[toPos];
      if (fromRoom == null || toRoom == null) {
        continue;
      }

      fromRoom.neighbors.add(toPos);
      toRoom.neighbors.add(fromPos);

      final direction = _cardinalBetween(fromGen, toGen);
      fromRoom.exits[direction] = toPos;
      toRoom.exits[direction.opposite] = fromPos;
    }

    final distance = _distanceFromStart(start: start, rooms: rooms);
    final nonStartRooms = rooms.values
        .where((room) => room.position != start)
        .toList();
    if (levelNumber == 1) {
      for (final room in nonStartRooms) {
        room.type = RoomType.combat;
        room.turretCount = 0;
        room.walkerCount = 0;
        room.hedgehogCount = 0;
        room.bossCount = 0;
        room.paddleCount = 0;
        room.pulserCount = 0;
        room.hasCenterBumper = false;
        room.trapCount = 0;
        room.pitCount = 0;
        room.chestSpins = 0;
        room.chestCoins = 0;
        room.dangerTier = 1;
        room.interiorWalls.clear();
      }
      if (nonStartRooms.isNotEmpty) {
        nonStartRooms.sort(
          (a, b) => (distance[a.position] ?? 1 << 30).compareTo(
            distance[b.position] ?? 1 << 30,
          ),
        );
        nonStartRooms.first.walkerCount = 1;
      }
      return _LevelPlan(
        width: generatedLevel.width,
        height: generatedLevel.height,
        start: start,
        rooms: rooms,
        roomScale: roomScale,
        tileSize: _bspTileSize,
        corridors: corridorPlans,
      );
    }
    if ((startRoom.chestCoins > 0 || startRoom.chestSpins > 0) &&
        nonStartRooms.isNotEmpty) {
      var receiver = nonStartRooms.first;
      var bestDistance = distance[receiver.position] ?? 1 << 30;
      for (final candidate in nonStartRooms.skip(1)) {
        final candidateDistance = distance[candidate.position] ?? 1 << 30;
        if (candidateDistance < bestDistance) {
          receiver = candidate;
          bestDistance = candidateDistance;
        }
      }
      receiver.chestCoins += startRoom.chestCoins;
      receiver.chestSpins += max(1, startRoom.chestSpins);
      startRoom.chestCoins = 0;
      startRoom.chestSpins = 0;
    }
    var hasAnyCenterBumper = false;
    var hasAnyEnemy = false;
    for (final room in rooms.values) {
      if (room.position == start) {
        room.type = RoomType.start;
        room.cleared = true;
        room.visited = true;
        continue;
      }

      final roomDistance = distance[room.position] ?? 1;
      final roomDifficulty = roomDistance + levelNumber;
      room.dangerTier = max(room.dangerTier, roomDifficulty);
      room.precisionFocus = _shouldMarkPrecisionRoom(
        levelNumber: levelNumber,
        room: room,
        distanceFromStart: roomDistance,
      );

      // Interior room walls are disabled until collision + art are reliable
      // (invisible-hit issues). Perimeter / corridor walls unchanged.
      room.interiorWalls.clear();

      if (room.pitCount <= 0) {
        room.pitCount = _samplePitCount(
          levelNumber: levelNumber,
          roomType: room.type,
          distanceFromStart: roomDistance,
        );
      } else {
        room.pitCount = room.pitCount.clamp(0, 5);
      }

      if (room.type == RoomType.treasure) {
        room.chestSpins = max(room.chestSpins, 1 + ((levelNumber + 1) ~/ 3));
        room.chestCoins = max(
          room.chestCoins,
          12 + levelNumber * 4 + _random.nextInt(10),
        );
        room.pitCount = max(0, room.pitCount - 1);
      }

      if (room.type == RoomType.trap) {
        room.trapCount = max(room.trapCount, 1 + ((levelNumber - 1) ~/ 4));
      } else if (levelNumber >= 7 && _random.nextDouble() < 0.25) {
        room.trapCount = max(room.trapCount, 1);
      }

      if (room.precisionFocus) {
        _tuneRoomForPrecision(room: room);
      }

      if (levelNumber >= 2 && !room.hasCenterBumper) {
        final centerBumperChance = room.type == RoomType.trap
            ? 0.78
            : (0.22 + levelNumber * 0.035 + roomDistance * 0.025)
                  .clamp(0.22, 0.7)
                  .toDouble();
        room.hasCenterBumper = _random.nextDouble() < centerBumperChance;
      }
      hasAnyCenterBumper = hasAnyCenterBumper || room.hasCenterBumper;

      if (levelNumber >= 4 && !room.hasCenterBumper && room.paddleCount <= 0) {
        final paddleChance = (0.06 + levelNumber * 0.018 + roomDistance * 0.01)
            .clamp(0.06, 0.24)
            .toDouble();
        if (_random.nextDouble() < paddleChance) {
          room.paddleCount = 1;
          if (room.type == RoomType.trap &&
              levelNumber >= 6 &&
              _random.nextDouble() < 0.4) {
            room.paddleCount += 1;
          }
        }
      }

      if (room.chestCoins > 0 && room.chestSpins <= 0) {
        room.chestSpins = 1;
      }

      if (room.bossCount > 0) {
        room.walkerCount = 0;
        room.turretCount = 0;
        room.hedgehogCount = 0;
        room.paddleCount = 0;
        room.pulserCount = 0;
        room.hasCenterBumper = false;
        room.precisionFocus = false;
        room.type = RoomType.combat;
        room.trapCount = max(0, room.trapCount - 1);
        room.pitCount = max(0, room.pitCount - 1);
        room.dangerTier = max(room.dangerTier, levelNumber + 4);
      }

      hasAnyEnemy = hasAnyEnemy || _roomHasEnemies(room);
    }

    if (levelNumber >= 2 && !hasAnyCenterBumper && nonStartRooms.isNotEmpty) {
      final chosen = nonStartRooms[_random.nextInt(nonStartRooms.length)];
      chosen.hasCenterBumper = true;
    }

    if (levelNumber >= 5 &&
        !nonStartRooms.any((room) => room.precisionFocus) &&
        nonStartRooms.isNotEmpty) {
      final candidates = nonStartRooms
          .where((room) => room.bossCount <= 0)
          .toList();
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) {
          final typeScoreA = a.type == RoomType.trap ? 1 : 0;
          final typeScoreB = b.type == RoomType.trap ? 1 : 0;
          if (typeScoreA != typeScoreB) {
            return typeScoreB.compareTo(typeScoreA);
          }
          final distanceA = distance[a.position] ?? 0;
          final distanceB = distance[b.position] ?? 0;
          return distanceB.compareTo(distanceA);
        });
        final chosen = candidates.first;
        chosen.precisionFocus = true;
        chosen.interiorWalls.clear();
        _tuneRoomForPrecision(room: chosen);
      }
    }

    if (!hasAnyEnemy && levelNumber < 10 && nonStartRooms.isNotEmpty) {
      final chosen = nonStartRooms[_random.nextInt(nonStartRooms.length)];
      chosen.walkerCount = max(chosen.walkerCount, 1);
      hasAnyEnemy = true;
    }

    if (levelNumber >= 10 &&
        nonStartRooms.isNotEmpty &&
        !nonStartRooms.any((room) => room.bossCount > 0)) {
      final bossRoom = nonStartRooms.first;
      bossRoom.walkerCount = 0;
      bossRoom.turretCount = 0;
      bossRoom.hedgehogCount = 0;
      bossRoom.paddleCount = 0;
      bossRoom.pulserCount = 0;
      bossRoom.bossCount = 1;
      bossRoom.hasCenterBumper = false;
      bossRoom.precisionFocus = false;
      bossRoom.type = RoomType.combat;
      bossRoom.trapCount = max(0, bossRoom.trapCount - 1);
      bossRoom.pitCount = max(0, bossRoom.pitCount - 1);
      bossRoom.dangerTier = max(bossRoom.dangerTier, levelNumber + 4);
    }

    _normalizeTrapsAndPitsForFeatureFlag(rooms);

    return _LevelPlan(
      width: generatedLevel.width,
      height: generatedLevel.height,
      start: start,
      rooms: rooms,
      roomScale: roomScale,
      tileSize: _bspTileSize,
      corridors: corridorPlans,
    );
  }

  Map<_GridPos, int> _distanceFromStart({
    required _GridPos start,
    required Map<_GridPos, _RoomPlan> rooms,
  }) {
    final distance = <_GridPos, int>{start: 0};
    final queue = <_GridPos>[start];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final room = rooms[current];
      if (room == null) {
        continue;
      }

      final currentDistance = distance[current] ?? 0;
      for (final next in room.neighbors) {
        if (!distance.containsKey(next)) {
          distance[next] = currentDistance + 1;
          queue.add(next);
        }
      }
    }

    return distance;
  }

  void _normalizeTrapsAndPitsForFeatureFlag(Map<_GridPos, _RoomPlan> rooms) {
    if (_spawnTrapsAndPits) {
      return;
    }
    for (final room in rooms.values) {
      room.trapCount = 0;
      room.pitCount = 0;
      if (room.type == RoomType.trap) {
        room.type = RoomType.combat;
      }
    }
  }

  RoomType _roomTypeFromDungeon(DungeonRoomType roomType) {
    switch (roomType) {
      case DungeonRoomType.start:
        return RoomType.start;
      case DungeonRoomType.combat:
        return RoomType.combat;
      case DungeonRoomType.trap:
        return RoomType.trap;
      case DungeonRoomType.treasure:
        return RoomType.treasure;
      case DungeonRoomType.boss:
        return RoomType.combat;
    }
  }

  /// Dominant-axis cardinal direction from room [a] to room [b].
  RoomDirection _cardinalBetween(DungeonRoom a, DungeonRoom b) {
    final dx = b.centerX - a.centerX;
    final dy = b.centerY - a.centerY;
    if (dx.abs() >= dy.abs()) {
      return dx >= 0 ? RoomDirection.right : RoomDirection.left;
    }
    return dy >= 0 ? RoomDirection.down : RoomDirection.up;
  }

  void _applyDungeonMonsterToRoom({
    required _RoomPlan room,
    required DungeonMonster monster,
  }) {
    final type = monster.type.trim().toLowerCase();
    switch (type) {
      case 'boss':
        room.bossCount += 1;
        return;
      case 'turret':
        room.turretCount += 1;
        return;
      case 'hedgehog':
        room.hedgehogCount += 1;
        return;
      case 'paddle':
        room.paddleCount += 1;
        return;
      case 'pulser':
        room.pulserCount += 1;
        return;
      default:
        room.walkerCount += 1;
        return;
    }
  }

  void _applyDungeonItemToRoom({
    required _RoomPlan room,
    required DungeonItem item,
    required int levelNumber,
  }) {
    final type = item.type.trim().toLowerCase();
    final amount = max(1, item.amount);
    switch (type) {
      case 'spin_charge':
        room.chestSpins += amount;
        return;
      case 'coins':
        room.chestCoins += amount;
        return;
      case 'boss_relic':
      case 'relic_shard':
        room.chestCoins += 20 * amount;
        return;
      case 'repair_kit':
        room.chestCoins += (8 + levelNumber) * amount;
        return;
      default:
        room.chestCoins += (4 + levelNumber) * amount;
        return;
    }
  }

  bool _roomHasEnemies(_RoomPlan room) {
    return room.walkerCount > 0 ||
        room.turretCount > 0 ||
        room.hedgehogCount > 0 ||
        room.bossCount > 0 ||
        room.paddleCount > 0 ||
        room.pulserCount > 0;
  }

  int _normalizedSeed(int seed) {
    final normalized = seed.abs() % 2147483647;
    return normalized == 0 ? 1 : normalized;
  }

  int _seedForLevel(int levelNumber) {
    final baseSeed = _activeRunSeed ?? 1;
    return _normalizedSeed(baseSeed);
  }

  int _samplePitCount({
    required int levelNumber,
    required RoomType roomType,
    required int distanceFromStart,
  }) {
    if (levelNumber <= 2) {
      return 0;
    }

    var pits = (levelNumber - 1) ~/ 3;
    if (distanceFromStart > 2) {
      pits += 1;
    }

    if (roomType == RoomType.trap) {
      pits += 1;
    } else if (roomType == RoomType.treasure) {
      pits = max(0, pits - 1);
    }

    final variance = min(2, levelNumber ~/ 6);
    if (variance > 0) {
      pits += _random.nextInt(variance + 1);
    }

    return pits.clamp(0, 5).toInt();
  }

  bool _shouldMarkPrecisionRoom({
    required int levelNumber,
    required _RoomPlan room,
    required int distanceFromStart,
  }) {
    if (levelNumber <= 3 || room.type == RoomType.start || room.bossCount > 0) {
      return false;
    }

    var chance = room.type == RoomType.trap ? 0.36 : 0.16;
    if (room.type == RoomType.treasure) {
      chance -= 0.06;
    }
    if (distanceFromStart >= 3) {
      chance += 0.1;
    }
    if (distanceFromStart >= 5) {
      chance += 0.08;
    }
    chance += ((levelNumber - 3) * 0.01).clamp(0, 0.08).toDouble();
    return _random.nextDouble() < chance.clamp(0.08, 0.62).toDouble();
  }

  void _tuneRoomForPrecision({required _RoomPlan room}) {
    if (room.type == RoomType.start || room.bossCount > 0) {
      return;
    }

    room.precisionFocus = true;

    if (room.pitCount > 1) {
      room.pitCount = max(1, room.pitCount - 1);
    }
    if (room.trapCount > 1 && room.pitCount > 0) {
      room.pitCount = max(0, room.pitCount - 1);
    }

    final mobileThreat =
        room.walkerCount +
        room.hedgehogCount +
        room.paddleCount +
        room.pulserCount;
    if (mobileThreat > 2) {
      if (room.walkerCount > 0) {
        room.walkerCount -= 1;
      } else if (room.hedgehogCount > 0) {
        room.hedgehogCount -= 1;
      } else if (room.pulserCount > 0) {
        room.pulserCount -= 1;
      } else if (room.paddleCount > 0) {
        room.paddleCount -= 1;
      }
    }
  }

  double _enemyDangerScaleForTier(int tier) {
    final depthAdjusted = tier + _currentLevelIndex;
    return (0.72 + depthAdjusted * 0.11).clamp(0.72, 3.0).toDouble();
  }

  EnemyArchetype _archetypeForSpawn({
    required EnemyType type,
    required _RoomPlan room,
  }) {
    switch (type) {
      case EnemyType.walker:
        if (room.type == RoomType.trap &&
            levelNumber >= 4 &&
            _random.nextDouble() < 0.4) {
          return EnemyArchetype.spiked;
        }
        if (levelNumber >= 3 && _random.nextDouble() < 0.24) {
          return EnemyArchetype.stalker;
        }
        final depth = _currentLevelIndex + room.dangerTier * 0.15;
        final standardBias = (1.15 - depth * 0.12).clamp(0.28, 0.82).toDouble();
        return _random.nextDouble() < standardBias
            ? EnemyArchetype.standard
            : EnemyArchetype.absorber;
      case EnemyType.turret:
        return _random.nextBool()
            ? EnemyArchetype.blower
            : EnemyArchetype.sucker;
      case EnemyType.paddle:
        return EnemyArchetype.blocker;
      case EnemyType.hedgehog:
        return EnemyArchetype.spiked;
      case EnemyType.boss:
        final roll = _random.nextDouble();
        final dangerBias = (room.dangerTier / 20).clamp(0.0, 0.2);
        if (roll < 0.34 + dangerBias) {
          return EnemyArchetype.blocker;
        }
        return roll < 0.66 ? EnemyArchetype.sucker : EnemyArchetype.blower;
      case EnemyType.pulser:
        return EnemyArchetype.standard;
    }
  }

  _RoomPlan? _debugSpawnRoom() {
    final currentRoom = _currentRoom;
    if (currentRoom != null &&
        currentRoom.type != RoomType.start &&
        currentRoom.worldRect != null) {
      return currentRoom;
    }

    final level = _currentLevel;
    if (level == null) {
      return null;
    }

    for (final room in level.rooms.values) {
      if (room.type != RoomType.start && room.worldRect != null) {
        return room;
      }
    }

    final startRoom = level.rooms[level.start];
    if (startRoom == null || startRoom.worldRect == null) {
      return null;
    }
    return startRoom;
  }

  double _enemyRadiusForType(EnemyType type) {
    return switch (type) {
      EnemyType.turret => 18,
      EnemyType.walker => 16,
      EnemyType.boss => 24,
      EnemyType.paddle => 18,
      EnemyType.hedgehog => 24,
      EnemyType.pulser => 19,
    };
  }

  EnemyComponent _createDebugEnemy({
    required EnemyType type,
    required EnemyArchetype archetype,
    required Vector2 position,
  }) {
    final direction = Vector2(
      _random.nextDouble() - 0.5,
      _random.nextDouble() - 0.5,
    );
    final levelBoost = (1 + (_currentLevelIndex * 0.1)).clamp(1.0, 2.4);

    switch (type) {
      case EnemyType.walker:
        return EnemyComponent.walker(
          position: position,
          direction: direction,
          archetype: archetype,
          hpMultiplier: levelBoost,
          speedMultiplier: (0.95 + _currentLevelIndex * 0.02)
              .clamp(0.9, 1.35)
              .toDouble(),
          contactDamageMultiplier: levelBoost.clamp(1.0, 1.8).toDouble(),
        );
      case EnemyType.turret:
        return EnemyComponent.turret(
          position: position,
          archetype: archetype,
          hpMultiplier: levelBoost,
          contactDamageMultiplier: levelBoost.clamp(1.0, 1.8).toDouble(),
          fireRateMultiplier: (1 + (_currentLevelIndex * 0.05))
              .clamp(1.0, 1.6)
              .toDouble(),
          projectileDamageMultiplier: (1 + (_currentLevelIndex * 0.06))
              .clamp(1.0, 1.8)
              .toDouble(),
          projectileSpeedMultiplier: (1 + (_currentLevelIndex * 0.04))
              .clamp(1.0, 1.6)
              .toDouble(),
        );
      case EnemyType.hedgehog:
        return EnemyComponent.hedgehog(
          position: position,
          direction: direction,
          archetype: archetype,
          hpMultiplier: levelBoost,
          speedMultiplier: (0.92 + _currentLevelIndex * 0.02)
              .clamp(0.88, 1.3)
              .toDouble(),
          contactDamageMultiplier: levelBoost.clamp(1.0, 2.0).toDouble(),
        );
      case EnemyType.paddle:
        return EnemyComponent.paddle(
          position: position,
          archetype: archetype,
          hpMultiplier: levelBoost,
          contactDamageMultiplier: levelBoost.clamp(1.0, 1.8).toDouble(),
        );
      case EnemyType.boss:
        return EnemyComponent.boss(
          position: position,
          archetype: archetype,
          hpMultiplier: (0.75 + (_currentLevelIndex * 0.08))
              .clamp(0.75, 1.8)
              .toDouble(),
          contactDamageMultiplier: (0.9 + (_currentLevelIndex * 0.05))
              .clamp(0.9, 1.6)
              .toDouble(),
        );
      case EnemyType.pulser:
        return EnemyComponent.pulser(
          position: position,
          direction: direction,
          archetype: archetype,
          hpMultiplier: levelBoost,
          speedMultiplier: (0.88 + _currentLevelIndex * 0.02)
              .clamp(0.85, 1.25)
              .toDouble(),
          contactDamageMultiplier: levelBoost.clamp(1.0, 1.75).toDouble(),
        );
    }
  }

  double _powerupSpawnChanceForLevel(int levelNumber) {
    return (0.45 + levelNumber * 0.04).clamp(0.45, 0.85).toDouble();
  }

  List<PowerupType> _availablePowerupTypes() {
    final types = <PowerupType>[PowerupType.tether];
    if (_progress.unlockedAbilities.contains(DungeonAbility.fireball)) {
      types.add(PowerupType.fireball);
    }
    if (_progress.unlockedAbilities.contains(DungeonAbility.needles)) {
      types.add(PowerupType.needles);
    }
    return types;
  }

  PowerupType _rollPowerupForLevel(int levelNumber) {
    final available = _availablePowerupTypes();
    if (available.length == 1) {
      return available.first;
    }
    final roll = _random.nextDouble();
    if (levelNumber <= 2) {
      if (available.contains(PowerupType.needles) && roll >= 0.65) {
        return PowerupType.needles;
      }
      return PowerupType.tether;
    }
    if (levelNumber <= 4) {
      if (roll < 0.45) {
        return PowerupType.tether;
      }
      if (roll < 0.78 && available.contains(PowerupType.needles)) {
        return PowerupType.needles;
      }
      if (available.contains(PowerupType.fireball)) {
        return PowerupType.fireball;
      }
      return available.last;
    }

    if (roll < 0.28 || !available.contains(PowerupType.fireball)) {
      return PowerupType.tether;
    }
    if (roll < 0.63 || !available.contains(PowerupType.needles)) {
      return PowerupType.fireball;
    }
    return PowerupType.needles;
  }

  void _spawnDungeonAbilityDrop(Vector2 position) {
    if (_runPhase != RunPhase.playing) {
      return;
    }
    final available = _availablePowerupTypes();
    if (available.isEmpty) {
      return;
    }
    final type = available[_random.nextInt(available.length)];
    final powerup = PowerupComponent(
      type: type,
      position: position,
      durationSeconds: 10 + _currentLevelIndex * 0.8,
    );
    _powerups.add(powerup);
    world.add(powerup);
  }

  int spawnDebugEnemies({
    required EnemyType type,
    EnemyArchetype archetype = EnemyArchetype.standard,
    int count = 1,
  }) {
    if (!canOpenDebugSpawner) {
      return 0;
    }

    final room = _debugSpawnRoom();
    if (room == null) {
      return 0;
    }

    final spawnCount = count.clamp(1, 25).toInt();
    var spawned = 0;
    for (var i = 0; i < spawnCount; i++) {
      final radius = _enemyRadiusForType(type);
      final position = _randomSpawnInRoom(
        room: room,
        radius: radius,
        avoidDoorLanes: true,
      );
      final enemy = _createDebugEnemy(
        type: type,
        archetype: archetype,
        position: position,
      );
      _enemies.add(enemy);
      _enemyRooms[enemy] = room.position;
      _enemyBounds[enemy] = room.enemyClampRect;
      world.add(enemy);
      spawned += 1;
    }

    _syncRoomAndLevelState();
    _notifyHud();
    return spawned;
  }

  bool armDebugSpawnAtLocation({
    required int levelNumber,
    required EnemyType type,
    required EnemyArchetype archetype,
    int count = 1,
  }) {
    if (!canOpenDebugSpawner || spinnerMoving || _isCharging) {
      return false;
    }

    final levelIndex = levelNumber - 1;
    if (levelIndex < 0 || levelIndex >= _levels.length) {
      return false;
    }

    _pendingDebugSpawnPlacement = _PendingDebugSpawnPlacement(
      levelIndex: levelIndex,
      type: type,
      archetype: archetype,
      count: count.clamp(1, 25).toInt(),
    );
    _notifyHud();
    return true;
  }

  void cancelDebugSpawnAtLocation() {
    if (_pendingDebugSpawnPlacement == null) {
      return;
    }
    _pendingDebugSpawnPlacement = null;
    _notifyHud();
  }

  int placeArmedDebugSpawnAt(Vector2 worldPoint) {
    final pending = _pendingDebugSpawnPlacement;
    if (pending == null ||
        !canOpenDebugSpawner ||
        spinnerMoving ||
        _isCharging) {
      return 0;
    }

    _pendingDebugSpawnPlacement = null;

    if (pending.levelIndex == _currentLevelIndex) {
      final level = _currentLevel;
      if (level == null) {
        return 0;
      }
      final spawned = _spawnDebugEnemiesInLevelAtPoint(
        level: level,
        point: worldPoint,
        type: pending.type,
        archetype: pending.archetype,
        count: pending.count,
      );
      _notifyHud();
      return spawned;
    }

    final normalizedX = _normalizeLevelCoordinate(
      value: worldPoint.x,
      min: _levelMin.x,
      max: _levelMax.x,
    );
    final normalizedY = _normalizeLevelCoordinate(
      value: worldPoint.y,
      min: _levelMin.y,
      max: _levelMax.y,
    );
    _queuedDebugSpawnPlacements.add(
      _QueuedDebugSpawnPlacement(
        levelIndex: pending.levelIndex,
        normalizedX: normalizedX,
        normalizedY: normalizedY,
        type: pending.type,
        archetype: pending.archetype,
        count: pending.count,
      ),
    );
    _notifyHud();
    return pending.count;
  }

  int _spawnDebugEnemiesInLevelAtPoint({
    required _LevelPlan level,
    required Vector2 point,
    required EnemyType type,
    required EnemyArchetype archetype,
    required int count,
  }) {
    final room = _roomForDebugSpawnPoint(level: level, point: point);
    if (room == null) {
      return 0;
    }

    final spawnCount = count.clamp(1, 25).toInt();
    var spawned = 0;
    for (var i = 0; i < spawnCount; i++) {
      final radius = _enemyRadiusForType(type);
      final position = _positionForDebugSpawn(
        room: room,
        anchor: point,
        radius: radius,
      );
      final enemy = _createDebugEnemy(
        type: type,
        archetype: archetype,
        position: position,
      );
      _enemies.add(enemy);
      _enemyRooms[enemy] = room.position;
      _enemyBounds[enemy] = room.enemyClampRect;
      world.add(enemy);
      spawned += 1;
    }

    _syncRoomAndLevelState();
    return spawned;
  }

  _RoomPlan? _roomForDebugSpawnPoint({
    required _LevelPlan level,
    required Vector2 point,
  }) {
    final offset = Offset(point.x, point.y);
    for (final room in level.rooms.values) {
      final rect = room.worldRect;
      if (rect == null || room.type == RoomType.start) {
        continue;
      }
      if (rect.inflate(8).contains(offset)) {
        return room;
      }
    }

    _RoomPlan? best;
    var bestDistance = double.infinity;
    for (final room in level.rooms.values) {
      final rect = room.worldRect;
      if (rect == null || room.type == RoomType.start) {
        continue;
      }
      final center = Vector2(rect.center.dx, rect.center.dy);
      final distance = center.distanceTo(point);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = room;
      }
    }

    return best;
  }

  Vector2 _positionForDebugSpawn({
    required _RoomPlan room,
    required Vector2 anchor,
    required double radius,
  }) {
    final bounds = room.enemyClampRect;
    final minX = bounds.left + radius;
    final maxX = bounds.right - radius;
    final minY = bounds.top + radius;
    final maxY = bounds.bottom - radius;
    if (minX >= maxX || minY >= maxY) {
      return _randomSpawnInRoom(
        room: room,
        radius: radius,
        avoidDoorLanes: true,
      );
    }

    for (var attempt = 0; attempt < 56; attempt++) {
      late final Vector2 candidate;
      if (attempt == 0) {
        candidate = Vector2(
          anchor.x.clamp(minX, maxX).toDouble(),
          anchor.y.clamp(minY, maxY).toDouble(),
        );
      } else {
        final spread = 24 + attempt * 7.5;
        final theta = _random.nextDouble() * pi * 2;
        candidate = Vector2(
          (anchor.x + cos(theta) * spread).clamp(minX, maxX).toDouble(),
          (anchor.y + sin(theta) * spread).clamp(minY, maxY).toDouble(),
        );
      }

      if (_blocksDoorLane(room, candidate, radius)) {
        continue;
      }
      if (_insideAnyWall(candidate, radius)) {
        continue;
      }
      if (_overlapsExisting(candidate, radius)) {
        continue;
      }
      return candidate;
    }

    return _randomSpawnInRoom(room: room, radius: radius, avoidDoorLanes: true);
  }

  double _normalizeLevelCoordinate({
    required double value,
    required double min,
    required double max,
  }) {
    final span = max - min;
    if (span <= 0.0001) {
      return 0.5;
    }
    return ((value - min) / span).clamp(0.0, 1.0).toDouble();
  }

  void _spawnQueuedDebugEnemiesForCurrentLevel() {
    if (_queuedDebugSpawnPlacements.isEmpty) {
      return;
    }
    final level = _currentLevel;
    if (level == null) {
      return;
    }

    final queued = _queuedDebugSpawnPlacements
        .where((entry) => entry.levelIndex == _currentLevelIndex)
        .toList();
    if (queued.isEmpty) {
      return;
    }

    for (final entry in queued) {
      final point = Vector2(
        _levelMin.x + ((_levelMax.x - _levelMin.x) * entry.normalizedX),
        _levelMin.y + ((_levelMax.y - _levelMin.y) * entry.normalizedY),
      );
      _spawnDebugEnemiesInLevelAtPoint(
        level: level,
        point: point,
        type: entry.type,
        archetype: entry.archetype,
        count: entry.count,
      );
    }

    _queuedDebugSpawnPlacements.removeWhere(
      (entry) => entry.levelIndex == _currentLevelIndex,
    );
    _notifyHud();
  }

  void _advanceToNextLevel() {
    if (_runPhase != RunPhase.playing) {
      return;
    }

    if (_currentLevelIndex >= _levels.length - 1) {
      return;
    }

    _currentLevelIndex += 1;
    _currentRoomPos = _currentLevel?.start;
    _levelComplete = false;
    _levelClearAcknowledged = false;
    _targetCameraZoom = _baseCameraZoom;

    _addScore(30 + _currentLevelIndex * 35, depthScaled: false);

    // Bumping deepestLevelReached as we descend lets depth-gated cosmetic parts
    // unlock the moment the player crosses the threshold (toast pops in HUD).
    final reachedDepth = levelNumber;
    if (reachedDepth > _progress.deepestLevelReached) {
      _progress = _progress.copyWith(deepestLevelReached: reachedDepth);
      _syncUnlockedAndBuildFromProgress(announceNewUnlocks: true);
      _persistProgress();
    }

    if (showTutorialDepthPrompt) {
      dismissTutorialDepthPrompt();
    }

    _buildAndSpawnCurrentLevel();
    _persistRunSnapshot(force: true);
  }

  /// Lays out the current [DungeonLevel] in world space, builds collision and
  /// template visuals, **then** spawns enemies and props — spawns always run
  /// after room geometry is final.
  void _buildAndSpawnCurrentLevel() {
    _clearActiveComponents();

    final level = _currentLevel;
    if (level == null) {
      return;
    }

    _applyThemeForLevel(levelNumber);
    _layoutLevel(level);
    _buildLevelGeometry(level);
    _spawnCenterBumpers(level);
    _spawnLevelContent(level);
    _spawnSpinner(level);
    _spawnAbilityVisuals();
    _spawnQueuedDebugEnemiesForCurrentLevel();

    _isCharging = false;
    _spinDetector.reset();
    _spinner?.clearChargePreview();
    _syncRoomAndLevelState(notify: false);

    _configureCamera();
    _notifyHud();
    _persistRunSnapshot();
  }

  void _spawnAbilityVisuals() {
    _tetherLink?.removeFromParent();
    _tetherLink = TetherLinkComponent();
    world.add(_tetherLink!);
  }

  void _clearActiveComponents() {
    _tetherLink?.removeFromParent();
    _tetherLink = null;
    _clearTetherLineVisual();
    _activePowerup = null;
    _activeTetherTarget = null;
    _selectedPowerup = null;
    _queuedTetherTarget = null;
    _fireballCooldown = 0;
    _needlesCooldown = 0;
    _clearPitHoverState();
    _pendingDebugSpawnPlacement = null;

    for (final floor in _floors) {
      floor.removeFromParent();
    }
    _floors.clear();
    for (final layer in _semanticTileLayers) {
      layer.removeFromParent();
    }
    _semanticTileLayers.clear();
    for (final h in _semanticHazards) {
      h.removeFromParent();
    }
    _semanticHazards.clear();
    _floorCellKeys.clear();

    for (final wall in _walls) {
      wall.removeFromParent();
    }
    _walls.clear();

    for (final bumper in _bumpers) {
      bumper.removeFromParent();
    }
    _bumpers.clear();

    for (final visual in _wallVisuals) {
      visual.removeFromParent();
    }
    _wallVisuals.clear();

    for (final trap in _traps) {
      trap.removeFromParent();
    }
    _traps.clear();

    for (final pit in _pits) {
      pit.removeFromParent();
    }
    _pits.clear();

    for (final coin in _coins) {
      coin.removeFromParent();
    }
    _coins.clear();

    for (final powerup in _powerups) {
      powerup.removeFromParent();
    }
    _powerups.clear();

    for (final shot in _spinnerShots) {
      shot.removeFromParent();
    }
    _spinnerShots.clear();

    for (final projectile in _enemyProjectiles) {
      projectile.removeFromParent();
    }
    _enemyProjectiles.clear();

    for (final chest in _chests) {
      chest.removeFromParent();
    }
    _chests.clear();

    for (final enemy in _enemies) {
      enemy.removeFromParent();
    }
    _enemies.clear();

    _enemyRooms.clear();
    _enemyBounds.clear();
    _chestRooms.clear();

    for (final decoration in _decorations) {
      decoration.removeFromParent();
    }
    _decorations.clear();

    _spinner?.removeFromParent();
    _spinner = null;
  }

  void _layoutLevel(_LevelPlan level) {
    final ts = level.tileSize;
    for (final room in level.rooms.values) {
      room.worldRect = Rect.fromLTWH(
        mapMargin + room.tileX * ts,
        mapMargin + room.tileY * ts,
        room.tileW * ts,
        room.tileH * ts,
      );
    }
    _levelMin = Vector2(mapMargin, mapMargin);
    _levelMax = Vector2(
      mapMargin + level.width * ts,
      mapMargin + level.height * ts,
    );
  }

  void _buildLevelGeometry(_LevelPlan level) {
    final ts = level.tileSize;
    final stride = level.width + 2;
    int key(int tx, int ty) => tx + ty * stride;

    // Tile-occupancy mask of all walkable cells (rooms + corridors); the
    // perimeter walls are the outline of this mask.
    final floorTiles = <int>{};

    void markBand(int txLo, int tyLo, int txHi, int tyHi) {
      final x0 = txLo.clamp(0, level.width - 1);
      final y0 = tyLo.clamp(0, level.height - 1);
      final x1 = txHi.clamp(0, level.width - 1);
      final y1 = tyHi.clamp(0, level.height - 1);
      for (var ty = y0; ty <= y1; ty++) {
        for (var tx = x0; tx <= x1; tx++) {
          floorTiles.add(key(tx, ty));
        }
      }
      _addFloorRect(
        Rect.fromLTWH(
          mapMargin + x0 * ts,
          mapMargin + y0 * ts,
          (x1 - x0 + 1) * ts,
          (y1 - y0 + 1) * ts,
        ),
      );
    }

    for (final room in level.rooms.values) {
      _addFloorRect(room.worldRect!);
      markBand(
        room.tileX,
        room.tileY,
        room.tileX + room.tileW - 1,
        room.tileY + room.tileH - 1,
      );
    }

    for (final corridor in level.corridors) {
      final half = corridor.width ~/ 2;
      void segment(int x0, int y0, int x1, int y1) {
        if (y0 == y1) {
          markBand(min(x0, x1), y0 - half, max(x0, x1), y0 + half);
        } else {
          markBand(x0 - half, min(y0, y1), x0 + half, max(y0, y1));
        }
      }

      segment(corridor.ax, corridor.ay, corridor.elbowX, corridor.elbowY);
      segment(corridor.elbowX, corridor.elbowY, corridor.bx, corridor.by);
    }

    _addFloorMaskWalls(floorTiles: floorTiles, stride: stride, tileSize: ts);

    for (final room in level.rooms.values) {
      _applySemanticRoomTemplateIfPresent(room);
    }

    _rebuildFloorTilesFromWang();
    if (_floors.isNotEmpty) {
      world.addAll(_floors);
    }
    if (_walls.isNotEmpty) {
      world.addAll(_walls);
    }
    if (_wallVisuals.isNotEmpty) {
      world.addAll(_wallVisuals);
    }
    if (_decorations.isNotEmpty) {
      world.addAll(_decorations);
    }
  }

  /// Emits perimeter walls around the [floorTiles] mask: any floor tile with a
  /// non-floor neighbour gets a wall on that edge, with an inward-facing
  /// normal. Collinear edges are merged into runs to keep component counts low.
  void _addFloorMaskWalls({
    required Set<int> floorTiles,
    required int stride,
    required double tileSize,
  }) {
    bool isFloor(int tx, int ty) => floorTiles.contains(tx + ty * stride);

    // Vertical walls grouped by edge column; horizontal by edge row.
    final eastByCol = <int, List<int>>{};
    final westByCol = <int, List<int>>{};
    final northByRow = <int, List<int>>{};
    final southByRow = <int, List<int>>{};

    for (final k in floorTiles) {
      final tx = k % stride;
      final ty = k ~/ stride;
      if (!isFloor(tx + 1, ty)) eastByCol.putIfAbsent(tx, () => []).add(ty);
      if (!isFloor(tx - 1, ty)) westByCol.putIfAbsent(tx, () => []).add(ty);
      if (!isFloor(tx, ty - 1)) northByRow.putIfAbsent(ty, () => []).add(tx);
      if (!isFloor(tx, ty + 1)) southByRow.putIfAbsent(ty, () => []).add(tx);
    }

    void emitVertical(
      Map<int, List<int>> byCol,
      double Function(int) edgeX,
      WallSide side,
    ) {
      byCol.forEach((tx, tys) {
        tys.sort();
        var runStart = tys.first;
        var prev = tys.first;
        for (final ty in tys.skip(1)) {
          if (ty == prev + 1) {
            prev = ty;
            continue;
          }
          _addVerticalWall(
            x: edgeX(tx),
            top: mapMargin + runStart * tileSize,
            bottom: mapMargin + (prev + 1) * tileSize,
            side: side,
          );
          runStart = ty;
          prev = ty;
        }
        _addVerticalWall(
          x: edgeX(tx),
          top: mapMargin + runStart * tileSize,
          bottom: mapMargin + (prev + 1) * tileSize,
          side: side,
        );
      });
    }

    void emitHorizontal(
      Map<int, List<int>> byRow,
      double Function(int) edgeY,
      WallSide side,
    ) {
      byRow.forEach((ty, txs) {
        txs.sort();
        var runStart = txs.first;
        var prev = txs.first;
        for (final tx in txs.skip(1)) {
          if (tx == prev + 1) {
            prev = tx;
            continue;
          }
          _addHorizontalWall(
            y: edgeY(ty),
            left: mapMargin + runStart * tileSize,
            right: mapMargin + (prev + 1) * tileSize,
            side: side,
          );
          runStart = tx;
          prev = tx;
        }
        _addHorizontalWall(
          y: edgeY(ty),
          left: mapMargin + runStart * tileSize,
          right: mapMargin + (prev + 1) * tileSize,
          side: side,
        );
      });
    }

    // East void -> normal points west (WallSide.right); etc.
    emitVertical(
      eastByCol,
      (tx) => mapMargin + (tx + 1) * tileSize,
      WallSide.right,
    );
    emitVertical(westByCol, (tx) => mapMargin + tx * tileSize, WallSide.left);
    emitHorizontal(northByRow, (ty) => mapMargin + ty * tileSize, WallSide.top);
    emitHorizontal(
      southByRow,
      (ty) => mapMargin + (ty + 1) * tileSize,
      WallSide.bottom,
    );
  }

  /// Paints semantic tile overlays and spawns interior walls / pits / hurt rects
  /// from [RoomTemplateCatalog] when [room.roomTemplateId] is set.
  void _applySemanticRoomTemplateIfPresent(_RoomPlan room) {
    final templateId = room.roomTemplateId;
    final rect = room.worldRect;
    if (templateId == null || rect == null) {
      return;
    }
    final template = RoomTemplateCatalog.instance.byId(templateId);
    final mapping = _semanticThemeMapping;
    if (template == null || mapping == null) {
      return;
    }
    final sprites = _floorTileSprites;
    if (sprites.isEmpty) {
      return;
    }

    final transformed = applyTemplateTransform(
      template,
      quarterTurns: room.templateRotationQuarterTurns,
      flipH: room.templateFlipH,
      flipV: room.templateFlipV,
    );
    final cols = transformed.cols;
    final rows = transformed.rows;
    final sem = transformed.sem;
    final hurt = transformed.hurt;
    if (cols <= 0 || rows <= 0 || sem.length != cols * rows) {
      return;
    }

    final cellW = rect.width / cols;
    final cellH = rect.height / rows;

    final overlay = PositionComponent(priority: -88);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final idx = y * cols + x;
        final s = sem[idx];
        final cx = rect.left + (x + 0.5) * cellW;
        final cy = rect.top + (y + 0.5) * cellH;

        final isWallCell = TileSemantics.createsSolidWall(s);
        final wallSprites = _wallTileSprites;
        final sprite = isWallCell && wallSprites.isNotEmpty
            ? wallSprites[(((x * 83492791) ^ (y * 1234559)) & 0x7fffffff) %
                  wallSprites.length]
            : mapping.spriteForSemantic(sprites, s);
        if (sprite != null) {
          overlay.add(
            SpriteComponent(
              sprite: sprite,
              position: Vector2(cx, cy),
              size: Vector2(cellW, cellH),
              anchor: Anchor.center,
              priority: -88,
            ),
          );
        }

        if (TileSemantics.isPit(s)) {
          final pit = PitComponent(
            position: Vector2(cx, cy),
            radius: min(cellW, cellH) * 0.38,
          );
          _pits.add(pit);
          world.add(pit);
        } else if (TileSemantics.createsSolidWall(s)) {
          final side = cellW >= cellH ? WallSide.left : WallSide.top;
          final wall = WallComponent(
            side: side,
            position: Vector2(cx, cy),
            size: Vector2(cellW, cellH),
          );
          _walls.add(wall);
        }

        var hurtTier = 0;
        if (hurt != null && idx < hurt.length) {
          hurtTier = hurt[idx];
        }
        if (hurtTier <= 0 && TileSemantics.isHazard(s)) {
          hurtTier = TileSemantics.hazardDamageTier(s);
        }
        if (hurtTier > 0) {
          final damage = (hurtTier >= 2 ? 16.0 : 9.0);
          final hazard = SemanticHazardRectComponent(
            position: Vector2(cx, cy),
            size: Vector2(cellW * 0.92, cellH * 0.92),
            damage: damage,
            onDamage: (d) => applyPlayerDamage(d, source: 'HazardTile'),
            isWorldFrozen: () => isWorldFrozen,
          );
          _semanticHazards.add(hazard);
          world.add(hazard);
        }
      }
    }
    _semanticTileLayers.add(overlay);
    world.add(overlay);
  }

  void _spawnCenterBumpers(_LevelPlan level) {
    for (final room in level.rooms.values) {
      if (room.type == RoomType.start || !room.hasCenterBumper) {
        continue;
      }

      final radius = (15 + room.dangerTier * 0.45).clamp(14, 23).toDouble();
      final boost = (1.12 + room.dangerTier * 0.014)
          .clamp(1.12, 1.3)
          .toDouble();
      final controlLoss = (0.24 + room.dangerTier * 0.014)
          .clamp(0.24, 0.62)
          .toDouble();
      final bumper = BumperComponent(
        position: room.center,
        radius: radius,
        boostMultiplier: boost,
        controlLossRadians: controlLoss,
      );
      _bumpers.add(bumper);
      world.add(bumper);
    }
  }

  void _spawnLevelContent(_LevelPlan level) {
    final spawnablePowerupRooms = <_RoomPlan>[];
    var carvedFloorForPits = false;

    for (final room in level.rooms.values) {
      if (room.type == RoomType.start) {
        room.cleared = true;
        continue;
      }

      room.cleared = false;
      spawnablePowerupRooms.add(room);
      final roomBounds = room.enemyClampRect;
      final dangerScale = _enemyDangerScaleForTier(room.dangerTier);
      final eliteScale = room.type == RoomType.trap ? 1.12 : 1.0;

      for (var i = 0; i < room.turretCount; i++) {
        final enemy = EnemyComponent.turret(
          position: _randomSpawnInRoom(room: room, radius: 18),
          archetype: _archetypeForSpawn(type: EnemyType.turret, room: room),
          hpMultiplier: dangerScale * eliteScale,
          contactDamageMultiplier: 0.9 + dangerScale * 0.2,
          fireRateMultiplier: 0.92 + dangerScale * 0.18,
          projectileDamageMultiplier: 0.9 + dangerScale * 0.22,
          projectileSpeedMultiplier: 0.95 + dangerScale * 0.14,
          coinDropBonus: room.type == RoomType.treasure ? 1 : 0,
        );
        _enemies.add(enemy);
        _enemyRooms[enemy] = room.position;
        _enemyBounds[enemy] = roomBounds;
        world.add(enemy);
      }

      for (var i = 0; i < room.walkerCount; i++) {
        final direction = Vector2(
          _random.nextDouble() - 0.5,
          _random.nextDouble() - 0.5,
        );

        final walkerArchetype = _archetypeForSpawn(
          type: EnemyType.walker,
          room: room,
        );
        final walkerHpScale = walkerArchetype == EnemyArchetype.standard
            ? 0.88
            : 1.0;
        final stalkerSpeed = walkerArchetype == EnemyArchetype.stalker
            ? 1.16
            : 1.0;

        final enemy = EnemyComponent.walker(
          position: _randomSpawnInRoom(
            room: room,
            radius: 16,
            maxCenterY: _gameMode == SpinnerGameMode.invasion
                ? _levelMax.y - _invasionWalkerSpawnMaxYInset
                : null,
          ),
          direction: direction,
          archetype: walkerArchetype,
          hpMultiplier: (dangerScale * eliteScale * walkerHpScale)
              .clamp(0.8, 3.8)
              .toDouble(),
          speedMultiplier:
              (0.88 + dangerScale * 0.16).clamp(0.8, 2.4).toDouble() *
              stalkerSpeed,
          contactDamageMultiplier:
              ((0.88 + dangerScale * 0.18) *
                      (walkerArchetype == EnemyArchetype.stalker ? 1.08 : 1.0))
                  .clamp(0.8, 2.85)
                  .toDouble(),
          coinDropBonus: room.type == RoomType.treasure ? 1 : 0,
        );
        _enemies.add(enemy);
        _enemyRooms[enemy] = room.position;
        _enemyBounds[enemy] = roomBounds;
        world.add(enemy);
      }

      for (var i = 0; i < room.hedgehogCount; i++) {
        // Hedgehogs patrol a single axis (H or V) — pick one at spawn
        // and never change. `_hedgehogAxisVelocity` snaps the vector to
        // that axis, so it's fine to hand in a pure-axis unit vector.
        final horizontal = _random.nextBool();
        final forward = _random.nextBool() ? 1.0 : -1.0;
        final direction = horizontal
            ? Vector2(forward, 0)
            : Vector2(0, forward);
        final enemy = EnemyComponent.hedgehog(
          position: _randomSpawnInRoom(
            room: room,
            radius: 24,
            avoidDoorLanes: true,
          ),
          direction: direction,
          archetype: _archetypeForSpawn(type: EnemyType.hedgehog, room: room),
          hpMultiplier: (dangerScale * eliteScale * 1.08)
              .clamp(0.8, 4.2)
              .toDouble(),
          speedMultiplier: (0.82 + dangerScale * 0.14)
              .clamp(0.75, 2.2)
              .toDouble(),
          contactDamageMultiplier: (0.92 + dangerScale * 0.2)
              .clamp(0.9, 2.8)
              .toDouble(),
          coinDropBonus: room.type == RoomType.treasure ? 1 : 0,
        );
        _enemies.add(enemy);
        _enemyRooms[enemy] = room.position;
        _enemyBounds[enemy] = roomBounds;
        world.add(enemy);
      }

      for (var i = 0; i < room.pulserCount; i++) {
        final direction = Vector2(
          _random.nextDouble() - 0.5,
          _random.nextDouble() - 0.5,
        );
        final enemy = EnemyComponent.pulser(
          position: _randomSpawnInRoom(
            room: room,
            radius: 19,
            avoidDoorLanes: true,
          ),
          direction: direction,
          archetype: _archetypeForSpawn(type: EnemyType.pulser, room: room),
          hpMultiplier: (dangerScale * eliteScale * 1.02)
              .clamp(0.85, 3.9)
              .toDouble(),
          speedMultiplier: (0.82 + dangerScale * 0.12)
              .clamp(0.75, 2.0)
              .toDouble(),
          contactDamageMultiplier: (0.9 + dangerScale * 0.16)
              .clamp(0.85, 2.5)
              .toDouble(),
          coinDropBonus: room.type == RoomType.treasure ? 1 : 0,
        );
        _enemies.add(enemy);
        _enemyRooms[enemy] = room.position;
        _enemyBounds[enemy] = roomBounds;
        world.add(enemy);
      }

      for (var i = 0; i < room.bossCount; i++) {
        final enemy = EnemyComponent.boss(
          position: _randomSpawnInRoom(room: room, radius: 24),
          archetype: _archetypeForSpawn(type: EnemyType.boss, room: room),
          hpMultiplier: (1 + levelNumber * 0.12).clamp(1.0, 2.5).toDouble(),
          contactDamageMultiplier: (1 + levelNumber * 0.08)
              .clamp(1.0, 2.0)
              .toDouble(),
          coinDropBonus: 25,
        );
        _enemies.add(enemy);
        _enemyRooms[enemy] = room.position;
        _enemyBounds[enemy] = roomBounds;
        world.add(enemy);
      }

      for (var i = 0; i < room.paddleCount; i++) {
        final enemy = EnemyComponent.paddle(
          position: _randomSpawnInRoom(
            room: room,
            radius: 18,
            avoidDoorLanes: true,
          ),
          archetype: _archetypeForSpawn(type: EnemyType.paddle, room: room),
          hpMultiplier: (dangerScale * 0.95).clamp(0.8, 3.6).toDouble(),
          contactDamageMultiplier: (0.92 + dangerScale * 0.12)
              .clamp(0.8, 2.2)
              .toDouble(),
          coinDropBonus: room.type == RoomType.treasure ? 1 : 0,
        );
        _enemies.add(enemy);
        _enemyRooms[enemy] = room.position;
        _enemyBounds[enemy] = roomBounds;
        world.add(enemy);
      }

      if (_spawnTrapsAndPits) {
        for (var i = 0; i < room.trapCount; i++) {
          final trap = TrapComponent(
            position: _randomSpawnInRoom(room: room, radius: 16),
          );
          _traps.add(trap);
          world.add(trap);
        }

        for (var i = 0; i < room.pitCount; i++) {
          final pitRadius = 14 + _random.nextDouble() * 18;
          final pit = PitComponent(
            radius: pitRadius,
            position: _randomSpawnInRoom(
              room: room,
              radius: pitRadius,
              avoidDoorLanes: true,
            ),
          );
          _pits.add(pit);
          world.add(pit);
          carvedFloorForPits =
              _carveFloorCellsForPit(pit) || carvedFloorForPits;
        }
      }

      if (room.chestSpins > 0 && !room.chestOpened) {
        final chest = ChestComponent(
          position: _randomSpawnInRoom(room: room, radius: 18),
          coinReward: room.chestCoins,
        );
        _chests.add(chest);
        _chestRooms[chest] = room.position;
        world.add(chest);
      }
    }

    if (spawnablePowerupRooms.isNotEmpty &&
        _random.nextDouble() < _powerupSpawnChanceForLevel(levelNumber)) {
      final room =
          spawnablePowerupRooms[_random.nextInt(spawnablePowerupRooms.length)];
      final powerup = PowerupComponent(
        type: _rollPowerupForLevel(levelNumber),
        position: _randomSpawnInRoom(room: room, radius: 14),
        durationSeconds: 12 + levelNumber * 0.8,
      );
      _powerups.add(powerup);
      world.add(powerup);
    }

    if (carvedFloorForPits) {
      _refreshFloorVisualsFromCells();
    }
  }

  void _spawnSpinner(_LevelPlan level) {
    final startRoom = level.rooms[level.start];
    if (startRoom == null) {
      return;
    }

    final spinner = SpinnerComponent(position: startRoom.center);
    spinner.configureForRun(
      damageMultiplier:
          _appliedUpgrades.damageMultiplier *
          _selectedBuildStats.damageMultiplier,
      friction:
          _appliedUpgrades.frictionRetention +
          _selectedBuildStats.frictionBonus,
      topPhysics: SpinnerTopPhysicsConfig.fromBuildStats(_selectedBuildStats),
    );
    spinner.configureBuildVisual(_selectedBuildStats);
    _spinner = spinner;
    _currentRoomPos = level.start;
    _wasSpinnerMoving = spinner.isMoving;
    world.add(spinner);
  }

  void _configureCamera() {
    final spinner = _spinner;
    if (spinner == null) {
      return;
    }

    camera.viewfinder.zoom = _baseCameraZoom;
    _targetCameraZoom = _baseCameraZoom;
    _attachCameraFollow(snap: true);
    camera.setBounds(_cameraBoundsForLevel(), considerViewport: true);
  }

  flame_exp.Rectangle _cameraBoundsForLevel() {
    final scale = _activeRoomScale.clamp(_minRoomScale, _maxRoomScale);
    final horizontalPad = (_cameraBoundsHorizontalPadding * scale)
        .clamp(140.0, 320.0)
        .toDouble();
    final topPad = (_cameraBoundsTopPadding * scale)
        .clamp(240.0, 460.0)
        .toDouble();
    final bottomPad = (_cameraBoundsBottomPadding * scale)
        .clamp(120.0, 320.0)
        .toDouble();

    return flame_exp.Rectangle.fromLTRB(
      _levelMin.x - horizontalPad,
      _levelMin.y - topPad,
      _levelMax.x + horizontalPad,
      _levelMax.y + bottomPad,
    );
  }

  void _updateCameraZoom(double dt) {
    if (_isCameraGestureActive || _isCameraDragActive) {
      _cameraImpactZoomBump *= pow(0.06, dt).toDouble();
      return;
    }

    _cameraImpactZoomBump *= pow(0.035, dt).toDouble();
    if (_cameraImpactZoomBump < 0.0005) {
      _cameraImpactZoomBump = 0;
    }

    final currentZoom = camera.viewfinder.zoom;
    final alpha = (dt * 4).clamp(0, 1).toDouble();
    final targetZoom = _targetCameraZoom + _cameraImpactZoomBump;
    camera.viewfinder.zoom = currentZoom + (targetZoom - currentZoom) * alpha;
  }

  void _attachCameraFollow({required bool snap}) {
    final spinner = _spinner;
    if (spinner == null) {
      return;
    }

    camera.follow(spinner, snap: snap, maxSpeed: 3400);
    _isCameraFollowingSpinner = true;
  }

  void _detachCameraFollow() {
    if (!_isCameraFollowingSpinner) {
      return;
    }

    camera.stop();
    _isCameraFollowingSpinner = false;
  }

  void _syncCurrentRoomFromSpinner() {
    final level = _currentLevel;
    final spinner = _spinner;
    if (level == null || spinner == null) {
      return;
    }

    final point = Offset(spinner.position.x, spinner.position.y);
    _GridPos? found;

    for (final entry in level.rooms.entries) {
      final roomRect = entry.value.worldRect;
      if (roomRect != null && roomRect.inflate(14).contains(point)) {
        found = entry.key;
        break;
      }
    }

    if (found != null && found != _currentRoomPos) {
      _currentRoomPos = found;
      _notifyHud();
    }
  }

  void _syncRoomAndLevelState({bool notify = true}) {
    final level = _currentLevel;
    if (level == null) {
      return;
    }

    if (_gameMode == SpinnerGameMode.invasion) {
      _levelComplete = false;
      _levelClearAcknowledged = false;
      if (notify) {
        _notifyHud();
      }
      return;
    }

    final wasLevelComplete = _levelComplete;

    final enemyCounts = <_GridPos, int>{};
    for (final entry in _enemyRooms.entries) {
      if (!entry.key.countsTowardRoomClear) {
        continue;
      }
      final roomPos = entry.value;
      enemyCounts[roomPos] = (enemyCounts[roomPos] ?? 0) + 1;
    }

    for (final room in level.rooms.values) {
      final wasCleared = room.cleared;
      if (room.type == RoomType.start) {
        room.cleared = true;
      } else {
        room.cleared = (enemyCounts[room.position] ?? 0) == 0;
      }

      if (_runPhase == RunPhase.playing &&
          !wasCleared &&
          room.cleared &&
          room.type != RoomType.start) {
        _addScore(120, depthScaled: true);
      }
    }

    _levelComplete = level.rooms.values
        .where((room) => room.type != RoomType.start)
        .every((room) => room.cleared);

    if (_runPhase == RunPhase.playing && _levelComplete && !wasLevelComplete) {
      _levelClearAcknowledged = false;
      _isCharging = false;
      _spinDetector.reset();
      _spinner?.clearChargePreview();
      _spinner?.stop();

      _runStats = _runStats.copyWith(
        levelsCleared: _runStats.levelsCleared + 1,
      );
      _addScore(220, depthScaled: true);

      if (_currentLevelIndex == _levels.length - 1) {
        _addScore(500, depthScaled: true);
        _endRun(RunEndReason.victory);
        return;
      }
    }

    if (notify) {
      _notifyHud();
    }
  }

  Vector2 _widgetToWorld(Vector2 widgetPoint) {
    return camera.globalToLocal(widgetPoint.clone());
  }

  void _addFloorRect(Rect rect) {
    final startX = (rect.left / _floorTileWorldSize).floor();
    final endX = (rect.right / _floorTileWorldSize).ceil();
    final startY = (rect.top / _floorTileWorldSize).floor();
    final endY = (rect.bottom / _floorTileWorldSize).ceil();

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        _floorCellKeys.add(_cellKey(x, y));
      }
    }
  }

  bool _carveFloorCellsForPit(PitComponent pit) {
    if (_floorCellKeys.isEmpty) {
      return false;
    }

    final carveRadius = pit.radius + (_floorTileWorldSize * 0.15);
    final startX = ((pit.position.x - carveRadius) / _floorTileWorldSize)
        .floor();
    final endX = ((pit.position.x + carveRadius) / _floorTileWorldSize).ceil();
    final startY = ((pit.position.y - carveRadius) / _floorTileWorldSize)
        .floor();
    final endY = ((pit.position.y + carveRadius) / _floorTileWorldSize).ceil();

    var removedAny = false;
    for (var y = startY; y <= endY; y++) {
      for (var x = startX; x <= endX; x++) {
        final centerX = (x * _floorTileWorldSize) + (_floorTileWorldSize * 0.5);
        final centerY = (y * _floorTileWorldSize) + (_floorTileWorldSize * 0.5);
        final dx = centerX - pit.position.x;
        final dy = centerY - pit.position.y;
        if ((dx * dx) + (dy * dy) > carveRadius * carveRadius) {
          continue;
        }
        removedAny = _floorCellKeys.remove(_cellKey(x, y)) || removedAny;
      }
    }

    return removedAny;
  }

  void _refreshFloorVisualsFromCells() {
    for (final floor in _floors) {
      floor.removeFromParent();
    }
    _rebuildFloorTilesFromWang();
    if (_floors.isNotEmpty) {
      world.addAll(_floors);
    }
  }

  void _addWallVisualForBounds({required Rect rect, required bool vertical}) {
    final container = PositionComponent(priority: -90);
    // Always add a backplate: wall sprites prefer [upperTerrainSprite], which in
    // some themed exports is blank or the same albedo as floor—players then see
    // only collision, not the obstacle.
    container.add(
      RectangleComponent(
        position: Vector2(rect.center.dx, rect.center.dy),
        size: Vector2(rect.width, rect.height),
        anchor: Anchor.center,
        paint: Paint()..color = _kWallVisualBackplate,
        priority: -91,
      ),
    );

    final wallSprites = _wallTileSprites;
    if (wallSprites.isNotEmpty || _floorTileSprites.isNotEmpty) {
      final startX = (rect.left / _floorTileWorldSize).floor();
      final endX = (rect.right / _floorTileWorldSize).ceil();
      final startY = (rect.top / _floorTileWorldSize).floor();
      final endY = (rect.bottom / _floorTileWorldSize).ceil();

      for (var y = startY; y < endY; y++) {
        for (var x = startX; x < endX; x++) {
          final variant = ((x * 83492791) ^ (y * 1234559)) & 0x7fffffff;
          final Sprite sprite;
          if (wallSprites.isNotEmpty) {
            // Dedicated, visually-distinct wall art — read as an obstacle
            // instead of blending with floor tiles.
            sprite = wallSprites[variant % wallSprites.length];
          } else {
            final spriteIndices = vertical
                ? const <int>[12, 13, 14, 15]
                : const <int>[8, 9, 10, 11];
            sprite =
                _upperTerrainSprite ??
                _floorTileSprites[spriteIndices[variant %
                    spriteIndices.length]];
          }
          final centerX =
              (x * _floorTileWorldSize) + (_floorTileWorldSize * 0.5);
          final centerY =
              (y * _floorTileWorldSize) + (_floorTileWorldSize * 0.5);
          container.add(
            SpriteComponent(
              sprite: sprite,
              position: Vector2(centerX, centerY),
              size: Vector2.all(_floorTileWorldSize),
              anchor: Anchor.center,
              priority: -90,
            ),
          );
        }
      }
    }

    _wallVisuals.add(container);
  }

  Future<void> _loadDungeonTiles() async {
    _themeSpriteMap.clear();
    _fallbackTheme = null;

    for (final asset in kDungeonThemeAssets) {
      final loaded = await _loadThemeTileset(asset);
      if (loaded != null) {
        _themeSpriteMap[asset.theme] = loaded;
        _fallbackTheme ??= loaded;
      }
    }

    // If none of the new themed tilesets shipped yet, fall back to the
    // legacy temple tileset so existing builds keep rendering.
    if (_themeSpriteMap.isEmpty) {
      final legacy = await _loadThemeTileset(kLegacyTempleTheme);
      if (legacy != null) {
        _themeSpriteMap[DungeonTheme.templeWarm] = legacy;
        _fallbackTheme = legacy;
      }
    }
  }

  Future<_ThemeSprites?> _loadThemeTileset(DungeonThemeAssets asset) async {
    try {
      final image = await images.load(asset.pngAsset);
      // Wang tilesets always ship as a 4×4 grid, so tile size is imageWidth/4.
      final tileWidth = image.width / 4;
      final tileHeight = image.height / 4;
      if (tileWidth <= 0 || tileHeight <= 0) {
        return null;
      }

      final floorTileSprites = <Sprite>[];
      for (var row = 0; row < 4; row++) {
        for (var col = 0; col < 4; col++) {
          floorTileSprites.add(
            Sprite(
              image,
              srcPosition: Vector2(col * tileWidth, row * tileHeight),
              srcSize: Vector2(tileWidth, tileHeight),
            ),
          );
        }
      }

      final wangTileSpritesByKey = <String, Sprite>{};
      Sprite? lowerTerrainSprite;
      Sprite? upperTerrainSprite;

      try {
        final metadataRaw = await rootBundle.loadString(asset.jsonAsset);
        final metadata = jsonDecode(metadataRaw);
        final tilesRaw = switch (metadata) {
          Map() when metadata['tiles'] is List => metadata['tiles'] as List,
          Map()
              when metadata['tileset_data'] is Map &&
                  (metadata['tileset_data'] as Map)['tiles'] is List =>
            ((metadata['tileset_data'] as Map)['tiles'] as List),
          _ => const <dynamic>[],
        };
        for (final tile in tilesRaw) {
          if (tile is! Map) {
            continue;
          }
          final cornersRaw = tile['corners'];
          final bboxRaw = tile['bounding_box'];
          if (cornersRaw is! Map || bboxRaw is! Map) {
            continue;
          }
          final x = (bboxRaw['x'] as num?)?.toInt() ?? 0;
          final y = (bboxRaw['y'] as num?)?.toInt() ?? 0;
          final col = (x / tileWidth).floor();
          final row = (y / tileHeight).floor();
          if (col < 0 || col > 3 || row < 0 || row > 3) {
            continue;
          }
          final spriteIndex = row * 4 + col;
          if (spriteIndex < 0 || spriteIndex >= floorTileSprites.length) {
            continue;
          }
          final sprite = floorTileSprites[spriteIndex];
          final nwLower = (cornersRaw['NW'] as String?) == 'lower';
          final neLower = (cornersRaw['NE'] as String?) == 'lower';
          final swLower = (cornersRaw['SW'] as String?) == 'lower';
          final seLower = (cornersRaw['SE'] as String?) == 'lower';
          final key = _wangKey(
            nw: nwLower,
            ne: neLower,
            sw: swLower,
            se: seLower,
          );
          wangTileSpritesByKey[key] = sprite;

          final allLower = nwLower && neLower && swLower && seLower;
          final allUpper = !nwLower && !neLower && !swLower && !seLower;
          if (allLower) {
            lowerTerrainSprite = sprite;
          } else if (allUpper) {
            upperTerrainSprite = sprite;
          }
        }
      } catch (_) {
        // JSON is optional — without it we still render random floor variation
        // from the 16-tile grid, just without precise corner matching.
      }

      final wallTileSprites = await _loadWallTileSprites(asset.wallPngAsset);
      final openFloorTileSprites = await _loadTileStrip(
        asset.openFloorPngAsset,
        kOpenFloorVariantCount,
      );

      return _ThemeSprites(
        image: image,
        floorTileSprites: floorTileSprites,
        wangTileSpritesByKey: wangTileSpritesByKey,
        lowerTerrainSprite: lowerTerrainSprite,
        upperTerrainSprite: upperTerrainSprite,
        wallTileSprites: wallTileSprites,
        openFloorTileSprites: openFloorTileSprites,
      );
    } catch (_) {
      return null;
    }
  }

  /// Loads a dedicated, seamlessly-tileable wall texture if the theme ships
  /// one. Returns an empty list when [wallPngAsset] is null or fails to
  /// load, so callers can fall back to reusing floor art.
  Future<List<Sprite>> _loadWallTileSprites(String? wallPngAsset) async {
    if (wallPngAsset == null) {
      return const <Sprite>[];
    }
    try {
      final image = await images.load(wallPngAsset);
      if (image.width <= 0 || image.height <= 0) {
        return const <Sprite>[];
      }
      return <Sprite>[Sprite(image)];
    } catch (_) {
      return const <Sprite>[];
    }
  }

  /// Loads [count] equal-width square tiles packed side by side in one strip
  /// image. Returns an empty list when [path] is null or fails to load.
  Future<List<Sprite>> _loadTileStrip(String? path, int count) async {
    if (path == null || count <= 0) {
      return const <Sprite>[];
    }
    try {
      final image = await images.load(path);
      final tileWidth = image.width / count;
      final tileHeight = image.height.toDouble();
      if (tileWidth <= 0 || tileHeight <= 0) {
        return const <Sprite>[];
      }
      return <Sprite>[
        for (var i = 0; i < count; i++)
          Sprite(
            image,
            srcPosition: Vector2(i * tileWidth, 0),
            srcSize: Vector2(tileWidth, tileHeight),
          ),
      ];
    } catch (_) {
      return const <Sprite>[];
    }
  }

  /// Called right before a level is built so floor and wall rendering use the
  /// art that matches the current depth.
  void _applyThemeForLevel(int levelNumber) {
    final target = themeForLevel(levelNumber);
    if (_themeSpriteMap.containsKey(target)) {
      _activeTheme = target;
    } else if (_fallbackTheme != null) {
      // Theme isn't shipped yet — keep using the first available theme so the
      // biome still renders something cohesive instead of failing silently.
      _activeTheme = _themeSpriteMap.keys.first;
    }
  }

  int _tileIndexForGrid(int x, int y) {
    final seed = ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff;
    return seed % _floorTileSprites.length;
  }

  void _rebuildFloorTilesFromWang() {
    _floors.clear();

    if (_floorCellKeys.isEmpty) {
      return;
    }

    if (_floorTileSprites.isEmpty) {
      _addFallbackFloorRect();
      return;
    }

    final bounds = _floorCellBounds();
    final container = PositionComponent(priority: -100);
    for (var y = bounds.$2 - 1; y <= bounds.$4 + 1; y++) {
      for (var x = bounds.$1 - 1; x <= bounds.$3 + 1; x++) {
        if (!_isFloorCell(x, y) && !_hasNeighborFloorCell(x, y)) {
          continue;
        }

        final nw = _vertexIsLower(x, y);
        final ne = _vertexIsLower(x + 1, y);
        final sw = _vertexIsLower(x, y + 1);
        final se = _vertexIsLower(x + 1, y + 1);
        if (!nw && !ne && !sw && !se) {
          continue;
        }

        final openFloorSprites = _openFloorTileSprites;
        final Sprite sprite;
        if (nw && ne && sw && se && openFloorSprites.isNotEmpty) {
          // Fully-interior cell, no wall/path edge nearby — the plain Wang
          // tile repeats identically here across large open rooms and reads
          // as a visible grid. Break it up with a varied, seamless tile.
          final variant = ((x * 83492791) ^ (y * 1234559)) & 0x7fffffff;
          sprite = openFloorSprites[variant % openFloorSprites.length];
        } else {
          sprite =
              _wangTileSpritesByKey[_wangKey(nw: nw, ne: ne, sw: sw, se: se)] ??
              _wangTileSpritesByKey[_wangKey(
                nw: true,
                ne: true,
                sw: true,
                se: true,
              )] ??
              _lowerTerrainSprite ??
              _floorTileSprites[_tileIndexForGrid(x, y)];
        }
        final centerX = (x * _floorTileWorldSize) + (_floorTileWorldSize * 0.5);
        final centerY = (y * _floorTileWorldSize) + (_floorTileWorldSize * 0.5);
        container.add(
          SpriteComponent(
            sprite: sprite,
            position: Vector2(centerX, centerY),
            size: Vector2.all(_floorTileWorldSize),
            anchor: Anchor.center,
            priority: -100,
          ),
        );
      }
    }
    _floors.add(container);
  }

  void _addFallbackFloorRect() {
    final container = PositionComponent(priority: -100);
    for (final key in _floorCellKeys) {
      final (x, y) = _parseCellKey(key);
      final centerX = (x * _floorTileWorldSize) + (_floorTileWorldSize * 0.5);
      final centerY = (y * _floorTileWorldSize) + (_floorTileWorldSize * 0.5);
      container.add(
        RectangleComponent(
          position: Vector2(centerX, centerY),
          size: Vector2.all(_floorTileWorldSize),
          anchor: Anchor.center,
          paint: Paint()..color = const Color(0xFF8A4B00),
          priority: -100,
        ),
      );
    }
    _floors.add(container);
  }

  (int, int, int, int) _floorCellBounds() {
    var minX = 1 << 30;
    var minY = 1 << 30;
    var maxX = -(1 << 30);
    var maxY = -(1 << 30);
    for (final key in _floorCellKeys) {
      final cell = _parseCellKey(key);
      minX = min(minX, cell.$1);
      minY = min(minY, cell.$2);
      maxX = max(maxX, cell.$1);
      maxY = max(maxY, cell.$2);
    }
    return (minX, minY, maxX, maxY);
  }

  String _cellKey(int x, int y) => '$x:$y';

  (int, int) _parseCellKey(String key) {
    final split = key.split(':');
    if (split.length != 2) {
      return (0, 0);
    }
    return (int.tryParse(split[0]) ?? 0, int.tryParse(split[1]) ?? 0);
  }

  bool _isFloorCell(int x, int y) => _floorCellKeys.contains(_cellKey(x, y));

  bool _hasNeighborFloorCell(int x, int y) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (_isFloorCell(x + dx, y + dy)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _vertexIsLower(int vx, int vy) {
    return _isFloorCell(vx - 1, vy - 1) ||
        _isFloorCell(vx, vy - 1) ||
        _isFloorCell(vx - 1, vy) ||
        _isFloorCell(vx, vy);
  }

  String _wangKey({
    required bool nw,
    required bool ne,
    required bool sw,
    required bool se,
  }) {
    String label(bool lower) => lower ? 'lower' : 'upper';
    return 'NW:${label(nw)}|NE:${label(ne)}|SW:${label(sw)}|SE:${label(se)}';
  }

  void _addVerticalWall({
    required double x,
    required double top,
    required double bottom,
    required WallSide side,
  }) {
    final height = bottom - top;
    if (height <= 2) {
      return;
    }

    _walls.add(
      WallComponent(
        side: side,
        position: Vector2(x, (top + bottom) * 0.5),
        size: Vector2(wallThickness, height),
      ),
    );
    _addWallVisualForBounds(
      rect: Rect.fromCenter(
        center: Offset(x, (top + bottom) * 0.5),
        width: wallThickness,
        height: height,
      ),
      vertical: true,
    );
  }

  void _addHorizontalWall({
    required double y,
    required double left,
    required double right,
    required WallSide side,
  }) {
    final width = right - left;
    if (width <= 2) {
      return;
    }

    _walls.add(
      WallComponent(
        side: side,
        position: Vector2((left + right) * 0.5, y),
        size: Vector2(width, wallThickness),
      ),
    );
    _addWallVisualForBounds(
      rect: Rect.fromCenter(
        center: Offset((left + right) * 0.5, y),
        width: width,
        height: wallThickness,
      ),
      vertical: false,
    );
  }

  Vector2 _randomSpawnInRoom({
    required _RoomPlan room,
    required double radius,
    bool avoidDoorLanes = false,
    double? maxCenterY,
  }) {
    final roomScale = _activeRoomScale;
    final deflatePadding = (84 * roomScale).clamp(44, 84).toDouble();
    final centerKeepout = (94 * roomScale).clamp(54, 94).toDouble();
    final rect = room.worldRect!.deflate(deflatePadding);

    final minY = rect.top + radius;
    final cappedMaxY = maxCenterY == null
        ? rect.bottom - radius
        : min(maxCenterY, rect.bottom - radius);
    final maxY = max(minY, cappedMaxY);
    final ySpan = max(1e-6, maxY - minY);

    for (var attempt = 0; attempt < 80; attempt++) {
      final candidate = Vector2(
        rect.left + radius + _random.nextDouble() * (rect.width - radius * 2),
        minY + _random.nextDouble() * ySpan,
      );

      if (candidate.distanceTo(room.center) < centerKeepout) {
        continue;
      }

      if (avoidDoorLanes && _blocksDoorLane(room, candidate, radius)) {
        continue;
      }

      if (_insideAnyWall(candidate, radius)) {
        continue;
      }

      if (_overlapsExisting(candidate, radius)) {
        continue;
      }

      return candidate;
    }

    return Vector2(
      rect.left + radius + (rect.width - radius * 2) * 0.35,
      minY + ySpan * 0.25,
    );
  }

  bool _insideAnyWall(Vector2 candidate, double radius) {
    final point = Offset(candidate.x, candidate.y);

    for (final wall in _walls) {
      final rect = Rect.fromCenter(
        center: Offset(wall.position.x, wall.position.y),
        width: wall.size.x,
        height: wall.size.y,
      ).inflate(radius + 6);

      if (rect.contains(point)) {
        return true;
      }
    }

    return false;
  }

  bool _overlapsExisting(Vector2 candidate, double radius) {
    for (final enemy in _enemies) {
      if (candidate.distanceTo(enemy.position) < radius + enemy.radius + 16) {
        return true;
      }
    }

    for (final bumper in _bumpers) {
      if (candidate.distanceTo(bumper.position) < radius + bumper.radius + 14) {
        return true;
      }
    }

    for (final trap in _traps) {
      if (candidate.distanceTo(trap.position) < radius + trap.radius + 12) {
        return true;
      }
    }

    for (final pit in _pits) {
      if (candidate.distanceTo(pit.position) < radius + pit.radius + 16) {
        return true;
      }
    }

    for (final chest in _chests) {
      final half = chest.size * 0.5;
      final dx = (candidate.x - chest.position.x).abs();
      final dy = (candidate.y - chest.position.y).abs();
      if (dx < half.x + radius + 8 && dy < half.y + radius + 8) {
        return true;
      }
    }

    for (final powerup in _powerups) {
      if (candidate.distanceTo(powerup.position) <
          radius + powerup.radius + 12) {
        return true;
      }
    }

    return false;
  }

  bool _canSkimPit({
    required PitComponent pit,
    required SpinnerComponent spinner,
  }) {
    if (_appliedUpgrades.pitSkimMaxRadius <= 0) {
      return false;
    }

    if (pit.radius > _appliedUpgrades.pitSkimMaxRadius) {
      return false;
    }

    return spinner.velocity.length >= _appliedUpgrades.pitSkimMinSpeed;
  }

  bool _blocksDoorLane(_RoomPlan room, Vector2 candidate, double radius) {
    final rect = room.worldRect!;
    final center = room.center;
    final laneHalf = _activeCorridorWidth * 0.62;
    final edgeDepth = 112 + radius;

    final nearLeftLane =
        room.exits.containsKey(RoomDirection.left) &&
        candidate.x < rect.left + edgeDepth &&
        (candidate.y - center.y).abs() < laneHalf + radius;
    final nearRightLane =
        room.exits.containsKey(RoomDirection.right) &&
        candidate.x > rect.right - edgeDepth &&
        (candidate.y - center.y).abs() < laneHalf + radius;
    final nearTopLane =
        room.exits.containsKey(RoomDirection.up) &&
        candidate.y < rect.top + edgeDepth &&
        (candidate.x - center.x).abs() < laneHalf + radius;
    final nearBottomLane =
        room.exits.containsKey(RoomDirection.down) &&
        candidate.y > rect.bottom - edgeDepth &&
        (candidate.x - center.x).abs() < laneHalf + radius;

    return nearLeftLane || nearRightLane || nearTopLane || nearBottomLane;
  }

  Vector2 _safeRespawnPosition() {
    final room = _currentRoom;
    if (room != null) {
      return room.center + Vector2(0, -_activeRoomHeight * 0.18);
    }

    final level = _currentLevel;
    if (level != null) {
      final startRoom = level.rooms[level.start];
      if (startRoom != null) {
        return startRoom.center;
      }
    }

    return Vector2(
      (_levelMin.x + _levelMax.x) * 0.5,
      (_levelMin.y + _levelMax.y) * 0.5,
    );
  }

  void _updateSpinPowerups(double dt) {
    if (_runPhase != RunPhase.playing || isWorldFrozen) {
      _clearTetherLineVisual();
      return;
    }

    final spinner = _spinner;
    if (spinner == null || !spinner.isMoving) {
      _clearTetherLineVisual();
      return;
    }

    if (_activePowerup == PowerupType.tether) {
      _applyTetherPull(spinner, dt);
      return;
    }

    _clearTetherLineVisual();
    if (_activePowerup == PowerupType.fireball) {
      _fireballCooldown -= dt;
      if (_fireballCooldown <= 0) {
        _spawnFireballShot(spinner);
        _fireballCooldown = 0.24;
      }
      return;
    }

    if (_activePowerup == PowerupType.needles) {
      _needlesCooldown -= dt;
      if (_needlesCooldown <= 0) {
        _spawnNeedleVolley(spinner);
        _needlesCooldown = 0.42;
      }
    }
  }

  void _applyTetherPull(SpinnerComponent spinner, double dt) {
    final target = _activeTetherTarget;
    if (target == null) {
      _clearTetherLineVisual();
      return;
    }

    final link = target - spinner.position;
    if (link.length2 <= 0) {
      _clearTetherLineVisual();
      return;
    }

    _tetherLineStart = spinner.position.clone();
    _tetherLineEnd = target.clone();

    final direction = link.normalized();
    final pullForce = (300 + spinner.velocity.length * 0.24) * dt;
    spinner.addExternalImpulse(direction * (pullForce * 1.4));

    final along = direction * spinner.velocity.dot(direction);
    final lateral = spinner.velocity - along;
    final lateralRetention = max(0.0, 1.0 - (dt * 3.0));
    spinner.velocity = along + (lateral * lateralRetention);

    final maxSpeed =
        maxLaunchSpeed * _appliedUpgrades.launchSpeedMultiplier * 1.32;
    if (spinner.velocity.length > maxSpeed) {
      spinner.velocity = spinner.velocity.normalized() * maxSpeed;
    }
  }

  void _clearTetherLineVisual() {
    _tetherLineStart = null;
    _tetherLineEnd = null;
  }

  void _activateSelectedPowerupForCurrentSpin() {
    final selected = _selectedPowerup;
    if (selected == null) {
      return;
    }

    if (abilityChargesFor(selected) <= 0) {
      _selectedPowerup = null;
      _queuedTetherTarget = null;
      _notifyHud();
      return;
    }

    if (selected == PowerupType.tether) {
      final queuedTarget = _queuedTetherTarget;
      if (queuedTarget == null) {
        return;
      }
      _activeTetherTarget = queuedTarget.clone();
    } else {
      _activeTetherTarget = null;
      _clearTetherLineVisual();
    }

    _activePowerup = selected;
    _consumePowerupCharge(selected);
    _selectedPowerup = null;
    _queuedTetherTarget = null;

    if (selected == PowerupType.fireball) {
      _fireballCooldown = 0;
    }
    if (selected == PowerupType.needles) {
      _needlesCooldown = 0;
    }

    _notifyHud();
  }

  void _clearActivePowerupForStop() {
    _activePowerup = null;
    _activeTetherTarget = null;
    _selectedPowerup = null;
    _queuedTetherTarget = null;
    _fireballCooldown = 0;
    _needlesCooldown = 0;
    _clearTetherLineVisual();
    _notifyHud();
  }

  void _consumePowerupCharge(PowerupType type) {
    final current = abilityChargesFor(type);
    if (current <= 1) {
      _abilityCharges.remove(type);
      return;
    }
    _abilityCharges[type] = current - 1;
  }

  void _spawnFireballShot(SpinnerComponent spinner) {
    final direction = _abilityAimDirection(
      spinner,
      fallback: _spinShotDirection(spinner),
      maxDistance: 620,
    );
    final speed = 560 + spinner.velocity.length * 0.25;
    final damage = (8 + levelNumber * 1.4) * _appliedUpgrades.damageMultiplier;
    final shot = SpinnerShotComponent.fireball(
      position: spinner.position + direction * (spinner.radius + 8),
      velocity: direction * speed,
      damage: damage,
    );
    _spinnerShots.add(shot);
    world.add(shot);
  }

  void _spawnNeedleVolley(SpinnerComponent spinner) {
    final baseDirection = _abilityAimDirection(
      spinner,
      fallback: _spinShotDirection(spinner),
      maxDistance: 540,
    );
    const spreads = <double>[-0.34, 0, 0.34];
    final baseDamage =
        (4 + levelNumber * 0.8) * _appliedUpgrades.damageMultiplier;
    final speed = 700 + spinner.velocity.length * 0.18;

    for (final spread in spreads) {
      final direction = _rotateVector(baseDirection, spread);
      final shot = SpinnerShotComponent.needle(
        position: spinner.position + direction * (spinner.radius + 7),
        velocity: direction * speed,
        damage: baseDamage,
      );
      _spinnerShots.add(shot);
      world.add(shot);
    }
  }

  Vector2 _spinShotDirection(SpinnerComponent spinner) {
    if (spinner.velocity.length2 > 0) {
      return spinner.velocity.normalized();
    }

    return Vector2(cos(spinner.angle), sin(spinner.angle));
  }

  Vector2 _abilityAimDirection(
    SpinnerComponent spinner, {
    required Vector2 fallback,
    required double maxDistance,
  }) {
    EnemyComponent? target;
    var bestDistance2 = maxDistance * maxDistance;
    for (final enemy in _enemies) {
      if (enemy.isDead) {
        continue;
      }
      final delta = enemy.position - spinner.position;
      final distance2 = delta.length2;
      if (distance2 <= 1 || distance2 > bestDistance2) {
        continue;
      }
      target = enemy;
      bestDistance2 = distance2;
    }

    if (target == null) {
      return fallback;
    }
    return (target.position - spinner.position).normalized();
  }

  Vector2 _rotateVector(Vector2 direction, double radians) {
    final c = cos(radians);
    final s = sin(radians);
    return Vector2(
      direction.x * c - direction.y * s,
      direction.x * s + direction.y * c,
    );
  }

  void _spawnCoinBurst(Vector2 origin, int baseAmount) {
    if (baseAmount <= 0) {
      return;
    }

    final adjusted = max(
      1,
      (baseAmount * _appliedUpgrades.coinMultiplier).round(),
    );
    for (var i = 0; i < adjusted; i++) {
      final theta = _random.nextDouble() * pi * 2;
      final distance = 8 + _random.nextDouble() * 16;
      final speed = 26 + _random.nextDouble() * 78;
      final offset = Vector2(cos(theta), sin(theta)) * distance;
      final velocity = Vector2(cos(theta), sin(theta)) * speed;

      final coin = CoinPickupComponent(
        position: origin + offset,
        value: 1,
        initialVelocity: velocity,
      );
      _coins.add(coin);
      world.add(coin);
    }
  }

  void _addScore(int baseScore, {required bool depthScaled}) {
    if (baseScore <= 0) {
      return;
    }

    final score = depthScaled
        ? (baseScore * (1 + (_currentLevelIndex * 0.2))).round()
        : baseScore;
    _runStats = _runStats.copyWith(runScore: _runStats.runScore + score);
    _progress = _progress.copyWith(
      bestScore: max(_progress.bestScore, _runStats.runScore),
    );
    _notifyHud();
  }

  void _persistRunSnapshot({bool force = false}) {
    if (!_bootstrappedRun || !_progressLoaded || !_snapshotLoaded) {
      return;
    }

    if (_gameMode == SpinnerGameMode.invasion) {
      return;
    }

    if (force) {
      _runSnapshotAutosaveTimer = 0;
    }

    _queuedRunSnapshot = _buildRunSnapshotPayload();
    if (_runSnapshotSaveInFlight) {
      return;
    }

    _flushQueuedRunSnapshot();
  }

  void _flushQueuedRunSnapshot() {
    final payload = _queuedRunSnapshot;
    if (payload == null) {
      return;
    }

    _queuedRunSnapshot = null;
    _runSnapshotSaveInFlight = true;
    unawaited(
      _runSnapshotRepository
          .save(payload)
          .catchError((_) => Future<void>.value())
          .whenComplete(() {
            _runSnapshotSaveInFlight = false;
            if (_queuedRunSnapshot != null) {
              _flushQueuedRunSnapshot();
            }
          }),
    );
  }

  // ignore: unused_element
  bool _restoreRunSnapshot() {
    final payload = _pendingRunSnapshot;
    _pendingRunSnapshot = null;
    if (payload == null || payload.isEmpty) {
      return false;
    }

    try {
      final schema = (payload['schema'] as num?)?.toInt() ?? 0;
      if (schema != 2) {
        unawaited(_runSnapshotRepository.clear());
        return false;
      }

      final levelsRaw = payload['levels'];
      if (levelsRaw is! List || levelsRaw.isEmpty) {
        unawaited(_runSnapshotRepository.clear());
        return false;
      }

      final restoredLevels = <_LevelPlan>[];
      for (final levelEntry in levelsRaw) {
        if (levelEntry is! Map) {
          continue;
        }
        restoredLevels.add(
          _LevelPlan.fromJson(Map<String, dynamic>.from(levelEntry)),
        );
      }

      if (restoredLevels.isEmpty) {
        unawaited(_runSnapshotRepository.clear());
        return false;
      }

      _levels
        ..clear()
        ..addAll(restoredLevels);
      for (final level in _levels) {
        _normalizeTrapsAndPitsForFeatureFlag(level.rooms);
      }

      _appliedUpgrades = UpgradeSystem.apply(_progress.tiers);

      _runPhase = _runPhaseFromIndex((payload['runPhase'] as num?)?.toInt());
      _runEndReason = _runEndReasonFromIndex(
        (payload['runEndReason'] as num?)?.toInt(),
      );
      final runStatsRaw = payload['runStats'];
      _runStats = runStatsRaw is Map
          ? RunStats.fromJson(Map<String, dynamic>.from(runStatsRaw))
          : const RunStats();

      _currentLevelIndex =
          ((payload['currentLevelIndex'] as num?)?.toInt() ?? 0)
              .clamp(0, _levels.length - 1)
              .toInt();
      _currentRoomPos = _gridPosFromJson(payload['currentRoomPos']);

      _maxHp = (payload['maxHp'] as num?)?.toInt() ?? _appliedUpgrades.maxHp;
      _maxHp = max(1, _maxHp);
      _currentHp = ((payload['currentHp'] as num?)?.toInt() ?? _maxHp)
          .clamp(0, _maxHp)
          .toInt();
      _pitSavesRemaining =
          ((payload['pitSavesRemaining'] as num?)?.toInt() ??
                  _appliedUpgrades.pitSaves)
              .clamp(0, 99)
              .toInt();

      _dungeonComplete = payload['dungeonComplete'] as bool? ?? false;
      _levelComplete = payload['levelComplete'] as bool? ?? false;
      _levelClearAcknowledged =
          payload['levelClearAcknowledged'] as bool? ?? false;
      _lastDamageSource = payload['lastDamageSource'] as String? ?? '-';
      _lastDamageAmount = 0;
      _damageAlertSeconds = 0;

      final targetZoom =
          (payload['targetCameraZoom'] as num?)?.toDouble() ?? _baseCameraZoom;
      final cameraZoom =
          (payload['cameraZoom'] as num?)?.toDouble() ?? _baseCameraZoom;
      final shouldFollow = payload['cameraFollow'] as bool? ?? false;
      double legacyTetherSeconds = 0;
      double legacyFireballSeconds = 0;
      double legacyNeedlesSeconds = 0;

      final timersRaw = payload['timers'];
      if (timersRaw is Map) {
        final timers = Map<String, dynamic>.from(timersRaw);
        _damageInvulnerabilityRemaining =
            (timers['damageInvulnerability'] as num?)?.toDouble() ?? 0;
        legacyTetherSeconds =
            (timers['tetherSecondsRemaining'] as num?)?.toDouble() ?? 0;
        legacyFireballSeconds =
            (timers['fireballSecondsRemaining'] as num?)?.toDouble() ?? 0;
        legacyNeedlesSeconds =
            (timers['needlesSecondsRemaining'] as num?)?.toDouble() ?? 0;
        _fireballCooldown =
            (timers['fireballCooldown'] as num?)?.toDouble() ?? 0;
        _needlesCooldown = (timers['needlesCooldown'] as num?)?.toDouble() ?? 0;
      } else {
        _damageInvulnerabilityRemaining = 0;
        _fireballCooldown = 0;
        _needlesCooldown = 0;
      }

      _abilityCharges.clear();
      _selectedPowerup = null;
      _activePowerup = null;
      _queuedTetherTarget = null;
      _activeTetherTarget = null;
      _clearPitHoverState();
      _pendingDebugSpawnPlacement = null;
      _queuedDebugSpawnPlacements.clear();

      final abilitiesRaw = payload['abilities'];
      if (abilitiesRaw is Map) {
        final abilities = Map<String, dynamic>.from(abilitiesRaw);
        final chargesRaw = abilities['charges'];
        if (chargesRaw is List) {
          for (final entry in chargesRaw) {
            if (entry is! Map) {
              continue;
            }
            final item = Map<String, dynamic>.from(entry);
            final type = _powerupTypeFromIndex((item['type'] as num?)?.toInt());
            if (type == null) {
              continue;
            }
            final count = ((item['count'] as num?)?.toInt() ?? 0).clamp(0, 99);
            if (count > 0) {
              _abilityCharges[type] = count;
            }
          }
        }

        _selectedPowerup = _powerupTypeFromIndex(
          (abilities['selected'] as num?)?.toInt(),
        );
        _activePowerup = _powerupTypeFromIndex(
          (abilities['active'] as num?)?.toInt(),
        );
        _queuedTetherTarget = _vector2FromJson(abilities['queuedTetherTarget']);
        _activeTetherTarget = _vector2FromJson(abilities['activeTetherTarget']);
      } else {
        if (legacyTetherSeconds > 0) {
          _abilityCharges[PowerupType.tether] = 1;
        }
        if (legacyFireballSeconds > 0) {
          _abilityCharges[PowerupType.fireball] = 1;
        }
        if (legacyNeedlesSeconds > 0) {
          _abilityCharges[PowerupType.needles] = 1;
        }
      }

      _selectedPowerup =
          _selectedPowerup != null && abilityChargesFor(_selectedPowerup!) > 0
          ? _selectedPowerup
          : null;
      if (_selectedPowerup != PowerupType.tether) {
        _queuedTetherTarget = null;
      }
      if (_activePowerup != PowerupType.tether) {
        _activeTetherTarget = null;
      } else if (_activeTetherTarget == null) {
        _activePowerup = null;
      }

      _isCharging = false;
      _spinDetector.reset();
      _isCameraGestureActive = false;
      _isCameraDragActive = false;

      final spinnerRaw = payload['spinner'];
      final levelStateRaw = payload['levelState'];
      final spinnerState = spinnerRaw is Map
          ? Map<String, dynamic>.from(spinnerRaw)
          : null;
      final levelState = levelStateRaw is Map
          ? Map<String, dynamic>.from(levelStateRaw)
          : null;

      _buildAndSpawnCurrentLevelFromSnapshot(
        spinnerState: spinnerState,
        levelState: levelState,
      );

      _targetCameraZoom = targetZoom.clamp(_planningMinZoom, _planningMaxZoom);
      camera.viewfinder.zoom = cameraZoom.clamp(
        _planningMinZoom,
        _planningMaxZoom,
      );
      if (shouldFollow && (_spinner?.isMoving ?? false)) {
        _attachCameraFollow(snap: true);
      } else {
        _detachCameraFollow();
      }

      _pausedByMenu = payload['pausedByMenu'] as bool? ?? false;
      if (_pausedByMenu) {
        pauseEngine();
      } else {
        resumeEngine();
      }

      overlays.remove('upgrade_menu');
      overlays.remove('start_flow');
      if (_runPhase == RunPhase.upgrading) {
        overlays.add('upgrade_menu');
      }
      if (_runPhase == RunPhase.startMenu || _runPhase == RunPhase.loadout) {
        overlays.add('start_flow');
      }

      _notifyHud();
      return true;
    } catch (_) {
      unawaited(_runSnapshotRepository.clear());
      return false;
    }
  }

  Map<String, dynamic> _buildRunSnapshotPayload() {
    final spinner = _spinner;
    final levelState = <String, dynamic>{
      'levelIndex': _currentLevelIndex,
      'enemies': _enemies.where((enemy) => !enemy.isDead).map((enemy) {
        final room = _enemyRooms[enemy];
        return <String, dynamic>{
          'type': enemy.type.index,
          'archetype': enemy.archetype.index,
          'x': enemy.position.x,
          'y': enemy.position.y,
          'vx': enemy.velocity.x,
          'vy': enemy.velocity.y,
          'angle': enemy.angle,
          'hp': enemy.hp,
          'maxHp': enemy.maxHp,
          'moveSpeed': enemy.moveSpeed,
          'contactDamage': enemy.contactDamage,
          'coinDrop': enemy.coinDrop,
          'fireRateMultiplier': enemy.fireRateMultiplier,
          'projectileDamageMultiplier': enemy.projectileDamageMultiplier,
          'projectileSpeedMultiplier': enemy.projectileSpeedMultiplier,
          'room': room?.toJson(),
        };
      }).toList(),
      'traps': _spawnTrapsAndPits
          ? _traps
                .map(
                  (trap) => <String, dynamic>{
                    'x': trap.position.x,
                    'y': trap.position.y,
                  },
                )
                .toList()
          : <Map<String, dynamic>>[],
      'pits': _spawnTrapsAndPits
          ? _pits
                .map(
                  (pit) => <String, dynamic>{
                    'x': pit.position.x,
                    'y': pit.position.y,
                    'radius': pit.radius,
                  },
                )
                .toList()
          : <Map<String, dynamic>>[],
      'chests': _chests.map((chest) {
        final room = _chestRooms[chest];
        return <String, dynamic>{
          'x': chest.position.x,
          'y': chest.position.y,
          'coinReward': chest.coinReward,
          'opened': chest.isOpened,
          'room': room?.toJson(),
        };
      }).toList(),
      'powerups': _powerups
          .where((powerup) => !powerup.isConsumed)
          .map(
            (powerup) => <String, dynamic>{
              'type': powerup.type.index,
              'x': powerup.position.x,
              'y': powerup.position.y,
              'durationSeconds': powerup.durationSeconds,
              'ageSeconds': powerup.ageSeconds,
            },
          )
          .toList(),
    };

    return <String, dynamic>{
      'schema': 3,
      'savedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
      'runPhase': _runPhase.index,
      'runEndReason': _runEndReason?.index,
      'runStats': _runStats.toJson(),
      'currentLevelIndex': _currentLevelIndex,
      'currentRoomPos': _currentRoomPos?.toJson(),
      'configuredRunSeed': _configuredRunSeed,
      'activeRunSeed': _activeRunSeed,
      'currentHp': _currentHp,
      'maxHp': _maxHp,
      'pitSavesRemaining': _pitSavesRemaining,
      'dungeonComplete': _dungeonComplete,
      'levelComplete': _levelComplete,
      'levelClearAcknowledged': _levelClearAcknowledged,
      'lastDamageSource': _lastDamageSource,
      'targetCameraZoom': _targetCameraZoom,
      'cameraZoom': camera.viewfinder.zoom,
      'cameraFollow': _isCameraFollowingSpinner,
      'pausedByMenu': _pausedByMenu,
      'timers': <String, dynamic>{
        'damageInvulnerability': _damageInvulnerabilityRemaining,
        'fireballCooldown': _fireballCooldown,
        'needlesCooldown': _needlesCooldown,
      },
      'abilities': <String, dynamic>{
        'charges': _abilityCharges.entries
            .map(
              (entry) => <String, dynamic>{
                'type': entry.key.index,
                'count': entry.value,
              },
            )
            .toList(),
        'selected': _selectedPowerup?.index,
        'active': _activePowerup?.index,
        'queuedTetherTarget': _vector2ToJson(_queuedTetherTarget),
        'activeTetherTarget': _vector2ToJson(_activeTetherTarget),
      },
      'levels': _levels.map((level) => level.toJson()).toList(),
      'spinner': spinner == null
          ? null
          : <String, dynamic>{
              'x': spinner.position.x,
              'y': spinner.position.y,
              'vx': spinner.velocity.x,
              'vy': spinner.velocity.y,
              'angle': spinner.angle,
              'angularVelocity': spinner.angularVelocity,
              'isMoving': spinner.isMoving,
              'precessionPhase': spinner.topPrecessionPhase,
              'nutationPhase': spinner.topNutationPhase,
            },
      'levelState': levelState,
    };
  }

  void _buildAndSpawnCurrentLevelFromSnapshot({
    required Map<String, dynamic>? spinnerState,
    required Map<String, dynamic>? levelState,
  }) {
    _clearActiveComponents();

    final level = _currentLevel;
    if (level == null) {
      return;
    }

    _applyThemeForLevel(levelNumber);
    _layoutLevel(level);
    _buildLevelGeometry(level);
    _spawnCenterBumpers(level);
    if (levelState != null &&
        (levelState['levelIndex'] as num?)?.toInt() == _currentLevelIndex) {
      _spawnLevelContentFromSnapshot(level, levelState);
    } else {
      _spawnLevelContent(level);
    }

    if (spinnerState != null) {
      _spawnSpinnerFromSnapshot(level, spinnerState);
    } else {
      _spawnSpinner(level);
    }
    _spawnQueuedDebugEnemiesForCurrentLevel();

    _isCharging = false;
    _spinDetector.reset();
    _spinner?.clearChargePreview();
    _syncRoomAndLevelState(notify: false);
    _syncCurrentRoomFromSpinner();

    _configureCamera();
    _notifyHud();
  }

  void _spawnLevelContentFromSnapshot(
    _LevelPlan level,
    Map<String, dynamic> levelState,
  ) {
    _enemyRooms.clear();
    _enemyBounds.clear();
    _chestRooms.clear();
    var carvedFloorForPits = false;

    for (final room in level.rooms.values) {
      if (room.type == RoomType.start) {
        room.cleared = true;
        room.visited = true;
      }
    }

    final enemiesRaw = levelState['enemies'];
    if (enemiesRaw is List) {
      for (final entry in enemiesRaw) {
        if (entry is! Map) {
          continue;
        }
        final json = Map<String, dynamic>.from(entry);
        final typeIndex = (json['type'] as num?)?.toInt() ?? 0;
        final type = typeIndex >= 0 && typeIndex < EnemyType.values.length
            ? EnemyType.values[typeIndex]
            : EnemyType.walker;
        final archetypeIndex = (json['archetype'] as num?)?.toInt();
        final archetype =
            archetypeIndex != null &&
                archetypeIndex >= 0 &&
                archetypeIndex < EnemyArchetype.values.length
            ? EnemyArchetype.values[archetypeIndex]
            : EnemyArchetype.standard;
        final enemy = EnemyComponent.restored(
          type: type,
          archetype: archetype,
          position: Vector2(
            (json['x'] as num?)?.toDouble() ?? 0,
            (json['y'] as num?)?.toDouble() ?? 0,
          ),
          maxHp: (json['maxHp'] as num?)?.toDouble() ?? 32,
          hp: (json['hp'] as num?)?.toDouble() ?? 32,
          moveSpeed: (json['moveSpeed'] as num?)?.toDouble() ?? 58,
          velocity: Vector2(
            (json['vx'] as num?)?.toDouble() ?? 0,
            (json['vy'] as num?)?.toDouble() ?? 0,
          ),
          contactDamage: (json['contactDamage'] as num?)?.toDouble() ?? 10,
          coinDrop: (json['coinDrop'] as num?)?.toInt() ?? 1,
          fireRateMultiplier:
              (json['fireRateMultiplier'] as num?)?.toDouble() ?? 1,
          projectileDamageMultiplier:
              (json['projectileDamageMultiplier'] as num?)?.toDouble() ?? 1,
          projectileSpeedMultiplier:
              (json['projectileSpeedMultiplier'] as num?)?.toDouble() ?? 1,
        );
        enemy.angle = (json['angle'] as num?)?.toDouble() ?? 0;
        _enemies.add(enemy);

        final room =
            _gridPosFromJson(json['room']) ??
            _findRoomForPoint(level, enemy.position);
        if (room != null) {
          _enemyRooms[enemy] = room;
          final roomPlan = level.rooms[room];
          if (roomPlan?.worldRect != null) {
            _enemyBounds[enemy] = roomPlan!.enemyClampRect;
          }
        }
        world.add(enemy);
      }
    }

    if (_spawnTrapsAndPits) {
      final trapsRaw = levelState['traps'];
      if (trapsRaw is List) {
        for (final entry in trapsRaw) {
          if (entry is! Map) {
            continue;
          }
          final json = Map<String, dynamic>.from(entry);
          final trap = TrapComponent(
            position: Vector2(
              (json['x'] as num?)?.toDouble() ?? 0,
              (json['y'] as num?)?.toDouble() ?? 0,
            ),
          );
          _traps.add(trap);
          world.add(trap);
        }
      }

      final pitsRaw = levelState['pits'];
      if (pitsRaw is List) {
        for (final entry in pitsRaw) {
          if (entry is! Map) {
            continue;
          }
          final json = Map<String, dynamic>.from(entry);
          final pit = PitComponent(
            position: Vector2(
              (json['x'] as num?)?.toDouble() ?? 0,
              (json['y'] as num?)?.toDouble() ?? 0,
            ),
            radius: (json['radius'] as num?)?.toDouble() ?? 24,
          );
          _pits.add(pit);
          world.add(pit);
          carvedFloorForPits =
              _carveFloorCellsForPit(pit) || carvedFloorForPits;
        }
      }
    }

    final chestsRaw = levelState['chests'];
    if (chestsRaw is List) {
      for (final entry in chestsRaw) {
        if (entry is! Map) {
          continue;
        }
        final json = Map<String, dynamic>.from(entry);
        final chest = ChestComponent(
          position: Vector2(
            (json['x'] as num?)?.toDouble() ?? 0,
            (json['y'] as num?)?.toDouble() ?? 0,
          ),
          coinReward: (json['coinReward'] as num?)?.toInt() ?? 0,
        );
        if (json['opened'] == true) {
          chest.open();
        }
        _chests.add(chest);
        final room =
            _gridPosFromJson(json['room']) ??
            _findRoomForPoint(level, chest.position);
        if (room != null) {
          _chestRooms[chest] = room;
        }
        world.add(chest);
      }
    }

    final powerupsRaw = levelState['powerups'];
    if (powerupsRaw is List) {
      for (final entry in powerupsRaw) {
        if (entry is! Map) {
          continue;
        }
        final json = Map<String, dynamic>.from(entry);
        final typeIndex = (json['type'] as num?)?.toInt() ?? 0;
        if (typeIndex < 0 || typeIndex >= PowerupType.values.length) {
          continue;
        }
        final powerup = PowerupComponent(
          type: PowerupType.values[typeIndex],
          position: Vector2(
            (json['x'] as num?)?.toDouble() ?? 0,
            (json['y'] as num?)?.toDouble() ?? 0,
          ),
          durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 14,
        );
        powerup.restoreState(
          ageSeconds: (json['ageSeconds'] as num?)?.toDouble() ?? 0,
          consumed: false,
        );
        _powerups.add(powerup);
        world.add(powerup);
      }
    }

    if (carvedFloorForPits) {
      _refreshFloorVisualsFromCells();
    }
  }

  void _spawnSpinnerFromSnapshot(
    _LevelPlan level,
    Map<String, dynamic> spinnerState,
  ) {
    final startRoom = level.rooms[level.start];
    if (startRoom == null) {
      _spawnSpinner(level);
      return;
    }

    final spinner = SpinnerComponent(
      position: Vector2(
        (spinnerState['x'] as num?)?.toDouble() ?? startRoom.center.x,
        (spinnerState['y'] as num?)?.toDouble() ?? startRoom.center.y,
      ),
    );
    spinner.configureForRun(
      damageMultiplier:
          _appliedUpgrades.damageMultiplier *
          _selectedBuildStats.damageMultiplier,
      friction:
          _appliedUpgrades.frictionRetention +
          _selectedBuildStats.frictionBonus,
      topPhysics: SpinnerTopPhysicsConfig.fromBuildStats(_selectedBuildStats),
    );
    spinner.configureBuildVisual(_selectedBuildStats);
    spinner.velocity = Vector2(
      (spinnerState['vx'] as num?)?.toDouble() ?? 0,
      (spinnerState['vy'] as num?)?.toDouble() ?? 0,
    );
    spinner.angle = (spinnerState['angle'] as num?)?.toDouble() ?? 0;
    spinner.angularVelocity =
        (spinnerState['angularVelocity'] as num?)?.toDouble() ?? 0;
    spinner.restoreTopMotionPhases(
      precessionPhase:
          (spinnerState['precessionPhase'] as num?)?.toDouble() ?? 0,
      nutationPhase: (spinnerState['nutationPhase'] as num?)?.toDouble() ?? 0,
    );
    spinner.isMoving = spinnerState['isMoving'] as bool? ?? false;
    if (!spinner.isMoving) {
      spinner.velocity = Vector2.zero();
      spinner.angularVelocity = 0;
    }

    _spinner = spinner;
    _currentRoomPos = _currentRoomPos ?? level.start;
    _wasSpinnerMoving = spinner.isMoving;
    world.add(spinner);
    clampSpinnerToArena(spinner);
  }

  _GridPos? _findRoomForPoint(_LevelPlan level, Vector2 point) {
    final offset = Offset(point.x, point.y);
    for (final entry in level.rooms.entries) {
      final rect = entry.value.worldRect;
      if (rect != null && rect.inflate(20).contains(offset)) {
        return entry.key;
      }
    }
    return null;
  }

  _GridPos? _gridPosFromJson(dynamic json) {
    if (json is! Map) {
      return null;
    }

    final x = (json['x'] as num?)?.toInt();
    final y = (json['y'] as num?)?.toInt();
    if (x == null || y == null) {
      return null;
    }
    return _GridPos(x, y);
  }

  Map<String, dynamic>? _vector2ToJson(Vector2? value) {
    if (value == null) {
      return null;
    }
    return <String, dynamic>{'x': value.x, 'y': value.y};
  }

  Vector2? _vector2FromJson(dynamic json) {
    if (json is! Map) {
      return null;
    }
    final x = (json['x'] as num?)?.toDouble();
    final y = (json['y'] as num?)?.toDouble();
    if (x == null || y == null) {
      return null;
    }
    return Vector2(x, y);
  }

  PowerupType? _powerupTypeFromIndex(int? index) {
    if (index == null || index < 0 || index >= PowerupType.values.length) {
      return null;
    }
    return PowerupType.values[index];
  }

  RunPhase _runPhaseFromIndex(int? index) {
    if (index == null || index < 0 || index >= RunPhase.values.length) {
      return RunPhase.playing;
    }
    return RunPhase.values[index];
  }

  RunEndReason? _runEndReasonFromIndex(int? index) {
    if (index == null || index < 0 || index >= RunEndReason.values.length) {
      return null;
    }
    return RunEndReason.values[index];
  }

  void _restoreSeedPreferencesFromSnapshot() {
    final payload = _pendingRunSnapshot;
    if (payload == null || payload.isEmpty) {
      return;
    }

    final configuredSeed = (payload['configuredRunSeed'] as num?)?.toInt();
    _configuredRunSeed = configuredSeed == null
        ? null
        : _normalizedSeed(configuredSeed);

    final activeSeed = (payload['activeRunSeed'] as num?)?.toInt();
    _activeRunSeed = activeSeed == null ? null : _normalizedSeed(activeSeed);
  }

  void _persistProgress() {
    if (!_progressLoaded || _progressSaveInFlight) {
      return;
    }

    _progressSaveInFlight = true;
    unawaited(
      _progressRepository
          .save(_progress)
          .catchError((_) => Future<void>.value())
          .whenComplete(() {
            _progressSaveInFlight = false;
          }),
    );
  }

  void _notifyHud() {
    hudTick.value += 1;
  }
}

class _LevelPlan {
  _LevelPlan({
    required this.width,
    required this.height,
    required this.start,
    required this.rooms,
    required this.roomScale,
    required this.tileSize,
    this.corridors = const <_CorridorPlan>[],
  });

  /// Tile dimensions of the whole map.
  final int width;
  final int height;
  final _GridPos start;
  final Map<_GridPos, _RoomPlan> rooms;
  final double roomScale;

  /// World units per tile.
  final double tileSize;

  /// L-shaped corridors connecting rooms (tile coordinates).
  final List<_CorridorPlan> corridors;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'width': width,
      'height': height,
      'start': start.toJson(),
      'roomScale': roomScale,
      'tileSize': tileSize,
      'rooms': rooms.values.map((room) => room.toJson()).toList(),
      'corridors': corridors.map((c) => c.toJson()).toList(),
    };
  }

  factory _LevelPlan.fromJson(Map<String, dynamic> json) {
    final width = (json['width'] as num?)?.toInt() ?? 4;
    final height = (json['height'] as num?)?.toInt() ?? 4;
    final start = _GridPos.fromJson(json['start']) ?? const _GridPos(0, 0);
    final roomScale = (json['roomScale'] as num?)?.toDouble() ?? 1.0;
    final tileSize = (json['tileSize'] as num?)?.toDouble() ?? 48.0;

    final rooms = <_GridPos, _RoomPlan>{};
    final roomsRaw = json['rooms'];
    if (roomsRaw is List) {
      for (final entry in roomsRaw) {
        if (entry is! Map) {
          continue;
        }
        final room = _RoomPlan.fromJson(Map<String, dynamic>.from(entry));
        rooms[room.position] = room;
      }
    }

    final corridors = <_CorridorPlan>[];
    final corridorsRaw = json['corridors'];
    if (corridorsRaw is List) {
      for (final entry in corridorsRaw) {
        if (entry is! Map) {
          continue;
        }
        corridors.add(_CorridorPlan.fromJson(Map<String, dynamic>.from(entry)));
      }
    }

    return _LevelPlan(
      width: width,
      height: height,
      start: start,
      rooms: rooms,
      roomScale: roomScale,
      tileSize: tileSize,
      corridors: corridors,
    );
  }
}

/// An L-shaped corridor between two room centres, in tile coordinates. Mirrors
/// [DungeonCorridor] from the generator.
class _CorridorPlan {
  const _CorridorPlan({
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
    required this.horizontalFirst,
    required this.width,
  });

  final int ax;
  final int ay;
  final int bx;
  final int by;
  final bool horizontalFirst;
  final int width;

  int get elbowX => horizontalFirst ? bx : ax;
  int get elbowY => horizontalFirst ? ay : by;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'ax': ax,
    'ay': ay,
    'bx': bx,
    'by': by,
    'horizontalFirst': horizontalFirst,
    'width': width,
  };

  factory _CorridorPlan.fromJson(Map<String, dynamic> json) {
    return _CorridorPlan(
      ax: (json['ax'] as num?)?.toInt() ?? 0,
      ay: (json['ay'] as num?)?.toInt() ?? 0,
      bx: (json['bx'] as num?)?.toInt() ?? 0,
      by: (json['by'] as num?)?.toInt() ?? 0,
      horizontalFirst: json['horizontalFirst'] as bool? ?? true,
      width: (json['width'] as num?)?.toInt() ?? 3,
    );
  }
}

class _RoomPlan {
  _RoomPlan({required this.position, this.tileW = 12, this.tileH = 12});

  final _GridPos position;

  /// Room rect size in tiles. The top-left tile is [position].
  int tileW;
  int tileH;

  int get tileX => position.x;
  int get tileY => position.y;

  /// Lossy cardinal adjacency (one neighbour per side) used for the
  /// enclosed-room check; for the full graph use [neighbors].
  final Map<RoomDirection, _GridPos> exits = <RoomDirection, _GridPos>{};

  /// Every room reachable directly via a corridor. Populated during generation
  /// and used for distance-from-start; not persisted.
  final List<_GridPos> neighbors = <_GridPos>[];
  final List<_InteriorWallPlan> interiorWalls = <_InteriorWallPlan>[];

  RoomType type = RoomType.combat;

  int turretCount = 0;
  int walkerCount = 0;
  int hedgehogCount = 0;
  int bossCount = 0;
  int paddleCount = 0;
  int pulserCount = 0;
  bool hasCenterBumper = false;
  int trapCount = 0;
  int pitCount = 0;
  int chestSpins = 0;
  int chestCoins = 0;
  int dangerTier = 1;
  bool precisionFocus = false;

  bool visited = false;
  bool cleared = false;
  bool chestOpened = false;

  /// See [DungeonRoom.roomTemplateId].
  String? roomTemplateId;
  int templateRotationQuarterTurns = 0;
  bool templateFlipH = false;
  bool templateFlipV = false;

  Rect? worldRect;

  Vector2 get center {
    final rect = worldRect!;
    return Vector2(rect.center.dx, rect.center.dy);
  }

  Rect get enemyClampRect => worldRect!.deflate(52);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'position': position.toJson(),
      'tileW': tileW,
      'tileH': tileH,
      'type': type.index,
      'turretCount': turretCount,
      'walkerCount': walkerCount,
      'hedgehogCount': hedgehogCount,
      'bossCount': bossCount,
      'paddleCount': paddleCount,
      'pulserCount': pulserCount,
      'hasCenterBumper': hasCenterBumper,
      'trapCount': trapCount,
      'pitCount': pitCount,
      'chestSpins': chestSpins,
      'chestCoins': chestCoins,
      'dangerTier': dangerTier,
      'precisionFocus': precisionFocus,
      'visited': visited,
      'cleared': cleared,
      'chestOpened': chestOpened,
      'exits': exits.entries
          .map(
            (entry) => <String, dynamic>{
              'direction': entry.key.index,
              'to': entry.value.toJson(),
            },
          )
          .toList(),
      'interiorWalls': interiorWalls
          .map((interiorWall) => interiorWall.toJson())
          .toList(),
      'roomTemplateId': roomTemplateId,
      'templateRotationQuarterTurns': templateRotationQuarterTurns,
      'templateFlipH': templateFlipH,
      'templateFlipV': templateFlipV,
    };
  }

  factory _RoomPlan.fromJson(Map<String, dynamic> json) {
    final position =
        _GridPos.fromJson(json['position']) ?? const _GridPos(0, 0);
    final room = _RoomPlan(
      position: position,
      tileW: (json['tileW'] as num?)?.toInt() ?? 12,
      tileH: (json['tileH'] as num?)?.toInt() ?? 12,
    );
    room.type = RoomTypeX.fromIndex((json['type'] as num?)?.toInt());
    room.turretCount = (json['turretCount'] as num?)?.toInt() ?? 0;
    room.walkerCount = (json['walkerCount'] as num?)?.toInt() ?? 0;
    room.hedgehogCount = (json['hedgehogCount'] as num?)?.toInt() ?? 0;
    room.bossCount = (json['bossCount'] as num?)?.toInt() ?? 0;
    room.paddleCount = (json['paddleCount'] as num?)?.toInt() ?? 0;
    room.pulserCount = (json['pulserCount'] as num?)?.toInt() ?? 0;
    room.hasCenterBumper = json['hasCenterBumper'] as bool? ?? false;
    room.trapCount = (json['trapCount'] as num?)?.toInt() ?? 0;
    room.pitCount = (json['pitCount'] as num?)?.toInt() ?? 0;
    room.chestSpins = (json['chestSpins'] as num?)?.toInt() ?? 0;
    room.chestCoins = (json['chestCoins'] as num?)?.toInt() ?? 0;
    room.dangerTier = (json['dangerTier'] as num?)?.toInt() ?? 1;
    room.precisionFocus = json['precisionFocus'] as bool? ?? false;
    room.visited = json['visited'] as bool? ?? false;
    room.cleared = json['cleared'] as bool? ?? false;
    room.chestOpened = json['chestOpened'] as bool? ?? false;
    room.roomTemplateId = json['roomTemplateId'] as String?;
    room.templateRotationQuarterTurns =
        (json['templateRotationQuarterTurns'] as num?)?.toInt() ?? 0;
    room.templateFlipH = json['templateFlipH'] as bool? ?? false;
    room.templateFlipV = json['templateFlipV'] as bool? ?? false;

    final exitsRaw = json['exits'];
    if (exitsRaw is List) {
      for (final entry in exitsRaw) {
        if (entry is! Map) {
          continue;
        }
        final direction = RoomDirectionX.fromIndex(
          (entry['direction'] as num?)?.toInt(),
        );
        final target = _GridPos.fromJson(entry['to']);
        if (direction != null && target != null) {
          room.exits[direction] = target;
        }
      }
    }

    // Ignore saved interior walls (re-enable when in-room walls are solid).
    room.interiorWalls.clear();

    return room;
  }
}

class _PendingDebugSpawnPlacement {
  const _PendingDebugSpawnPlacement({
    required this.levelIndex,
    required this.type,
    required this.archetype,
    required this.count,
  });

  final int levelIndex;
  final EnemyType type;
  final EnemyArchetype archetype;
  final int count;
}

class _QueuedDebugSpawnPlacement {
  const _QueuedDebugSpawnPlacement({
    required this.levelIndex,
    required this.normalizedX,
    required this.normalizedY,
    required this.type,
    required this.archetype,
    required this.count,
  });

  final int levelIndex;
  final double normalizedX;
  final double normalizedY;
  final EnemyType type;
  final EnemyArchetype archetype;
  final int count;
}

class _ThemeSprites {
  _ThemeSprites({
    required this.image,
    required this.floorTileSprites,
    required this.wangTileSpritesByKey,
    required this.lowerTerrainSprite,
    required this.upperTerrainSprite,
    this.wallTileSprites = const <Sprite>[],
    this.openFloorTileSprites = const <Sprite>[],
  });

  final ui.Image image;
  final List<Sprite> floorTileSprites;
  final Map<String, Sprite> wangTileSpritesByKey;
  final Sprite? lowerTerrainSprite;
  final Sprite? upperTerrainSprite;

  /// Dedicated wall texture variants (distinct from floor art), sliced from
  /// [DungeonThemeAssets.wallPngAsset]. Empty when the theme ships no wall art
  /// yet, in which case callers fall back to floor-sprite reuse.
  final List<Sprite> wallTileSprites;

  /// Variant tiles for fully-interior floor cells, sliced from
  /// [DungeonThemeAssets.openFloorPngAsset]. Empty when the theme ships none,
  /// in which case callers fall back to the plain Wang floor tile (which
  /// visibly repeats across large open rooms).
  final List<Sprite> openFloorTileSprites;
}

class _GridPos {
  const _GridPos(this.x, this.y);

  final int x;
  final int y;

  _GridPos step(RoomDirection direction) {
    switch (direction) {
      case RoomDirection.up:
        return _GridPos(x, y - 1);
      case RoomDirection.right:
        return _GridPos(x + 1, y);
      case RoomDirection.down:
        return _GridPos(x, y + 1);
      case RoomDirection.left:
        return _GridPos(x - 1, y);
    }
  }

  @override
  bool operator ==(Object other) {
    return other is _GridPos && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'x': x, 'y': y};
  }

  static _GridPos? fromJson(dynamic json) {
    if (json is! Map) {
      return null;
    }
    final x = (json['x'] as num?)?.toInt();
    final y = (json['y'] as num?)?.toInt();
    if (x == null || y == null) {
      return null;
    }
    return _GridPos(x, y);
  }
}

class _InteriorWallPlan {
  _InteriorWallPlan({
    required this.localPosition,
    required this.size,
    required this.side,
  });

  final Vector2 localPosition;
  final Vector2 size;
  final WallSide side;

  Rect get asLocalRect => Rect.fromCenter(
    center: Offset(localPosition.x, localPosition.y),
    width: size.x,
    height: size.y,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'localX': localPosition.x,
      'localY': localPosition.y,
      'sizeX': size.x,
      'sizeY': size.y,
      'side': side.index,
    };
  }
}

enum RoomType { start, combat, trap, treasure }

extension on RoomType {
  String get label {
    switch (this) {
      case RoomType.start:
        return 'Start Zone';
      case RoomType.combat:
        return 'Combat Zone';
      case RoomType.trap:
        return 'Trap Zone';
      case RoomType.treasure:
        return 'Treasure Zone';
    }
  }
}

extension RoomTypeX on RoomType {
  static RoomType fromIndex(int? index) {
    if (index == null || index < 0 || index >= RoomType.values.length) {
      return RoomType.combat;
    }
    return RoomType.values[index];
  }
}

enum RoomDirection { up, right, down, left }

extension on RoomDirection {
  RoomDirection get opposite {
    switch (this) {
      case RoomDirection.up:
        return RoomDirection.down;
      case RoomDirection.right:
        return RoomDirection.left;
      case RoomDirection.down:
        return RoomDirection.up;
      case RoomDirection.left:
        return RoomDirection.right;
    }
  }
}

extension RoomDirectionX on RoomDirection {
  static RoomDirection? fromIndex(int? index) {
    if (index == null || index < 0 || index >= RoomDirection.values.length) {
      return null;
    }
    return RoomDirection.values[index];
  }
}
