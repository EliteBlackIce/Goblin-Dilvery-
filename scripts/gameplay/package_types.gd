class_name PackageTypes
extends RefCounted
## Data for every kind of package. Each one changes how the goblin moves:
##   weight     -> slower, lower jumps, wider turns
##   wobble     -> the stack sways and pushes your balance around
##   fragility  -> integrity lost on hard landings / hits / ragdolls
##   size       -> visual size; "front" carry blocks the view
##   carry      -> "back" stack, "front" (arms full), or "float" (magic)

const TYPES := {
	"small": {
		"name": "Small Parcel", "weight": 1.0, "wobble": 0.0, "fragility": 0.15,
		"size": Vector3(0.38, 0.28, 0.32), "carry": "back", "color": Color(0.78, 0.6, 0.38), "bonus": 0,
		"items": ["a love letter", "a jar of pickled toads", "a very important sock", "overdue library scrolls", "a sack of buttons"],
	},
	"heavy": {
		"name": "Heavy Crate", "weight": 5.0, "wobble": 0.05, "fragility": 0.05,
		"size": Vector3(0.55, 0.45, 0.5), "carry": "back", "color": Color(0.45, 0.42, 0.4), "bonus": 8,
		"items": ["an anvil (small)", "forty pounds of potatoes", "a box of rocks (premium)", "a cast-iron bathtub plug collection"],
	},
	"huge": {
		"name": "Enormous Package", "weight": 4.0, "wobble": 0.25, "fragility": 0.1,
		"size": Vector3(1.05, 1.0, 0.75), "carry": "front", "color": Color(0.7, 0.5, 0.3), "bonus": 12,
		"items": ["a grandfather clock", "a wardrobe", "a suspiciously large wheel of cheese", "a whole door"],
	},
	"fragile": {
		"name": "Fragile Parcel", "weight": 1.5, "wobble": 0.1, "fragility": 1.0,
		"size": Vector3(0.42, 0.42, 0.42), "carry": "back", "color": Color(0.75, 0.88, 0.95), "bonus": 12,
		"items": ["grandma's porcelain", "a stained-glass window", "a crate of potion bottles", "a single precious egg"],
	},
	"unstable": {
		"name": "Unstable Load", "weight": 2.5, "wobble": 1.0, "fragility": 0.35,
		"size": Vector3(0.36, 0.75, 0.36), "carry": "back", "color": Color(0.95, 0.75, 0.82), "bonus": 10,
		"items": ["a seven-tier wedding cake", "a stack of loose plates", "a wobbling jelly sculpture"],
	},
	"magical": {
		"name": "Floating Parcel", "weight": 0.0, "wobble": 0.0, "fragility": 0.2,
		"size": Vector3(0.4, 0.4, 0.4), "carry": "float", "color": Color(0.62, 0.38, 0.95), "bonus": 14,
		"items": ["a humming orb", "a bottled thunderstorm", "a grimoire that bites", "a teleporting hat"],
	},
	"explosive": {
		"name": "Explosive Parcel", "weight": 2.0, "wobble": 0.15, "fragility": 0.7,
		"size": Vector3(0.45, 0.45, 0.45), "carry": "back", "color": Color(0.85, 0.22, 0.15), "bonus": 22,
		"items": ["festival fireworks", "Definitely Not Explosives(tm)", "dragon pepper preserves", "a barrel of blasting powder"],
	},
	"cursed": {
		"name": "Cursed Parcel", "weight": 1.5, "wobble": 0.1, "fragility": 0.3,
		"size": Vector3(0.42, 0.42, 0.42), "carry": "back", "color": Color(0.35, 0.2, 0.45), "bonus": 26,
		"items": ["a haunted music box", "a doll that blinks", "a jar of whispers", "a 'lucky' rabbit foot"],
	},
	"valuable": {
		"name": "Valuable Parcel", "weight": 1.5, "wobble": 0.05, "fragility": 0.6,
		"size": Vector3(0.4, 0.32, 0.4), "carry": "back", "color": Color(0.95, 0.8, 0.25), "bonus": 40,
		"items": ["the Duke's signet ring", "a chest of gold coins", "a jewelled goose egg", "the town's tax money"],
	},
	"living": {
		"name": "Living Package", "weight": 2.0, "wobble": 0.35, "fragility": 0.25,
		"size": Vector3(0.5, 0.42, 0.42), "carry": "back", "color": Color(0.55, 0.68, 0.35), "bonus": 16,
		"items": ["a very angry chicken", "a mystery creature (DO NOT OPEN)", "a baby griffin", "seventeen frogs"],
	},
}


static func get_def(type_id: String) -> Dictionary:
	return TYPES.get(type_id, TYPES["small"])


static func ids() -> Array:
	var k := TYPES.keys()
	k.sort()
	return k


