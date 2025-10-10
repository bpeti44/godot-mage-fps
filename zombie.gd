extends CharacterBody3D

# -------------------------
# STATS
# -------------------------
@export var max_health: int = 100
@export var damage_on_hit: int = 10 # Zombie's damage (ha később támadni fog)
var current_health: int = 0 # Initialized in _ready()

signal zombie_died(zombie_position) 


# -------------------------
# MOVEMENT SETTINGS
# -------------------------
@export var speed: float = 3.0           # Zombie movement speed
@export var rotation_speed: float = 5.0  # Rotation interpolation speed
@export var gravity: float = 9.8         # Gravity magnitude

# ZOMBIE STATES
enum State {CHASE, IDLE}
var current_state: State = State.CHASE

# References
var player_target: CharacterBody3D = null
var attack_zone: Area3D = null
var animation_player: AnimationPlayer = null

# HP BAR VÁLTOZÓK (ÚJ)
var health_bar_mesh: MeshInstance3D = null
var health_bar_max_scale_x: float = 0.0

# -------------------------
# READY FUNCTION
# -------------------------
func _ready():
	# Initialize health
	current_health = max_health
	
	# 1. Setup Attack Zone and connect signals
	attack_zone = $AttackZone
	if attack_zone:
		attack_zone.body_entered.connect(_on_attack_zone_body_entered)
		attack_zone.body_exited.connect(_on_attack_zone_body_exited)
	
	# 2. Setup Player Target (Fallback if GameManager didn't set it)
	if not player_target:
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node is CharacterBody3D:
			player_target = player_node
			
	# 3. Setup Animation Player
	if has_node("zombie/AnimationPlayer"):
		animation_player = $zombie/AnimationPlayer
	else:
		print("FATAL ERROR: AnimationPlayer not found at path 'zombie/AnimationPlayer'!")
	
	# 4. Initialize State and force Run animation
	if animation_player:
		set_state(State.CHASE)
		animation_player.play("zombie_run/Run")
		
	# 5. HP BAR INITIALIZATION (ÚJ)
	if has_node("HealthBar/Bar"):
		health_bar_mesh = $HealthBar/Bar
		# Eltároljuk az eredeti skálát (ami az 1.5 volt a beállítások szerint)
		health_bar_max_scale_x = health_bar_mesh.scale.x 


# -------------------------
# COMBAT FUNCTIONS (HP BAR FRISSÍTÉSÉVEL)
# -------------------------

# Function called by the Spell when a collision occurs
func take_damage(amount: int):
	current_health -= amount
	print("Zombie took ", amount, " damage. Health: ", current_health)
	
	# HP BAR FRISSÍTÉS (ÚJ KÓD)
	if health_bar_mesh:
		var health_ratio = float(current_health) / float(max_health)
		var new_scale_x = health_bar_max_scale_x * health_ratio
		
		# Skálázás
		health_bar_mesh.scale.x = new_scale_x
		
		# HA a bar középpontja a zombi feje felett van, akkor a skálázás középről történik.
		# A pozíciót csak akkor kell módosítani, ha a sávot balról akarjuk fixálni. 
		# Ha középről csökken, ez a legegyszerűbb.

	if current_health <= 0:
		_die()

func _die():
	print("Zombie died!")
	emit_signal("zombie_died", global_position) # <-- Ez a kulcs!
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

# -------------------------
# PHYSICS / MOVEMENT
# -------------------------
func _physics_process(delta):
	
	# 1. GRAVITY AND VERTICAL STABILIZATION
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# MOVEMENT AND ROTATION LOGIC
	if player_target:
		var target_position = player_target.global_position
		var current_position = global_position
		
		var distance_vector = target_position - current_position
		var direction: Vector3 = Vector3.ZERO
		
		# Calculate the normalized direction vector towards the player
		if distance_vector.length_squared() > 0.0001:
			direction = distance_vector.normalized()
			direction.y = 0 
		
		# 2. ROTATION: Smoothly look at the target
		if direction.length_squared() > 0.0001:
			var target_transform = global_transform.looking_at(target_position, Vector3.UP, true)
			global_transform = global_transform.interpolate_with(target_transform, rotation_speed * delta)
		
		
		# 3. VELOCITY APPLICATION
		if current_state == State.CHASE:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		
		elif current_state == State.IDLE:
			velocity.x = 0
			velocity.z = 0
	
	# Apply the movement vector
	move_and_slide()

# -------------------------
# HELPER FUNCTION FOR CLEAN ANIMATION SWITCHING
# -------------------------
func _play_animation(name: String):
	if animation_player and animation_player.current_animation != name:
		animation_player.play(name)

# ------------------------------------
# ATTACK ZONE SIGNAL HANDLING
# ------------------------------------

# Player ENTERS the zone: STOP the zombie (IDLE state)
func _on_attack_zone_body_entered(body: Node3D):
	if body.is_in_group("player"):
		set_state(State.IDLE)

# Player EXITS the zone: START the zombie again (CHASE state)
func _on_attack_zone_body_exited(body: Node3D):
	if body.is_in_group("player"):
		set_state(State.CHASE)
