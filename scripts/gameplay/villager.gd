class_name Villager
extends Node3D
## A chunky NPC: potential sender/recipient of parcels. Bobs, looks at the
## goblin, waves, says personality-flavoured lines in a speech bubble, and
## lights up a marker when you're carrying something for them.
##
## Dialogue goes through WorldText.villager_line(), which is the single hook
## where AI-generated / AI-voiced lines would plug in later.

const SKIN_TONES := [Color(0.96, 0.8, 0.66), Color(0.85, 0.65, 0.5), Color(0.62, 0.45, 0.32), Color(0.45, 0.32, 0.24)]

var npc: Dictionary = {}
var interact_radius := 2.8
var world: Node = null

var _body: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _marker: Label3D
var _bubble: Label3D
var _bubble_t := 0.0
var _t := 0.0
var _wave_t := 0.0
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _wander_t := 0.0
var _greeted := false
var _hop := Spring.new(200.0, 8.0)
var _rng := RandomNumberGenerator.new()


func setup(data: Dictionary) -> void:
	npc = data
	_rng.seed = str(data.get("id", "")).hash()


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("villager")
	_home = global_position
	_target = _home
	_t = _rng.randf() * 10.0
	_build()
	if GameState.player:
		GameState.player.carrier.changed.connect(_refresh_marker)
	_refresh_marker()


