class_name FlickerLight
extends OmniLight3D
## Torch/campfire light that flickers. Fades out with distance for performance.

var _base := 1.0
var _t := 0.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 10.0
	shadow_enabled = false
	distance_fade_enabled = true
	distance_fade_begin = 45.0
	distance_fade_length = 15.0


func _process(delta: float) -> void:
	_t += delta
	light_energy = _base * (0.85 + 0.1 * sin(_t * 11.0) + 0.05 * sin(_t * 23.0 + 1.3))
