extends CharacterBody3D

# -------------------------
# STATS
# -------------------------
@export var max_health: int = 100
@export var damage_on_hit: int = 10 
var current_health: int = 0 

signal zombie_died(zombie_position)

# -------------------------
# COMBAT FEEL / KNOCKBACK
# -------------------------
@export var knockback_strength: float = 32.0  # Initial impulse strength
@export var stun_duration: float = 0.2	 # Duration of the knockback impulse
@export var knockback_decay: float = 0.1 # Decay factor for the knockback vector (lower value = slower decay)
var knockback_vector: Vector3 = Vector3.ZERO
var knockback_timer: float = 0.0

# -------------------------
# MOVEMENT SETTINGS
# -------------------------
@export var speed: float = 3.0	 	 	
@export var rotation_speed: float = 5.0	
@export var gravity: float = 9.8		

# ZOMBIE STATES
enum State {CHASE, IDLE, STUNNED} 
var current_state: State = State.CHASE

# References
var player_target: CharacterBody3D = null
var attack_zone: Area3D = null
var animation_player: AnimationPlayer = null

# HP BAR VARIABLES
var health_bar_mesh: MeshInstance3D = null
var health_bar_max_scale_x: float = 0.0

# -------------------------
# READY FUNCTION
# -------------------------
func _ready():
	current_health = max_health
	
	# Setup Attack Zone and connect signals
	attack_zone = $AttackZone
	if attack_zone:
		attack_zone.body_entered.connect(_on_attack_zone_body_entered)
		attack_zone.body_exited.connect(_on_attack_zone_body_exited)
	
	# Setup Player Target 
	if not player_target:
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node is CharacterBody3D:
			player_target = player_node
			
	# Setup Animation Player
	if has_node("zombie/AnimationPlayer"):
		animation_player = $zombie/AnimationPlayer
	else:
		print("FATAL ERROR: AnimationPlayer not found at path 'zombie/AnimationPlayer'!")
	
	# Initialize State and force Run animation
	if animation_player:
		set_state(State.CHASE)
		animation_player.play("zombie_run/Run")
		
	# HP BAR INITIALIZATION
	if has_node("HealthBar/Bar"):
		health_bar_mesh = $HealthBar/Bar
		health_bar_max_scale_x = health_bar_mesh.scale.x


# -------------------------
# COMBAT FUNCTIONS
# -------------------------

func take_damage(amount: int, hit_direction: Vector3):
	current_health -= amount
	print("Zombie took ", amount, " damage. Health: ", current_health)
	
	# Apply knockback impulse
	knockback_timer = stun_duration
	
	# Flatten the hit_direction to ensure pure horizontal knockback
	var flat_hit_direction = Vector3(hit_direction.x, 0, hit_direction.z).normalized()
	
	# Set knockback vector: Moves the zombie AWAY from the hit source (opposite of the inverted vector)
	knockback_vector = flat_hit_direction * knockback_strength
	
	# Update HP Bar
	if health_bar_mesh:
		var health_ratio = float(current_health) / float(max_health)
		var new_scale_x = health_bar_max_scale_x * health_ratio
		health_bar_mesh.scale.x = new_scale_x

	if current_health <= 0:
		_die()

func _die():
	print("Zombie died!")
	emit_signal("zombie_died", global_position)
	queue_free()

# -------------------------
# STATE CHANGE FUNCTION
# -------------------------
func set_state(new_state: State):
	if current_state == new_state:
		return
	
	current_state = new_state
	
	match current_state:
		State.CHASE:
			if animation_player:
				_play_animation("zombie_run/Run")
		State.IDLE:
			if animation_player:
				_play_animation("zombie_idle/Idle")
		State.STUNNED:
			# State not used for movement, animation handled by physics logic if needed
			pass

# -------------------------
# PHYSICS / MOVEMENT
# -------------------------
func _physics_process(delta):
	
	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	
	# 2. Normal Movement and Rotation Logic (Always runs)
	
	velocity.x = 0
	velocity.z = 0
	
	if player_target:
		var target_position = player_target.global_position
		var current_position = global_position
		
		var distance_vector = target_position - current_position
		var direction: Vector3 = Vector3.ZERO
		
		if distance_vector.length_squared() > 0.0001:
			direction = distance_vector.normalized()
			direction.y = 0
		
		# Rotation
		if current_state == State.CHASE or current_state == State.IDLE:
			if direction.length_squared() > 0.0001:
				var target_transform = global_transform.looking_at(target_position, Vector3.UP, true)
				global_transform = global_transform.interpolate_with(target_transform, rotation_speed * delta)
		
		
		# Velocity Application
		if current_state == State.CHASE:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
	
	
	# 3. Additive Knockback Impulse
	if knockback_timer > 0:
		knockback_timer -= delta
		
		# Decay the knockback vector for smooth deceleration
		knockback_vector = knockback_vector.lerp(Vector3.ZERO, knockback_decay)
		
		# Add the knockback force to the normal velocity
		velocity.x += knockback_vector.x 
		velocity.z += knockback_vector.z
			
	
	# Final physics application
	move_and_slide()

# -------------------------
# HELPER FUNCTION FOR CLEAN ANIMATION SWITCHING
# -------------------------
func _play_animation(anim_name: String):
	if animation_player and animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

# ------------------------------------
# ATTACK ZONE SIGNAL HANDLING
# ------------------------------------

# Player ENTERS the zone: STOP the zombie (IDLE state)
func _on_attack_zone_body_entered(body: Node3D):
	if body.is_in_group("player") and current_state != State.STUNNED:
		set_state(State.IDLE)

# Player EXITS the zone: START the zombie again (CHASE state)
func _on_attack_zone_body_exited(body: Node3D):
	if body.is_in_group("player") and current_state != State.STUNNED:
		set_state(State.CHASE)
