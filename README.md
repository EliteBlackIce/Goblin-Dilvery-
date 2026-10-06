# Goblin Delivery Co.

A goofy, physics-driven medieval postal RPG in **Godot 4.3+**. You are a goblin
courier who is barely holding itself together, delivering parcels across a
procedurally generated fantasy region that is different every time:

> "Okay... where the heck is my post office this time?"

This repo is the first vertical slice, built in the order the design asked for:
**one biome, one generated region, modular terrain, one village (plus hamlets),
roads, one dungeon, and basic procedural enemies, loot and deliveries**, all on
top of a hybrid "floppy" character controller.

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (standard build, no C#).
2. Open `project.godot`, press **F5**.
3. Type a seed (or leave it blank for a random one) and press **Start Delivering**.
   The same seed always produces the same world, so you can share seeds.
   Words work as seeds too.

Command-line shortcut that skips the title screen: `godot --path . -- --seed 48291736`

**Movement Playground** (on the title screen, or `scenes/movement_playground.tscn`)
is a small handmade test level for tuning the goblin's feel. It has ramps, a
steep slope, a tower to jump off, crates, explosive barrels, spike traps, a boar
and a bandit. Keys **1–8** give you each package type so you can feel how it
changes your movement. **X** sets off an explosion, **T** trips you, **R** resets.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Camera | Mouse | Right stick |
| Sprint | Shift | L3 / LB |
| Jump (mash it while ragdolled to get up faster) | Space | A |
| Sneak (enemies notice you less) | just walk, don't sprint | – |
| Satchel bonk | F / left click | RB / B |
| Interact / deliver | E | X |
| Map | M | Back |
| Recentre camera | C | R3 |
| Pause menu (seed entry, clumsiness slider) | Esc | Start |
| New random world | F5 | – |

## What's in the slice

**The goblin.** A `CharacterBody3D` handles normal movement, and temporary
ragdolls handle the big reactions. Movement has momentum: the faster you go,
the slower you can turn, and reversing at speed makes you skid. The goblin
keeps a hidden balance value that turns into stumbles, windmilling arms and
the occasional trip. The body is animated procedurally with springs: squash
and stretch, wobbling while standing still, leaning into turns and into
sprints, bobbing and waddling, floppy ears and cap, arms that swing, flap and
flail, legs that run on air while falling, and an expressive face. Explosions,
boar charges, huge falls and tumbling down cliffs switch to a jointed ragdoll
that you can steer and wiggle out of. See [docs/DESIGN.md](docs/DESIGN.md#1-movement--goofy-floppy-physics-based).

**Packages change how you move.** Heavy parcels slow you down. A huge parcel
fills your arms and blocks the view. Fragile parcels lose integrity when you
take a hard landing, get hit or ragdoll. Unstable loads sway and push your
balance around. Magical parcels float behind you. Explosive parcels blow up if
they get damaged too much. Living parcels jolt around and shove you.

**Camera.** A third-person orbit camera with world collision. It reacts
subtly: it pulls back and widens the FOV when you sprint, shakes on big
landings, kicks when you're hit, and follows the ragdoll more loosely. Shake
is capped.

**The procedural world.** The pipeline is seed → biome → terrain → sites →
roads → settlements → dungeon → camps → NPCs → deliveries → loot → events,
and it assembles handcrafted building pieces rather than scattering random
objects. Safe main roads wind around forests and bandit camps; dangerous
shortcuts cut straight through them. Settlements have personalities (cozy,
wealthy, goblin-run, farm, abandoned, bandit-controlled). The dungeon is a
graph of rooms, and the package recipient is unfortunately inside it.
Deliveries chain into routes. Terrain streams in as 32 m chunks around the
player, with MultiMesh-instanced vegetation.

## Home base and progression

- **Post office.** Walk in through the front door; the roof hides while you're inside so the camera can see you.
  - **Delivery counter and mission board:** contracts. Normal contracts are open to everyone, dangerous ones need reputation 2, and special ones need reputation 3 plus the Brass Counter upgrade.
  - **Quartermaster's shop:** gear, furniture and building materials.
  - **Upgrade desk:** building upgrades.
  - **Storage chest:** unloads your backpack.
  - **Personal room:** furniture spots, a decorating catalogue, a trophy shelf for collectibles, and a bed that heals you and saves.
- **Building upgrades physically add to the building:**
  - Storage Annex (more storage space)
  - Gadget Workshop (unlocks gadgets in the shop)
  - Bedroom Extension (4 more furniture spots)
  - Brass Counter (+15% delivery pay, unlocks special contracts)
- **Contracts** have tiers and optional bonus goals (deliver in time, keep it pristine, don't get hit). They pay gold, reputation and items, and many offer a guaranteed item reward.
- **Packages:**
  - Cursed and valuable parcels make enemies notice you from further away.
  - Floating parcels make you lighter and floatier.
  - Living parcels can escape.
  - Bandits and ragdolls can knock parcels off you; press E to grab them back.
- **Gear slots:** pack, boots, gloves, gadget and hat. Each piece changes gameplay, for example more parcel slots, higher jumps, gentler handling of fragile parcels, sneaking, or chest markers on the map.
- **Saving.** Progress saves automatically to `user://goblin_save.json`: gold, reputation, items, gear, furniture, upgrades, and per-world progress. It saves after deliveries and purchases, when you enter the post office, when you rest in bed, and when you quit. The title screen has **Continue**, and starting a new world keeps your goblin's progress.

## Tests

```bash
# All scripts compile (run as a scene so the GameState autoload exists)
godot --headless --path . res://tests/check_scripts.tscn
# Generator: determinism, connectivity, content counts; optional top-down map
godot --headless --path . -s res://tests/run_tests.gd -- --map /tmp/map.png --seed 123
# Gameplay smoke test: spawn, sprint, explosion -> ragdoll -> recovery,
# stumble, accept + deliver, dungeon round trip
godot --headless --path . res://tests/smoke_test.tscn
# Builds every chunk, placement, dungeon and piece type for several seeds
godot --headless --path . res://tests/all_chunks_test.tscn
# Screenshots / animation contact sheets (need a renderer, e.g. xvfb-run)
godot --rendering-driver opengl3 --path . res://tests/visual_check.tscn -- --out /tmp/shots
godot --rendering-driver opengl3 --path . res://tests/anim_check.tscn -- --out /tmp/anim
```

`tests/run_all.sh` runs the headless suite.

## Project layout

```
scenes/            main.tscn (entry), movement_playground.tscn
scripts/
  autoload/        game_state.gd: gold, jobs, trinkets, looted/defeated state
  core/            springs, MeshKit (chunky mesh builder), materials, seeded RNG, input map, lighting
  player/          goblin.gd (controller), goblin_rig.gd (procedural animation),
                   goblin_ragdoll.gd, package_carrier.gd
  camera/          goblin_camera.gd
  world/           world_generator.gd (the pipeline) + road/settlement/dungeon/
                   delivery/event generators, world_data.gd, piece_library.gd,
                   chunk_manager.gd, terrain_chunk.gd, dungeon_builder.gd, world.gd
  gameplay/        enemies, villagers, chests, physics props, explosions, FX, loot tables
  ui/              HUD, map, heart bar
tests/             headless + visual tests
docs/DESIGN.md     how each system works, and the roadmap
```

## Replacing art

All art is currently built in code from chunky primitives using `MeshKit`.
To replace any piece with a handmade scene, save it as
`res://pieces/<piece_id>.tscn` (for example `res://pieces/tavern.tscn`). The
generator picks it up automatically. See `PieceLibrary` for the piece ids.
