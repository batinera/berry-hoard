extends MultiMeshInstance3D

## Decoração densa: parece um "mar", não é 1 por 1 coletável.
@export var instance_count: int = 14000
@export var core_half: Vector3 = Vector3(11.0, 0.0, 14.0)
@export var falloff_half: Vector3 = Vector3(21.0, 0.0, 26.0)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.94, 0.16, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.05, 0.08)
	mat.emission_energy_multiplier = 0.22
	mat.roughness = 0.4
	material_override = mat
	_rng.randomize()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = instance_count
	mm.mesh = _make_berry_mesh()
	multimesh = mm
	for i in instance_count:
		var pos := _sample_pile_position()
		var scale := _rng.randf_range(0.82, 1.12)
		var t := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), pos)
		t = t.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		mm.set_instance_transform(i, t)


func _sample_pile_position() -> Vector3:
	# 75% das instâncias no núcleo denso; resto numa coroa mais larga.
	var use_core := _rng.randf() < 0.78
	var half := core_half if use_core else falloff_half
	var x := _rng.randf_range(-half.x, half.x)
	var z := _rng.randf_range(-half.z, half.z)
	if use_core:
		# Empilha mais no centro (distribuição em cunha).
		var t := pow(_rng.randf(), 1.6)
		x *= t
		z *= t
	var h: float = _rng.randf_range(0.0, 0.08) if use_core else _rng.randf_range(0.0, 0.04)
	return BerryField.berry_center_on_surface(x, z, h)


func _make_berry_mesh() -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.34
	sphere.radial_segments = 8
	sphere.rings = 6
	return sphere