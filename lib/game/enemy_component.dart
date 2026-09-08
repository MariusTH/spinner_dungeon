import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../systems/collision_system.dart';
import 'creature_body.dart';
import 'enemy_taxonomy.dart';
import 'physics.dart';
import 'spinner_component.dart';
import 'spinner_game.dart';
import 'wall_component.dart';

export 'enemy_taxonomy.dart' show EnemyArchetype, EnemyType;

class EnemyComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<SpinnerGame> {
  // Legacy pixel-sprite image caches have been removed now that every enemy
  // silhouette is drawn procedurally via `CreatureRenderer`. Historical PNG
  // assets still live under `assets/images/enemies/` but are no longer loaded
  // at runtime.
  EnemyComponent.turret({
    required Vector2 position,
    EnemyArchetype archetype = EnemyArchetype.standard,
    double hpMultiplier = 1,
    double contactDamageMultiplier = 1,
    double fireRateMultiplier = 1,
    double projectileDamageMultiplier = 1,
    double projectileSpeedMultiplier = 1,
    int coinDropBonus = 0,
  }) : this._(
         type: EnemyType.turret,
         archetype: archetype,
         position: position,
         radius: 18,
         maxHp: 42 * hpMultiplier.clamp(0.5, 6).toDouble(),
         moveSpeed: 0,
         initialVelocity: Vector2.zero(),
         contactDamage: 16 * contactDamageMultiplier.clamp(0.6, 4).toDouble(),
         coinDrop: max(1, 6 + coinDropBonus),
         color: EnemyTaxonomy.bodyColorForType(EnemyType.turret),
         fireRateMultiplier: fireRateMultiplier.clamp(0.6, 2.6).toDouble(),
         projectileDamageMultiplier: projectileDamageMultiplier
             .clamp(0.6, 3.2)
             .toDouble(),
         projectileSpeedMultiplier: projectileSpeedMultiplier
             .clamp(0.7, 2.8)
             .toDouble(),
       );

  EnemyComponent.walker({
    required Vector2 position,
    required Vector2 direction,
    EnemyArchetype archetype = EnemyArchetype.standard,
    double hpMultiplier = 1,
    double speedMultiplier = 1,
    double contactDamageMultiplier = 1,
    int coinDropBonus = 0,
  }) : this._(
         type: EnemyType.walker,
         archetype: archetype,
         position: position,
         radius: 16,
         maxHp: 32 * hpMultiplier.clamp(0.5, 6).toDouble(),
         moveSpeed: 58 * speedMultiplier.clamp(0.5, 3).toDouble(),
         initialVelocity: direction.length2 == 0
             ? Vector2(58, 0)
             : direction.normalized() * 58 * speedMultiplier.clamp(0.5, 3),
         contactDamage: 10 * contactDamageMultiplier.clamp(0.6, 4).toDouble(),
         coinDrop: max(1, 3 + coinDropBonus),
         color: EnemyTaxonomy.bodyColorForType(EnemyType.walker),
         fireRateMultiplier: 1,
         projectileDamageMultiplier: 1,
         projectileSpeedMultiplier: 1,
       );

  /// Hedgehog enemy — bigger, slower patroller locked to a single axis.
  ///
  /// The passed `direction` is snapped at construction time to either
  /// horizontal (±x) or vertical (±y) based on whichever component is
  /// dominant. Once spawned the hedgehog never changes axis: it just
  /// bounces back and forth on its lane, keeping spike-side vs weak-side
  /// readable so the player can time a perpendicular strike.
  EnemyComponent.hedgehog({
    required Vector2 position,
    required Vector2 direction,
    EnemyArchetype archetype = EnemyArchetype.standard,
    double hpMultiplier = 1,
    double speedMultiplier = 1,
    double contactDamageMultiplier = 1,
    int coinDropBonus = 0,
  }) : this._(
         type: EnemyType.hedgehog,
         archetype: archetype,
         position: position,
         radius: 24,
         maxHp: 58 * hpMultiplier.clamp(0.6, 6).toDouble(),
         moveSpeed: 28 * speedMultiplier.clamp(0.5, 2.2).toDouble(),
         initialVelocity: _hedgehogAxisVelocity(
           direction: direction,
           speed: 28 * speedMultiplier.clamp(0.5, 2.2).toDouble(),
         ),
         contactDamage: 18 * contactDamageMultiplier.clamp(0.7, 3.4).toDouble(),
         coinDrop: max(1, 6 + coinDropBonus),
         color: EnemyTaxonomy.bodyColorForType(EnemyType.hedgehog),
         fireRateMultiplier: 1,
         projectileDamageMultiplier: 1,
         projectileSpeedMultiplier: 1,
         patrolAxisVertical: direction.y.abs() > direction.x.abs(),
       );

  /// Snap an input direction to the hedgehog's dominant axis (horizontal
  /// or vertical) and multiply by the locomotion speed.
  static Vector2 _hedgehogAxisVelocity({
    required Vector2 direction,
    required double speed,
  }) {
    if (direction.y.abs() > direction.x.abs()) {
      final sign = direction.y == 0 ? 1.0 : direction.y.sign;
      return Vector2(0, sign * speed);
    }
    final sign = direction.x == 0 ? 1.0 : direction.x.sign;
    return Vector2(sign * speed, 0);
  }

