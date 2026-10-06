# Design notes

How the first slice implements the brief, and where each system goes next.
Numbers quoted here are the current defaults; they're exported or kept as
constants so they're easy to tune.

---

## 1. Movement — goofy, floppy, physics-based

### Hybrid controller

| Layer | Node | Job |
|---|---|---|
| Control | `Goblin` (`CharacterBody3D`) | Reads input, moves, jumps, collides. Always responsive. |
| Personality | `GoblinRig` (procedural, top-level) | Springs turn the controller's state into an exaggerated cartoon pose every frame. |
| Physical reactions | `GoblinRagdoll` (temporary `RigidBody3D` limbs + `ConeTwistJoint3D`) | Spawned for big events, copying the rig's pose so the hand-off is seamless. |

The rig interpolates between physics ticks (`prev_physics_pos` → current), so
it stays smooth on high-refresh displays even though movement runs at 60 Hz.

### Keeping the player in control

The comedy comes from the body, not from taking control away:

- **Input is always read.** Jumps are buffered (0.14 s) and coyote time
  (0.12 s) is on, so platforming stays fair.
- **Stumbles don't stop you.** Speed is capped at about walk speed for under
  a second, with a sideways sway on top of your steering.
- **Ragdolls have clear causes:** explosions, hits with force ≥ 11 (boar
  charge, brute slam, spike trap), landings from more than about 25 m/s of
  fall speed, sliding down slopes too steep to stand on, or balance hitting
  100%.
- **Even ragdolled you can act.** The movement direction pushes the torso
  ("wiggling"). Mashing jump shortens recovery once the body has stopped
  flying through the air, and recovery never starts mid-air.
- **Random trips are rare.** They only happen while sprinting on the ground,
  with at least 25 s between trips. About 75% are near-misses (a stumble).
  The rate scales with instability and with the **Clumsiness** slider in the
  pause menu, which goes from 0 (never) to 2 (chaos).

### Momentum

- **Acceleration and deceleration.** Fast start (32 m/s²), slower spin-up into
  a sprint (14 m/s²), and a slidey stop (17 m/s²).
- **Limited turning.** The velocity direction can only rotate so fast: 14 rad/s
  at walking speed, down to 4 rad/s at a sprint, and lower again with heavy
  parcels. The body yaw catches up separately and lags at a sprint, which is
  where "the body leans and takes a moment to catch up" comes from.
- **Skids.** Reversing more than ~125° above 5.5 m/s triggers a skid. The
  goblin leans back, windmills its arms and kicks up dust, then turns around.
- **Balance.** A hidden 0–1 value. Hard turns at speed, unstable parcels,
  overloading, landings and hits all add to it, and it decays over time.
  Above 0.6 you stumble; at 1.0 you fall over.

### Animation (all procedural, spring-driven)

| Brief | How |
|---|---|
| Wobble while standing | Noise-driven lean, breathing bob, dangling arms, floppy head roll. After 5 s idle the goblin fidgets: looks around, scratches its head, wobbles, yawns. |
| Lean when turning / sprinting | Lean is derived from acceleration (forward and sideways), plus an extra sprint lean. The springs are underdamped, so the goblin overshoots and wobbles back. |
| Bob while walking | Step phase advances with distance travelled. The hips bob and waddle, and the head and ears bounce on each step. |
| Swing arms while running | Arms swing opposite the legs, and flap wildly at a sprint. |
| Funny direction changes | The head turns toward the new direction first (anticipation), the body follows, and there's the skid pose. |
| Goofy jump / landing | A one-frame squash, then a big stretch with arms thrown up. The landing squash scales with impact, and everything jiggles: ears, cap, head, arms. |
| Flail when falling | Arms windmill and the legs "run on air". Below −8 m/s the face switches to scared. |
| Stumble / hit | Arms windmill, the body sways, the face panics. Hits kick the springs in the direction of the impact. |
| Get up awkwardly | The pose starts face-down, the springs pull upright with low stiffness, and the head shakes with a dizzy face. |
| Facial expressions | neutral, happy, determined (sprint), scared, panic, ouch, dizzy, strain (heavy load), sleepy. Plus random blinks, pupils that look where you're steering, and asymmetric eyes. |

### Physics reactions

The goblin pushes rigid props (crates, barrels, hay bales) out of the way.
Heavy props rolling into the goblin hit it in turn. Explosions apply radial
impulses to everything in the `explodable` group, and explosive barrels set
each other off in chains. Spike traps launch the goblin. Boars that miss
their charge bonk into trees and get stunned.

---

## 2. Packages and movement

