extends Node
## Headless gameplay smoke test (runs the real game loop, no rendering):
##   godot --headless --path . res://tests/smoke_test.tscn
## Exits 0 on success, 1 on failure.

var failures := 0
var main: Node


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		failures += 1


func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	GameState.pending_seed = 48291736
	GameState.toast_requested.connect(func(t, _c): print("  toast: ", t))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run()


func _run() -> void:
	await _wait(120)
	var g: Goblin = GameState.player
	var world: World = main.get_node("World")
	check(g != null, "goblin spawned")
	check(world.chunks.loaded_count() >= 9, "chunks streamed in around the player (%d)" % world.chunks.loaded_count())
	check(g.grounded, "goblin is standing on the generated terrain")
	check(g.global_position.distance_to(GameState.world.start_pos) < 4.0, "spawned at the post office")

	# Chunk build cost (the streaming budget depends on this).
	var t := Time.get_ticks_usec()
	var c := TerrainChunk.new()
	world.chunks.add_child(c)
	c.build(GameState.world, Vector2i(3, 3), FastNoiseLite.new(), func(_p, _n): pass)
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	c.queue_free()
	print("  info chunk build: %.1f ms" % ms)
	check(ms < 60.0, "chunk builds fast enough to stream")

	# Sprint down the middle of the first main road.
	var road: Dictionary = GameState.world.roads[0]
	var pts: PackedVector3Array = road["points"]
	var mid := pts.size() / 2
	var along: Vector3 = (pts[mid + 4] - pts[mid]).normalized()
	g.teleport(pts[mid] + Vector3.UP * 0.5)
	world.chunks.build_now(g.global_position, 2)
	var cam: GoblinCamera = get_tree().get_first_node_in_group("game_camera")
	cam.auto_follow = false
	cam.yaw = atan2(-along.x, -along.z)
	await _wait(20)
	var start := g.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(90)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var moved := Vector2(g.global_position.x - start.x, g.global_position.z - start.z).length()
	check(moved > 6.0, "sprinting moves the goblin (%.1f m)" % moved)
	await _wait(60)

	# Explosion -> ragdoll -> recovery.
	Explosion.explode(get_tree(), g.global_position + Vector3(0.5, 0.2, 0.5), 5.0, 15.0, 0)
	await _wait(2)
	check(g.state == Goblin.State.RAGDOLL, "explosion ragdolls the goblin")
	var recovered := false
	for i in 600:
		await get_tree().physics_frame
		if g.state != Goblin.State.RAGDOLL:
			recovered = true
			break
	check(recovered, "goblin recovers from ragdoll")
	check(g.rig.visible, "animated rig is visible again after recovery")

	# Hit -> stumble (not ragdoll).
	await _wait(60)
	print("  info pos=%s" % g.global_position)
	print("  info before hit: state=%s hp=%d grounded=%s" % [Goblin.State.keys()[g.state], g.health, g.grounded])
	g.take_hit(Vector3.RIGHT, 6.0, 0)
	print("  info after hit: state=%s" % Goblin.State.keys()[g.state])
	check(g.state == Goblin.State.STUMBLE, "small hits cause a stumble, not a ragdoll")
	await _wait(90)

	# Accept and deliver a job.
	var jobs := GameState.jobs_at("village")
	check(jobs.size() > 0, "the village board has jobs")
	var job: Dictionary = jobs[0]
	check(GameState.accept_job(job["id"]), "accepting a job")
	check(g.carrier.packages.size() == 1, "the parcel is carried")
	var mods := g.carrier.get_modifiers()
	print("  info carrying %s: speed x%.2f, instability %.2f" % [job["package"], mods["speed"], mods["instability"]])
	var gold_before := GameState.gold
	check(GameState.try_deliver(job["recipient_id"]), "delivering to the recipient")
	check(GameState.gold > gold_before, "delivery pays gold")
	check(g.carrier.packages.is_empty(), "parcel handed over")

	# Dungeon round trip.
	world.enter_dungeon("dungeon_0")
	await _wait(30)
	check(world.in_dungeon and g.global_position.y < -200.0, "entered the dungeon")
	check(get_tree().get_nodes_in_group("enemy").size() > 0, "dungeon has enemies")
	await _wait(60)
	check(g.global_position.y > DungeonGenerator.DUNGEON_Y - 5.0, "goblin stands on the dungeon floor")
	world.exit_dungeon()
	await _wait(30)
	check(not world.in_dungeon and g.global_position.y > 0.0, "exited back to the overworld")

	print("\n%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	get_tree().quit(1 if failures > 0 else 0)