  EnemyComponent.boss({
    required Vector2 position,
    EnemyArchetype archetype = EnemyArchetype.standard,
    double hpMultiplier = 1,
    double contactDamageMultiplier = 1,
    int coinDropBonus = 0,
  }) : this._(
         type: EnemyType.boss,
         archetype: archetype,
         position: position,
         radius: 24,
         maxHp: 260 * hpMultiplier.clamp(0.8, 4.0).toDouble(),
         moveSpeed: 74,
         initialVelocity: Vector2.zero(),
         contactDamage: 24 * contactDamageMultiplier.clamp(0.8, 2.8).toDouble(),
         coinDrop: max(12, 26 + coinDropBonus),
         color: EnemyTaxonomy.bodyColorForType(EnemyType.boss),
         fireRateMultiplier: 1.25,
         projectileDamageMultiplier: 1.3,
         projectileSpeedMultiplier: 1.15,
       );

  EnemyComponent.paddle({
    required Vector2 position,
    EnemyArchetype archetype = EnemyArchetype.standard,
    double hpMultiplier = 1,
    double contactDamageMultiplier = 1,
    int coinDropBonus = 0,
  }) : this._(
         type: EnemyType.paddle,
         archetype: archetype,
         position: position,
         radius: 18,
         maxHp: 52 * hpMultiplier.clamp(0.7, 5).toDouble(),
         moveSpeed: 0,
         initialVelocity: Vector2.zero(),
         contactDamage: 14 * contactDamageMultiplier.clamp(0.7, 4).toDouble(),
         coinDrop: max(1, 4 + coinDropBonus),
         color: EnemyTaxonomy.bodyColorForType(EnemyType.paddle),
         fireRateMultiplier: 1,
         projectileDamageMultiplier: 1,
         projectileSpeedMultiplier: 1,
       );

  EnemyComponent.pulser({
    required Vector2 position,
    required Vector2 direction,
    EnemyArchetype archetype = EnemyArchetype.standard,
    double hpMultiplier = 1,
    double speedMultiplier = 1,
    double contactDamageMultiplier = 1,
    int coinDropBonus = 0,
  }) : this._(
         type: EnemyType.pulser,
         archetype: archetype,
         position: position,
         radius: 19,
         maxHp: 48 * hpMultiplier.clamp(0.5, 6).toDouble(),
         moveSpeed: 38 * speedMultiplier.clamp(0.45, 2.6).toDouble(),
         initialVelocity: direction.length2 == 0
             ? Vector2(38, 0)
             : direction.normalized() * 38 * speedMultiplier.clamp(0.45, 2.6),
         contactDamage: 11 * contactDamageMultiplier.clamp(0.6, 4).toDouble(),
         coinDrop: max(1, 5 + coinDropBonus),
         color: EnemyTaxonomy.bodyColorForType(EnemyType.pulser),
         fireRateMultiplier: 1,
         projectileDamageMultiplier: 1,
         projectileSpeedMultiplier: 1,
       );

  EnemyComponent._({
    required this.type,
    required this.archetype,
    required Vector2 position,
    required double radius,
    required double maxHp,
    required double moveSpeed,
    required Vector2 initialVelocity,
    required double contactDamage,
    required int coinDrop,
    required Color color,
    required double fireRateMultiplier,
    required double projectileDamageMultiplier,
    required double projectileSpeedMultiplier,
    bool patrolAxisVertical = false,
  }) : _maxHp = maxHp,
       _hp = maxHp,
       _moveSpeed = moveSpeed,
       _velocity = initialVelocity,
       _contactDamage = contactDamage,
       _coinDrop = coinDrop,
       _baseColor = color,
       _fireRateMultiplier = fireRateMultiplier,
       _projectileDamageMultiplier = projectileDamageMultiplier,
       _projectileSpeedMultiplier = projectileSpeedMultiplier,
       _patrolAxisVertical = patrolAxisVertical,
       super(
         position: position,
         radius: radius,
         anchor: Anchor.center,
         paint: Paint()..color = color,
       );

  factory EnemyComponent.restored({
    required EnemyType type,
    required EnemyArchetype archetype,
    required Vector2 position,
    required double maxHp,
    required double hp,
    required double moveSpeed,
    required Vector2 velocity,
    required double contactDamage,
    required int coinDrop,
    required double fireRateMultiplier,
    required double projectileDamageMultiplier,
    required double projectileSpeedMultiplier,
  }) {
    final enemy = EnemyComponent._(
      type: type,
      archetype: archetype,
      position: position,
      radius: switch (type) {
        EnemyType.turret => 18,
        EnemyType.walker => 16,
        EnemyType.boss => 24,
        EnemyType.paddle => 18,
        EnemyType.hedgehog => 24,
        EnemyType.pulser => 19,
      },
      maxHp: maxHp,
      moveSpeed: moveSpeed,
      initialVelocity: velocity,
      contactDamage: contactDamage,
      coinDrop: coinDrop,
      color: EnemyTaxonomy.bodyColorForType(type),
      fireRateMultiplier: fireRateMultiplier,
      projectileDamageMultiplier: projectileDamageMultiplier,
      projectileSpeedMultiplier: projectileSpeedMultiplier,
      // Hedgehogs persist their patrol axis via the dominant velocity
      // component; other enemies ignore this flag.
      patrolAxisVertical:
          type == EnemyType.hedgehog && velocity.y.abs() > velocity.x.abs(),
    );
    enemy._hp = hp.clamp(1, maxHp).toDouble();
    enemy._velocity = velocity.clone();
    return enemy;
  }

