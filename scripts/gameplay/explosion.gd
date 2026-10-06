class_name Explosion
extends Node3D
## Big cartoony explosion: an expanding fireball, a light flash, smoke, and a
## radial impulse applied to everything in the "explodable" group (the goblin
## ragdolls, enemies get launched, crates and barrels fly).

var radius := 5.0
var _t := 0.0
var _ball: MeshInstance3D
var _light: OmniLight3D


static func explode(tree: SceneTree, pos: Vector3, radius_: float, force: float, damage: int) -> void:
	var e := Explosion.new()
	e.radius = radius_
	tree.current_scene.add_child(e)
	e.global_position = pos
	for n in tree.get_nodes_in_group("explodable"):
		if n.has_method("apply_explosion"):
			n.apply_explosion(pos, radius_, force, damage)
	for i in 6:
		FX.puff(pos + Vector3(randf_range(-1, 1), randf_range(0, 1.5), randf_range(-1, 1)), Color(0.35, 0.33, 0.32), randf_range(1.0, 1.8), 2.5, 1.2)


func _ready() -> void:
	var k := MeshKit.new(3, 0.0)
	k.sphere(Transform3D(), 1.0, Color.WHITE, 10, 7)
	_ball = MeshInstance3D.new()
	_ball.mesh = Assets.pick("fx/explosion_ball", k.commit())
	_ball.material_override = Mats.color(Color(1.0, 0.65, 0.2), 3.0)
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ball.scale = Vector3.ONE * 0.2
	add_child(_ball)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.7, 0.3)
	_light.light_energy = 6.0
	_light.omni_range = radius * 3.0
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var s := radius * 0.7 * ease(minf(_t / 0.25, 1.0), 0.3)
	_ball.scale = Vector3.ONE * maxf(s * (1.0 - maxf(0.0, _t - 0.25) * 3.0), 0.01)
	_light.light_energy = maxf(0.0, 6.0 * (1.0 - _t / 0.5))
	if _t > 0.6:
		queue_free()
