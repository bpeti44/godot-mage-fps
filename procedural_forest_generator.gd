extends Node3D

# -------------------------
# PROCEDURAL FOREST GENERATOR
# -------------------------
# Generates a random forest with winding paths on each run
# Trees spawn everywhere except on paths
# Paths can branch and wind organically

@export var world_size: Vector2 = Vector2(200, 200)
@export var world_offset: Vector2 = Vector2(-100, -100)  # Offset so (0,0,0) is in the center
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
var height_map: Array = []  # 2D grid storing terrain heights
var tree_instances: Array = []
var terrain: Terrain3D = null  # Reference to Terrain3D node
var terrain_data = null  # Reference to Terrain3DData

func _ready():
	print("ProceduralForestGenerator: Starting initialization...")

	# Find Terrain3D node
	terrain = get_node_or_null("../Terrain")
	if terrain:
		print("ProceduralForestGenerator: Found Terrain3D node")
		terrain_data = terrain.get_data()
		if terrain_data:
			print("ProceduralForestGenerator: Got Terrain3DData reference")
		else:
			print("ProceduralForestGenerator: WARNING - Could not get Terrain3DData")

		# Ensure collision is enabled
		if terrain.has_method("set_collision_enabled"):
			terrain.set_collision_enabled(true)
			print("ProceduralForestGenerator: Enabled terrain collision")
	else:
		print("ProceduralForestGenerator: WARNING - Terrain3D node not found")

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

	print("ProceduralForestGenerator: Generating heightmap...")
	# Generate terrain heightmap AFTER paths are marked
	_generate_heightmap()

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
	# Find player position (assuming player spawns at world origin)
	var player_spawn = Vector2(world_size.x * 0.5, world_size.y * 0.5)  # Center of world in grid space

	# Try to find actual player node
	var player = get_node_or_null("../Player")
	if player:
		# Convert world position to grid position
		var world_pos = Vector2(player.global_position.x, player.global_position.z)
		player_spawn = world_pos - world_offset  # Remove offset to get grid coordinates
		print("ProceduralForestGenerator: Found player at world (%f, %f), grid (%f, %f)" % [world_pos.x, world_pos.y, player_spawn.x, player_spawn.y])
	else:
		print("ProceduralForestGenerator: Player not found, using center position")

	# Ensure player spawn is within world bounds (grid space)
	player_spawn.x = clamp(player_spawn.x, 0, world_size.x - 1)
	player_spawn.y = clamp(player_spawn.y, 0, world_size.y - 1)

	# Generate main path starting from player position
	var main_path_end = Vector2(
		randf_range(world_size.x * 0.7, world_size.x * 0.9),
		randf_range(world_size.y * 0.3, world_size.y * 0.7)
	)
	_generate_single_path(player_spawn, main_path_end, path_segments)
	print("ProceduralForestGenerator: Main path from player (%f, %f) to (%f, %f)" % [player_spawn.x, player_spawn.y, main_path_end.x, main_path_end.y])

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

func _generate_heightmap():
	# Create heightmap with hills and mountains, keeping paths flat
	var grid_width = int(world_size.x)
	var grid_height = int(world_size.y)

	# Initialize height_map
	height_map.resize(grid_height)
	for y in grid_height:
		height_map[y] = []
		height_map[y].resize(grid_width)
		for x in grid_width:
			height_map[y][x] = 0.0

	# Create noise generators for terrain
	var terrain_noise_large = FastNoiseLite.new()
	terrain_noise_large.seed = randi()
	terrain_noise_large.frequency = 0.015  # Large hills/mountains
	terrain_noise_large.noise_type = FastNoiseLite.TYPE_PERLIN

	var terrain_noise_small = FastNoiseLite.new()
	terrain_noise_small.seed = randi()
	terrain_noise_small.frequency = 0.08  # Small bumps
	terrain_noise_small.noise_type = FastNoiseLite.TYPE_PERLIN

	# Generate base heightmap
	for y in range(grid_height):
		for x in range(grid_width):
			# Combine large and small noise
			var large_noise = terrain_noise_large.get_noise_2d(x, y)
			var small_noise = terrain_noise_small.get_noise_2d(x, y)

			# Large features (0-40m), small features (0-5m)
			var height = large_noise * 40.0 + small_noise * 5.0

			# Ensure non-negative heights
			height = max(0.0, height)

			# If this is a path, flatten it (low height)
			if path_map[y][x]:
				height = 0.0  # Paths at ground level (0m) so player spawns on them

			height_map[y][x] = height

	# Smooth path edges to create gentle slopes
	for y in range(grid_height):
		for x in range(grid_width):
			if path_map[y][x]:
				# Smooth the area around paths
				_smooth_height_around(x, y, 3)

	# Apply heightmap to Terrain3D
	if terrain_data:
		print("ProceduralForestGenerator: Applying heightmap to Terrain3D...")
		var heights_set = 0
		for y in range(grid_height):
			for x in range(grid_width):
				# Apply world offset so (0,0,0) is at the center
				var pos = Vector3(x + world_offset.x, 0, y + world_offset.y)
				var height = height_map[y][x]
				terrain_data.set_height(pos, height)
				heights_set += 1

		# Update terrain maps to apply changes
		terrain_data.update_maps()
		print("ProceduralForestGenerator: Set %d height values" % heights_set)

		# Force collision regeneration
		if terrain.has_method("update_aabbs"):
			terrain.update_aabbs()
			print("ProceduralForestGenerator: Updated terrain collision")
	else:
		print("ProceduralForestGenerator: WARNING - Cannot apply heightmap, terrain_data not available")