  final EnemyType type;
  final EnemyArchetype archetype;
  final double _maxHp;
  final double _moveSpeed;
  final double _contactDamage;
  final int _coinDrop;
  final Color _baseColor;
  final double _fireRateMultiplier;
  final double _projectileDamageMultiplier;
  final double _projectileSpeedMultiplier;
  final bool _patrolAxisVertical;

  double _hp;
  Vector2 _velocity;
  Vector2 _impulse = Vector2.zero();
  double _hitFlashUntil = -1;
  double _hitPulseUntil = -1;
  double _contactCooldown = 0;
  double _behaviorTimer = 0;
  double _dashTimer = 0;
  double _dashCooldown = 0;
  double _turretShotTimer = 0;
  double _walkPhase = 0;
  /// Facing direction for soft-vector rendering; snapped to 8 octants in
  /// `CreatureRenderer` at draw time.
  double _creatureFacingAngle = 0;
  // Damage flash + telegraph phases for procedural creatures.
  double _creatureDamageFlash = 0;
  double _creatureBreathPhase = 0;
  bool _turretTelegraphBusy = false;
  bool _bossFanTelegraphBusy = false;
  bool _dashTelegraphActive = false;
  double _groundSlamTimer = 0;
  double _spikeHazardPulse = 0;
  final Random _random = Random();

  bool isDead = false;

  double get hp => _hp;
  double get maxHp => _maxHp;
  double get moveSpeed => _moveSpeed;
  Vector2 get velocity => _velocity.clone();
  double get fireRateMultiplier => _fireRateMultiplier;
  double get projectileDamageMultiplier => _projectileDamageMultiplier;
  double get projectileSpeedMultiplier => _projectileSpeedMultiplier;
  double get healthRatio => (_hp / _maxHp).clamp(0, 1).toDouble();
  double get contactDamage => _contactDamage;
  int get coinDrop => _coinDrop;
  bool get hasDirectionalSpikes => type == EnemyType.hedgehog;

  /// Hedgehogs patrol back-and-forth along a single axis. The axis is
  /// baked in at spawn and never changes — this flag tells renderers and
  /// collision code which axis is "spiked" (the patrol axis) vs "weak"
  /// (perpendicular).
  bool get patrolAxisVertical => _patrolAxisVertical;
  bool get isAbsorber => archetype == EnemyArchetype.absorber;
  bool get isBlower => archetype == EnemyArchetype.blower;
  bool get isSucker => archetype == EnemyArchetype.sucker;
  bool get isBlocker => archetype == EnemyArchetype.blocker;
  bool get isSpiked => archetype == EnemyArchetype.spiked;
  bool get isStalker => archetype == EnemyArchetype.stalker;

  /// Paddles and similar props stay as hazards but do not block dungeon progress.
  bool get countsTowardRoomClear => type != EnemyType.paddle;

  String get contactSourceLabel {
    return switch (type) {
      EnemyType.hedgehog => 'Hedgehog',
      _ => 'Enemy Contact',
    };
  }

  bool canDamageSpinnerOnContact(Vector2 spinnerPosition) {
    if (isSpiked) {
      return true;
    }
    if (hasDirectionalSpikes) {
      // Hedgehog only hurts the spinner when struck on its spike side
      // (the two ends of its patrol axis). Perpendicular (weak) sides
      // are safe to brush — that's how the player safely lines up a hit.
      return _hedgehogSpikeFacingSpinner(spinnerPosition);
    }
    return false;
  }

  bool canTakeDamageFromSpinner(Vector2 spinnerPosition) {
    if (hasDirectionalSpikes) {
      // Mirror of the contact-damage check: the hedgehog is armored on
      // its spike side and only takes damage when struck from one of the
      // perpendicular weak patches.
      return !_hedgehogSpikeFacingSpinner(spinnerPosition);
    }
    return true;
  }

  /// True when the vector from the hedgehog to the spinner lies inside
  /// one of the two spike cones (±[_spikeHalfAngleCos] of the patrol
  /// axis).
  ///
  /// Threshold corresponds to ±45° per cone (cos(45°) ≈ 0.707), so the
  /// spike coverage is ~180° total and the perpendicular "weak lane" is
  /// ~180° total — a clearly readable half/half split.
  static const double _spikeHalfAngleCos = 0.707; // cos(45°)

  bool _hedgehogSpikeFacingSpinner(Vector2 spinnerPosition) {
    final delta = spinnerPosition - position;
    final lenSq = delta.length2;
    if (lenSq < 0.0001) {
      return true;
    }
    final inv = 1.0 / sqrt(lenSq);
    final axisComponent = _patrolAxisVertical ? delta.y * inv : delta.x * inv;
    return axisComponent.abs() >= _spikeHalfAngleCos;
  }

