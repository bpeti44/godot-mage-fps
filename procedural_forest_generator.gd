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

# Foliage scene references
@export var bush_scene: PackedScene
@export var rock_scene: PackedScene
@export var bush_density: float = 0.02  # Bushes per square meter
@export var rock_density: float = 0.015  # Rocks per square meter

# Path generation settings
@export var path_segments: int = 50
@export var path_curve_strength: float = 20.0
@export var branch_probability: float = 0.15
@export var max_branches: int = 3
@export var max_path_slope_degrees: float = 15.0  # Maximum walkable slope in degrees
@export var path_smoothing_radius: float = 6.0  # Radius for terrain smoothing around paths

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

	print("ProceduralForestGenerator: Generating foliage (bushes and rocks)...")
	# Generate bushes and rocks
	_generate_foliage()

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
	# Create heightmap with hills and mountains, paths follow terrain
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

	# Generate base heightmap - paths now follow terrain naturally
	for y in range(grid_height):
		for x in range(grid_width):
			# Combine large and small noise
			var large_noise = terrain_noise_large.get_noise_2d(x, y)
			var small_noise = terrain_noise_small.get_noise_2d(x, y)

			# Large features (0-40m), small features (0-5m)
			var height = large_noise * 40.0 + small_noise * 5.0

			# Ensure non-negative heights
			height = max(0.0, height)

			height_map[y][x] = height

	# Smooth paths to make them walkable and visually coherent
	_smooth_paths_for_walkability()

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


func _smooth_paths_for_walkability():
	# Smooth terrain along paths to ensure walkability and visual coherence
	# Strategy:
	# 1. Within path width, terrain is flat (same height across width)
	# 2. Outside path, smooth transition to natural terrain
	# 3. Along path length, gentle slopes respecting max_path_slope_degrees

	var grid_width = int(world_size.x)
	var grid_height = int(world_size.y)
	var max_slope_radians = deg_to_rad(max_path_slope_degrees)
	var path_half_width = path_width * 0.5
	var smoothing_radius = int(path_smoothing_radius)

	# Create a copy of the heightmap for reading while we modify
	var original_heights: Array = []
	original_heights.resize(grid_height)
	for y in range(grid_height):
		original_heights[y] = height_map[y].duplicate()

	# First pass: Flatten path pixels to have consistent height across width
	# We'll use the average height of each path segment
	for y in range(grid_height):
		for x in range(grid_width):
			if path_map[y][x]:
				# Calculate average height in a small radius (just the path itself)
				var sum_height = 0.0
				var count = 0
				var check_radius = int(path_half_width)

				for dy in range(-check_radius, check_radius + 1):
					for dx in range(-check_radius, check_radius + 1):
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
							if path_map[ny][nx]:
								sum_height += original_heights[ny][nx]
								count += 1

				if count > 0:
					var avg_height = sum_height / count
					# Set all path pixels in width to same height
					for dy in range(-check_radius, check_radius + 1):
						for dx in range(-check_radius, check_radius + 1):
							var nx = x + dx
							var ny = y + dy
							if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
								var dist_from_center = sqrt(dx * dx + dy * dy)
								if dist_from_center <= path_half_width and path_map[ny][nx]:
									height_map[ny][nx] = avg_height

	# Second pass: Smooth edges outside path for natural transitions
	var pixels_smoothed = 0
	for y in range(grid_height):
		for x in range(grid_width):
			if not path_map[y][x]:  # If NOT on path
				# Check if we're near a path
				var nearest_path_height = -1.0
				var nearest_path_dist = 999999.0

				for dy in range(-smoothing_radius, smoothing_radius + 1):
					for dx in range(-smoothing_radius, smoothing_radius + 1):
						var nx = x + dx
						var ny = y + dy

						if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
							if path_map[ny][nx]:
								var dist = sqrt(dx * dx + dy * dy)
								if dist < nearest_path_dist:
									nearest_path_dist = dist
									nearest_path_height = height_map[ny][nx]

				# If near a path, blend height
				if nearest_path_height >= 0.0 and nearest_path_dist <= smoothing_radius:
					var blend = 1.0 - (nearest_path_dist / smoothing_radius)
					blend = blend * blend  # Smooth falloff

					var original_height = original_heights[y][x]
					var target_height = lerp(original_height, nearest_path_height, blend)

					# Respect max slope
					var horizontal_dist = max(nearest_path_dist, 0.1)
					var height_diff = abs(target_height - nearest_path_height)
					var slope_angle = atan(height_diff / horizontal_dist)

					if slope_angle > max_slope_radians:
						var max_height_diff = horizontal_dist * tan(max_slope_radians)
						if target_height > nearest_path_height:
							target_height = nearest_path_height + max_height_diff
						else:
							target_height = nearest_path_height - max_height_diff

					height_map[y][x] = target_height
					pixels_smoothed += 1

	print("ProceduralForestGenerator: Smoothed %d pixels for walkable paths" % pixels_smoothed)

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
	# Create smooth path mesh that perfectly follows terrain heightmap
	# Uses ArrayMesh for optimal performance and smooth appearance

	var path_material = StandardMaterial3D.new()
	path_material.albedo_color = Color(0.9, 0.85, 0.7)  # Sandy color
	path_material.roughness = 0.8
	path_material.metallic = 0.0
	path_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides

	# Load sandy_gravel texture
	var sandy_texture = load("res://demo/assets/textures/sandy_gravel_02_diff_1k.jpg")
	if sandy_texture:
		path_material.albedo_texture = sandy_texture
		path_material.uv1_scale = Vector3(0.3, 0.3, 0.3)
		print("ProceduralForestGenerator: Sandy texture loaded")

	# Create single continuous mesh for all paths
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.set_material(path_material)

	var vertices_added = 0

	# Generate mesh triangles for each path pixel
	for y in range(path_map.size() - 1):
		for x in range(path_map[y].size() - 1):
			if path_map[y][x]:  # If this is a path pixel
				# Get heights for 4 corners of this pixel
				var h00 = height_map[y][x] if y < height_map.size() and x < height_map[y].size() else 0.0
				var h10 = height_map[y][x+1] if y < height_map.size() and x+1 < height_map[y].size() else 0.0
				var h01 = height_map[y+1][x] if y+1 < height_map.size() and x < height_map[y+1].size() else 0.0
				var h11 = height_map[y+1][x+1] if y+1 < height_map.size() and x+1 < height_map[y+1].size() else 0.0

				# Apply world offset and slight elevation
				var offset_y = 0.05  # Slightly above terrain
				var v00 = Vector3(x + world_offset.x, h00 + offset_y, y + world_offset.y)
				var v10 = Vector3(x + 1 + world_offset.x, h10 + offset_y, y + world_offset.y)
				var v01 = Vector3(x + world_offset.x, h01 + offset_y, y + 1 + world_offset.y)
				var v11 = Vector3(x + 1 + world_offset.x, h11 + offset_y, y + 1 + world_offset.y)

				# UV coordinates for texture mapping
				var uv_scale = 0.1  # Texture repeat scale
				var uv00 = Vector2(x * uv_scale, y * uv_scale)
				var uv10 = Vector2((x + 1) * uv_scale, y * uv_scale)
				var uv01 = Vector2(x * uv_scale, (y + 1) * uv_scale)
				var uv11 = Vector2((x + 1) * uv_scale, (y + 1) * uv_scale)

				# Create two triangles for this quad
				# Triangle 1: v00, v10, v11
				surface_tool.set_uv(uv00)
				surface_tool.add_vertex(v00)
				surface_tool.set_uv(uv10)
				surface_tool.add_vertex(v10)
				surface_tool.set_uv(uv11)
				surface_tool.add_vertex(v11)

				# Triangle 2: v00, v11, v01
				surface_tool.set_uv(uv00)
				surface_tool.add_vertex(v00)
				surface_tool.set_uv(uv11)
				surface_tool.add_vertex(v11)
				surface_tool.set_uv(uv01)
				surface_tool.add_vertex(v01)

				vertices_added += 6

	if vertices_added > 0:
		surface_tool.generate_normals()
		var mesh = surface_tool.commit()

		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = mesh
		add_child(mesh_instance)

		print("ProceduralForestGenerator: Created smooth path mesh with %d vertices" % vertices_added)
	else:
		print("ProceduralForestGenerator: No path vertices to create")

