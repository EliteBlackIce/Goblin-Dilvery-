class_name SpikeTrap
extends Node3D
## Floor plate that rattles (telegraph!) then pops spikes that launch the
## goblin skyward. Timed, readable, and very funny when you forget about it.

var phase := 0.0
var _t := 0.0
var _spikes: Node3D
var _fired := false
const CYCLE := 3.2


func _ready() -> void:
	_t = phase
	var k := MeshKit.new(8)
	k.box(MeshKit.at(Vector3(0, 0.03, 0)), Vector3(2.0, 0.08, 2.0), Color(0.35, 0.33, 0.32))
	for x in [-0.6, 0.0, 0.6]:
		for z in [-0.6, 0.0, 0.6]:
			k.box(MeshKit.at(Vector3(x, 0.075, z)), Vector3(0.16, 0.02, 0.16), Color(0.1, 0.1, 0.1))
	add_child(Mats.instance(k.commit()))
	_spikes = Node3D.new()
	add_child(_spikes)
	var sk := MeshKit.new(9)
	for x in [-0.6, 0.0, 0.6]:
		for z in [-0.6, 0.0, 0.6]:
			sk.cylinder(MeshKit.at(Vector3(x, 0.3, z)), 0.08, 0.0, 0.6, Color(0.75, 0.75, 0.78), 5)
	_spikes.add_child(Mats.instance(sk.commit()))
	_spikes.position.y = -0.62


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, CYCLE)
	var target := -0.62
	if _t > CYCLE - 0.5 and _t < CYCLE - 0.0:
		target = -0.5 + sin(_t * 60.0) * 0.04  # rattle
	if _t < 0.6:
		target = 0.0
		if not _fired:
			_fired = true
			var p := GameState.player
			if p:
				var d := p.global_position - global_position
				if absf(d.x) < 1.2 and absf(d.z) < 1.2 and absf(d.y) < 1.0:
					p.take_hit(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 12.0, 1)
	else:
		_fired = false
	_spikes.position.y = lerpf(_spikes.position.y, target, 1.0 - exp(-30.0 * delta))