func _build() -> void:
	var colors: Array = npc.get("colors", [Color.SKY_BLUE, Color.SADDLE_BROWN, Color.RED])
	var goblin: bool = npc.get("species", "human") == "goblin"
	var skin: Color = GoblinRig.SKIN.darkened(_rng.randf() * 0.2) if goblin else SKIN_TONES[_rng.randi() % SKIN_TONES.size()]
	var shirt: Color = colors[0]
	var pants: Color = colors[1]
	var hat: Color = colors[2]
	var scale_y := _rng.randf_range(0.9, 1.15)

	var body_root := Node3D.new()
	add_child(body_root)
	_body = body_root
	var k := MeshKit.new(_rng.randi())
	k.sphere(MeshKit.at(Vector3(0, 0.75 * scale_y, 0), 0, Vector3(1.0, 1.25 * scale_y, 0.85)), 0.36, shirt, 8, 5)
	k.cylinder(MeshKit.at(Vector3(0, 0.25, 0)), 0.3, 0.32, 0.5, pants, 8)
	for sx in [-0.14, 0.14]:
		k.sphere(MeshKit.at(Vector3(sx, 0.07, -0.06), 0, Vector3(1, 0.6, 1.5)), 0.12, pants.darkened(0.4), 6, 4)
	k.cylinder(MeshKit.at(Vector3(0, 0.62, 0)), 0.36, 0.36, 0.06, pants.darkened(0.2), 8)
	body_root.add_child(Mats.instance(Assets.pick("villagers/body", k.commit())))

	_head = Node3D.new()
	_head.position = Vector3(0, 1.25 * scale_y + 0.2, 0)
	body_root.add_child(_head)
	k = MeshKit.new(_rng.randi())
	var head_r := 0.33 if goblin else 0.28
	k.sphere(MeshKit.at(Vector3.ZERO, 0, Vector3(1.1 if goblin else 1.0, 0.95, 1.0)), head_r, skin, 8, 6)
	if goblin:
		k.cone_between(Vector3(0, -0.02, -0.28), Vector3(0, -0.07, -0.5), 0.07, 0.0, skin.darkened(0.15), 6)
		for side in [-1.0, 1.0]:
			k.cone_between(Vector3(side * 0.32, 0.04, 0), Vector3(side * 0.7, 0.14, 0.05), 0.11, 0.0, skin, 6, 0.45)
	else:
		k.sphere(MeshKit.at(Vector3(0, -0.03, -0.27)), 0.07, skin.darkened(0.1), 6, 4)
		k.sphere(MeshKit.at(Vector3(0, 0.12, 0.05), 0, Vector3(1.05, 0.6, 1.05)), 0.29, Color.from_hsv(_rng.randf_range(0.05, 0.12), 0.5, _rng.randf_range(0.2, 0.7)), 8, 4)
	for side in [-1.0, 1.0]:
		k.sphere(MeshKit.at(Vector3(side * 0.1, 0.06, -head_r + 0.03), 0, Vector3(1, 1.2, 0.6)), 0.065, Color(1, 0.98, 0.9), 6, 4)
		k.sphere(MeshKit.at(Vector3(side * 0.1, 0.06, -head_r - 0.01)), 0.032, Color(0.05, 0.05, 0.05), 5, 3)
	k.box(MeshKit.at(Vector3(0, -0.13, -head_r + 0.04)), Vector3(0.12, 0.03, 0.03), Color(0.35, 0.1, 0.1))
	match int(npc.get("hat_style", 0)):
		1:
			k.cylinder(MeshKit.at(Vector3(0, head_r * 0.8, 0)), head_r * 0.85, head_r * 0.8, 0.14, hat, 8)
			k.box(MeshKit.at(Vector3(0, head_r * 0.75, -head_r * 0.8)), Vector3(head_r * 1.2, 0.03, 0.18), hat.darkened(0.2))
		2:
			k.cylinder(MeshKit.at(Vector3(0, head_r * 0.75, 0)), head_r * 1.7, head_r * 1.7, 0.04, Color(0.9, 0.8, 0.45), 10)
			k.cylinder(MeshKit.at(Vector3(0, head_r * 0.95, 0)), head_r * 0.8, head_r * 0.7, 0.25, Color(0.9, 0.8, 0.45), 8)
		3:
			k.cylinder(MeshKit.rot(Vector3(0, head_r + 0.15, 0.05), Vector3(-0.3, 0, 0)), head_r * 0.9, 0.0, 0.55, hat, 7)
	if npc.get("role", "") == "postmaster":
		k.cylinder(MeshKit.at(Vector3(0, head_r * 0.85, 0)), head_r * 0.9, head_r * 0.85, 0.15, GoblinRig.CAP, 8)
		k.box(MeshKit.at(Vector3(0, head_r * 0.78, -head_r * 0.85)), Vector3(head_r * 1.3, 0.03, 0.2), GoblinRig.CAP_DARK)
	_head.add_child(Mats.instance(Assets.pick("villagers/head_" + ("goblin" if goblin else "human"), k.commit())))

	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.36, 1.0 * scale_y, 0)
		body_root.add_child(arm)
		var ak := MeshKit.new(3)
		ak.cylinder(MeshKit.at(Vector3(0, -0.22, 0)), 0.07, 0.07, 0.44, shirt.darkened(0.1), 6)
		ak.sphere(MeshKit.at(Vector3(0, -0.48, 0)), 0.09, skin, 6, 4)
		arm.add_child(Mats.instance(Assets.pick("villagers/arm", ak.commit())))
		if side < 0:
			_arm_l = arm
		else:
			_arm_r = arm

	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 4  # blocks the goblin, but not the camera
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	body.add_child(cs)
	add_child(body)

	_marker = Label3D.new()
	_marker.text = "!"
	_marker.font_size = 140
	_marker.outline_size = 28
	_marker.modulate = Color(1, 0.85, 0.2)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.fixed_size = true
	_marker.pixel_size = 0.0009
	_marker.position = Vector3(0, 2.6, 0)
	_marker.visible = false
	add_child(_marker)

	_bubble = Label3D.new()
	_bubble.font_size = 40
	_bubble.outline_size = 12
	_bubble.pixel_size = 0.005
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.width = 600
	_bubble.position = Vector3(0, 2.3, 0)
	_bubble.visible = false
	add_child(_bubble)


func _refresh_marker() -> void:
	if _marker == null or GameState.player == null:
		return
	var p := GameState.player.carrier.find_for_recipient(npc.get("id", ""))
	_marker.visible = not p.is_empty()


