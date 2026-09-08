import 'dart:ui' show Rect;

/// Design notes: replacing obvious brick tiling with **noise-splatted dungeon stone**
/// (agent.md: base #919090, cool shadows #27367b, large logical tiles, hidden grid).
///
/// ## Option A — Flame / Canvas fragment shader (preferred at runtime)
/// Single full-screen or floor-chunk shader sample:
/// - **UV**: world position × `1 / tileWorldSize` (64 or 128 world units).
/// - **Macro variation**: `hash(floor(uv))` or cheap value noise on cell id to pick
///   one of N stone albedo variants and rotate 0/90/180/270°.
/// - **Micro splat**: combine 2–3 layers of sine / triangle waves at **incommensurate**
///   scales, e.g. `sin(dot(uv, vec2(17.0, 23.0)))`, `sin(dot(uv, vec2(41.0, 29.0)))`,
///   `fract(sin(dot(uv, vec2(12.9898,78.233))) * 43758.5453)` — breaks grid aliasing.
/// - **Mortar mask**: `smoothstep` on `fract(uv)` edges with width driven by splat
///   noise so joints are irregular, not a perfect grid.
/// - **Cool shadow wash**: multiply or overlay #27367b in cavity regions (low splat).
/// - **Outline rule**: keep environment edges off pure black; use cooled shadow color.
///
/// Ship as [FragmentShader] `.frag` asset + uniform: `uCameraOrigin`, `uTileSize`,
/// `uTime` (optional subtle shimmer), atlas slots for 3–4 stone tones.
///
/// ## Option B — Large tilemap + rule tiles (art-heavy)
/// - Author 64×64 / 128×128 Wang or blob tiles with broken edges.
/// - At generation time, stamp from **Poisson or noise-weighted** distribution so
///   the same tile index never forms a visible lattice; use a second overlay layer
///   for cracks/decals.
///
/// ## Option C — Hybrid (fast to ship in Flutter without custom frag today)
/// - Draw floor in chunks; per chunk, pick transform (flip/mirror) from `hash(chunkId)`.
/// - Overlay a semi-transparent Canvas noise gradient (low frequency) modulating
///   blend between two stone colors (#919090 ↔ slightly lighter/darker).
///
/// This file holds no runtime implementation yet; hook the chosen path from
/// [DungeonPreviewRenderer] / floor paint code when ready.

typedef StoneSplatUv = ({double x, double y});

/// Cheap deterministic hash for CPU-side experiments (mirrors shader intent).
double stoneSplatMix(StoneSplatUv worldUv, double tileInv) {
  final gx = (worldUv.x * tileInv).floor();
  final gy = (worldUv.y * tileInv).floor();
  var h = (gx * 374761393 + gy * 668265263) & 0x7FFFFFFF;
  h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF;
  return ((h & 0xFFFF) / 65535.0).clamp(0.0, 1.0);
}

Rect stoneChunkRect({required double left, required double top, required double size}) {
  return Rect.fromLTWH(left, top, size, size);
}
