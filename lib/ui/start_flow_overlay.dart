import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/spinner_game.dart';
import 'hall_of_spinners_screen.dart';
import 'workbench/spinner_workbench_screen.dart';
import 'workbench/wood_workbench_painter.dart';
import 'workbench/workbench_buttons.dart';
import 'workbench/workbench_palette.dart';

/// Chunky display font for the start menu (logo-adjacent arcade feel).
TextStyle _startMenuLinkStyle({
  required double size,
  required Color color,
}) {
  return GoogleFonts.bungee(
    fontSize: size,
    color: color,
    height: 1.15,
    letterSpacing: 0.4,
    shadows: const <Shadow>[
      Shadow(
        color: Color(0xB0181008),
        offset: Offset(1.4, 1.4),
        blurRadius: 0,
      ),
      Shadow(
        color: Color(0x55181008),
        offset: Offset(0, 2.5),
        blurRadius: 5,
      ),
    ],
  );
}

class _StartMenuTextLink extends StatelessWidget {
  const _StartMenuTextLink({
    required this.label,
    this.onPressed,
    this.size = 19,
  });

  final String label;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final active = onPressed != null;
    final base = _startMenuLinkStyle(
      size: size,
      color: WorkbenchPalette.parchment.withValues(alpha: active ? 0.96 : 0.4),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          splashColor: WorkbenchPalette.actionHighlight.withValues(alpha: 0.12),
          highlightColor: WorkbenchPalette.actionHighlight.withValues(
            alpha: 0.06,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: base,
            ),
          ),
        ),
      ),
    );
  }
}

class StartFlowOverlay extends StatelessWidget {
  const StartFlowOverlay({super.key, required this.game});

