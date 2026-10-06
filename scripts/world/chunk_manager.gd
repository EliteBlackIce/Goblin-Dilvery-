class_name ChunkManager
extends Node3D
## Streams terrain chunks in and out around a focus point (the player).
## Only ~9x9 chunks exist at once; new ones are built nearest-first under a
## per-frame time budget so walking around never hitches.

@export var load_radius := 4
@export var unload_radius := 5
@export var frame_budget_ms := 5.0

var world: WorldData
var spawn: Callable
var chunks := {}
var _queue: Array[Vector2i] = []
var _focus := Vector2i(-999, -999)
var _color_noise := FastNoiseLite.new()
var paused := false


func setup(w: WorldData, spawn_fn: Callable) -> void:
	world = w
	spawn = spawn_fn
	_color_noise.seed = w.world_seed
	_color_noise.frequency = 0.02


func clear() -> void:
	for c in chunks.values():
		c.queue_free()
	chunks.clear()
	_queue.clear()
	_focus = Vector2i(-999, -999)


func loaded_count() -> int:
	return chunks.size()


func update_focus(pos: Vector3) -> void:
	if world == null:
		return
	var c := Vector2i(int(floor(pos.x / WorldData.CHUNK)), int(floor(pos.z / WorldData.CHUNK)))
	if c == _focus:
		return
	_focus = c
	# Unload far chunks.
	for key in chunks.keys():
		var k: Vector2i = key
		if maxi(absi(k.x - c.x), absi(k.y - c.y)) > unload_radius:
			chunks[k].queue_free()
			chunks.erase(k)
	# Queue missing ones, nearest first.
	_queue.clear()
	for dz in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			if k.x < 0 or k.y < 0 or k.x >= WorldData.CHUNKS or k.y >= WorldData.CHUNKS:
				continue
			if not chunks.has(k):
				_queue.append(k)
	_queue.sort_custom(func(a, b): return (a - c).length_squared() < (b - c).length_squared())


## Synchronously builds everything around a position (used at spawn/teleport).
func build_now(pos: Vector3, radius := 2) -> void:
	update_focus(pos)
	var c := _focus
	var keep: Array[Vector2i] = []
	for k in _queue:
		if maxi(absi(k.x - c.x), absi(k.y - c.y)) <= radius:
			_build(k)
		else:
			keep.append(k)
	_queue = keep


func _process(_delta: float) -> void:
	if paused or _queue.is_empty():
		return
	var start := Time.get_ticks_usec()
	while not _queue.is_empty():
		var k: Vector2i = _queue.pop_front()
		if not chunks.has(k):
			_build(k)
		if (Time.get_ticks_usec() - start) / 1000.0 > frame_budget_ms:
			break


func _build(k: Vector2i) -> void:
	var chunk := TerrainChunk.new()
	add_child(chunk)
	chunk.build(world, k, _color_noise, spawn)
	chunks[k] = chunk
