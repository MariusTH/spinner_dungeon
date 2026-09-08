/// Version of the semantic tile vocabulary. Bump when adding/remapping IDs so
/// shipped [RoomTemplate] JSON and LDtk projects can be validated.
const int kTileSemanticsVersion = 1;

/// Shared **game** meaning of each IntGrid / cell value. All [DungeonTheme]s map
/// these IDs to different art in per-theme JSON; layouts stay identical across themes.
///
/// Convention: `0` is always walkable floor. Higher IDs are bands, props, or hazards.
abstract final class TileSemantics {
  /// LDtk / raw export void (no tile).
  static const int empty = -1;

  /// Open walkable floor (Wang background may still render underneath).
  static const int floor = 0;

  /// Full-width band along the **north** edge of the room (ASCII row of `1`s).
  static const int wallNorthBand = 1;

  /// Full-width band along the **south** edge.
  static const int wallSouthBand = 2;

  /// Band along **east** / **west** (vertical strips).
  static const int wallEastBand = 3;
  static const int wallWestBand = 4;

  /// Interior solid cell (blocking), e.g. pillar or chunk.
  static const int solidBlock = 5;

  /// Pit / void (no floor walk — may use pit logic later).
  static const int pit = 6;

  /// Hazard: light contact damage tier.
  static const int hurtLow = 7;

  /// Hazard: heavy contact damage tier.
  static const int hurtHigh = 8;

  /// Highest ID reserved in v1 (extend list + bump [kTileSemanticsVersion]).
  static const int maxDefined = 8;

  static bool isDefined(int id) =>
      id == empty || (id >= floor && id <= maxDefined);

  /// Used for [WallComponent] placement (axis-aligned blocking).
  /// True if the cell should be non-walkable for generic pathing. (Pits are
  /// non-walkable but use [PitComponent], not [WallComponent].)
  static bool blocksMovement(int id) {
    switch (id) {
      case floor:
      case empty:
      case hurtLow:
      case hurtHigh:
        return false;
      case pit:
        return true;
      default:
        return id >= wallNorthBand && id <= solidBlock;
    }
  }

  /// Solid [WallComponent] for interior template cells (excludes pits / hurt only).
  static bool createsSolidWall(int id) {
    if (id == pit || isHazard(id)) {
      return false;
    }
    return id >= wallNorthBand && id <= solidBlock;
  }

  static bool isPit(int id) => id == pit;

  /// Optional tick damage when standing in cell (separate from walls).
  static bool isHazard(int id) => id == hurtLow || id == hurtHigh;

  static int hazardDamageTier(int id) {
    switch (id) {
      case hurtHigh:
        return 2;
      case hurtLow:
        return 1;
      default:
        return 0;
    }
  }
}
