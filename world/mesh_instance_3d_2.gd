@tool
extends MeshInstance3D

func _ready():
	setup_quad_wireframe()

func setup_quad_wireframe():
	var old_mesh = mesh
	if not old_mesh: return
	
	var surface_array = old_mesh.surface_get_arrays(0)
	var verts = surface_array[Mesh.ARRAY_VERTEX]
	var indices = surface_array[Mesh.ARRAY_INDEX]
	
	var new_verts = PackedVector3Array()
	var new_uvs = PackedVector2Array()
	
	# We iterate through indices in groups of 6 (2 triangles = 1 quad)
	for i in range(0, indices.size(), 6):
		# Triangle 1 of the Quad
		new_verts.append(verts[indices[i]])
		new_verts.append(verts[indices[i+1]])
		new_verts.append(verts[indices[i+2]])
		
		new_uvs.append(Vector2(0, 0))
		new_uvs.append(Vector2(1, 0))
		new_uvs.append(Vector2(1, 1))
		
		# Triangle 2 of the Quad
		new_verts.append(verts[indices[i+3]])
		new_verts.append(verts[indices[i+4]])
		new_verts.append(verts[indices[i+5]])
		
		new_uvs.append(Vector2(1, 1))
		new_uvs.append(Vector2(0, 1))
		new_uvs.append(Vector2(0, 0))
	
	var new_mesh = ArrayMesh.new()
	var new_arrays = []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX] = new_verts
	new_arrays[Mesh.ARRAY_TEX_UV] = new_uvs
	
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
	mesh = new_mesh
