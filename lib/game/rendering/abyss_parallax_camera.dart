import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Planned 6-layer abyss behind the arena (agent.md: Layer 0 arena → Layer 5 solid dark).
///
/// Integration sketch for [SpinnerGame]:
/// - Add a screen-fixed [PositionComponent] (or Flutter stack under the Flame widget)
///   that owns six full-bleed quads/sprites ordered back-to-front.
/// - Each frame (or on camera move only), set `position` / `parallax` offset from the
///   world camera center so nearer layers move more than distant ones.
///
/// Suggested parallax factors (depth increasing): 0.0, 0.04, 0.09, 0.16, 0.26, 0.38
/// relative to normalized camera delta from a run-time anchor. Layer 0 can be fully
/// static (arena edge mask only).
class AbyssParallaxLayerSpec {
  const AbyssParallaxLayerSpec({
    required this.depthIndex,
    required this.parallaxFactor,
    required this.tint,
    this.noiseScale = 1,
  }) : assert(depthIndex >= 0 && depthIndex < 6);

  /// 0 = just above void, 5 = deepest / solid.
  final int depthIndex;
  final double parallaxFactor;
  final Color tint;
  final double noiseScale;
}

/// Default palette-aligned stack (tweak art-side when sprites exist).
abstract final class AbyssParallaxPresets {
  static const List<AbyssParallaxLayerSpec> dungeonAbyss = <AbyssParallaxLayerSpec>[
    AbyssParallaxLayerSpec(
      depthIndex: 0,
      parallaxFactor: 0,
      tint: Color(0xFF4A4A4A),
    ),
    AbyssParallaxLayerSpec(
      depthIndex: 1,
      parallaxFactor: 0.045,
      tint: Color(0xFF3D3D3D),
      noiseScale: 0.018,
    ),
    AbyssParallaxLayerSpec(
      depthIndex: 2,
      parallaxFactor: 0.09,
      tint: Color(0xFF353535),
      noiseScale: 0.014,
    ),
    AbyssParallaxLayerSpec(
      depthIndex: 3,
      parallaxFactor: 0.16,
      tint: Color(0xFF2F2F2F),
      noiseScale: 0.011,
    ),
    AbyssParallaxLayerSpec(
      depthIndex: 4,
      parallaxFactor: 0.26,
      tint: Color(0xFF2A2A2A),
      noiseScale: 0.008,
    ),
    AbyssParallaxLayerSpec(
      depthIndex: 5,
      parallaxFactor: 0.38,
      tint: Color(0xFF1E1E1E),
      noiseScale: 0.005,
    ),
  ];
}

/// Apply to a layer's draw offset from camera delta (world or logical pixels).
Vector2 abyssLayerOffset({
  required Vector2 cameraDelta,
  required AbyssParallaxLayerSpec spec,
}) {
  return cameraDelta * spec.parallaxFactor;
}
