class_name WorldRng
extends RefCounted
## Deterministic random streams derived from the world seed.
##
## Every generation stage asks for its own named stream ("roads", "village:3",
## "chunk:4:7"...). That way adding a new stage, or consuming more numbers in
## one stage, never changes the results of the others — the same seed keeps
## producing the same world as the generator grows.


static func stream(world_seed: int, name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_of(world_seed, name)
	return rng


static func hash_of(world_seed: int, name: String) -> int:
	# String.hash() is a stable djb2 hash, identical on every platform.
	return ("%d::%s" % [world_seed, name]).hash() * 2654435761 + world_seed


static func pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]


## Weighted pick from {key: weight}. Keys are sorted so the result never
## depends on Dictionary insertion order.
static func pick_weighted(rng: RandomNumberGenerator, weights: Dictionary) -> Variant:
	var keys := weights.keys()
	keys.sort()
	var total := 0.0
	for k in keys:
		total += float(weights[k])
	var roll := rng.randf() * total
	for k in keys:
		roll -= float(weights[k])
		if roll <= 0.0:
			return k
	return keys[keys.size() - 1]


static func shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
