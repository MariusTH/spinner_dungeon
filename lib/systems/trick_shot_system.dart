/// Trick-shot rules for a single fling: bank shots (kills after bouncing off
/// walls or bumpers) and multi-kills. Pure logic so it can be unit tested;
/// the game feeds it events and turns results into score, coins and callouts.
class TrickShotTracker {
  int _banks = 0;
  int _kills = 0;

  /// Wall/bumper bounces since the last launch.
  int get banks => _banks;

  /// Kills since the last launch.
  int get kills => _kills;

  void onLaunch() {
    _banks = 0;
    _kills = 0;
  }

  void onBank() {
    _banks++;
  }

  /// Registers a kill made by the moving spinner and returns its reward.
  TrickKill onKill() {
    _kills++;
    final callouts = <String>[];
    var scoreMultiplier = 1.0 + 0.15 * (_kills - 1).clamp(0, 12);
    var bonusCoins = 0;

    if (_banks >= 3) {
      callouts.add('RICOCHET!');
      scoreMultiplier += 1.0;
      bonusCoins += 2;
    } else if (_banks >= 1) {
      callouts.add('BANK SHOT!');
      scoreMultiplier += 0.5;
      bonusCoins += 1;
    }

    final multi = multiKillLabel(_kills);
    if (multi != null) {
      callouts.add(multi);
      bonusCoins += _kills - 1;
    }

    return TrickKill(
      chainIndex: _kills,
      callouts: callouts,
      scoreMultiplier: scoreMultiplier,
      bonusCoins: bonusCoins,
    );
  }

  static String? multiKillLabel(int kills) {
    if (kills >= 4) {
      return 'CARNAGE!';
    }
    return switch (kills) {
      2 => 'DOUBLE!',
      3 => 'TRIPLE!',
      _ => null,
    };
  }
}

class TrickKill {
  const TrickKill({
    required this.chainIndex,
    required this.callouts,
    required this.scoreMultiplier,
    required this.bonusCoins,
  });

  /// 1 for the first kill of the fling, 2 for the second, ...
  final int chainIndex;

  /// Labels to pop over the kill, most important last.
  final List<String> callouts;
  final double scoreMultiplier;
  final int bonusCoins;
}

/// Kill combo that survives between flings. Every kill refreshes a short
/// window; the window only drains while the spinner is at rest, so the
/// player keeps a combo alive by re-flinging quickly.
class ComboTracker {
  static const double window = 3.0;

  int _count = 0;
  double _remaining = 0;

  int get count => _count;

  /// 1..0 share of the window left; 0 when no combo is running.
  double get fraction => _count == 0 ? 0 : (_remaining / window).clamp(0, 1);

  /// Score multiplier for the next kill: +10% per combo kill, max x3.
  double get multiplier => 1 + 0.1 * _count.clamp(0, 20);

  void onKill() {
    _count++;
    _remaining = window;
  }

  /// Advances time. Returns the finished combo's size when it runs out.
  int? tick(double dt, {required bool draining}) {
    if (_count == 0 || !draining) {
      return null;
    }
    _remaining -= dt;
    if (_remaining > 0) {
      return null;
    }
    return end();
  }

  /// Ends the combo now (e.g. on leaving the floor) and returns its size.
  int? end() {
    if (_count == 0) {
      return null;
    }
    final finished = _count;
    _count = 0;
    _remaining = 0;
    return finished;
  }

  /// Coins paid out when a combo of [size] ends; small combos pay nothing.
  static int payoutCoins(int size) => size < 3 ? 0 : size ~/ 2;
}

enum FloorPaceTier { none, speedy, blazing }

/// Reward for clearing a floor fast ("racing down into the abyss").
class FloorPace {
  const FloorPace._();

  /// Par time in seconds for a floor with [roomCount] rooms.
  static double parSeconds(int roomCount) => 12.0 + roomCount * 16.0;

  static FloorPaceTier tierFor({
    required double elapsedSeconds,
    required int roomCount,
  }) {
    final par = parSeconds(roomCount);
    if (elapsedSeconds <= par * 0.6) {
      return FloorPaceTier.blazing;
    }
    if (elapsedSeconds <= par) {
      return FloorPaceTier.speedy;
    }
    return FloorPaceTier.none;
  }

  static int bonusCoins(FloorPaceTier tier, int levelNumber) {
    return switch (tier) {
      FloorPaceTier.blazing => 6 + levelNumber,
      FloorPaceTier.speedy => 3 + levelNumber ~/ 2,
      FloorPaceTier.none => 0,
    };
  }

  static String? label(FloorPaceTier tier) {
    return switch (tier) {
      FloorPaceTier.blazing => 'BLAZING DESCENT!',
      FloorPaceTier.speedy => 'SPEEDY!',
      FloorPaceTier.none => null,
    };
  }
}