## Builds the visual for a package type (one mesh, vertex coloured).
static func build_mesh(type_id: String) -> ArrayMesh:
	var d := get_def(type_id)
	var size: Vector3 = d["size"]
	var col: Color = d["color"]
	var k := MeshKit.new(type_id.hash())
	match type_id:
		"heavy":
			k.box(Transform3D(), size, col)
			for y in [-0.3, 0.3]:
				k.box(MeshKit.at(Vector3(0, size.y * y, 0)), Vector3(size.x + 0.03, 0.06, size.z + 0.03), Color(0.25, 0.24, 0.25))
		"huge":
			k.box(Transform3D(), size, col)
			k.box(MeshKit.at(Vector3(0, 0, -size.z * 0.5 - 0.005)), Vector3(size.x * 0.15, size.y, 0.01), Color(0.85, 0.75, 0.55))
			k.box(MeshKit.at(Vector3(0, size.y * 0.25, -size.z * 0.5 - 0.01)), Vector3(size.x * 0.5, size.y * 0.2, 0.01), Color(0.95, 0.95, 0.9))
		"fragile":
			k.box(Transform3D(), size, col)
			k.box(MeshKit.at(Vector3(0, 0, 0)), Vector3(size.x + 0.02, 0.08, size.z + 0.02), Color(0.9, 0.15, 0.15))
			k.cylinder(MeshKit.at(Vector3(0, size.y * 0.5 + 0.08, 0)), 0.07, 0.1, 0.16, Color(0.85, 0.95, 1.0), 6)
		"unstable":
			var y := -size.y * 0.5
			var tiers := 4
			for i in tiers:
				var w := size.x * (1.0 - i * 0.18)
				var h := size.y / tiers
				k.cylinder(MeshKit.rot(Vector3(0.02 * (i % 2), y + h * 0.5, 0), Vector3(0, 0, 0.05 * (i % 2 - 0.5))), w * 0.6, w * 0.55, h, col if i % 2 == 0 else Color(1, 0.95, 0.9), 8)
				y += h
			k.sphere(MeshKit.at(Vector3(0, y + 0.04, 0)), 0.05, Color(0.9, 0.1, 0.2), 6, 4)
		"cursed":
			k.box(Transform3D(), size, col)
			k.box(MeshKit.rot(Vector3(0, 0, -size.z * 0.5 - 0.01), Vector3(0, 0, 0.785)), Vector3(0.3, 0.06, 0.01), Color(0.6, 1.0, 0.5))
			k.box(MeshKit.rot(Vector3(0, 0, -size.z * 0.5 - 0.01), Vector3(0, 0, -0.785)), Vector3(0.3, 0.06, 0.01), Color(0.6, 1.0, 0.5))
		"valuable":
			k.box(Transform3D(), size, col)
			k.box(MeshKit.at(Vector3(0, size.y * 0.5, 0)), Vector3(size.x + 0.02, 0.04, 0.08), Color(0.7, 0.15, 0.2))
			k.sphere(MeshKit.at(Vector3(0, size.y * 0.5 + 0.05, 0)), 0.06, Color(0.7, 0.15, 0.2), 6, 4)
		"magical":
			k.box(MeshKit.rot(Vector3.ZERO, Vector3(0.6, 0.6, 0.0)), size, col)
			k.sphere(MeshKit.at(Vector3.ZERO), size.x * 0.45, Color(0.9, 0.8, 1.0), 6, 4)
		"explosive":
			k.cylinder(Transform3D(), size.x * 0.5, size.x * 0.5, size.y, col, 10)
			for y in [-0.3, 0.3]:
				k.cylinder(MeshKit.at(Vector3(0, size.y * y, 0)), size.x * 0.52, size.x * 0.52, 0.05, Color(0.12, 0.1, 0.1), 10)
			k.cylinder_between(Vector3(0, size.y * 0.5, 0), Vector3(0.05, size.y * 0.5 + 0.18, 0.03), 0.015, Color(0.3, 0.25, 0.2), 4)
		"living":
			k.box(Transform3D(), size, col)
			for x in [-0.12, 0.0, 0.12]:
				k.box(MeshKit.at(Vector3(x, 0.05, -size.z * 0.5 - 0.005)), Vector3(0.05, 0.05, 0.01), Color(0.1, 0.1, 0.08))
			k.box(MeshKit.at(Vector3(0, size.y * 0.5 + 0.005, 0)), Vector3(size.x * 0.9, 0.02, 0.06), Color(0.4, 0.3, 0.2))
		_:
			k.box(Transform3D(), size, col)
			k.box(Transform3D(), Vector3(size.x + 0.01, size.y + 0.01, 0.05), Color(0.85, 0.78, 0.55))
	return Assets.pick("packages/" + type_id, k.commit())