  double spinnerCollisionRestitution({required bool spinnerCanDamage}) {
    if (isBlocker) {
      return 1.2;
    }
    return spinnerCanDamage ? 0.98 : 0.9;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(collisionType: CollisionType.active));

    _behaviorTimer = 0.45 + _random.nextDouble() * 0.8;
    _turretShotTimer = (0.8 + _random.nextDouble() * 0.8) / _fireRateMultiplier;
    if (type == EnemyType.pulser) {
      _groundSlamTimer = 0.7 + _random.nextDouble() * 1.15;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isDead) {
      return;
    }

    _syncHitVisualFromElapsed();

    if (game.isWorldFrozen) {
      return;
    }

    _updateStateTimers(dt);

    if (type == EnemyType.walker) {
      _updateWalkerMovement(dt);
    } else if (type == EnemyType.pulser) {
      _updatePulserMovement(dt);
    } else if (type == EnemyType.hedgehog) {
      _updateHedgehogMovement(dt);
    } else if (type == EnemyType.turret) {
      _updateTurretBehavior(dt);
    } else if (type == EnemyType.paddle) {
      _updatePaddleBehavior(dt);
    } else {
      _updateBossBehavior(dt);
    }

    _applyArchetypeAuras(dt);
    _updateImpulse(dt);
    game.clampEnemyToArena(this);

    if (!isDead &&
        (type == EnemyType.hedgehog ||
            (type == EnemyType.walker && isSpiked))) {
      _spikeHazardPulse += dt * 0.85;
    }
    if (!isDead && type == EnemyType.pulser) {
      _spikeHazardPulse += dt * 0.55;
    }

