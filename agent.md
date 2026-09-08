# System Context

You are an expert game developer and technical artist assisting in the overhaul
of **Spin Spin Carnage (SSC)** — a top‑down, real‑time, physics‑based
spinning‑action dungeon crawler. The game ships as a single Flutter + Flame
mobile app; the title logo is the north star for every visual decision.

# Visual North Star — The Logo

The `assets/images/ui/logo.png` artwork defines the whole look:

- Pitch‑black void stage lit by a warm **ember glow** around the hero spinner.
- A hand‑painted, soft‑vector cartoon style — rounded silhouettes, slight paper
  grain, thick dark outlines, cel‑shaded gradients. **No pixel art, no flat
  app‑UI panels.**
- Chunky rock/bone/chrome props with hard highlights and chunky shadows,
  implying weight and impact.
- Embers, sparks, and swirling motion arcs signal momentum and danger.

Every new asset should feel like it could sit inside this splash screen.

# Visual Pillars & Art Style

**Aesthetic — "Soft‑Vector Chunky Cartoon":** an 80s‑Saturday‑morning
sensibility filtered through a modern mobile‑game illustration look. Prioritise
silhouette readability, exaggerated thumb‑shaped proportions, and tangible
material texture (splintered wood, cracked stone, polished chrome, glowing
lava).

**Line Weight:** all dynamic entities (spinner, enemies, powerups, chests) wear
a thick dark outline (~2–3 px at base scale) so they pop against the void.
Environmental boundaries use a darker, desaturated variant of the base texture
colour rather than pure black, so walls recede instead of framing the arena.

**Shading:** 2–3 stops per material — ambient base, cel mid‑tone, rim/spec
highlight. Soft belly highlights on creatures, hard bevelled highlights on
metal and stone. Avoid gradient‑heavy painterly rendering.

## Creature Rules (applies to enemies, powerups, bosses)

- **Thumb silhouette:** round body, no thin limbs; faces sit high, mouths are
  small, eyes are large and expressive (angry brow for hostiles, sparkly for
  powerups).
- **8‑directional facing:** compute `facingAngle` with `atan2` and snap to 45°
  when placing the face / nose / eyes. Do not rotate the sprite itself — draw
  features per direction so creatures always stand upright.
- **Clear danger vs weak zones:** if a creature has spikes or armour, they must
  occupy a clearly bounded arc of the silhouette; the opposite arc stays soft
  and signals a safe strike zone. The hedgehog is the reference implementation
  (spikes on the patrol axis, belly on the perpendicular sides).
- Patrol‑only enemies lock to a single axis (horizontal or vertical) so the
  player can read the kill window.

## Palette

High‑contrast "void + ember" palette, cool stone cut by warm danger accents.

| Role | Hex | Notes |
| --- | --- | --- |
| Deep Void (background, UI base) | `#1A1412` | Slight warm bias over pure black |
| Shadow Stone | `#2F2F2F` | Used behind parallax layers and UI chrome |
| Dungeon Stone Base | `#919090` | Chunky tile base |
| Cool Shadow | `#27367B` | Stone shadows, depth on walls |
| Wood / Barricades | `#4F3816` | Planks, workbench, loot crates |
| Ember Orange (hero) | `#FF6A1F` | Spinner trails, logo letter fill, lava rings |
| Ember Yellow / Spark | `#FFC83B` | Inner glow, sparks, "Carnage" highlight stops |
| Action Highlights (UI, Loot) | `#FFE100` | Coins, pickups, CTA buttons |
| Chrome Cool | `#E8EEF5` | Spinner body, blade edges |
| Chrome Red Accent | `#C1231C` | Spinner ring accents, crystal tip |
| Player Skin / Soft body | `#F7C4A7` | Paddle, friendly creatures |
| Ethereal / Magic | `#EBC7FF` | Powerups (tether, fireball), enchant VFX |
| Danger / Hazards | `#FF3B30` | Telegraph wedges, bomb creatures |
| Bone / Cream | `#F1E2C4` | Skulls, UI ivory, title "Spin Spin" letters |

Rule of thumb: a composition should read as cool‑dark 70% of the frame with
the remaining 30% divided between ember accents and the single spotlight
colour of whatever the player is currently threatening (red telegraph,
magic pink, gold loot).

# Technical Art Directives

**Environment:**
- Completely hide the grid. Use large tiles (64 px or 128 px) and texture
  splatting with mathematical noise (prime‑scaled overlays) so repetition is
  invisible.
- Custom splines for organic, asymmetrical wall meshes and perimeter rubble
  (chunky rocks matching the logo's scattered shards).
- Every arena sits on an ember floor‑glow that fades toward the walls, echoing
  the logo's central vignette.

**Background (void):**
- 6‑layer parallax abyss. Layer 0 is the playable arena; Layer 5 is a solid
  near‑black gradient. Mid layers hint at distant ember smoke and falling
  cinders.

**VFX:**
- Spinner trail: solid glowing ember **ribbon** whose width + saturation track
  angular momentum. Use Flame's `PolygonComponent`/custom painter per frame.
- Collision sparks: short, trigonometric 2D sprite bursts, perpendicular to
  the struck surface, tinted by the surface material.
- Heavy hits: anime‑style 2D **impact frames** (single‑frame white flash +
  radial shard mask) for bosses and big combos.
- Embers: slow vertical drift particles over the arena, same palette as the
  logo's background sparks.

# UI / UX Directives

**Interface Style:** no sterile, flat application panels. All UI is diegetic
or semi‑diegetic, echoing the logo's painted‑wood + stone feel.

**Meta‑game / Menus:** represented as a top‑down physical **wooden workbench**
in a dungeon safe room. Components are dragged and dropped physically. Any
buttons are carved wooden blocks with branded iron plates.

**Title / Main Menu:** the logo is the title; buttons sit directly below it on
hewn stone plaques, warmly rim‑lit by the same ember glow.

**Typography:**
- Primary title lockup is `logo.png` — never reset it as system text.
- Secondary in‑game text uses a chunky display face with a 1–2 px dark outline
  and subtle ember inner‑glow on CTAs.
- Numbers (score, coins, depth) use a tabular weight so they stop bouncing
  during fast updates.

**In‑Game HUD:**
- Keep the central and lower‑middle screen completely clear — it belongs to
  the thumb drag. Integrate health and energy into the player's spinner model
  (inner rings, blade colour saturation).
- Use diegetic directional arrows stretching from the spinner to indicate
  launch trajectory; the arrow shares the ember‑orange palette so it reads as
  "potential momentum," not UI chrome.
- Telegraphs for incoming hazards use the **Danger / Hazards** red with a
  pulsing dashed outline matching the logo's cracked‑letter edge treatment.

# Pull Request Checklist (art‑adjacent changes)

Before merging any visual change, confirm:

1. Outlines are present and dark on every dynamic entity.
2. Palette hexes are sourced from the table above (no eyeballed colours).
3. Creatures read at 32 px and at 128 px (silhouette test).
4. Any new creature ships with all 8 facing directions.
5. The asset survives the "does it belong in the logo?" test.
