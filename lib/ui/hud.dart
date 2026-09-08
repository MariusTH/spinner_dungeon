import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/enemy_component.dart';
import '../game/powerup_component.dart';
import '../game/spinner_game.dart';
import 'workbench/workbench_palette.dart';

String _formatInvasionTime(double seconds) {
  final s = seconds.floor().clamp(0, 359999);
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});

  static const String overlayId = 'hud';

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<int>(
        valueListenable: game.hudTick,
        builder: (context, _, __) {
          if (game.showStartMenu || game.showLoadoutBuilder) {
            return const SizedBox.shrink();
          }
          return Stack(
            children: [
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: game.toggleHudDebugOverlay,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _GameplayEssentialsStrip(game: game),
                      ),
                    ),
                    if (game.hudDebugOverlayVisible) ...[
                      const SizedBox(height: 8),
                      _HudDebugRunPanel(game: game),
                    ],
                    if (game.showDamageAlert) ...[
                      const SizedBox(height: 8),
                      IgnorePointer(child: _DamageAlertBanner(game: game)),
                    ],
                    if (game.showUnlockToast) ...[
                      const SizedBox(height: 8),
                      IgnorePointer(child: _UnlockToast(game: game)),
                    ],
                  ],
                ),
              ),
              if (game.showTutorialSpinPrompt ||
                  game.showTutorialGoalPrompt ||
                  game.showTutorialDepthPrompt)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: game.showAbilitySelectionPanel ? 96 : 24,
                  child: IgnorePointer(child: _TutorialPrompt(game: game)),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: _HudButtons(game: game, parentContext: context),
              ),
              if (game.debugSpawnPlacementArmed)
                Positioned(
                  top: 54,
                  right: 12,
                  child: IgnorePointer(
                    child: _DebugPlacementBanner(
                      text: game.debugSpawnPlacementLabel,
                    ),
                  ),
                ),
              if (!game.progressLoaded)
                const Center(child: _LoadingBanner())
              else if (game.runPhase == RunPhase.runOver)
                Center(child: _RunOverBanner(game: game))
              else if (game.levelComplete) ...[
                if (!game.levelClearAcknowledged) ...[
                  // Full-screen pass-through so the playfield can receive
                  // spin gestures. The footer is a separate sibling painted
                  // above this.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: _LevelClearBanner(
                          text: game.levelClearBannerText,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _LevelClearFooter(
                      label: 'Continue',
                      onPressed: game.acknowledgeLevelClear,
                    ),
                  ),
                ] else
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _LevelClearFooter(
                      label: 'Descend',
                      compact: true,
                      onPressed: game.tryAdvanceAfterLevelClear,
                    ),
                  ),
              ],
              if (game.pausedByMenu)
                const Center(
                  child: _BannerCard(
                    text: 'PAUSED',
                    borderColor: Color(0xFF8AD7F2),
                    background: Color(0xCC163144),
                    foreground: Color(0xFFE6F8FF),
                  ),
                ),
              if (game.showAbilitySelectionPanel)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _AbilitySelectionPanel(game: game),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GameplayEssentialsStrip extends StatelessWidget {
  const _GameplayEssentialsStrip({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 228),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: WorkbenchPalette.woodDark.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WorkbenchPalette.ink, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              offset: const Offset(3, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChunkyMiniStatBar(
                label: 'HP ${game.currentHp}/${game.maxHp}',
                ratio: game.hpRatio,
                fill: const Color(0xFF57D16F),
              ),
              const SizedBox(height: 6),
              Text(
                'Hold for debug info',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: WorkbenchPalette.parchment.withValues(alpha: 0.42),
                ),
              ),
              if (game.bladeStanceHudHint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  game.bladeStanceHudHint,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: WorkbenchPalette.actionHighlight.withValues(
                      alpha: 0.85,
                    ),
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChunkyMiniStatBar extends StatelessWidget {
  const _ChunkyMiniStatBar({
    required this.label,
    required this.ratio,
    required this.fill,
  });

  final String label;
  final double ratio;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: WorkbenchPalette.parchment,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: WorkbenchPalette.ink.withValues(alpha: 0.65),
                      border: Border.all(
                        color: WorkbenchPalette.woodEdge,
                        width: 1,
                      ),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: clamped,
                  child: DecoratedBox(decoration: BoxDecoration(color: fill)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HudDebugRunPanel extends StatelessWidget {
  const _HudDebugRunPanel({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 344, minWidth: 252),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xC3121B2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF34445F)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: WorkbenchPalette.actionHighlight.withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: WorkbenchPalette.actionHighlight.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ),
                child: const Text(
                  'RUN DEBUG',
                  style: TextStyle(
                    color: WorkbenchPalette.parchment,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (game.isInvasionMode) ...[
                    _InfoChip(text: 'Infinite Invasion'),
                    _InfoChip(text: 'Kills ${game.invasionKills}'),
                    _InfoChip(
                      text: _formatInvasionTime(game.invasionElapsedSeconds),
                    ),
                    _InfoChip(text: 'Score ${game.runScore}'),
                  ] else ...[
                    _InfoChip(
                      text: 'Lv ${game.levelNumber}/${game.totalLevels}',
                    ),
                    _InfoChip(text: 'Score ${game.runScore}'),
                    _InfoChip(text: 'Coins ${game.runCoins}'),
                    _InfoChip(
                      text:
                          'Zone ${game.zonesClearedInLevel}/${game.zonesInLevel}',
                    ),
                  ],
                  if (game.spinnerMoving && game.spinChainKills >= 2)
                    _InfoChip(text: 'Chain ×${game.spinChainKills}'),
                ],
              ),
              const SizedBox(height: 8),
              _RunSeedRow(game: game),
              const SizedBox(height: 8),
              _MiniStatBar(
                label: 'HP ${game.currentHp}/${game.maxHp}',
                ratio: game.hpRatio,
                fill: const Color(0xFF57D16F),
              ),
              const SizedBox(height: 6),
              if (!game.isInvasionMode)
                _MiniStatBar(
                  label:
                      'Dungeon ${game.zonesClearedInLevel}/${game.zonesInLevel}',
                  ratio: game.levelProgressRatio,
                  fill: const Color(0xFF6CCBFF),
                ),
              if (game.isInvasionMode)
                _MiniStatBar(
                  label: 'Survive — do not let them reach you',
                  ratio: 1.0,
                  fill: const Color(0xFF6CCBFF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2538),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF3A4D6A)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MiniStatBar extends StatelessWidget {
  const _MiniStatBar({
    required this.label,
    required this.ratio,
    required this.fill,
  });

  final String label;
  final double ratio;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFEAF2FF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1322),
                      border: Border.all(color: const Color(0xFF2D3D57)),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: clamped,
                  child: DecoratedBox(decoration: BoxDecoration(color: fill)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RunSeedRow extends StatelessWidget {
  const _RunSeedRow({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    final seed = game.activeRunSeed;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2538),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF3A4D6A)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                'Seed ${game.activeRunSeedLabel}',
                style: const TextStyle(
                  color: Color(0xFFEAF2FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            InkWell(
              onTap: seed == null
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: seed.toString()),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied seed $seed'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: seed == null
                      ? const Color(0xFF6B7A8E)
                      : const Color(0xFFAED7FF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DamageAlertBanner extends StatelessWidget {
  const _DamageAlertBanner({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: game.damageAlertOpacity,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE0311116),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFED6F6F), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              game.damageAlertText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFC6C6),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DebugPlacementBanner extends StatelessWidget {
  const _DebugPlacementBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE0302412),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3A048)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFFD8A7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HudButtons extends StatelessWidget {
  const _HudButtons({required this.game, required this.parentContext});

  final SpinnerGame game;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final canInteract =
        game.progressLoaded && game.runPhase == RunPhase.playing;
    final canDebugInteract =
        game.canOpenDebugSpawner && !game.spinnerMoving && !game.isCharging;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xAA10131A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3446)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: canDebugInteract
                ? () => _showDebugSpawnerDialog(parentContext, game)
                : null,
            icon: Icon(
              Icons.bug_report_outlined,
              color: game.debugSpawnPlacementArmed
                  ? const Color(0xFFFFC16A)
                  : Colors.white,
            ),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            tooltip: game.debugSpawnPlacementArmed
                ? game.debugSpawnPlacementLabel
                : 'Debug Spawn',
          ),
          IconButton(
            onPressed: canInteract
                ? () => _showHelpDialog(parentContext, game)
                : null,
            icon: const Icon(Icons.help_outline, color: Colors.white),
            tooltip: 'Help',
          ),
          IconButton(
            onPressed: canInteract
                ? () => _showStatsDialog(parentContext, game)
                : null,
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            tooltip: 'Stats',
          ),
          IconButton(
            onPressed: canInteract
                ? () => _showPauseDialog(parentContext, game)
                : null,
            icon: const Icon(Icons.pause_circle_outline, color: Colors.white),
            tooltip: 'Pause',
          ),
        ],
      ),
    );
  }
}

void _showHelpDialog(BuildContext context, SpinnerGame game) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF161B27),
      title: const Text('How To Play', style: TextStyle(color: Colors.white)),
      content: const Text(
        '1 finger near spinner: draw circles then swipe and release to launch.\n\n'
        'When stopped: choose an ability from the bottom panel before your next launch.\n\n'
        '2 fingers: pan and zoom the camera to scout.\n\n'
        'Collect coins, unlock abilities, and clear all 10 levels to defeat the final boss.',
        style: TextStyle(color: Color(0xFFCFD8EB)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showStatsDialog(BuildContext context, SpinnerGame game) {
  final launchPower = (game.chargeAmount * 10).clamp(0, 100).round();
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF161B27),
      title: const Text('Run Stats', style: TextStyle(color: Colors.white)),
      content: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFFCFD8EB), fontSize: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dungeon ${game.levelNumber}/${game.totalLevels}'),
            Text('Zone ${game.zoneCoordinateLabel} (${game.zoneTypeLabel})'),
            Text('Zones ${game.zonesClearedInLevel}/${game.zonesInLevel}'),
            Text('HP ${game.currentHp}/${game.maxHp}'),
            Text('Enemies ${game.enemiesRemaining}'),
            Text('Powerups ${game.activePowerupsLabel}'),
            Text('Score ${game.runScore}'),
            Text('Coins ${game.runCoins} | Bank ${game.bankedCoins}'),
            Text('Speed ${game.spinnerSpeed.toStringAsFixed(0)}'),
            Text('Charge $launchPower%'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showPauseDialog(BuildContext context, SpinnerGame game) {
  game.pauseFromHud();
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF161B27),
      title: const Text('Paused', style: TextStyle(color: Colors.white)),
      content: const Text(
        'Game is paused.',
        style: TextStyle(color: Color(0xFFCFD8EB)),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            game.resumeFromHud();
          },
          child: const Text('Resume'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            game.returnToMainMenuFromHud();
          },
          child: const Text('Main Menu'),
        ),
      ],
    ),
  );
}