func _smooth_height_around(center_x: int, center_y: int, radius: int):
	# Smooth heights around a point to create gentle transitions
	var grid_width = int(world_size.x)
	var grid_height = int(world_size.y)

	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var nx = center_x + dx
			var ny = center_y + dy

			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if not path_map[ny][nx]:
					# Gradually increase height away from path
					var dist = sqrt(dx * dx + dy * dy)
					var blend = clamp(dist / radius, 0.0, 1.0)
					var current_height = height_map[ny][nx]
					var path_height = 0.0  # Paths at ground level
					height_map[ny][nx] = lerp(path_height, current_height, blend)

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

		# Random position in grid space
		var grid_x = int(randf_range(0, world_size.x))
		var grid_z = int(randf_range(0, world_size.y))

		# Check if on path
		if grid_z >= 0 and grid_z < path_map.size() and grid_x >= 0 and grid_x < path_map[grid_z].size():
			if path_map[grid_z][grid_x]:
				continue  # Skip if on path

			# Check if on mountain (too high)
			var terrain_height = height_map[grid_z][grid_x] if height_map.size() > grid_z and height_map[grid_z].size() > grid_x else 0.0
			if terrain_height > 30.0:  # Don't spawn trees on mountains above 30m
				continue

			# Convert to world position with offset
			var pos = Vector3(
				grid_x + world_offset.x,
				terrain_height,
				grid_z + world_offset.y
			)

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
	path_material.albedo_color = Color(1.0, 0.95, 0.8)  # Very bright sandy/yellow color
	path_material.roughness = 0.7
	path_material.metallic = 0.0
	path_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
	path_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Always visible, no shadows

	# Load sandy_gravel texture if available
	var sandy_texture = load("res://demo/assets/textures/sandy_gravel_02_diff_1k.jpg")
	if sandy_texture:
		path_material.albedo_texture = sandy_texture
		path_material.uv1_scale = Vector3(0.3, 0.3, 0.3)  # Smaller scale for more detail
		print("ProceduralForestGenerator: Sandy texture loaded successfully")
	else:
		print("ProceduralForestGenerator: WARNING - Sandy texture not found!")

	var meshes_created = 0

	# Create mesh strips for each continuous path segment
	for y in range(path_map.size()):
		for x in range(path_map[y].size()):
			if path_map[y][x]:  # If this is a path
				# Get height from our generated height_map
				var terrain_height = height_map[y][x] if height_map.size() > y and height_map[y].size() > x else 0.0

				# Apply world offset so (0,0,0) is at the center
				var world_pos = Vector3(x + world_offset.x, terrain_height + 0.05, y + world_offset.y)

				# Create a flat box mesh for the path
				var mesh_instance = MeshInstance3D.new()
				var box_mesh = BoxMesh.new()
				box_mesh.size = Vector3(1.2, 0.05, 1.2)  # Thin, flat box at terrain level
				mesh_instance.mesh = box_mesh
				mesh_instance.material_override = path_material
				mesh_instance.position = world_pos

				add_child(mesh_instance)
				meshes_created += 1

	print("ProceduralForestGenerator: Created %d path mesh segments" % meshes_created)
