extends Area3D

@export var speed: float = 20.0 # Movement speed of the spell
@export var damage: int = 30	# Damage value to be dealt on hit
@export var lifetime: float = 3.0 # Duration before the spell despawns

var direction: Vector3 = Vector3.FORWARD # Set by the Player's _cast_spell() function
var player_node: Node # Reference to the Player node


func _ready():
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)
	
	# Find the Player node reference
	player_node = get_tree().get_first_node_in_group("player")
	
	# Start timer for the spell's lifetime (assuming a Timer node exists)
	var timer_node = $Timer
	if timer_node:
		timer_node.start(lifetime)
	
	# CRITICAL FIX: Prevent immediate collision with the Player upon spawning
	
	# 1. Disable Area3D monitoring
	monitoring = false
	
	# 2. Wait a short time (e.g., 0.05 seconds) for the spell to move away from the spawn point
	await get_tree().create_timer(0.05).timeout
	
	# 3. Re-enable Area3D monitoring to detect collisions
	monitoring = true
	

func _physics_process(delta):
	# Move the spell in its set direction (linear movement)
	global_position += direction * speed * delta

# SIGNAL HANDLER: Called when the Area3D enters another Body
func _on_body_entered(body: Node3D):
	
	# Check if the hit body belongs to the "zombie" group
	if body.is_in_group("zombie"):
		if body.has_method("take_damage"):
			
			# KNOCKBACK LOGIC: Calculate the direction of the impact (from spell to target)
			# This vector is used by the zombie to push itself away.
			var hit_direction = (body.global_position - global_position).normalized()
			
			# Apply damage to the zombie (passing the hit_direction for knockback)
			body.take_damage(damage, hit_direction)
	
	# Activate camera shake on the Player
	_emit_camera_shake_signal()

	# Despawn the spell upon hitting ANYTHING (zombie, wall, ground)
	queue_free()

# SIGNAL HANDLER: Called when the Timer runs out
func _on_Timer_timeout():
	# Despawn the spell after its lifetime expires, if it hasn't hit anything yet
	queue_free()

# -------------------------
# CAMERA SHAKE SIGNAL EMISSION
# -------------------------
func _emit_camera_shake_signal():
	# Check if the player node exists and has the method (i.e., is listening for the signal)
	if player_node and player_node.has_method("start_camera_shake"):
		# Emit the hit_registered signal to the Player node
		# Values: ( 0.2 seconds duration, 0.3 intensity )
		player_node.emit_signal("hit_registered", 0.2, 0.3)