`PackageCarrier` combines what you're carrying into movement modifiers
(speed, acceleration, jump, turn rate, instability) and simulates each parcel
on a spring:

| Type | Weight | Effect |
|---|---|---|
| Small | 1 | Normal movement. |
| Heavy | 5 | Noticeably slower, lower jumps, wider turns. |
| Huge | 4 | Carried in front with arms full. The camera rises and pulls back because you can barely see around it. Only one at a time. |
| Fragile | 1.5 | Loses integrity on hard landings, hits, ragdolls, and when you bonk things with your satchel. Pay is scaled by integrity; at 0% it shatters. |
| Unstable | 2.5 | Very springy, so the stack sways and leans while you run, and it keeps pushing your balance. |
| Magical | 0 | Floats behind you on a lazy spring, with its own light. |
| Explosive | 2 | Fragile-ish. Hisses below 40% integrity and explodes at 0%, ragdolling you. |
| Living | 2 | Jolts every few seconds, shoving you sideways and adding balance. Occasionally makes noises. |

Carrying more than your capacity (9, or more with the Strong-Back Belt)
overloads you: slower and much less stable.

---

## 3. Camera

`GoblinCamera` is an orbit rig (yaw → pitch → `SpringArm3D` → `Camera3D`)
following an interpolated target.

- **Framing.** It sits 6.2 m back at about −18° pitch, so the whole body and
  its animation stay visible.
- **Smoothing.** Horizontal follow is tight; vertical follow is looser so
  jumps read clearly. While ragdolled it follows looser still and pulls back
  1 m.
- **Auto-follow.** When you aren't steering the camera, it drifts gently
  behind the direction you're running. It never whips around when you run
  toward it.
- **Reactions.** Sprinting pulls the camera back about 0.9 m, widens the FOV
  by 6° and adds a gentle sway. Landings, hits and explosions shake it using
  squared "trauma" with hard caps (0.28 m offset, 2.5° roll). Hits also give
  a springy kick away from the impact.

---

## 4. Art direction

- **One material.** Everything is built with `MeshKit`: flat-shaded, chunky,
  low-poly primitives with per-face colour jitter for a hand-painted feel.
  Colour lives in the vertices, so each building is one mesh with one shared
  material, which means one draw call.
- **Lighting.** Stylised: toon diffuse with a rim light on characters and
  props, a warm sun with crisp two-split shadows, sky ambient, light fog,
  filmic tonemapping, a little glow and a little extra saturation. See
  `Atmosphere`.
- **Proportions.** Exaggerated: the goblin has a huge head, a tiny body,
  noodle arms with big hands, big feet and an oversized courier cap.
- **Terrain.** Gently terraced into shelves and short ramps, and ringed by
  low-poly mountains so the region reads as a bowl.
- **Replacing art.** Artists can replace any piece by saving
  `res://pieces/<piece_id>.tscn`, and the generator uses it automatically.

---

## 5. The procedural world

```
World Seed
 → Biome Selection        Biomes.select (weighted; only Green Fields implemented)
 → Terrain Generation     noise heightmap + rim mountains + terraces; forest density map
 → Site Selection         village (with the post office), 2 hamlets, dungeon, 2–3 camps, 3 landmarks
 → Terrain Shaping        flatten building sites
 → Road Generation        A* (AStarGrid2D) per road profile, Chaikin smoothing, carving,
                          bridges over water, signposts
 → Settlement Placement   streets follow arriving roads; lots along streets; handcrafted pieces
 → Dungeon Placement      entrance facing its trail + a room-graph layout
 → Enemy Camps            tents, campfire, bandits, a chest, and a chief (who is a recipient!)
 → NPC Locations          residents at their doors, wanderers on plazas, hermit, dungeon prisoner
 → Delivery Jobs          chains + singles, priced by distance/danger/package
 → Loot                   seeded chest contents, coin piles (richer on dangerous routes)
 → Random Events          ambush, merchant, lost parcel, broken cart, rival courier
 → Final World
```

### Determinism

Every stage draws from its own named random stream
(`WorldRng.stream(seed, "roads")`, `"settlement:hamlet_0"`,
`"veg:4:7"`, and so on). Adding a stage, or drawing more numbers in one
stage, doesn't change the others. `tests/run_tests.gd` checks that the same
seed gives an identical world signature and different seeds give different
ones.

### Handcrafted feel, not noise

- **Settlements** are assembled from building pieces along streets that line
  up with the roads that actually arrive there. Important buildings claim the
  lots nearest the plaza. The post office always faces the plaza, with a
  notice board and a tall flag so you can find home.
