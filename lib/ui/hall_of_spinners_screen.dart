import 'package:flutter/material.dart';

import '../game/spinner_game.dart';
import '../systems/spinner_parts.dart';
import '../systems/upgrade_system.dart';
import 'workbench/wood_workbench_painter.dart';
import 'workbench/workbench_palette.dart';

/// Showcase scoreboard. Renders each leaderboard entry with the spinner build
/// the player used to achieve the score (chunky-cartoon styled), so finishing
/// a strong run is something you can come back and admire.
class HallOfSpinnersScreen extends StatefulWidget {
  const HallOfSpinnersScreen({super.key, required this.game});

  final SpinnerGame game;

  @override
  State<HallOfSpinnersScreen> createState() => _HallOfSpinnersScreenState();
}

class _HallOfSpinnersScreenState extends State<HallOfSpinnersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkbenchPalette.deepVoid,
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: widget.game.hudTick,
          builder: (context, _, __) {
            final allEntries = widget.game.leaderboardEntries;
            final weeklyKey = widget.game.weeklyKey;
            final weeklyEntries = allEntries
                .where((entry) => entry.weeklyKey == weeklyKey)
                .toList();

            return ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: WoodWorkbenchPainter(cornerRadius: 22),
                    ),
                  ),
                  Column(
                    children: [
                      _Header(
                        onClose: () => Navigator.of(context).pop(),
                        weeklyName: widget.game.weeklyChallengeName,
                        weeklyDates: widget.game.weeklyDateRangeLabel,
                      ),
                      _SegmentedTabs(controller: _tabController),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _LeaderboardList(
                              entries: allEntries,
                              emptyHint:
                                  'No runs yet. Survive a dungeon to claim your slot.',
                              game: widget.game,
                            ),
                            _LeaderboardList(
                              entries: weeklyEntries,
                              emptyHint:
                                  'No weekly attempts yet. Press "Play Weekly Run" on the menu.',
                              game: widget.game,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onClose,
    required this.weeklyName,
    required this.weeklyDates,
  });

  final VoidCallback onClose;
  final String weeklyName;
  final String weeklyDates;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: WorkbenchPalette.parchment),
            onPressed: onClose,
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hall of Spinners',
                  style: TextStyle(
                    color: WorkbenchPalette.parchment,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'This week: $weeklyName · $weeklyDates',
                  style: TextStyle(
                    color: WorkbenchPalette.parchment.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: WorkbenchPalette.woodDark.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: WorkbenchPalette.ink, width: 2),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            color: WorkbenchPalette.actionHighlight,
            borderRadius: BorderRadius.circular(8),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          labelColor: WorkbenchPalette.ink,
          unselectedLabelColor: WorkbenchPalette.parchment,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.6,
          ),
          tabs: const [
            Tab(text: 'ALL TIME'),
            Tab(text: 'THIS WEEK'),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.entries,
    required this.emptyHint,
    required this.game,
  });

  final List<LeaderboardEntry> entries;
  final String emptyHint;
  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            emptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: WorkbenchPalette.parchment.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _LeaderboardRow(
          rank: index + 1,
          entry: entries[index],
          game: game,
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.game,
  });

  final int rank;
  final LeaderboardEntry entry;
  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;
    final build = entry.build;
    final accent = isTop
        ? WorkbenchPalette.actionHighlight
        : WorkbenchPalette.ink.withValues(alpha: 0.85);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: WorkbenchPalette.woodDark.withValues(
          alpha: isTop ? 0.78 : 0.62,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: isTop ? 2.5 : 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            offset: const Offset(3, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            _RankBadge(rank: rank, accent: accent),
            const SizedBox(width: 12),
            BuildPreviewBadge(spinnerBuild: build, size: 60),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${entry.score}',
                        style: const TextStyle(
                          color: WorkbenchPalette.parchment,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'pts',
                        style: TextStyle(
                          color: WorkbenchPalette.parchment.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lv ${entry.deepestLevel} · ${entry.enemiesKilled} kills'
                    '${entry.maxSpinChain > 1 ? ' · chain ×${entry.maxSpinChain}' : ''}',
                    style: TextStyle(
                      color: WorkbenchPalette.parchment.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildSummary(build) ?? 'Spinner build not recorded',
                    style: TextStyle(
                      color: WorkbenchPalette.parchment.withValues(alpha: 0.65),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontStyle: build == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (entry.weeklyKey != null) ...[
              const SizedBox(width: 8),
              const _WeeklyTag(),
            ],
          ],
        ),
      ),
    );
  }

  String? _buildSummary(SpinnerBuild? build) {
    if (build == null) {
      return null;
    }
    final core = SpinnerPartCatalog.partById(build.coreId);
    final ring = SpinnerPartCatalog.partById(build.ringId);
    return '${core.name} · ${ring.name}';
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.accent});

  final int rank;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: rank == 1
            ? WorkbenchPalette.actionHighlight
            : WorkbenchPalette.deepVoid,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '#$rank',
        style: TextStyle(
          color: rank == 1
              ? WorkbenchPalette.ink
              : WorkbenchPalette.parchment,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _WeeklyTag extends StatelessWidget {
  const _WeeklyTag();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WorkbenchPalette.magicTint.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: WorkbenchPalette.magicTint.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          'WEEKLY',
          style: TextStyle(
            color: WorkbenchPalette.magicTint,
            fontWeight: FontWeight.w900,
            fontSize: 9,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

/// Compact diegetic preview of a spinner build: layered concentric rings of
/// each part's primary color, with a glow halo and three blade tips. Used in
/// the Hall of Spinners list so each row literally shows the spinner that
/// scored that run.
class BuildPreviewBadge extends StatelessWidget {
  const BuildPreviewBadge({
    super.key,
    required this.spinnerBuild,
    this.size = 64,
  });

  final SpinnerBuild? spinnerBuild;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BuildPreviewPainter(spinnerBuild: spinnerBuild),
      ),
    );
  }
}