func _process(delta: float) -> void:
	_t += delta
	var player := GameState.player
	var near := false
	if player:
		var to := player.global_position - global_position
		to.y = 0.0
		near = to.length() < 7.0
		if near:
			var want := atan2(-to.x, -to.z)
			rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-4.0 * delta))
			if not _greeted:
				_greeted = true
				_wave_t = 1.2
				_hop.kick(3.0)
		elif to.length() > 15.0:
			_greeted = false

	# Gentle wandering around home when the player isn't chatting.
	var role: String = npc.get("role", "")
	if not near and role in ["villager", "resident", "farmer"]:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = _rng.randf_range(3.0, 7.0)
			_target = _home + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
		var d := _target - global_position
		d.y = 0
		if d.length() > 0.2:
			var step := d.normalized() * minf(1.2 * delta, d.length())
			global_position += step
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-5.0 * delta))
			if world and world.has_method("ground_height"):
				global_position.y = world.ground_height(global_position)

	var bob := sin(_t * 2.0) * 0.02 + _hop.step(0.0, delta) * 0.1
	_body.position.y = maxf(bob, -0.05)
	_body.rotation.z = sin(_t * 1.3) * 0.04
	_head.rotation = Vector3(sin(_t * 0.9) * 0.05, sin(_t * 0.6) * 0.2, sin(_t * 1.7) * 0.06)
	if _wave_t > 0.0:
		_wave_t -= delta
		_arm_r.rotation = Vector3(0, 0, 2.6 + sin(_t * 14.0) * 0.4)
	else:
		_arm_r.rotation = Vector3(sin(_t * 1.1) * 0.08, 0, 0.12)
	_arm_l.rotation = Vector3(sin(_t * 1.1 + 1.0) * 0.08, 0, -0.12)
	if _marker.visible:
		_marker.position.y = 2.6 + sin(_t * 4.0) * 0.12
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.visible = false


func say(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = 4.0


# --- Interactable protocol --------------------------------------------------

func can_interact(_g: Goblin) -> bool:
	return true


func get_interact_prompt(_g: Goblin) -> String:
	var name_: String = npc.get("name", "someone")
	if not GameState.player.carrier.find_for_recipient(npc.get("id", "")).is_empty():
		return "Deliver parcel to %s" % name_
	match npc.get("role", ""):
		"postmaster":
			return "Open the delivery board"
		"merchant":
			return "Buy a potion from %s (15 gold)" % name_
		"quartermaster":
			return "Shop with %s" % name_
		"stranded":
			return "Help %s" % name_
	return "Talk to %s" % name_


func interact(g: Goblin) -> void:
	var id: String = npc.get("id", "")
	if GameState.try_deliver(id):
		_hop.kick(6.0)
		_wave_t = 1.5
		say(WorldText.pick(["Finally! Thank you!", "Is it... dented? Never mind. Thanks!", "My parcel! You absolute legend.", "Oh! I'd forgotten I ordered this."]))
		FX.sparkle(global_position + Vector3.UP * 2.0)
		_refresh_marker()
		return
	match npc.get("role", ""):
		"postmaster":
			GameState.board_requested.emit(npc.get("site", "village"))
			say("Pick a parcel, any parcel.")
			return
		"merchant":
			if GameState.gold >= 15:
				GameState.add_gold(-15)
				g.heal(3)
				say("A fine potion! Tastes like feet, works like magic.")
				FX.sparkle(g.global_position + Vector3.UP, Color(1, 0.4, 0.5))
			else:
				say("No gold, no potion. I'm a merchant, not a charity.")
			return
		"quartermaster":
			GameState.home_requested.emit("shop")
			say("Gear! Furniture! Planks! Everything a goblin could want.")
			return
		"stranded":
			if world and world.has_method("stranded_help"):
				world.stranded_help(self)
			return
		"rival":
			say(WorldText.pick(["Hah! Slowpoke. I've delivered three parcels while you tripped over that one.",
				"The Guild will never promote YOU.", "Nice cap. Mine's bigger."]))
			return
	say(WorldText.villager_line(npc.get("personality", "cozy"), npc.get("role", "")))
