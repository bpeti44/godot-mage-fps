extends Node3D

# -------------------------
# PROCEDURAL FOREST GENERATOR
# -------------------------
# Generates a random forest with winding paths on each run
# Trees spawn everywhere except on paths
# Paths can branch and wind organically

@export var world_size: Vector2 = Vector2(200, 200)
@export var path_width: float = 8.0
@export var tree_density: float = 0.01  # Trees per square meter in forest areas
@export var min_tree_spacing: float = 8.0
@export var random_seed: int = -1  # -1 = use random seed each run

# Tree scene references
@export var maple_tree_scene: PackedScene
@export var pine_tree_scene: PackedScene
@export var tree_mix_ratio: float = 0.5  # 0.0 = all pine, 1.0 = all maple

# Path generation settings
@export var path_segments: int = 50
@export var path_curve_strength: float = 20.0
@export var branch_probability: float = 0.15
@export var max_branches: int = 3

# Internal variables
var noise: FastNoiseLite
var path_map: Array = []  # 2D grid marking path locations
var tree_instances: Array = []
var terrain: Terrain3D = null  # Reference to Terrain3D node

func _ready():
	print("ProceduralForestGenerator: Starting initialization...")

	# Find Terrain3D node
	terrain = get_node_or_null("../Terrain")
	if terrain:
		print("ProceduralForestGenerator: Found Terrain3D node")
	else:
		print("ProceduralForestGenerator: WARNING - Terrain3D node not found, path textures will not be applied")

	# Set random seed
	if random_seed == -1:
		randomize()
	else:
		seed(random_seed)

	# Setup noise for path variation
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

	print("ProceduralForestGenerator: Initializing path map...")
	# Initialize path map
	_initialize_path_map()

	print("ProceduralForestGenerator: Generating paths...")
	# Generate paths
	_generate_paths()

	print("ProceduralForestGenerator: Applying path textures...")
	# Apply path textures to terrain
	_apply_path_textures()

	print("ProceduralForestGenerator: Generating forest...")
	# Generate forest
	_generate_forest()

	print("ProceduralForestGenerator: Initialization complete!")

func _initialize_path_map():
	# Create 2D grid for path marking
	var grid_width = int(world_size.x)
	var grid_height = int(world_size.y)

	path_map.resize(grid_height)
	for y in grid_height:
		path_map[y] = []
		path_map[y].resize(grid_width)
		for x in grid_width:
			path_map[y][x] = false

func _generate_paths():
	# Generate main path
	_generate_single_path(Vector2(world_size.x * 0.1, world_size.y * 0.5),
	                       Vector2(world_size.x * 0.9, world_size.y * 0.5),
	                       path_segments)

	# Generate branch paths
	var branches_created = 0
	for i in range(path_segments):
		if randf() < branch_probability and branches_created < max_branches:
			var branch_start = Vector2(
				randf_range(world_size.x * 0.2, world_size.x * 0.8),
				randf_range(world_size.y * 0.2, world_size.y * 0.8)
			)
			var branch_end = branch_start + Vector2(
				randf_range(-100, 100),
				randf_range(-100, 100)
			)
			_generate_single_path(branch_start, branch_end, int(path_segments / 2))
			branches_created += 1

func _generate_single_path(start: Vector2, end: Vector2, segments: int):
	var points: Array = []

	# Generate path points with noise-based curves
	for i in range(segments + 1):
		var t = float(i) / segments
		var base_point = start.lerp(end, t)

		# Add perpendicular offset using noise for organic curves
		var noise_value = noise.get_noise_2d(base_point.x * 0.1, base_point.y * 0.1)
		var perpendicular = (end - start).orthogonal().normalized()
		var curved_point = base_point + perpendicular * noise_value * path_curve_strength

		points.append(curved_point)

	# Mark path on grid
	for i in range(points.size() - 1):
		_mark_path_segment(points[i], points[i + 1])