class _BuildPreviewPainter extends CustomPainter {
  _BuildPreviewPainter({required this.spinnerBuild});

  final SpinnerBuild? spinnerBuild;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    final inkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = WorkbenchPalette.ink
      ..strokeWidth = 2;

    if (spinnerBuild == null) {
      // Silhouette for legacy entries with no recorded build.
      final dim = Paint()
        ..color = WorkbenchPalette.parchment.withValues(alpha: 0.18);
      canvas.drawCircle(center, r * 0.85, dim);
      canvas.drawCircle(center, r * 0.85, inkPaint);
      final tp = TextPainter(
        text: const TextSpan(
          text: '?',
          style: TextStyle(
            color: WorkbenchPalette.parchment,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
      return;
    }

    final core = SpinnerPartCatalog.partById(spinnerBuild!.coreId);
    final ring = SpinnerPartCatalog.partById(spinnerBuild!.ringId);
    final blade = SpinnerPartCatalog.partById(spinnerBuild!.bladeId);
    final glow = SpinnerPartCatalog.partById(spinnerBuild!.glowId);

    // Glow halo.
    final glowPaint = Paint()
      ..color = glow.primaryColor.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, r * 0.95, glowPaint);

    // Outer ring.
    final ringPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[ring.primaryColor, ring.secondaryColor],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r * 0.85, ringPaint);
    canvas.drawCircle(center, r * 0.85, inkPaint);

    // Three blade tips on the outer ring.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final bladePaint = Paint()..color = blade.primaryColor;
    final bladeOutline = Paint()
      ..style = PaintingStyle.stroke
      ..color = WorkbenchPalette.ink
      ..strokeWidth = 1.4;
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate(i * 2 * 3.14159 / 3);
      final path = Path()
        ..moveTo(r * 0.55, -r * 0.22)
        ..quadraticBezierTo(r * 1.05, 0, r * 0.55, r * 0.22)
        ..close();
      canvas.drawPath(path, bladePaint);
      canvas.drawPath(path, bladeOutline);
      canvas.restore();
    }
    canvas.restore();

    // Core inset.
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[core.primaryColor, core.secondaryColor],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.6));
    canvas.drawCircle(center, r * 0.42, corePaint);
    canvas.drawCircle(center, r * 0.42, inkPaint);

    // Accent dot.
    final accentPaint = Paint()..color = core.accentColor;
    canvas.drawCircle(center, r * 0.13, accentPaint);
    canvas.drawCircle(
      center,
      r * 0.13,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = WorkbenchPalette.ink
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _BuildPreviewPainter oldDelegate) =>
      oldDelegate.spinnerBuild?.coreId != spinnerBuild?.coreId ||
      oldDelegate.spinnerBuild?.ringId != spinnerBuild?.ringId ||
      oldDelegate.spinnerBuild?.bladeId != spinnerBuild?.bladeId ||
      oldDelegate.spinnerBuild?.glowId != spinnerBuild?.glowId;
}
