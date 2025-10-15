extends Node3D # Or your main scene's root node type (e.g. Node3D)

# Preload the zombie scene to avoid loading on every spawn
const ZOMBIE_SCENE = preload("res://zombie.tscn")

# List storing active zombies (optional, but good for tracking)
var active_zombies: Array = []
var max_zombies: int = 1 # Set how many zombies can be on the map at once

# Player reference
var player_target: CharacterBody3D = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# Find the Player and save its reference
	player_target = get_tree().get_first_node_in_group("player")

	if not player_target or not player_target is CharacterBody3D:
		print("FATAL ERROR: Player node not found or not in 'player' group.")
		return # Stop the script if player is not found

	# Wait for player to be positioned by terrain generator
	await get_tree().create_timer(0.5).timeout

	# Spawn a zombie close to player for testing (10 meters in front)
	var spawn_offset = player_target.transform.basis.z * -10.0  # 10m forward
	var zombie_spawn_pos = player_target.global_position + spawn_offset
	zombie_spawn_pos.y = player_target.global_position.y  # Same height as player
	spawn_zombie(zombie_spawn_pos)


func spawn_zombie(spawn_position: Vector3):
	# 1. Instantiate the Zombie scene
	var zombie_instance = ZOMBIE_SCENE.instantiate()

	# 2. Set the Player reference
	zombie_instance.player_target = player_target

	# 3. Connect the Zombie death signal to the _on_zombie_died function
	# Assumes that 'signal zombie_died(zombie_position)' is defined in the Zombie script
	zombie_instance.zombie_died.connect(_on_zombie_died)

	# 4. Add to the scene tree
	add_child(zombie_instance)

	# 5. Set its position on the map (global_position works because it's already in the tree)
	zombie_instance.global_position = spawn_position

	active_zombies.append(zombie_instance)


# NEW FUNCTION: Called by the Zombie when it dies
func _on_zombie_died(zombie_position: Vector3):
	print("Zombie killed. Respawning in 1 second...")

	# Remove inactive zombies from the list (queue_free() doesn't remove automatically)
	active_zombies.clear()

	# Optional delay before respawn (better visual experience)
	await get_tree().create_timer(1.0).timeout

	# Spawn a new zombie at the dead zombie's position
	# If you want a custom spawn location, replace zombie_position with another Vector3.
	spawn_zombie(zombie_position)