void _showDebugSpawnerDialog(BuildContext context, SpinnerGame game) {
  var selectedType = EnemyType.walker;
  var selectedArchetype = EnemyArchetype.standard;
  var spawnCount = 1;
  final levelCap = game.totalLevels > 0 ? game.totalLevels : game.levelNumber;
  var selectedLevel = game.levelNumber.clamp(1, levelCap).toInt();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: const Color(0xFF161B27),
        title: const Text(
          'Debug Enemy Spawner',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Target Level',
                style: TextStyle(
                  color: Color(0xFFCFD8EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: selectedLevel,
                dropdownColor: const Color(0xFF1B2232),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: <DropdownMenuItem<int>>[
                  for (var level = 1; level <= levelCap; level++)
                    DropdownMenuItem<int>(
                      value: level,
                      child: Text(
                        level == game.levelNumber
                            ? 'Level $level (Current)'
                            : 'Level $level',
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    selectedLevel = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Enemy Type',
                style: TextStyle(
                  color: Color(0xFFCFD8EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<EnemyType>(
                initialValue: selectedType,
                dropdownColor: const Color(0xFF1B2232),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: EnemyType.values
                    .map(
                      (type) => DropdownMenuItem<EnemyType>(
                        value: type,
                        child: Text(game.enemyTypeLabel(type)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    selectedType = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Archetype',
                style: TextStyle(
                  color: Color(0xFFCFD8EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<EnemyArchetype>(
                initialValue: selectedArchetype,
                dropdownColor: const Color(0xFF1B2232),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: EnemyArchetype.values
                    .map(
                      (archetype) => DropdownMenuItem<EnemyArchetype>(
                        value: archetype,
                        child: Text(game.enemyArchetypeLabel(archetype)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    selectedArchetype = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Count',
                    style: TextStyle(
                      color: Color(0xFFCFD8EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: spawnCount > 1
                        ? () {
                            setState(() {
                              spawnCount -= 1;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.white,
                    iconSize: 20,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$spawnCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: spawnCount < 25
                        ? () {
                            setState(() {
                              spawnCount += 1;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: Colors.white,
                    iconSize: 20,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                selectedLevel == game.levelNumber
                    ? 'Spawn Here adds enemies immediately in the current level.'
                    : 'Spawn Here is disabled for non-current levels.',
                style: const TextStyle(color: Color(0xFF9BB0C8), fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          if (game.debugSpawnPlacementArmed)
            TextButton(
              onPressed: () {
                game.cancelDebugSpawnAtLocation();
                setState(() {});
                ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                  const SnackBar(
                    content: Text('Canceled pending spawn placement.'),
                  ),
                );
              },
              child: const Text('Cancel Pending'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          OutlinedButton(
            onPressed: () {
              final armed = game.armDebugSpawnAtLocation(
                levelNumber: selectedLevel,
                type: selectedType,
                archetype: selectedArchetype,
                count: spawnCount,
              );
              if (!armed) {
                ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Can only arm placement while spinner is idle.',
                    ),
                  ),
                );
                return;
              }

              Navigator.of(dialogContext).pop();
              final typeLabel = game.enemyTypeLabel(selectedType);
              final archetypeLabel = game.enemyArchetypeLabel(
                selectedArchetype,
              );
              final target =
                  'Level $selectedLevel • $spawnCount $archetypeLabel $typeLabel';
              final hint = selectedLevel == game.levelNumber
                  ? 'Tap on the map to place.'
                  : 'Tap on the map to place relative position for that level.';
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text('Spawn armed: $target. $hint')),
              );
            },
            child: const Text('Spawn At Location'),
          ),
          FilledButton(
            onPressed: selectedLevel == game.levelNumber
                ? () {
                    final spawned = game.spawnDebugEnemies(
                      type: selectedType,
                      archetype: selectedArchetype,
                      count: spawnCount,
                    );
                    final typeLabel = game.enemyTypeLabel(selectedType);
                    final archetypeLabel = game.enemyArchetypeLabel(
                      selectedArchetype,
                    );
                    final message = spawned <= 0
                        ? 'Could not spawn enemies right now.'
                        : 'Spawned $spawned $archetypeLabel $typeLabel';
                    ScaffoldMessenger.maybeOf(
                      dialogContext,
                    )?.showSnackBar(SnackBar(content: Text(message)));
                  }
                : null,
            child: const Text('Spawn Here'),
          ),
        ],
      ),
    ),
  );
}

class _AbilitySelectionPanel extends StatelessWidget {
  const _AbilitySelectionPanel({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    final selected = game.selectedPowerup;
    final options = game.availablePowerups;
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD1111928),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF34445F)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Ability Before Launch',
              style: TextStyle(
                color: Color(0xFFEAF2FF),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in options)
                  _AbilityButton(
                    label:
                        '${game.powerupLabel(type)} x${game.abilityChargesFor(type)}',
                    selected: selected == type,
                    color: _powerupColor(type),
                    onPressed: () => game.selectPowerupForNextSpin(type),
                  ),
                if (selected != null)
                  _AbilityButton(
                    label: 'Clear',
                    selected: false,
                    color: const Color(0xFF9099A9),
                    onPressed: () => game.selectPowerupForNextSpin(null),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _statusText(game),
              style: const TextStyle(
                color: Color(0xFFCFD8EB),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(SpinnerGame game) {
    final selected = game.selectedPowerup;
    if (selected == null) {
      return 'Optional: pick an ability, then launch.';
    }
    if (selected == PowerupType.tether && !game.selectedPowerupReady) {
      return 'Tether selected: tap in the arena to choose anchor point.';
    }
    if (selected == PowerupType.tether) {
      return 'Tether anchor set. Launch to keep it active until you stop.';
    }
    return '${game.powerupLabel(selected)} armed until spinner stops.';
  }
}

class _AbilityButton extends StatelessWidget {
  const _AbilityButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withAlpha(205) : const Color(0xFF1A2538),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : const Color(0xFF3A4D6A),
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

Color _powerupColor(PowerupType type) {
  switch (type) {
    case PowerupType.tether:
      return const Color(0xFF66D2FF);
    case PowerupType.fireball:
      return const Color(0xFFFF875C);
    case PowerupType.needles:
      return const Color(0xFFA4FFD0);
    case PowerupType.spinRefill:
      return const Color(0xFFFFD54A);
  }
}

class _LevelClearBanner extends StatelessWidget {
  const _LevelClearBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _BannerCard(
      text: text,
      borderColor: const Color(0xFF8AD7F2),
      background: const Color(0xCC163144),
      foreground: const Color(0xFFE6F8FF),
    );
  }
}

class _LevelClearFooter extends StatelessWidget {
  const _LevelClearFooter({
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// True for the small persistent "Descend" control shown after the player
  /// has tapped Continue and is free to keep exploring the cleared floor.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: WorkbenchPalette.deepVoid.withValues(
                  alpha: compact ? 0.72 : 0.88,
                ),
                border: Border(
                  top: BorderSide(
                    color: WorkbenchPalette.actionHighlight.withValues(
                      alpha: 0.5,
                    ),
                    width: 2,
                  ),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    offset: const Offset(0, -2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  compact ? 6 : 10,
                  12,
                  compact ? 6 : 10,
                ),
                child: FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E4D7A),
                    foregroundColor: const Color(0xFFE6F8FF),
                    padding: EdgeInsets.symmetric(vertical: compact ? 10 : 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 14 : 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner();

  @override
  Widget build(BuildContext context) {
    return const _BannerCard(
      text: 'LOADING PROGRESSION',
      borderColor: Color(0xFF5ED2F7),
      background: Color(0xCC123142),
      foreground: Color(0xFFE2F8FF),
    );
  }
}

class _RunOverBanner extends StatelessWidget {
  const _RunOverBanner({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    final chainNote = game.maxSpinChainThisRun > 1
        ? '\nBest chain this run: ×${game.maxSpinChainThisRun}'
        : '';
    final newDeepest = game.newDeepestThisRun;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC3B1C1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF07373), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'RUN OVER',
              style: TextStyle(
                color: Color(0xFFFFE5E5),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            if (newDeepest) ...[
              const SizedBox(height: 6),
              const _NewDeepestChip(),
            ],
            const SizedBox(height: 6),
            Text(
              '${game.runEndReasonLabel}\n'
              'Score ${game.runScore} · Deepest level ${game.levelNumber}'
              '$chainNote\n'
              'Tap to return to the main menu',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFE5E5),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewDeepestChip extends StatelessWidget {
  const _NewDeepestChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WorkbenchPalette.actionHighlight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WorkbenchPalette.ink, width: 2),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          'NEW DEEPEST!',
          style: TextStyle(
            color: WorkbenchPalette.ink,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _UnlockToast extends StatelessWidget {
  const _UnlockToast({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: game.unlockToastOpacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: WorkbenchPalette.deepVoid.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: WorkbenchPalette.actionHighlight,
            width: 2.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(2, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium,
                color: WorkbenchPalette.actionHighlight,
                size: 22,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.unlockToastText,
                      style: const TextStyle(
                        color: WorkbenchPalette.actionHighlight,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (game.unlockToastSubtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          game.unlockToastSubtitle,
                          style: TextStyle(
                            color: WorkbenchPalette.parchment.withValues(
                              alpha: 0.85,
                            ),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPrompt extends StatelessWidget {
  const _TutorialPrompt({required this.game});

  final SpinnerGame game;

  ({String title, String body}) _content() {
    if (game.showTutorialSpinPrompt) {
      return (
        title: 'Drag in circles to spin',
        body:
            'Hold a finger near your spinner and circle around it. Release to launch.',
      );
    }
    if (game.showTutorialGoalPrompt) {
      return (
        title: 'Smash the dungeon',
        body:
            'Crash through every enemy in a level to open the path to the next floor.',
      );
    }
    return (
      title: 'Descend deeper for unlocks',
      body:
          'Each new floor banks coins and unlocks new spinner parts. Defeat the Warden on Lv 10.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _content();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: WorkbenchPalette.deepVoid.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: WorkbenchPalette.actionHighlight,
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                offset: const Offset(2, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title.toUpperCase(),
                  style: const TextStyle(
                    color: WorkbenchPalette.actionHighlight,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.body,
                  style: TextStyle(
                    color: WorkbenchPalette.parchment.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.text,
    required this.borderColor,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color borderColor;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foreground,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
