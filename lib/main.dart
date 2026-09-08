import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/spinner_game.dart';
import 'ui/hud.dart';
import 'ui/start_flow_overlay.dart';
import 'ui/upgrade_menu.dart';

void main() {
  final game = SpinnerGame();

  runApp(SscApp(game: game));
}

class SscApp extends StatelessWidget {
  const SscApp({super.key, required this.game});

  final SpinnerGame game;

  @override
  Widget build(BuildContext context) {
    return _LifecycleSnapshotSaver(game: game);
  }
}

class _LifecycleSnapshotSaver extends StatefulWidget {
  const _LifecycleSnapshotSaver({required this.game});

  final SpinnerGame game;

  @override
  State<_LifecycleSnapshotSaver> createState() =>
      _LifecycleSnapshotSaverState();
}

class _LifecycleSnapshotSaverState extends State<_LifecycleSnapshotSaver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.game.persistRunSnapshotNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spin Spin Carnage',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget<SpinnerGame>(
          game: widget.game,
          overlayBuilderMap: {
            Hud.overlayId: (context, game) => Hud(game: game),
            StartFlowOverlay.overlayId: (context, game) =>
                StartFlowOverlay(game: game),
            UpgradeMenuOverlay.overlayId: (context, game) =>
                UpgradeMenuOverlay(game: game),
          },
          initialActiveOverlays: const [
            Hud.overlayId,
            StartFlowOverlay.overlayId,
          ],
        ),
      ),
    );
  }
}
