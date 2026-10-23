# Enemies — shapes, colors, and behavior

Enemies are drawn as **soft-vector silhouettes** (`lib/game/creature_body.dart`). Gameplay identity is reinforced by **body color** (family), **collision radius** (size), and a small **taxonomy marker** above the HP bar (`lib/game/enemy_taxonomy.dart`): **primary type glyph**, optional **secondary type glyph**, and **archetype** shapes/colors.

## Shape legend (glyphs)

| Shape | Meaning in this project |
|-------|-------------------------|
| **△ Triangle** | Used in type/archetype markers (turret, hedgehog, blower, spiked, stalker combos). |
| **□ Square** | Walker body type; absorber/blocker archetype markers. |
| **○ Circle** | Paddle type marker; “orb” second mark on hedgehog/pulser; standard archetype. |
| **⬡ Hexagon** | Boss and pulser type marks; sucker / spiked combo marks. |

Markers are drawn as small filled shapes above the HP bar — **not** the full creature outline (the creature art is procedural bugs / golems / etc.).

## Enemy types (body color + default radius)

Source: `EnemyTaxonomy.bodyColorForType`, `EnemyComponent` constructors.

| Type | Body color (hex) | Default radius | Behavior summary |
|------|------------------|----------------|------------------|
| **Turret** | `#E06161` red | 18 | **Stationary.** Rotates to face the spinner. Fires **telegraphed beam shots** (wind-up, then projectile). |
| **Walker** | `#F0B248` amber | 16 | **Mobile.** Picks mixed wander / pursuit directions; occasional **dash** toward the spinner (with telegraph). In invasion mode, also **drifts downward**. |
| **Boss** | `#E87E4E` orange | 24 | **Chaser + shooter.** Moves in a pursuit+orbit pattern. Fires **fan of five** telegraphed shots. |
| **Paddle** | `#E35B5B` red-pink | 18 | **Prop hazard.** Bobbing plank; **does not count** toward room clear. No contact damage by default — **blocks / deflects** the spinner. |
| **Hedgehog** | `#8A9F56` green | 24 | **Lane-locked.** Slides on **one axis** only. **Spike side** along patrol hurts the spinner and is **armoured** (hits deal 35%, "CLANK"); **weak sides** perpendicular take a **critical** 2× hit ("CRIT!"). Never fully immune. Weak zones get a **glow tell**. |
| **Pulser** | `#9B5FD6` purple | 19 | **Mobile** like a walker. Periodically triggers a **ground slam** — large **AOE** after telegraph (damage in a big radius). |

### Type marker shapes (primary / secondary)

| Type | Primary | Secondary |
|------|---------|-----------|
| Turret | △ | — |
| Walker | □ | — |
| Boss | ⬡ | — |
| Paddle | ○ | — |
| Hedgehog | △ | ○ |
| Pulser | ⬡ | ○ |

## Archetypes (modifier color + marker)

Stacked on the same marker row; affects stats and some AI. Source: `EnemyArchetype`, `EnemyTaxonomy.archetypeGlyphFor` / `archetypeColorFor`.

| Archetype | Color (hex) | Marker | Gameplay notes |
|-----------|-------------|--------|----------------|
| **standard** | `#8B8B8B` grey | ○ | Baseline. |
| **absorber** | `#59D8A8` teal | □+○ | On **spinner contact**, **dampens** velocity and spin (`SpinnerComponent` collision). |
| **blower** | `#6BC7FF` sky | △ | While spinner is **moving**, applies **outward** impulse along the line to this enemy, **falling off** with distance (dungeon mode). |
| **sucker** | `#B18BFF` violet | ⬡ | While spinner is **moving**, applies **inward** pull on the same line, **falling off** with distance (dungeon mode). |
| **blocker** | `#BFC5CC` light grey | □ | **Higher** bounce restitution vs spinner. |
| **spiked** | `#FF8C6B` coral | △+⬡ | **Always** deals contact damage (where contact applies). **Walker** + spiked: extra **hazard ring** tell. |
| **stalker** | `#FF5C5C` red | △+□ | **Walker** pathing favors **direct pursuit** (less random wander). |

Blower / sucker auras are **disabled in invasion mode** (`_applyArchetypeAuras`).

## Killability rule and skill checks

Every enemy can always be damaged. `EnemyComponent.spinnerHitKind` classifies each spinner strike into an `EnemyHitKind`, which only scales damage and names a callout:

| Enemy | Skill check | Kind | Damage |
|-------|-------------|------|--------|
| Hedgehog | Strike a weak (perpendicular) side | `CRIT!` | 2× |
| Hedgehog | Strike the spike side (also hurts you) | `CLANK` | 0.35× |
| Turret | Strike from behind while its aim is locked for a shot | `BACKSTAB!` | 2.5× |
| Walker | Strike it mid-dash or during the dash wind-up | `COUNTER!` | 2× |
| Pulser | Strike it while its slam charges — the slam is cancelled and it explodes, hurting nearby enemies | `OVERLOAD!` | 2× |

Pulser slams that do land also hurt other enemies caught in them (80% damage).

Enemy HP scales with depth at roughly half the rate of other danger stats (`_enemyHpScale`, x0.87–1.9), so deep enemies still die in a few good hits.

## Size (reading the arena)

- **Larger radius** = larger hitbox and (usually) more HP.
- Rough tier from code defaults: **walker (16) < turret/paddle (18) < pulser (19) < boss/hedgehog (24)**.
- Scalers (`hpMultiplier`, `speedMultiplier`, etc.) from spawning code can change effective difficulty without changing the base silhouette.

## Code map

- Types & marker definitions: `lib/game/enemy_taxonomy.dart`
- Behavior & rendering: `lib/game/enemy_component.dart`
- Procedural art: `lib/game/creature_body.dart`
- Projectiles: `lib/game/enemy_projectile_component.dart`

When you add a new `EnemyType`, update **this file**, `EnemyTaxonomy`, and the `EnemyComponent` / spawn paths so markers and colors stay in sync.