- **Personality** sets the building mix, palette, props, villager species
  and dialogue:
  - *Wealthy*: blue roofs, a statue of the Founder of the Post, guard towers.
  - *Goblin-run*: crooked huts with spikes and junk, goblin villagers.
  - *Farm*: barn, windmill, crop fields with fences.
  - *Abandoned*: ruins and a single resident.
  - *Bandit-controlled*: dark palette inside a palisade.
- **Roads** come in three profiles, which is where route choice comes from:
  - `main` hates slopes, forest and camp proximity, so it's **safe but slow**.
  - `shortcut` ignores all of that, so it's **fast but dangerous**. It's only
    kept if it's at least 14% shorter than the safe route, and it gets bandit
    guards and ambush events.
  - `trail` leads out to the dungeon and landmarks.
  - New roads get a discount on cells that already carry road, so the network
    merges into junctions instead of running in parallel.
- **The dungeon** grows outward from the entry, biased toward extending the
  deepest branch. The deepest room is where the recipient is stuck. The room
  before it gets a brute boss, dead ends become treasure rooms, and up to two
  rooms get spike traps. One extra connection is sometimes added (60% chance)
  so it isn't a pure tree, and a secret room sits behind a cracked wall that
  you bonk open.

### Deliveries

- **Built from the world.** Jobs are generated from real sites and named
  NPCs. The reward is `10 + 0.07·distance + 25·danger + type bonus`.
- **Destinations shape the parcel.** Dungeon recipients get weird magical or
  living parcels, bandit chiefs get explosives, and wealthy towns get
  fragile goods.
- **Chains.** Each world starts with two chains of 3–4 legs. Leg *n*'s
  destination is leg *n+1*'s origin (each hamlet has a board), so a planner
  can run a whole route without going home. Later legs pay 20% more.
- **Guaranteed spice.** There's always a job into the dungeon ("The package
  recipient is unfortunately inside the dungeon.") and one to a bandit chief.
- **Refills.** When boards run low, a new deterministic round of jobs is
  generated (`deliveries:<round>`).

### Biome data

Everything that makes a biome distinct is stored as data in a `BiomeDef`:
colours, terrain shape, tree mix, enemies, settlement personalities,
package/event/loot weights, landmarks, dungeon theme, music id, weather and
secrets. Adding a biome means writing a new `BiomeDef` in `Biomes`; the
generators don't need new code.

---

## 6. Performance

- **Small region.** 512 × 512 m as pure data: a heightmap plus ground,
  occupancy and forest maps (about 2 MB). Generation takes about 0.75 s.
- **Streaming.** `ChunkManager` keeps 9 × 9 chunks of 32 m around the player
  and builds them nearest-first under a per-frame time budget. Each chunk is
  one terrain mesh plus a `HeightMapShape3D`. Far chunks are freed.
- **Vegetation.** Scattered deterministically per chunk when the chunk loads,
  so it uses no memory for land you're not near. It's rendered with
  `MultiMeshInstance3D`, with per-type visibility ranges (grass 45 m, trees
  about 210 m).
- **Shared meshes.** Pieces are cached and shared between instances. Each
  building is one mesh using the one shared material.
- **Cheap far objects.** Enemies sleep beyond 70 m. Lights fade with
  distance and cast no shadows. FX puffs are pooled.
- **Dungeons** are built only when entered, and the overworld is hidden while
  you're inside.
- **Measured:** about 9 ms to build one chunk (headless). The next step is
  moving chunk mesh building onto `WorkerThreadPool`.

---

## 7. Roadmap

Following the brief: get the slice reliable first, then grow the generator.

1. **Feel pass.** Playtest and tune the numbers in the Movement Playground.
   Add audio: footsteps, squeaks, "oof"s and the living-parcel noises.
2. **Second biome (Dark Forest).** Add a `BiomeDef`, wolves and a new tree
   set, plus multi-biome regions with blended borders.
3. **Bigger worlds.** Several regions stitched by roads, region-level
   streaming, threaded chunk builds, and HLOD for distant settlements.
4. **More dungeon kits** (mines, crypts, goblin tunnels, wizard towers) and
   traps.
5. **Reputation and factions** that feed into delivery generation and
   pricing.
6. **Co-op.** The controller already keeps input separate from state; the
   remaining work is a per-player input device, a split or shared camera, and
   authoritative physics for ragdolls.
7. **AI voice NPCs.** `WorldText.villager_line(personality, role)` is the
   single dialogue hook; swap it for an LLM plus TTS call that gets the same
   context (NPC, settlement personality, active deliveries).
8. **Weather and music** per biome. The data fields already exist in
   `BiomeDef`.