func _mark_path_segment(from: Vector2, to: Vector2):
	# Draw a thick line on the path map
	var distance = from.distance_to(to)
	var steps = int(distance)

	for i in range(steps + 1):
		var t = float(i) / max(steps, 1)
		var point = from.lerp(to, t)
		_mark_path_circle(point, path_width * 0.5)

func _mark_path_circle(center: Vector2, radius: float):
	# Mark a circular area as path
	var min_x = int(max(0, center.x - radius))
	var max_x = int(min(world_size.x - 1, center.x + radius))
	var min_y = int(max(0, center.y - radius))
	var max_y = int(min(world_size.y - 1, center.y + radius))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius and y < path_map.size() and x < path_map[y].size():
				path_map[y][x] = true

func _generate_forest():
	if maple_tree_scene == null or pine_tree_scene == null:
		push_warning("Tree scenes not assigned to ProceduralForestGenerator!")
		return

	# Calculate tree count
	var forest_area = world_size.x * world_size.y
	var target_tree_count = int(forest_area * tree_density)

	var trees_placed = 0
	var attempts = 0
	var max_attempts = target_tree_count * 10

	while trees_placed < target_tree_count and attempts < max_attempts:
		attempts += 1

		# Random position
		var pos = Vector3(
			randf_range(0, world_size.x),
			0,
			randf_range(0, world_size.y)
		)

		# Check if on path
		var grid_x = int(pos.x)
		var grid_z = int(pos.z)
		if grid_z >= 0 and grid_z < path_map.size() and grid_x >= 0 and grid_x < path_map[grid_z].size():
			if path_map[grid_z][grid_x]:
				continue  # Skip if on path

		# Check spacing from other trees
		if _check_tree_spacing(pos):
			_spawn_tree(pos)
			trees_placed += 1

	print("Procedural Forest: Placed %d trees out of %d target" % [trees_placed, target_tree_count])

func _check_tree_spacing(pos: Vector3) -> bool:
	for tree_pos in tree_instances:
		if pos.distance_to(tree_pos) < min_tree_spacing:
			return false
	return true

func _spawn_tree(pos: Vector3):
	# Choose tree type based on mix ratio
	var tree_scene = pine_tree_scene if randf() > tree_mix_ratio else maple_tree_scene

	var tree = tree_scene.instantiate()
	tree.position = pos

	# Random rotation
	tree.rotation.y = randf() * TAU

	# Large trees with significant size variation (3x to 12x original size)
	var scale_var = randf_range(3.0, 12.0)
	tree.scale = Vector3(scale_var, scale_var, scale_var)

	add_child(tree)
	tree_instances.append(pos)

func _apply_path_textures():
	# Create visual path meshes using MeshInstance3D with sandy gravel appearance
	# This is simpler than programmatically painting Terrain3D textures

	var path_material = StandardMaterial3D.new()
	path_material.albedo_color = Color(0.7, 0.65, 0.5)  # Sandy gravel color
	path_material.roughness = 0.9

	# Load sandy_gravel texture if available
	var sandy_texture = load("res://demo/assets/textures/sandy_gravel_02_diff_1k.jpg")
	if sandy_texture:
		path_material.albedo_texture = sandy_texture
		path_material.uv1_scale = Vector3(0.5, 0.5, 0.5)  # Scale texture for detail

	var meshes_created = 0

	# Create mesh strips for each continuous path segment
	for y in range(path_map.size()):
		for x in range(path_map[y].size()):
			if path_map[y][x]:  # If this is a path
				var world_pos = Vector3(x, 0.1, y)  # Slightly above ground

				# Create a small plane mesh at this location
				var mesh_instance = MeshInstance3D.new()
				var plane_mesh = PlaneMesh.new()
				plane_mesh.size = Vector2(1.0, 1.0)  # 1x1 meter quad
				mesh_instance.mesh = plane_mesh
				mesh_instance.material_override = path_material
				mesh_instance.position = world_pos
				mesh_instance.rotation.x = 0  # Flat on ground

				add_child(mesh_instance)
				meshes_created += 1

	print("ProceduralForestGenerator: Created %d path mesh segments" % meshes_created)
