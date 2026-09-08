import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/spinner_game.dart';
import '../../systems/spinner_parts.dart';
import 'part_drag_data.dart';
import 'wood_workbench_painter.dart';
import 'workbench_buttons.dart';
import 'workbench_palette.dart';

/// Diegetic loadout UI: top-down wooden bench with drag-and-drop parts.
class SpinnerWorkbenchScreen extends StatefulWidget {
  const SpinnerWorkbenchScreen({super.key, required this.game});

  final SpinnerGame game;

  @override
  State<SpinnerWorkbenchScreen> createState() => _SpinnerWorkbenchScreenState();
}

class _SpinnerWorkbenchScreenState extends State<SpinnerWorkbenchScreen> {
  SpinnerPartSlot _activeSlot = SpinnerPartSlot.core;
  late final TextEditingController _seedController;
  final FocusNode _seedFocusNode = FocusNode();

  static const List<SpinnerPartSlot> _slotOrder = <SpinnerPartSlot>[
    SpinnerPartSlot.core,
    SpinnerPartSlot.ring,
    SpinnerPartSlot.blade,
    SpinnerPartSlot.glow,
  ];

  @override
  void initState() {
    super.initState();
    _seedController = TextEditingController(
      text: widget.game.configuredRunSeed?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _seedController.dispose();
    _seedFocusNode.dispose();
    super.dispose();
  }

  void _syncSeedField() {
    if (!_seedFocusNode.hasFocus) {
      final t = widget.game.configuredRunSeed?.toString() ?? '';
      if (_seedController.text != t) {
        _seedController.text = t;
      }
    }
  }

  void _stepSlot(int delta) {
    final i = _slotOrder.indexOf(_activeSlot);
    setState(
      () => _activeSlot = _slotOrder[(i + delta + _slotOrder.length) % _slotOrder.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncSeedField();
    final game = widget.game;
    final stats = game.selectedBuildStats;
    final selectedId = switch (_activeSlot) {
      SpinnerPartSlot.core => game.selectedBuild.coreId,
      SpinnerPartSlot.ring => game.selectedBuild.ringId,
      SpinnerPartSlot.blade => game.selectedBuild.bladeId,
      SpinnerPartSlot.glow => game.selectedBuild.glowId,
    };
    final parts = game.partsForSlot(_activeSlot);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: WorkbenchOutlineButton(
                  label: 'Back',
                  onPressed: game.returnToStartMenu,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: WorkbenchPrimaryButton(
                  label: 'Start Game',
                  onPressed:
                      game.canStartRunFromBuilder ? game.startRunFromBuilder : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Spinner Workbench',
                  style: TextStyle(
                    color: WorkbenchPalette.parchment,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: <Shadow>[
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(1, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'Unlocked ${game.unlockedPartIds.length}',
                style: TextStyle(
                  color: WorkbenchPalette.parchment.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _BrassSeedStrip(
            game: game,
            controller: _seedController,
            focusNode: _seedFocusNode,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: WoodWorkbenchPainter(cornerRadius: 20),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Drag parts onto the sockets — or tap a tray piece.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: WorkbenchPalette.parchment.withValues(alpha: 0.88),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: WorkbenchSocket(
                                        game: game,
                                        slot: SpinnerPartSlot.core,
                                        label: 'Core',
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: WorkbenchSocket(
                                        game: game,
                                        slot: SpinnerPartSlot.ring,
                                        label: 'Ring',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: WorkbenchSocket(
                                        game: game,
                                        slot: SpinnerPartSlot.blade,
                                        label: 'Blades',
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: WorkbenchSocket(
                                        game: game,
                                        slot: SpinnerPartSlot.glow,
                                        label: 'Glow',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _CategoryArrow(icon: Icons.chevron_left, onTap: () => _stepSlot(-1)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _CategoryPeg(
                                      label: 'Core',
                                      active: _activeSlot == SpinnerPartSlot.core,
                                      onTap: () => setState(
                                        () => _activeSlot = SpinnerPartSlot.core,
                                      ),
                                    ),
                                    _CategoryPeg(
                                      label: 'Ring',
                                      active: _activeSlot == SpinnerPartSlot.ring,
                                      onTap: () => setState(
                                        () => _activeSlot = SpinnerPartSlot.ring,
                                      ),
                                    ),
                                    _CategoryPeg(
                                      label: 'Blades',
                                      active: _activeSlot == SpinnerPartSlot.blade,
                                      onTap: () => setState(
                                        () => _activeSlot = SpinnerPartSlot.blade,
                                      ),
                                    ),
                                    _CategoryPeg(
                                      label: 'Glow',
                                      active: _activeSlot == SpinnerPartSlot.glow,
                                      onTap: () => setState(
                                        () => _activeSlot = SpinnerPartSlot.glow,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _CategoryArrow(icon: Icons.chevron_right, onTap: () => _stepSlot(1)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 102,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: parts.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final part = parts[index];
                              final unlocked = game.isPartUnlocked(part.id);
                              final selected = selectedId == part.id;
                              return _TrayPartTile(
                                game: game,
                                slot: _activeSlot,
                                part: part,
                                unlocked: unlocked,
                                selected: selected,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _CarvedStatsStrip(stats: stats),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkbenchSocket extends StatelessWidget {
  const WorkbenchSocket({
    super.key,
    required this.game,
    required this.slot,
    required this.label,
  });

  final SpinnerGame game;
  final SpinnerPartSlot slot;
  final String label;

  String get _equippedId => switch (slot) {
    SpinnerPartSlot.core => game.selectedBuild.coreId,
    SpinnerPartSlot.ring => game.selectedBuild.ringId,
    SpinnerPartSlot.blade => game.selectedBuild.bladeId,
    SpinnerPartSlot.glow => game.selectedBuild.glowId,
  };

  @override
  Widget build(BuildContext context) {
    final part = game.partById(_equippedId);

    return DragTarget<SpinnerPartDragData>(
      onWillAcceptWithDetails: (details) {
        final dragged = SpinnerPartCatalog.partById(details.data.partId);
        return dragged.slot == slot && game.isPartUnlocked(details.data.partId);
      },
      onAcceptWithDetails: (details) {
        game.selectSpinnerPart(slot, details.data.partId);
      },
      builder: (context, candidateData, __) {
        final hover = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: WorkbenchPalette.woodDark.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: hover ? 3 : 2,
              color: hover
                  ? WorkbenchPalette.actionHighlight
                  : WorkbenchPalette.ink.withValues(alpha: 0.85),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                offset: const Offset(3, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: WorkbenchPalette.parchment.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              Expanded(
                child: Center(
                  child: LongPressDraggable<SpinnerPartDragData>(
                    data: SpinnerPartDragData(partId: part.id, sourceSlot: slot),
                    feedback: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      shadowColor: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      child: _PartToken(part: part, size: 76, outlined: true),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.38,
                      child: _PartToken(part: part, size: 58),
                    ),
                    child: _PartToken(part: part, size: 58),
                  ),
                ),
              ),
              Text(
                part.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WorkbenchPalette.parchment,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrayPartTile extends StatelessWidget {
  const _TrayPartTile({
    required this.game,
    required this.slot,
    required this.part,
    required this.unlocked,
    required this.selected,
  });

  final SpinnerGame game;
  final SpinnerPartSlot slot;
  final SpinnerPartDefinition part;
  final bool unlocked;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tile = GestureDetector(
      onTap: unlocked ? () => game.selectSpinnerPart(slot, part.id) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 118,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? WorkbenchPalette.stoneShadow.withValues(alpha: 0.45)
              : WorkbenchPalette.woodDark.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: selected ? 3 : 1.5,
            color: !unlocked
                ? WorkbenchPalette.ink.withValues(alpha: 0.4)
                : selected
                ? WorkbenchPalette.actionHighlight
                : WorkbenchPalette.ink.withValues(alpha: 0.75),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              offset: const Offset(2, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PartThumb(part: part, size: 28),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    part.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unlocked
                          ? WorkbenchPalette.parchment
                          : WorkbenchPalette.parchment.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                unlocked ? part.description : 'Locked',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked
                      ? WorkbenchPalette.parchment.withValues(alpha: 0.8)
                      : WorkbenchPalette.parchment.withValues(alpha: 0.4),
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!unlocked) {
      return tile;
    }

    return LongPressDraggable<SpinnerPartDragData>(
      data: SpinnerPartDragData(partId: part.id),
      feedback: Material(
        color: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 118,
          child: tile,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _PartToken extends StatelessWidget {
  const _PartToken({
    required this.part,
    required this.size,
    this.outlined = false,
  });

  final SpinnerPartDefinition part;
  final double size;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    // For blade parts we swap the generic colored chip out for an actual
    // blade silhouette preview so the socket matches what the player will see
    // on the in-game spinner.
    if (part.slot == SpinnerPartSlot.blade) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WorkbenchPalette.stoneShadow.withValues(alpha: 0.35),
          border: Border.all(
            color: outlined
                ? WorkbenchPalette.actionHighlight
                : WorkbenchPalette.ink,
            width: outlined ? 3 : 2.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(2, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: CustomPaint(
          painter: BladeShapePreviewPainter(part: part),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: outlined
              ? WorkbenchPalette.actionHighlight
              : WorkbenchPalette.ink,
          width: outlined ? 3 : 2.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(2, 3),
            blurRadius: 0,
          ),
        ],
        gradient: RadialGradient(
          colors: <Color>[part.primaryColor, part.secondaryColor],
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.2,
          height: size * 0.2,
          decoration: BoxDecoration(
            color: part.accentColor,
            shape: BoxShape.circle,
            border: Border.all(color: WorkbenchPalette.ink, width: 1),
          ),
        ),
      ),
    );
  }
}

/// Draws a stylised top-down spinner preview for a blade part so the socket
/// + tray thumbnail reflect the silhouette the player will see in play.
/// Kept intentionally close to `SpinnerComponent._drawXxxBlade` so a given
/// part reads consistently across menus and gameplay.
class BladeShapePreviewPainter extends CustomPainter {
  BladeShapePreviewPainter({required this.part});

  final SpinnerPartDefinition part;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Body radius is a fraction of the widget; blade reach scales with the
    // part's `bladeReach` so higher-reach parts clearly jut further out.
    final bodyRadius = math.min(size.width, size.height) * 0.22;
    final reachFraction = (part.bladeReach / 14.0).clamp(0.25, 1.15);
    final extraReach = bodyRadius * reachFraction * 1.15;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Slight tilt so blades don't render axis-aligned — reads more dynamic.
    canvas.rotate(math.pi / 8);

    // Body fill (skin-colored player spinner).
    final bodyFill = Paint()
      ..shader = RadialGradient(
        colors: const <Color>[Color(0xFFF7C4A7), Color(0xFFC68259)],
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: bodyRadius * 1.3),
      );
    canvas.drawCircle(Offset.zero, bodyRadius, bodyFill);
    canvas.drawCircle(
      Offset.zero,
      bodyRadius,
      Paint()
        ..color = WorkbenchPalette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final bladePaint = Paint()..color = part.primaryColor;
    final bladeShadow = Paint()..color = part.secondaryColor.withValues(alpha: 0.85);
    final bladeOutline = Paint()
      ..color = WorkbenchPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 2);
      _drawBladeForShape(
        canvas,
        shape: part.bladeShape,
        bodyRadius: bodyRadius,
        reach: extraReach,
        fill: bladePaint,
        shadow: bladeShadow,
        outline: bladeOutline,
      );
      canvas.restore();
    }

    // Accent dot on the hub — visual anchor, matches part color language.
    canvas.drawCircle(
      Offset.zero,
      bodyRadius * 0.34,
      Paint()..color = part.accentColor,
    );
    canvas.drawCircle(
      Offset.zero,
      bodyRadius * 0.34,
      Paint()
        ..color = WorkbenchPalette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.restore();
  }

  void _drawBladeForShape(
    Canvas canvas, {
    required BladeShape shape,
    required double bodyRadius,
    required double reach,
    required Paint fill,
    required Paint shadow,
    required Paint outline,
  }) {
    final r = bodyRadius;
    final tipR = bodyRadius + reach;

    switch (shape) {
      case BladeShape.standard:
        // Rectangular fin with a notched tip.
        final rect = Rect.fromCenter(
          center: Offset(r + reach * 0.5, 0),
          width: reach + r * 0.4,
          height: r * 0.42,
        );
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, outline);
      case BladeShape.curved:
        // Sickle arc.
        final path = Path()
          ..moveTo(r * 0.95, -r * 0.34)
          ..quadraticBezierTo(tipR * 1.02, -r * 0.05, tipR * 0.95, r * 0.2)
          ..quadraticBezierTo(r * 1.05, r * 0.12, r * 0.95, r * 0.34)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, outline);
      case BladeShape.hook:
        // Slim hooked comet tip.
        final path = Path()
          ..moveTo(r * 0.95, -r * 0.18)
          ..quadraticBezierTo(tipR * 0.8, -r * 0.35, tipR * 1.02, 0)
          ..quadraticBezierTo(tipR * 0.72, r * 0.05, r * 0.95, r * 0.18)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, outline);
      case BladeShape.spiky:
        // Triangular spur.
        final path = Path()
          ..moveTo(r * 0.9, -r * 0.4)
          ..lineTo(tipR * 1.02, 0)
          ..lineTo(r * 0.9, r * 0.4)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, outline);
      case BladeShape.extruded:
        // Chunky extended rectangle with a heavy shoulder near the body.
        final shoulder = Rect.fromCenter(
          center: Offset(r + reach * 0.18, 0),
          width: reach * 0.5 + r * 0.2,
          height: r * 0.62,
        );
        canvas.drawRect(shoulder, shadow);
        canvas.drawRect(shoulder, outline);
        final blade = Rect.fromCenter(
          center: Offset(r + reach * 0.6, 0),
          width: reach + r * 0.55,
          height: r * 0.44,
        );
        canvas.drawRect(blade, fill);
        canvas.drawRect(blade, outline);
    }
  }

  @override
  bool shouldRepaint(covariant BladeShapePreviewPainter old) =>
      old.part.id != part.id;
}

class _PartThumb extends StatelessWidget {
  const _PartThumb({required this.part, required this.size});

  final SpinnerPartDefinition part;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Blade parts always show the procedural silhouette so the tray accurately
    // distinguishes `standard` / `curved` / `hook` / `spiky` / `extruded`
    // rather than falling back to the generic previewUrl image.
    if (part.slot == SpinnerPartSlot.blade) {
      return _FallbackThumb(part: part, size: size);
    }
    final previewUrl = part.previewUrl;
    if (previewUrl != null && previewUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            previewUrl,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, __, ___) => _FallbackThumb(part: part, size: size),
          ),
        ),
      );
    }
    return _FallbackThumb(part: part, size: size);
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb({required this.part, required this.size});

  final SpinnerPartDefinition part;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Blade parts always render as a mini silhouette so the player can read
    // the shape from across the tray without opening the preview.
    if (part.slot == SpinnerPartSlot.blade) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: WorkbenchPalette.ink.withValues(alpha: 0.6)),
          color: WorkbenchPalette.stoneShadow.withValues(alpha: 0.35),
        ),
        child: CustomPaint(
          painter: BladeShapePreviewPainter(part: part),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: WorkbenchPalette.ink.withValues(alpha: 0.6)),
        gradient: LinearGradient(
          colors: <Color>[part.primaryColor, part.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.28,
          height: size * 0.28,
          decoration: BoxDecoration(
            color: part.accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _CategoryPeg extends StatelessWidget {
  const _CategoryPeg({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: active
                  ? WorkbenchPalette.stoneShadow.withValues(alpha: 0.55)
                  : WorkbenchPalette.woodDark.withValues(alpha: 0.55),
              border: Border.all(
                color: active
                    ? WorkbenchPalette.magicTint.withValues(alpha: 0.9)
                    : WorkbenchPalette.ink.withValues(alpha: 0.65),
                width: active ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: WorkbenchPalette.parchment,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryArrow extends StatelessWidget {
  const _CategoryArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WorkbenchPalette.woodDark.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, color: WorkbenchPalette.parchment, size: 22),
        ),
      ),
    );
  }
}

class _CarvedStatsStrip extends StatelessWidget {
  const _CarvedStatsStrip({required this.stats});

  final SpinnerBuildStats stats;

  @override
  Widget build(BuildContext context) {
    Widget bar(String label, int value) {
      final p = (value / 40).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label $value',
              style: const TextStyle(
                color: WorkbenchPalette.parchment,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 6,
                backgroundColor: WorkbenchPalette.ink.withValues(alpha: 0.55),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  WorkbenchPalette.actionHighlight,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: WorkbenchPalette.woodDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WorkbenchPalette.ink.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Build Stats',
              style: TextStyle(
                color: WorkbenchPalette.parchment,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            bar('Power', stats.power),
            bar('Speed', stats.speed),
            bar('Control', stats.control),
            bar('Endurance', stats.endurance),
            Text(
              'Gyro ${(stats.gyroStability * 100).round()}% · spin ×${stats.spinRetention.toStringAsFixed(2)} · dmg ×${stats.damageMultiplier.toStringAsFixed(2)}',
              style: TextStyle(
                color: WorkbenchPalette.parchment.withValues(alpha: 0.78),
                fontSize: 9,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrassSeedStrip extends StatelessWidget {
  const _BrassSeedStrip({
    required this.game,
    required this.controller,
    required this.focusNode,
  });

  final SpinnerGame game;
  final TextEditingController controller;
  final FocusNode focusNode;

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _apply(BuildContext context) {
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      game.clearConfiguredRunSeed();
      focusNode.unfocus();
      _toast(context, 'Seed cleared. Next run will be random.');
      return;
    }

    final parsed = int.tryParse(raw);
    if (parsed == null) {
      _toast(context, 'Seed must be a valid integer.');
      return;
    }
    game.setConfiguredRunSeed(parsed);
    controller.text = game.configuredRunSeed?.toString() ?? '';
    focusNode.unfocus();
    _toast(context, 'Seed applied: ${game.configuredRunSeedLabel}');
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[WorkbenchPalette.brass, WorkbenchPalette.brassDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WorkbenchPalette.ink.withValues(alpha: 0.65), width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(2, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Run seed (etched plate)',
              style: TextStyle(
                color: WorkbenchPalette.ink.withValues(alpha: 0.92),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Same integer = same dungeon on mobile or CLI.',
              style: TextStyle(
                color: WorkbenchPalette.ink.withValues(alpha: 0.75),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: WorkbenchPalette.ink,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Random if empty',
                hintStyle: TextStyle(
                  color: WorkbenchPalette.ink.withValues(alpha: 0.45),
                ),
                isDense: true,
                filled: true,
                fillColor: WorkbenchPalette.parchment.withValues(alpha: 0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: WorkbenchPalette.ink.withValues(alpha: 0.35),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: WorkbenchPalette.ink.withValues(alpha: 0.35),
                  ),
                ),
              ),
              onSubmitted: (_) => _apply(context),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SeedChip(
                  label: 'Apply',
                  filled: true,
                  onTap: () => _apply(context),
                ),
                _SeedChip(
                  label: 'Random',
                  onTap: () {
                    final seed = game.randomizeConfiguredRunSeed();
                    controller.text = seed.toString();
                    focusNode.unfocus();
                    _toast(context, 'Seed randomized: $seed');
                  },
                ),
                _SeedChip(
                  label: 'Clear',
                  onTap: () {
                    controller.clear();
                    game.clearConfiguredRunSeed();
                    focusNode.unfocus();
                    _toast(context, 'Seed cleared. Next run will be random.');
                  },
                ),
                _SeedChip(
                  label: 'Copy',
                  onTap: () {
                    final seed = game.configuredRunSeed;
                    if (seed == null) {
                      _toast(context, 'No custom seed set.');
                      return;
                    }
                    Clipboard.setData(ClipboardData(text: seed.toString()));
                    _toast(context, 'Copied seed $seed');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeedChip extends StatelessWidget {
  const _SeedChip({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: filled
                ? WorkbenchPalette.ink.withValues(alpha: 0.88)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: WorkbenchPalette.ink.withValues(alpha: 0.75),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled
                  ? WorkbenchPalette.parchment
                  : WorkbenchPalette.ink.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