    // Soft-vector creature animation clocks.
    if (_creatureDamageFlash > 0) {
      _creatureDamageFlash = max(0, _creatureDamageFlash - dt * 5.0);
    }
    _creatureBreathPhase =
        (_creatureBreathPhase + dt * 2.1) % (pi * 2);
  }

  @override
  void render(Canvas canvas) {
    // CircleComponent local origin is top-left; translate so sprite and HP bar
    // are centered on the enemy collision center.
    canvas.save();
    canvas.translate(radius, radius);

    // All creatures now render as soft-vector silhouettes or procedural
    // props. No pixel-sprite fallback path is needed.
    if (type == EnemyType.paddle) {
      _renderPaddle(canvas);
    } else {
      _renderSoftVectorCreature(canvas);
    }

    final barWidth = radius * 1.8;
    final barTop = -radius - 10;
    final left = -barWidth / 2;
    final bg = Paint()..color = const Color(0x66000000);
    final fg = Paint()..color = const Color(0xFF57D16F);

    canvas.drawRect(Rect.fromLTWH(left, barTop, barWidth, 4), bg);
    canvas.drawRect(Rect.fromLTWH(left, barTop, barWidth * healthRatio, 4), fg);
    _renderTaxonomyMarker(canvas);
    canvas.restore();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (isDead) {
      return;
    }

    if ((type == EnemyType.walker ||
            type == EnemyType.hedgehog ||
            type == EnemyType.pulser) &&
        other is WallComponent) {
      _velocity = CollisionSystem.bounce(
        velocity: _velocity,
        normal: other.normal,
        restitution: 1,
      );
    }

    if (other is SpinnerComponent &&
        _contactCooldown <= 0 &&
        canDamageSpinnerOnContact(other.position)) {
      _contactCooldown = 0.45;
      game.onEnemyContact(this);
    }
  }

  void takeDamage(double damage) {
    if (isDead) {
      return;
    }

    _hp -= damage;
    final now = game.elapsedSeconds;
    _hitFlashUntil = now + 0.12;
    _hitPulseUntil = now + 0.14;
    _creatureDamageFlash = 1.0;

    if (_hp <= 0) {
      _die();
    }
  }

  void addImpulse(Vector2 impulse) {
    if (type == EnemyType.paddle) {
      return;
    }
    _impulse += impulse;
  }

  void _updatePaddleBehavior(double dt) {
    _walkPhase += dt * 2.6;
    angle = 0;
    _velocity = Vector2.zero();
  }

  void _syncHitVisualFromElapsed() {
    final now = game.elapsedSeconds;
    if (now < _hitFlashUntil) {
      paint.color = Color.lerp(
        _baseColor,
        const Color(0xFFFF7040),
        0.82,
      )!;
    } else {
      paint.color = _baseColor;
    }

    const pulseDur = 0.14;
    if (now < _hitPulseUntil) {
      final u = ((_hitPulseUntil - now) / pulseDur).clamp(0.0, 1.0);
      final bump = sin(u * pi) * 0.11;
      scale = Vector2.all(1.0 + bump);
    } else {
      scale = Vector2.all(1.0);
    }
  }

  void _updateStateTimers(double dt) {
    if (_contactCooldown > 0) {
      _contactCooldown -= dt;
    }

    if (_dashCooldown > 0) {
      _dashCooldown -= dt;
    }
  }

  void _updateImpulse(double dt) {
    if (_impulse.length2 <= 0) {
      return;
    }

    PhysicsModel.integrate(this, _impulse, dt);
    _impulse = PhysicsModel.applyFriction(_impulse, 0.024, dt);
    if (_impulse.length < 5) {
      _impulse = Vector2.zero();
    }
  }

  void _applyArchetypeAuras(double dt) {
    if (game.isInvasionMode) {
      return;
    }
    if ((!isBlower && !isSucker) || dt <= 0) {
      return;
    }

    final spinner = game.spinner;
    if (spinner == null || !spinner.isMoving) {
      return;
    }

    final toSpinner = spinner.position - position;
    final distance = toSpinner.length;
    if (distance <= 0.0001) {
      return;
    }

    final maxRange = isSucker ? 236.0 : 212.0;
    if (distance > maxRange) {
      return;
    }

    final strength = (1 - (distance / maxRange)).clamp(0.0, 1.0);
    final direction = toSpinner / distance;
    final forceBase = isSucker ? 330.0 : 290.0;
    final force = forceBase * (0.28 + (strength * 0.72)) * dt;
    final impulse = direction * (isSucker ? -force : force);
    spinner.addExternalImpulse(impulse);
  }

  void _updateWalkerMovement(double dt) {
    _behaviorTimer -= dt;
    if (_behaviorTimer <= 0) {
      _velocity = _nextWalkerDirection() * _moveSpeed;
      _behaviorTimer = 0.45 + _random.nextDouble() * 0.8;
    }

    final spinner = game.spinner;
    if (!game.isInvasionMode &&
        spinner != null &&
        _dashCooldown <= 0 &&
        _dashTimer <= 0 &&
        !_dashTelegraphActive &&
        _random.nextDouble() < 0.18) {
      final toSpinner = spinner.position - position;
      if (toSpinner.length > 0 && toSpinner.length < 220) {
        final dashDir = toSpinner.normalized();
        _dashCooldown = 1.7 + _random.nextDouble() * 0.7;
        _dashTelegraphActive = true;
        final dirFrozen = dashDir.clone();
        game.queueWalkerDashTelegraph(
          muzzleWorld: () => position + dirFrozen * (radius + 6),
          dashDirection: dirFrozen,
          onComplete: () {
            _dashTelegraphActive = false;
            if (!isDead && type == EnemyType.walker) {
              _dashTimer = 0.35;
              _velocity = dirFrozen * (_moveSpeed * 2.4);
            }
          },
        );
      }
    }

    if (_dashTimer > 0) {
      _dashTimer -= dt;
      if (_dashTimer <= 0 && _velocity.length2 > 0) {
        _velocity = _velocity.normalized() * _moveSpeed;
      }
    }

    if (_velocity.length2 > 0) {
      PhysicsModel.integrate(this, _velocity, dt);
      if (_dashTimer <= 0) {
        _velocity = _velocity.normalized() * _moveSpeed;
      }
      _walkPhase += dt * (_dashTimer > 0 ? 20 : 12);
      _updateScarabFacing(dt, _velocity);
    }
    if (game.isInvasionMode) {
      position.y += 24 * dt;
    }
    // Scarabs should not spin around themselves.
    angle = 0;
  }

  void _updatePulserMovement(double dt) {
    _behaviorTimer -= dt;
    if (_behaviorTimer <= 0) {
      _velocity = _nextWalkerDirection() * _moveSpeed * 0.9;
      _behaviorTimer = 0.52 + _random.nextDouble() * 0.72;
    }

    if (_velocity.length2 > 0) {
      PhysicsModel.integrate(this, _velocity, dt);
      _velocity = _velocity.normalized() * _moveSpeed;
      _walkPhase += dt * 10;
      _updateScarabFacing(dt, _velocity);
    }
    if (game.isInvasionMode) {
      position.y += 24 * dt;
    }
    angle = 0;

    _groundSlamTimer -= dt;
    if (_groundSlamTimer <= 0 && !isDead) {
      _groundSlamTimer = 3.05 + _random.nextDouble() * 0.95;
      final slamDamage = (13 + game.levelNumber * 2.4).clamp(12, 48).toDouble();
      game.queueEnemyGroundSlam(
        centerWorld: () => position.clone(),
        radius: 102,
        damage: slamDamage,
        telegraphOwner: this,
      );
    }
  }

  void _updateHedgehogMovement(double dt) {
    // Hedgehog locks to a single patrol axis. External impulses (blasts,
    // tether pulls) may have nudged it off-lane this frame — re-snap
    // before integrating so the behaviour stays predictable.
    if (_patrolAxisVertical) {
      _velocity.x = 0;
      if (_velocity.y == 0) {
        _velocity.y = _moveSpeed;
      } else {
        _velocity.y = _velocity.y.sign * _moveSpeed;
      }
    } else {
      _velocity.y = 0;
      if (_velocity.x == 0) {
        _velocity.x = _moveSpeed;
      } else {
        _velocity.x = _velocity.x.sign * _moveSpeed;
      }
    }

    PhysicsModel.integrate(this, _velocity, dt);
    _walkPhase += dt * 6;
    _updateScarabFacing(dt, _velocity);
    // Hedgehogs move without spinning sprite body.
    angle = 0;
  }

  void _updateTurretBehavior(double dt) {
    final spinner = game.spinner;
    if (spinner == null) {
      return;
    }

    final toSpinner = spinner.position - position;
    if (toSpinner.length2 <= 0) {
      return;
    }

    if (!_turretTelegraphBusy) {
      angle = atan2(toSpinner.y, toSpinner.x);
    }

    if (_turretTelegraphBusy) {
      return;
    }

    _turretShotTimer -= dt;
    if (_turretShotTimer <= 0) {
      final direction = toSpinner.normalized();
      final dirFrozen = direction.clone();
      _turretTelegraphBusy = true;
      final dmg = 8 * _projectileDamageMultiplier;
      final spd = (250 + game.levelNumber * 12) * _projectileSpeedMultiplier;
      game.queueTelegraphedEnemyProjectile(
        muzzleWorld: () => position + dirFrozen * (radius + 8),
        fireDirection: dirFrozen,
        beamLength: 420,
        beamHalfWidth: 11,
        fillDuration: 0.36,
        damage: dmg,
        speed: spd,
        telegraphOwner: this,
        onWindupComplete: () {
          _turretTelegraphBusy = false;
          _turretShotTimer = max(
            0.25,
            (1.05 + _random.nextDouble() * 0.75) / _fireRateMultiplier,
          );
        },
      );
    }
  }

  void _updateBossBehavior(double dt) {
    final spinner = game.spinner;
    if (spinner == null) {
      return;
    }

    final toSpinner = spinner.position - position;
    if (toSpinner.length2 > 0) {
      final pursuit = toSpinner.normalized();
      final orbit =
          Vector2(-pursuit.y, pursuit.x) *
          (0.22 + 0.18 * sin(game.levelNumber * 0.7));
      final move = (pursuit + orbit).normalized();
      _velocity = move * _moveSpeed;
      PhysicsModel.integrate(this, _velocity, dt);
      _walkPhase += dt * 10;
      _updateScarabFacing(dt, _velocity);
    }
    // Boss scarab also uses directional walk, not sprite spinning.
    angle = 0;

    if (!_bossFanTelegraphBusy) {
      _turretShotTimer -= dt;
    }
    if (!_bossFanTelegraphBusy && _turretShotTimer <= 0) {
      final toward = toSpinner.length2 == 0
          ? Vector2(1, 0)
          : toSpinner.normalized();
      _bossFanTelegraphBusy = true;
      final dmg = 11 * _projectileDamageMultiplier;
      final spd = (290 + game.levelNumber * 15) * _projectileSpeedMultiplier;
      for (var i = 0; i < 5; i++) {
        final theta = (i - 2) * 0.22;
        final dir = Vector2(
          toward.x * cos(theta) - toward.y * sin(theta),
          toward.x * sin(theta) + toward.y * cos(theta),
        );
        final dirFrozen = dir.clone();
        final isLast = i == 4;
        game.queueTelegraphedEnemyProjectile(
          muzzleWorld: () => position + dirFrozen * (radius + 8),
          fireDirection: dirFrozen,
          beamLength: 380,
          beamHalfWidth: 9,
          startDelay: i * 0.068,
          fillDuration: 0.3,
          damage: dmg,
          speed: spd,
          telegraphOwner: this,
          onWindupComplete: () {
            if (isLast) {
              _bossFanTelegraphBusy = false;
              _turretShotTimer = 0.7 + _random.nextDouble() * 0.35;
            }
          },
        );
      }
    }
  }

  Vector2 _nextWalkerDirection() {
    final spinner = game.spinner;
    if (spinner == null) {
      return _randomUnit();
    }

    final toSpinner = spinner.position - position;
    if (toSpinner.length2 <= 0) {
      return _randomUnit();
    }

    if (archetype == EnemyArchetype.stalker) {
      final pursuit = toSpinner.normalized();
      final jitter = _randomUnit() * 0.1;
      final mixed = pursuit + jitter;
      if (mixed.length2 > 0.0001) {
        return mixed.normalized();
      }
      return pursuit;
    }

    if (_random.nextDouble() < 0.72) {
      final pursuit = toSpinner.normalized();
      final jitter = _randomUnit() * 0.25;
      final mixed = pursuit + jitter;
      if (mixed.length2 > 0) {
        return mixed.normalized();
      }
    }

    return _randomUnit();
  }

  Vector2 _randomUnit() {
    final theta = _random.nextDouble() * pi * 2;
    return Vector2(cos(theta), sin(theta));
  }

  void _updateScarabFacing(double dt, Vector2 direction) {
    if (direction.length2 <= 1) {
      return;
    }

    final blend = (dt * 14).clamp(0, 1).toDouble();
    final creatureTarget = atan2(direction.y, direction.x);
    _creatureFacingAngle = _lerpAngle(_creatureFacingAngle, creatureTarget, blend);
  }

  double _lerpAngle(double from, double to, double t) {
    final delta = atan2(sin(to - from), cos(to - from));
    return from + delta * t;
  }

  /// Route walker / pulser / turret through the procedural soft-vector
  /// creature renderer. Canvas is already translated so Offset.zero is the
  /// creature's visual center. Face elements step-snap to 8 octants while
  /// the body itself does NOT rotate — that's what separates this look from
  /// the old "sprite rotating to face you" feel.
  void _renderSoftVectorCreature(Canvas canvas) {
    final CreatureSilhouette silhouette;
    final CreaturePalette palette;
    switch (type) {
      case EnemyType.walker:
        silhouette = CreatureSilhouette.walkerBug;
        palette = CreaturePalettes.walkerBug;
      case EnemyType.pulser:
        silhouette = CreatureSilhouette.pulserCap;
        palette = CreaturePalettes.pulserCap;
      case EnemyType.turret:
        silhouette = CreatureSilhouette.turretEye;
        palette = CreaturePalettes.turretEye;
      case EnemyType.boss:
        silhouette = CreatureSilhouette.bossGolem;
        palette = CreaturePalettes.bossGolem;
      case EnemyType.hedgehog:
        silhouette = CreatureSilhouette.hedgehogSpiky;
        palette = CreaturePalettes.hedgehogSpiky;
      case EnemyType.paddle:
        // Paddle routes through `_renderPaddle` and re-enters here once
        // wrapped in its own canvas rotation — not called directly.
        return;
    }

    // Telegraph mapping per silhouette:
    //   - turret: shot-wind-up (eye glow rises as the shot timer ticks down)
    //   - pulser: slow cyclic pulse from the shared spike hazard clock
    //   - boss:   slow rune-eye throb tied to its slam cadence
    //   - hedgehog: spike extension breathes with the hazard clock
    //   - default: no telegraph
    final double telegraph;
    switch (type) {
      case EnemyType.turret:
        final ratio = (_turretShotTimer / 2.5).clamp(0.0, 1.0);
        telegraph = (1.0 - ratio).clamp(0.0, 1.0);
      case EnemyType.pulser:
        telegraph = (sin(_spikeHazardPulse * 1.2) * 0.5 + 0.5).clamp(0.0, 1.0);
      case EnemyType.boss:
        telegraph = (sin(_creatureBreathPhase * 0.7) * 0.5 + 0.5).clamp(0.0, 1.0);
      case EnemyType.hedgehog:
        telegraph = (sin(_spikeHazardPulse) * 0.5 + 0.5).clamp(0.0, 1.0);
      default:
        telegraph = 0;
    }

    // Hazard telegraphs painted BEFORE the creature silhouette so the
    // creature visually sits on top of its own danger arc:
    //   - hedgehog: highlights the two perpendicular "weak lane" patches
    //     so players can read the safe strike direction
    //   - walker (spiked variant): concentric danger ring while the spike
    //     hazard is arming
    // These are gameplay tells, not cosmetics, and are separate from the
    // silhouette's built-in telegraphPulse glow.
    if (type == EnemyType.hedgehog) {
      _renderHedgehogWeakSpotGlow(canvas);
    } else if (type == EnemyType.walker && isSpiked) {
      _renderSpikedWalkerHazardRing(canvas);
    }

    final state = CreatureRenderState(
      radius: radius,
      facingAngle: _creatureFacingAngle,
      idleBreathPhase: _creatureBreathPhase,
      damageFlashStrength: _creatureDamageFlash,
      telegraphPulse: telegraph,
      alert: _velocity.length2 > 1 || telegraph > 0.3,
      // Hedgehogs lock their spike clusters to their fixed patrol axis.
      // Other creatures don't use this field.
      spikeAxisAngle: type == EnemyType.hedgehog
          ? (_patrolAxisVertical ? pi / 2 : 0.0)
          : null,
    );
    CreatureRenderer.render(canvas, silhouette, palette, state);
  }

  void _renderPaddle(Canvas canvas) {
    // Paddle: sit the plank silhouette horizontally (long axis = X), bob
    // vertically with `_walkPhase`. The soft-vector silhouette wants "forward"
    // to be +X, so we just draw directly — no rotation needed for this plank
    // (it's a static-orientation bobbing hazard, not a swept blade).
    final bob = sin(_walkPhase) * 0.9;
    canvas.save();
    canvas.translate(0, bob);
    final state = CreatureRenderState(
      radius: radius,
      facingAngle: 0,
      idleBreathPhase: _creatureBreathPhase,
      damageFlashStrength: _creatureDamageFlash,
    );
    CreatureRenderer.render(
      canvas,
      CreatureSilhouette.paddlePlank,
      CreaturePalettes.paddlePlank,
      state,
    );
    canvas.restore();
  }

  /// Subtle glow on the two "weak lane" patches (perpendicular to the
  /// patrol axis). This is the opposite of the old forward-danger wedge:
  /// since hedgehogs now armor their whole patrol axis, the glow tells
  /// players *where it's safe to strike*, not where the danger is.
  void _renderHedgehogWeakSpotGlow(Canvas canvas) {
    final pulse = (sin(_spikeHazardPulse) * 0.5 + 0.5).clamp(0.0, 1.0);
    // Axis perpendicular to the patrol direction: that's where the soft
    // belly shows and the glow lives.
    final perp = _patrolAxisVertical ? Vector2(1, 0) : Vector2(0, 1);
    final glowRadius = radius * 0.32;
    final distance = radius * 0.78;
    final fill = Paint()
      ..color = Color.fromARGB((70 + 90 * pulse).round(), 255, 210, 130)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.2);
    for (final sign in <double>[1, -1]) {
      canvas.drawCircle(
        Offset(perp.x * distance * sign, perp.y * distance * sign),
        glowRadius,
        fill,
      );
    }
  }

  void _renderSpikedWalkerHazardRing(Canvas canvas) {
    final pulse = (sin(_spikeHazardPulse) * 0.5 + 0.5);
    final r = radius * 1.12;
    final stroke = Paint()
      ..color = const Color(0xAAFF6A45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fill = Paint()..color = const Color(0x38FF8560);
    canvas.drawCircle(Offset.zero, r, stroke);
    final sweep = -2 * pi * pulse;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r),
      -pi / 2,
      sweep,
      true,
      fill,
    );
  }

  void _renderTaxonomyMarker(Canvas canvas) {
    final taxonomy = EnemyTaxonomy.markerFor(type: type, archetype: archetype);
    final center = Offset(radius * 0.78, -radius * 0.48);
    final markerRadius = max(6.2, radius * 0.36);

    final plateFill = Paint()..color = const Color(0xC1171717);
    final plateStroke = Paint()
      ..color = const Color(0xFFEEE2C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, markerRadius, plateFill);
    canvas.drawCircle(center, markerRadius, plateStroke);

    _drawGlyph(
      canvas,
      glyph: taxonomy.typeGlyph,
      center: center,
      radius: markerRadius * 0.62,
      fillColor: taxonomy.typeColor,
      strokeColor: const Color(0xFF181414),
      strokeWidth: 0.9,
    );

    final variantCenter =
        center + Offset(markerRadius * 0.55, markerRadius * 0.55);
    final variantRadius = markerRadius * 0.58;
    final variantPlateFill = Paint()..color = const Color(0xD0121214);
    final variantPlateStroke = Paint()
      ..color = taxonomy.archetypeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95;
    canvas.drawCircle(variantCenter, variantRadius, variantPlateFill);
    canvas.drawCircle(variantCenter, variantRadius, variantPlateStroke);

    _drawGlyph(
      canvas,
      glyph: taxonomy.archetypeGlyph,
      center: variantCenter,
      radius: variantRadius * 0.54,
      fillColor: taxonomy.archetypeColor,
      strokeColor: const Color(0xFFF3F0E2),
      strokeWidth: 0.85,
    );
  }

  void _drawGlyph(
    Canvas canvas, {
    required EnemyMarkerGlyph glyph,
    required Offset center,
    required double radius,
    required Color fillColor,
    required Color strokeColor,
    required double strokeWidth,
  }) {
    final fill = Paint()..color = fillColor;
    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final secondary = glyph.secondary;
    if (secondary == null) {
      _drawShape(
        canvas,
        shape: glyph.primary,
        center: center,
        radius: radius,
        fill: fill,
        stroke: stroke,
      );
      return;
    }

    _drawShape(
      canvas,
      shape: glyph.primary,
      center: center.translate(-radius * 0.28, radius * 0.04),
      radius: radius * 0.72,
      fill: fill,
      stroke: stroke,
    );
    _drawShape(
      canvas,
      shape: secondary,
      center: center.translate(radius * 0.33, -radius * 0.08),
      radius: radius * 0.54,
      fill: fill,
      stroke: stroke,
    );
  }

  void _drawShape(
    Canvas canvas, {
    required EnemyMarkerShape shape,
    required Offset center,
    required double radius,
    required Paint fill,
    required Paint stroke,
  }) {
    switch (shape) {
      case EnemyMarkerShape.circle:
        canvas.drawCircle(center, radius, fill);
        canvas.drawCircle(center, radius, stroke);
      case EnemyMarkerShape.square:
        final rect = Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 2,
        );
        final square = RRect.fromRectAndRadius(
          rect,
          Radius.circular(radius * 0.2),
        );
        canvas.drawRRect(square, fill);
        canvas.drawRRect(square, stroke);
      case EnemyMarkerShape.triangle:
        final path = _regularPolygonPath(
          center: center,
          radius: radius,
          sides: 3,
          rotation: -pi / 2,
        );
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case EnemyMarkerShape.hexagon:
        final path = _regularPolygonPath(
          center: center,
          radius: radius,
          sides: 6,
          rotation: -pi / 2,
        );
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
    }
  }

  Path _regularPolygonPath({
    required Offset center,
    required double radius,
    required int sides,
    required double rotation,
  }) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final theta = rotation + ((pi * 2 * i) / sides);
      final point = Offset(
        center.dx + cos(theta) * radius,
        center.dy + sin(theta) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  void _die() {
    isDead = true;
    _turretTelegraphBusy = false;
    _bossFanTelegraphBusy = false;
    _dashTelegraphActive = false;
    removeFromParent();
    game.onEnemyDefeated(this);
  }
}
