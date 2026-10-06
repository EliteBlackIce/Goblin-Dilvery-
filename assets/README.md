# Art assets: how to replace everything

All of the game's art is generated in code, so you won't find hand-made model files anywhere except here. `assets/source/` holds an exported copy of **every** model as a `.glb` file. You can open these in Blender or any 3D tool.

## Replacing a model
1. Copy a file from `assets/source/<id>.glb` to `assets/models/<id>.glb`, keeping the same sub-folder and name.
2. Edit it, or replace it with your own model. `.glb`, `.gltf`, `.tscn`, `.tres`, `.res` and `.obj` all work.
3. Run the game. Your version is used automatically, and if you delete it the game goes back to the built-in model.

- **Materials and textures:** your model keeps its own. Built-in models use one shared vertex-colour material (`scripts/core/mats.gd`).
- **Multiple meshes in one file:** only the **first mesh** in the file is used, so merge your model into one mesh. Multiple materials on that mesh are fine.
- **Buildings and pieces:** collisions stay as they are in code. Keep about the same size and footprint so the goblin doesn't walk through walls.
- **Regenerating the source files:** run `tools/export_assets.tscn` in the editor (or `godot --path . res://tools/export_assets.tscn`).

## Conventions (so models line up)
- **Scale and orientation:** 1 unit = 1 metre, Y is up, and the front faces **−Z**.
- **Ground pieces** (buildings, props, trees, furniture): origin on the ground at the centre of the footprint.
- **Goblin parts:** each part is animated separately around its own origin.
  - `head`: origin at the neck. The head itself sits about 0.3 m above the origin.
  - `torso`: origin at the hips.
  - `arm_l`, `arm_r`: origin at the shoulder; the arm hangs down −Y.
  - `foot_l`, `foot_r`: origin at the ankle, on the ground.
  - `leg`: must be a **1 m tall cylinder centred on its origin**. It is stretched between hip and ankle every frame.
  - `eye`, `pupil`, `brow`, `mouth`: animated for facial expressions (blink, stretch, tilt).
  - `ear_l`, `ear_r`: origin where the ear joins the head.
  - `hat_*`: origin on top of the head.
- **Villagers** use the same body, head and arm for everyone; colours are random per villager on the built-in meshes only.
- **Enemies:** one mesh per enemy, origin at the feet. The club swings around its handle.

## Colours (no model needed)
- **Terrain, sky, water, fog, road and grass colours, plus biome content tables:** copy `assets/source/biomes/green_fields.tres` to `assets/biomes/green_fields.tres` and edit it in the Inspector.
- **Building colour palettes:** `PALETTES` in `scripts/world/piece_library.gd`.
- **Goblin colours:** the constants at the top of `scripts/player/goblin_rig.gd`.
- **Lighting:** `scripts/core/atmosphere.gd`.
- **App icon:** `icon.svg`.

## Still generated in code (not swappable as files)
- **Terrain:** a heightmap with vertex colours; change its colours via the biome file.
- **Dungeon walls and floors:** built per seed; colours come from `dungeon_theme` in the biome file. The cracked wall, enemies and props are swappable.
- **Post office:** `post_office/shell` and `post_office/roof` can be replaced, but the walls you collide with stay as laid out in `scripts/world/post_office.gd`.
- **Effects:** `fx/puff` and `fx/explosion_ball` are swappable meshes; their colours are set in `scripts/gameplay/fx.gd` and `scripts/gameplay/explosion.gd`.
- **UI:** uses Godot's default theme. Add a Theme in Project Settings → GUI → Theme to restyle it.

## Every model id
- **dungeon/**: cracked_wall
- **enemies/**: bandit, boar, brute, club, rat
- **furniture/**: furn_bed, furn_bed_fancy, furn_cauldron, furn_chair, furn_lamp, furn_painting, furn_plant, furn_rug, furn_shelf, furn_table, furn_throne
- **fx/**: explosion_ball, puff
- **goblin/**: arm_l, arm_r, brow, ear_l, ear_r, eye, foot_l, foot_r, hat_cap, hat_crown, hat_pot, hat_wizard, head, leg, mouth, pupil, torso
- **packages/**: cursed, explosive, fragile, heavy, huge, living, magical, small, unstable, valuable
- **pieces/**: barn, blacksmith, bridge_segment, campfire, cart, cart_broken, crop_field, dead_tree, dungeon_entrance, farmhouse, giant_tree, goblin_hut, guard_tower, house_medium, house_small, house_tall, lamp_post, log_seat, market_stall, notice_board, palisade_ring, ruined_house, ruined_tower, shop, signpost, stable, standing_stones, statue, tavern, temple, tent, town_hall, well, windmill, windmill_blades
- **post_office/**: roof, shell
- **props/**: barrel, chest_base, chest_lid, coins, crate, explosive_barrel, haybale, spike_plate, spikes
- **trophies/**: col_badge, col_coin, col_mushroom, col_sock, col_stamp, col_tooth
- **vegetation/**: birch, bush, flower_r, flower_w, flower_y, grass, mushroom, oak, oak2, pine, rock, rock2
- **villagers/**: arm, body, head_goblin, head_human
