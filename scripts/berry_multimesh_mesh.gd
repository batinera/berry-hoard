class_name BerryMultimeshMesh
extends RefCounted


static func build(radius: float = 0.24) -> ArrayMesh:
	var body := SphereMesh.new()
	body.radius = radius
	body.height = radius * 1.85
	body.radial_segments = 10
	body.rings = 8
	var stem := CylinderMesh.new()
	stem.top_radius = radius * 0.12
	stem.bottom_radius = radius * 0.18
	stem.height = radius * 0.28
	var body_mesh := ArrayMesh.new()
	body_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.get_mesh_arrays())
	var stem_mesh := ArrayMesh.new()
	stem_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stem.get_mesh_arrays())
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.create_from(body_mesh, 0)
	var stem_xf := Transform3D(Basis.IDENTITY, Vector3(0.0, radius * 0.84, 0.0))
	tool.append_from(stem_mesh, 0, stem_xf)
	var built := tool.commit()
	if built.get_surface_count() < 1:
		return body_mesh
	return built



static func body_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.11, 0.2, 1.0)
	mat.roughness = 0.48
	mat.metallic = 0.02
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat