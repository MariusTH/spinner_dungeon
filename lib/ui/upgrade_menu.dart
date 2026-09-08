import 'package:flutter/material.dart';

import '../game/spinner_game.dart';
import '../systems/spinner_parts.dart';
import '../systems/upgrade_system.dart';

class UpgradeMenuOverlay extends StatelessWidget {
  const UpgradeMenuOverlay({super.key, required this.game});

  static const String overlayId = 'upgrade_menu';

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD9111420),
      child: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: game.hudTick,
          builder: (context, _, __) {
            if (!game.showUpgradeMenu) {
              return const SizedBox.shrink();
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B27),
                    border: Border.all(color: const Color(0xFF33435F)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Upgrades',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          game.upgradeMenuOpenedFromMain
                              ? 'Spend banked coins on permanent power. '
                                  'Start a dungeon from the main menu when you are ready.'
                              : 'Meta progress and last run (legacy)',
                          style: const TextStyle(
                            color: Color(0xFFCFD8EB),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Banked ${game.bankedCoins}  ·  Best ${game.bestScore}  ·  '
                          'Runs ${game.totalRuns}  ·  Deepest Lv ${game.deepestLevelReached}',
                          style: const TextStyle(color: Color(0xFF9EB0D0)),
                        ),
                        if (game.leaderboardEntries.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Top runs (local)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...game.leaderboardEntries.asMap().entries.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _LeaderboardRow(
                                    rank: e.key + 1,
                                    entry: e.value,
                                  ),
                                ),
                              ),
                        ],
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFF31405A)),
                        const SizedBox(height: 8),
                        const Text(
                          'Permanent Upgrades',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView(
                            children: [
                              ...game.upgradeDefinitions.map(
                                (definition) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _UpgradeCard(
                                    game: game,
                                    definition: definition,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Divider(color: Color(0xFF31405A)),
                              const SizedBox(height: 8),
                              const Text(
                                'Dungeon Abilities (Coin Unlock)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...game.dungeonAbilities.map(
                                (ability) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _AbilityCard(
                                    game: game,
                                    ability: ability,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Divider(color: Color(0xFF31405A)),
                              const SizedBox(height: 8),
                              const Text(
                                'Spinner Gear Tasks',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...game.gearTaskProgress.map(
                                (task) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _TaskCard(task: task),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (game.upgradeMenuOpenedFromMain) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: game.closeUpgradeMenuToMainMenu,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE4ECFA),
                                side: const BorderSide(color: Color(0xFF5C6B86)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Back to main menu'),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: game.openLoadoutBuilder,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDAE8FC),
                                  side: const BorderSide(
                                    color: Color(0xFF58739A),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text(
                                  'Build Spinner',
                                  style: TextStyle(fontSize: 17),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: game.canStartRunFromHub
                                    ? game.startRunFromUpgradeHub
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D9FE8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text(
                                  'Play',
                                  style: TextStyle(fontSize: 17),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.game, required this.definition});

  final SpinnerGame game;
  final UpgradeDefinition definition;

  @override
  Widget build(BuildContext context) {
    final tier = game.upgradeTier(definition.type);
    final maxTier = definition.maxTier;
    final nextCost = game.upgradeCost(definition.type);
    final canBuy = game.canPurchaseUpgrade(definition.type);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF212A3D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF344865)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tier $tier/$maxTier',
                    style: const TextStyle(color: Color(0xFFC2CDE0)),
                  ),
                  Text(
                    'Current: ${game.upgradeCurrentEffect(definition.type)}',
                    style: const TextStyle(color: Color(0xFFA7BEDD)),
                  ),
                  if (nextCost != null)
                    Text(
                      'Next: ${game.upgradeNextEffect(definition.type)}',
                      style: const TextStyle(color: Color(0xFFA7BEDD)),
                    )
                  else
                    const Text(
                      'Maxed',
                      style: TextStyle(color: Color(0xFF8FE0A2)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: canBuy
                  ? () => game.purchaseUpgrade(definition.type)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A5A82),
                foregroundColor: Colors.white,
              ),
              child: Text(nextCost == null ? 'Max' : 'Buy $nextCost'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbilityCard extends StatelessWidget {
  const _AbilityCard({required this.game, required this.ability});

  final SpinnerGame game;
  final DungeonAbility ability;

  @override
  Widget build(BuildContext context) {
    final unlocked = game.isAbilityUnlocked(ability);
    final cost = game.abilityUnlockCost(ability);
    final canBuy = game.canUnlockAbility(ability);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF212A3D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF344865)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${game.abilityLabel(ability)} ${unlocked ? "(Unlocked)" : ""}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (cost != null)
              ElevatedButton(
                onPressed: canBuy ? () => game.unlockAbility(ability) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A5A82),
                  foregroundColor: Colors.white,
                ),
                child: Text(unlocked ? 'Owned' : 'Unlock $cost'),
              )
            else
              const Text('Starter', style: TextStyle(color: Color(0xFF8FE0A2))),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final SpinnerGearTaskProgress task;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2739),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.isComplete
              ? const Color(0xFF4EA772)
              : const Color(0xFF344865),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.definition.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              task.definition.description,
              style: const TextStyle(color: Color(0xFFB6C6DE), fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              task.progressLabel,
              style: TextStyle(
                color: task.isComplete
                    ? const Color(0xFF93E7AF)
                    : const Color(0xFFCFD8EB),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(entry.recordedAtMs);
    final dateStr =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final chain =
        entry.maxSpinChain > 1 ? ' · chain ×${entry.maxSpinChain}' : '';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF33435F)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Color(0xFF8DB9E8),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${entry.score} pts · Lv ${entry.deepestLevel} · '
                '${entry.enemiesKilled} kills$chain · $dateStr',
                style: const TextStyle(color: Color(0xFFCFD8EB), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