func _generate_foliage():
	# Generate bushes
	if bush_scene:
		_spawn_foliage_type(bush_scene, bush_density, "bushes", 0.5, 2.0)
	else:
		print("ProceduralForestGenerator: WARNING - Bush scene not assigned")

	# Generate rocks
	if rock_scene:
		_spawn_foliage_type(rock_scene, rock_density, "rocks", 0.3, 6.0)
	else:
		print("ProceduralForestGenerator: WARNING - Rock scene not assigned")

func _spawn_foliage_type(scene: PackedScene, density: float, type_name: String, min_scale: float, max_scale: float):
	var forest_area = world_size.x * world_size.y
	var target_count = int(forest_area * density)
	var placed = 0
	var attempts = 0
	var max_attempts = target_count * 5

	while placed < target_count and attempts < max_attempts:
		attempts += 1

		# Random position in grid space
		var grid_x = int(randf_range(0, world_size.x))
		var grid_z = int(randf_range(0, world_size.y))

		# Check if on path
		if grid_z >= 0 and grid_z < path_map.size() and grid_x >= 0 and grid_x < path_map[grid_z].size():
			if path_map[grid_z][grid_x]:
				continue  # Skip if on path

			# Get terrain height
			var terrain_height = height_map[grid_z][grid_x] if height_map.size() > grid_z and height_map[grid_z].size() > grid_x else 0.0

			# Don't spawn on mountains
			if terrain_height > 30.0:
				continue

			# Convert to world position with offset
			var pos = Vector3(
				grid_x + world_offset.x,
				terrain_height,
				grid_z + world_offset.y
			)

			# Spawn foliage
			var instance = scene.instantiate()
			instance.position = pos
			instance.rotation.y = randf() * TAU

			# Random scale
			var scale_var = randf_range(min_scale, max_scale)
			instance.scale = Vector3(scale_var, scale_var, scale_var)

			add_child(instance)
			placed += 1

	print("ProceduralForestGenerator: Placed %d %s out of %d target" % [placed, type_name, target_count])