  static const String overlayId = 'start_flow';

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE63D2E22),
      child: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: game.hudTick,
          builder: (context, _, __) {
            if (game.showStartMenu) {
              return _StartMenuWorkbench(game: game);
            }
            if (game.showLoadoutBuilder) {
              return SpinnerWorkbenchScreen(game: game);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _StartMenuWorkbench extends StatelessWidget {
  const _StartMenuWorkbench({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    final isFirstTime = game.isFirstRunEver && !game.tutorialSeen;
    final viewH = MediaQuery.sizeOf(context).height;
    final viewW = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: viewH,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: WoodWorkbenchPainter(cornerRadius: 22),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 2),
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: math.min(560, viewW - 20),
                                maxHeight: math.min(0.46 * viewH, 360),
                              ),
                              child: Image.asset(
                                'assets/images/ui/logo.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                                semanticLabel: 'Spin Spin Carnage',
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'TEN FLOORS · ONE WARDEN · SPIN TO WIN',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _startMenuLinkStyle(
                              size: 11.5,
                              color: WorkbenchPalette.parchment.withValues(
                                alpha: 0.88,
                              ),
                            ),
                          ),
                          const Spacer(flex: 1),
                          Center(
                            child: _StartMenuPlayText(
                              onPressed: game.canOpenLoadoutBuilder
                                  ? game.startCampaignRun
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _StartMenuTextLink(
                            size: 16,
                            label: 'TIPS, PROGRESS & WEEKLY',
                            onPressed: game.canOpenLoadoutBuilder
                                ? () => _openStartMenuDetailsSheet(
                                      context,
                                      game: game,
                                      expandedHowTo: isFirstTime,
                                    )
                                : null,
                          ),
                          const Spacer(flex: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StartMenuTextLink(
                                label: 'BUILD',
                                size: 18,
                                onPressed: game.canOpenLoadoutBuilder
                                    ? game.openLoadoutBuilder
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  '·',
                                  style: _startMenuLinkStyle(
                                    size: 20,
                                    color: WorkbenchPalette.parchment
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              _StartMenuTextLink(
                                label: 'HALL',
                                size: 18,
                                onPressed: game.canOpenLoadoutBuilder
                                    ? () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                HallOfSpinnersScreen(
                                              game: game,
                                            ),
                                          ),
                                        )
                                    : null,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StartMenuTextLink(
                                label: 'WEEKLY',
                                size: 18,
                                onPressed: game.canOpenLoadoutBuilder
                                    ? game.startWeeklyRun
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  '·',
                                  style: _startMenuLinkStyle(
                                    size: 20,
                                    color: WorkbenchPalette.parchment
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              _StartMenuTextLink(
                                label: 'INVASION',
                                size: 18,
                                onPressed: game.canOpenLoadoutBuilder
                                    ? game.startInvasionRun
                                    : null,
                              ),
                            ],
                          ),
                          _StartMenuTextLink(
                            label: 'UPGRADES',
                            size: 20,
                            onPressed: game.canOpenLoadoutBuilder
                                ? game.openUpgradesFromMainMenu
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartMenuPlayText extends StatelessWidget {
  const _StartMenuPlayText({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final active = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashColor: WorkbenchPalette.actionHighlight.withValues(alpha: 0.2),
        highlightColor: WorkbenchPalette.actionHighlight.withValues(
          alpha: 0.1,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          child: Text(
            'PLAY',
            textAlign: TextAlign.center,
            style: _startMenuLinkStyle(
              size: 40,
              color: active
                  ? const Color(0xFFFFE566)
                  : const Color(0xFF998866),
            ),
          ),
        ),
      ),
    );
  }
}

void _openStartMenuDetailsSheet(
  BuildContext context, {
  required SpinnerGame game,
  required bool expandedHowTo,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WorkbenchPalette.deepVoid.withValues(alpha: 0.97),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.32,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: WorkbenchPalette.parchment.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SpinHowToCard(expanded: expandedHowTo),
              const SizedBox(height: 12),
              _GoalPillar(game: game),
              const SizedBox(height: 12),
              _WeeklyChallengeCard(game: game),
              const SizedBox(height: 12),
              _BuildPreviewPlaque(game: game),
            ],
          );
        },
      );
    },
  );
}

/// Animated "drag circles around the spinner" demo + caption. Always visible
/// on the start menu so it doubles as a refresher; rendered larger when it's
/// truly a brand-new player.
class SpinHowToCard extends StatefulWidget {
  const SpinHowToCard({super.key, this.expanded = false});

  final bool expanded;

  @override
  State<SpinHowToCard> createState() => _SpinHowToCardState();
}

class _SpinHowToCardState extends State<SpinHowToCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demoSize = widget.expanded ? 132.0 : 96.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WorkbenchPalette.woodDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WorkbenchPalette.actionHighlight.withValues(
            alpha: widget.expanded ? 0.75 : 0.35,
          ),
          width: widget.expanded ? 2.5 : 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(3, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Row(
          children: [
            SizedBox(
              width: demoSize,
              height: demoSize,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => CustomPaint(
                  painter: _SpinDemoPainter(progress: _controller.value),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.expanded ? 'How to spin' : 'Spin to launch',
                    style: const TextStyle(
                      color: WorkbenchPalette.actionHighlight,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Drag circles around your spinner to wind it up. '
                    'Release to launch in the direction you swept.',
                    style: TextStyle(
                      color: WorkbenchPalette.parchment.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  if (widget.expanded) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Faster, tighter circles = stronger launch.',
                      style: TextStyle(
                        color: WorkbenchPalette.parchment.withValues(
                          alpha: 0.7,
                        ),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpinDemoPainter extends CustomPainter {
  _SpinDemoPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final spinnerRadius = math.min(size.width, size.height) * 0.18;
    final orbitRadius = math.min(size.width, size.height) * 0.38;

    final spinnerAngle = progress * 2 * math.pi * 1.6;

    // Trail (faint arc behind the finger).
    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: GradientRotation(progress * 2 * math.pi),
        colors: <Color>[
          WorkbenchPalette.actionHighlight.withValues(alpha: 0.0),
          WorkbenchPalette.actionHighlight.withValues(alpha: 0.7),
          WorkbenchPalette.actionHighlight.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: orbitRadius));
    canvas.drawCircle(center, orbitRadius, trailPaint);

    // Spinner body.
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: const <Color>[
          Color(0xFFF7C4A7),
          Color(0xFFC68259),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: spinnerRadius * 1.4),
      );
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = WorkbenchPalette.ink;
    canvas.drawCircle(center, spinnerRadius, bodyPaint);
    canvas.drawCircle(center, spinnerRadius, outline);

    // Three little blades to evoke motion.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spinnerAngle);
    final bladePaint = Paint()..color = const Color(0xFFFFE100);
    final bladeOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = WorkbenchPalette.ink;
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / 3);
      final path = Path()
        ..moveTo(spinnerRadius * 0.55, -spinnerRadius * 0.35)
        ..quadraticBezierTo(
          spinnerRadius * 1.6,
          0,
          spinnerRadius * 0.55,
          spinnerRadius * 0.35,
        )
        ..close();
      canvas.drawPath(path, bladePaint);
      canvas.drawPath(path, bladeOutline);
      canvas.restore();
    }
    canvas.restore();

    // Ghost finger orbiting the spinner.
    final fingerAngle = progress * 2 * math.pi;
    final fingerPos = Offset(
      center.dx + orbitRadius * math.cos(fingerAngle),
      center.dy + orbitRadius * math.sin(fingerAngle),
    );
    final fingerGlow = Paint()
      ..color = WorkbenchPalette.actionHighlight.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(fingerPos, 10, fingerGlow);

    final fingerPaint = Paint()..color = WorkbenchPalette.parchment;
    final fingerOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = WorkbenchPalette.ink;
    canvas.drawCircle(fingerPos, 7, fingerPaint);
    canvas.drawCircle(fingerPos, 7, fingerOutline);
  }

  @override
  bool shouldRepaint(covariant _SpinDemoPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GoalPillar extends StatelessWidget {
  const _GoalPillar({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    final progress = game.metaProgress;
    final deepest = progress.deepestLevelReached.clamp(0, 10);
    final ratio = (deepest / 10).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: WorkbenchPalette.woodDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WorkbenchPalette.ink.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(3, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'YOUR DESCENT',
                  style: TextStyle(
                    color: WorkbenchPalette.actionHighlight,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Lv $deepest / 10',
                  style: const TextStyle(
                    color: WorkbenchPalette.parchment,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ChunkyDepthBar(ratio: ratio),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _MetricChip(
                  label: 'Banked',
                  value: '${progress.bankedCoins}',
                  color: WorkbenchPalette.actionHighlight,
                ),
                _MetricChip(
                  label: 'Best score',
                  value: '${progress.bestScore}',
                  color: WorkbenchPalette.parchment,
                ),
                if (progress.bossClears > 0)
                  _MetricChip(
                    label: 'Wardens',
                    value: '${progress.bossClears}',
                    color: WorkbenchPalette.magicTint,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChunkyDepthBar extends StatelessWidget {
  const _ChunkyDepthBar({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: WorkbenchPalette.deepVoid,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: WorkbenchPalette.ink, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: ratio,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    WorkbenchPalette.actionHighlight,
                    Color(0xFFFF7A1E),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label  ',
          style: TextStyle(
            color: WorkbenchPalette.parchment.withValues(alpha: 0.7),
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _WeeklyChallengeCard extends StatelessWidget {
  const _WeeklyChallengeCard({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    final best = game.weeklyBestEntry;
    final hasRun = best != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WorkbenchPalette.stoneShadow.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WorkbenchPalette.magicTint.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(3, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'WEEKLY CHALLENGE',
                  style: TextStyle(
                    color: WorkbenchPalette.magicTint,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  game.weeklyDateRangeLabel,
                  style: TextStyle(
                    color: WorkbenchPalette.parchment.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              game.weeklyChallengeName,
              style: const TextStyle(
                color: WorkbenchPalette.parchment,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasRun
                  ? 'Your best this week: Lv ${best.deepestLevel} · ${best.score} pts · ${best.enemiesKilled} kills'
                  : 'Same dungeon for everyone this week. Set the bar.',
              style: TextStyle(
                color: WorkbenchPalette.parchment.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            WorkbenchOutlineButton(
              label: hasRun ? 'Beat your weekly run' : 'Play Weekly Run',
              onPressed: game.canOpenLoadoutBuilder ? game.startWeeklyRun : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildPreviewPlaque extends StatelessWidget {
  const _BuildPreviewPlaque({required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    final build = game.selectedBuild;
    final core = game.partById(build.coreId);
    final ring = game.partById(build.ringId);
    final blade = game.partById(build.bladeId);
    final glow = game.partById(build.glowId);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: WorkbenchPalette.woodDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WorkbenchPalette.ink.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(3, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Spinner',
              style: TextStyle(
                color: WorkbenchPalette.parchment,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Core: ${core.name} | Ring: ${ring.name}',
              style: TextStyle(
                color: WorkbenchPalette.parchment.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Blades: ${blade.name} | Glow: ${glow.name}',
              style: TextStyle(
                color: WorkbenchPalette.parchment.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
