import '../systems/spinner_parts.dart';

/// Tunable 2D approximation of spinning-top motion: spin decay, precession-style
/// lateral drift, nutation, and a short "sleep" window where the path steadies.
///
/// Build-specific behavior comes from [gyroStability] and [spinRetention]
/// (derived from parts in [SpinnerBuildStats]). All other fields are global
/// knobs you can tune without touching the integrator.
class SpinnerTopPhysicsConfig {
  SpinnerTopPhysicsConfig({
    required this.gyroStability,
    required this.spinRetention,
    this.sleepSpinReference = 13.5,
    this.precessionSpinEpsilon = 2.0,
    this.precessionPhaseDrive = 24.0,
    this.precessionAccelMax = 300.0,
    this.nutationFrequency = 14.0,
    this.nutationAccelMax = 135.0,
    this.nutationMix = 0.52,
    this.nutationHarmonic = 1.75,
    this.riseAlignStrength = 3.4,
    this.pathToSpinScale = 0.0172,
    this.spinBlendFromPath = 0.1,
    this.baseAngularDamping = 0.91,
    this.maxTopAccelPerFrame = 520.0,
  });

  /// From build: higher → less precession / nutation (more "locked in").
  final double gyroStability;

  /// From build: higher → |angularVelocity| decays more slowly (longer spin).
  final double spinRetention;

  /// |ω| at which the top is treated as mostly in the "sleeping" stable band.
  final double sleepSpinReference;

  /// Floor on spin magnitude when driving precession phase (avoids divide blow-up).
  final double precessionSpinEpsilon;

  /// Scales how fast the precession phase advances (higher → faster wandering).
  final double precessionPhaseDrive;

  /// Peak lateral acceleration from precession (world units / s²).
  final double precessionAccelMax;

  /// Nutation oscillation rate (rad/s).
  final double nutationFrequency;

  /// Peak lateral acceleration from nutation (world units / s²).
  final double nutationAccelMax;

  /// How much nutation mixes with precession (0 = precession only).
  final double nutationMix;

  /// Second harmonic multiplier on nutation phase.
  final double nutationHarmonic;

  /// When "sleeping", damp velocity perpendicular to motion (path straightens).
  final double riseAlignStrength;

  /// Maps linear speed to target visual spin rate.
  final double pathToSpinScale;

  /// How strongly spin rate follows linear speed (0–1 scale per blend step).
  final double spinBlendFromPath;

  /// Per-second angular damping base (raised to dt); modified by [spinRetention].
  final double baseAngularDamping;

  /// Safety clamp on |Δv| from top effects in one update (per second scale * dt).
  final double maxTopAccelPerFrame;

  factory SpinnerTopPhysicsConfig.fromBuildStats(SpinnerBuildStats stats) {
    return SpinnerTopPhysicsConfig(
      gyroStability: stats.gyroStability,
      spinRetention: stats.spinRetention,
    );
  }
}
