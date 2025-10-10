extends CharacterBody3D

# -------------------------
# MOVEMENT / FPS SETTINGS
# -------------------------
@export var speed: float = 5.0
@export var sprint_multiplier: float = 2.0
@export var jump_velocity: float = 5.0

# -------------------------
# MOUSE / CAMERA SETTINGS
# -------------------------
@export var mouse_sensitivity: float = 0.1

@export var zoom_min: float = 1.0
@export var zoom_max: float = 5.0
@export var zoom_speed: float = 0.5

var camera_distance: float = 3.0 # Default distance from the Player

# -------------------------
# CASTING & COMBAT VARIABLES
# -------------------------
@export var cast_cooldown: float = 0.5 # Cooldown between spells
@export var spell_cast_time: float = 0.5 # Duration of the casting animation
var is_casting: bool = false
var can_cast: bool = true
var casting_timer: Timer = null
var cast_animation_timer: Timer = null

# Reference to the Spell scene
const SPELL_SCENE = preload("res://spell.tscn")

@export var sprint_fov: float = 85.0 # A látómező sprinteléskor (alapérték 85)
const BASE_FOV: float = 75.0      # A normál látómező (alapérték 75)
const FOV_LERP_SPEED: float = 5.0 # A váltás sebessége (gyorsabb = gyorsabb váltás)

# -------------------------
# INTERNAL VARIABLES
# -------------------------
var camera: Camera3D # Explicitly typed for safety
var rotation_x = 0.0 # Vertical rotation (FPS mode pitch)
var camera_offset: float = 1.2 # Default camera height (focus point)
var is_sprinting = false
var animation_player: AnimationPlayer = null
var is_jumping = false
var has_started_jump = false

# ORBIT MODE VARIABLES
var orbiting = false # True if middle mouse is pressed
var orbit_distance = 3.0 # Distance from player when orbiting
var orbit_yaw = 0.0 # Horizontal (Y-axis) rotation for orbit
var orbit_pitch = 0.0 # Vertical (X-axis) rotation for orbit

var spell_spawn_point: Node3D = null # Az BoneAttachment3D hivatkozás


# -------------------------
# READY FUNCTION (A JAVÍTOTT INITIALIZÁCIÓ)
# -------------------------
func _ready():
	camera = $Camera3D
	camera.transform.origin.y = camera_offset
	
	# MOUSE/INPUT BEÁLLÍTÁSA
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# -----------------------------------------------------
	# 1. TIMER CSATLAKOZTATÁSA ÉS HOZZÁADÁSA (MINDENKÉPP ELŐBB FUT LE!)
	# -----------------------------------------------------
	
	# Setup casting timers
	casting_timer = Timer.new()
	add_child(casting_timer)
	casting_timer.one_shot = true
	casting_timer.timeout.connect(_on_cast_cooldown_timeout)
	
	cast_animation_timer = Timer.new()
	add_child(cast_animation_timer)
	cast_animation_timer.one_shot = true
	cast_animation_timer.timeout.connect(_on_cast_animation_timeout)
	
	# -----------------------------------------------------
	# 2. VÁRÁS: Késleltetjük a nehéz node-keresést
	# -----------------------------------------------------
	# Ez a kritikus fix a BoneAttachment3D megtalálásához!
	await get_tree().process_frame
	
	# -----------------------------------------------------
	# 3. NODE-KERESÉS: A MÁR SIKERES ÚTVONAL HASZNÁLATA
	# -----------------------------------------------------
	# A késleltetés után a csomópont már létezik
	spell_spawn_point = $"skeleton_mage/Rig/Skeleton3D/SpellSpawn"
	
	# Try to find the AnimationPlayer inside the character model
	if has_node("Skeleton_Mage/AnimationPlayer"):
		animation_player = $Skeleton_Mage/AnimationPlayer
	elif has_node("skeleton_mage/AnimationPlayer"):
		animation_player = $skeleton_mage/AnimationPlayer

	# Teszteléshez:
	if spell_spawn_point:
		print("Sikeresen csatlakoztunk a BoneAttachment3D-hez (Kéz)! Kész a varázslat pozíciója.")
	else:
		print("KRITIKUS HIBA: A BoneAttachment3D még mindig nem található! Ellenőrizd a betűzést!")
	
	# Start with idle animation
	if animation_player:
		animation_player.play("Idle")


# -------------------------
# INPUT HANDLING
# -------------------------
func _unhandled_input(event):
	
	# === HIBABAKERESÉS: TESZTELÉS ===
	# Ha ez fut, a kattintás érzékelve van.
	if event.is_action_pressed("fire_spell"):
		print("--- KATINTÁS ÉRZÉKELVE! ---")
		print("can_cast állapota:", can_cast)
		print("orbiting állapota:", orbiting)
	# ================================
	
	# CASTING INPUT CHECK
	# FIGYELEM: Ha az Input Map-ben az akció neve "primary_fire" és nem "fire_spell", 
	# a kódot is át kell írni "primary_fire"-re. Feltételezzük, hogy a név most helyes.
	if event.is_action_pressed("fire_spell") and can_cast and not orbiting:
		_cast_spell()
		# Mivel a Godot 4-ben az _unhandled_input fut, itt jelezhetjük, hogy kezeltük
		get_viewport().set_input_as_handled() 
		return # Befejezzük a további bevitel feldolgozását, ha varázslat indult
	
	# Existing Orbit and Mouse Movement Input
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			orbiting = event.pressed
			if orbiting:
				# ENTERING ORBIT MODE
				orbit_yaw = rotation.y
				orbit_pitch = rotation_x
			else:
				# EXITING ORBIT MODE: Snap back to behind the character
				rotation.y = orbit_yaw
				rotation_x = orbit_pitch
				camera.rotation_degrees.x = rotation_x
				camera.transform.origin = Vector3(0, camera_offset, 0)


	if event is InputEventMouseMotion:
		if orbiting:
			_rotate_camera_orbit(event.relative)
		else:
			_rotate_camera_fps(event.relative)
			
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_offset -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_offset += zoom_speed
		camera_offset = clamp(camera_offset, zoom_min, zoom_max)
		
		if not orbiting:
			camera.transform.origin.y = camera_offset

# ... (Az _rotate_camera_fps és _rotate_camera_orbit függvények változatlanok) ...
func _rotate_camera_fps(relative: Vector2):
	rotate_y(deg_to_rad(-relative.x * mouse_sensitivity))
	rotation_x += -relative.y * mouse_sensitivity
	rotation_x = clamp(rotation_x, -90, 90)
	camera.rotation_degrees.x = rotation_x

func _rotate_camera_orbit(relative: Vector2):
	orbit_yaw += deg_to_rad(-relative.x * mouse_sensitivity)
	orbit_pitch += -relative.y * mouse_sensitivity
	orbit_pitch = clamp(orbit_pitch, -80, 80)
	var yaw_rotation = Basis(Vector3.UP, orbit_yaw)
	var pitch_rotation = Basis(Vector3.RIGHT, deg_to_rad(orbit_pitch))
	var combined_rotation = yaw_rotation * pitch_rotation
	var focus_point = global_position + Vector3(0, camera_offset, 0)
	var orbit_direction = Vector3(0, 0, orbit_distance)
	var new_camera_global_position = focus_point + combined_rotation * orbit_direction
	camera.global_position = new_camera_global_position
	camera.look_at(focus_point, Vector3.UP)


# -------------------------
# CASTING FUNCTIONALITY
# -------------------------
func _cast_spell():
	print("--- VARÁZSLAT FÜGGVÉNY ELINDULT ---") 

	# 1. Start casting state and animation
	is_casting = true
	can_cast = false
	_play_animation("Spellcasting")
	cast_animation_timer.start(spell_cast_time)
	
	# 2. Start cooldown
	casting_timer.start(cast_cooldown)

	# 3. Determine spell target and direction (RAYCASTING)
	var mouse_pos = get_viewport().get_mouse_position()
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000)
	query.exclude = [get_rid()] 
	
	var ray_hit = get_world_3d().direct_space_state.intersect_ray(query)

	# 4. Instance the spell and set its direction
	
	if SPELL_SCENE == null:
		print("KRITIKUS HIBA: A SPELL_SCENE NULL (Nincs betöltve)")
		return
	
	var spell_instance = SPELL_SCENE.instantiate()
	
	if spell_instance == null:
		print("KRITIKUS HIBA: AZ INSTANTIATE() NULL-T ADOTT VISSZA.")
		return
	
	print("Lövedék: Instanciálás sikeres.") # <--- EZ A KULCS
	
	# === POZÍCIÓ ELLENŐRZÉS ===
	var spawn_position: Vector3
	
	if spell_spawn_point:
		spawn_position = spell_spawn_point.global_position
		print("Lövedék pozíció: KÉZ (BoneAttachment3D)")
	else:
		spawn_position = global_position + Vector3(0, camera_offset, 0)
		print("Lövedék pozíció: FALLBACK (Közép)")
	
	spell_instance.global_position = spawn_position
	# ===========================

	# Spell direction: Towards the ray hit point, or straight forward if no hit
	if ray_hit:
		spell_instance.direction = (ray_hit.position - spawn_position).normalized()
	else:
		spell_instance.direction = ray_direction.normalized()
	
	# Add the spell to the scene root
	get_tree().root.add_child(spell_instance)
	print("Lövedék: Hozzáadva a jelenetfához. Lövés OK.") # <-- Ezt látnod kell!


# -------------------------
# COOLDOWN/ANIMATION TIMERS
# -------------------------
func _on_cast_cooldown_timeout():
	can_cast = true

func _on_cast_animation_timeout():
	is_casting = false

# -------------------------
# PHYSICS / MOVEMENT
# -------------------------
func _physics_process(delta):
	# Prevent movement while casting
	if is_casting:
		move_and_slide() # Apply gravity
		return # Skip all movement input logic

	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("ui_up"):
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down"):
		input_dir.z += 1
	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()

	# Sprint check
	is_sprinting = Input.is_action_pressed("sprint")
	var current_speed = speed * (sprint_multiplier if is_sprinting else 1.0)

	# Movement relative to player rotation
	var direction = transform.basis * input_dir
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	# Gravity and Jump
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		# Landed
		if is_jumping:
			_play_animation("Jump_Land")
			is_jumping = false
			has_started_jump = false
		velocity.y = 0
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			is_jumping = true
			has_started_jump = false
			_play_animation("Jump_Start")

	move_and_slide()
	
	# -------------------------
	# DINAMIKUS FOV VÁLTÁS LOGIKA (ÚJ KÓD)
	# -------------------------
	var target_fov = BASE_FOV 
	
	if is_sprinting:
		target_fov = sprint_fov 
	
	# Sima átmenet a kamera aktuális FOV-ja felé a cél (cél FOV) és a sebesség alapján
	camera.fov = lerp(camera.fov, target_fov, delta * FOV_LERP_SPEED)
	# -------------------------


	# -------------------------
	# ANIMATION HANDLING
	# -------------------------
	if animation_player:
		# Casting animation has the highest priority
		if is_casting:
			return 

		# Handle jump state next
		if is_jumping:
			if not has_started_jump and not animation_player.is_playing():
				_play_animation("Jump_Idle")
				has_started_jump = true
			return 

		# Movement animations
		if input_dir.length() > 0:
			if is_sprinting:
				_play_animation("Running_A")
			else:
				_play_animation("Walking_A")
		else:
			_play_animation("Idle")

	# -------------------------
	# ANIMATION HANDLING
	# -------------------------
	if animation_player:
		# Casting animation has the highest priority
		if is_casting:
			return 

		# Handle jump state next
		if is_jumping:
			if not has_started_jump and not animation_player.is_playing():
				_play_animation("Jump_Idle")
				has_started_jump = true
			return 

		# Movement animations
		if input_dir.length() > 0:
			if is_sprinting:
				_play_animation("Running_A")
			else:
				_play_animation("Walking_A")
		else:
			_play_animation("Idle")

# -------------------------
# HELPER FUNCTION FOR CLEAN ANIMATION SWITCHING
# -------------------------
func _play_animation(name: String):
	if animation_player and animation_player.current_animation != name:
		animation_player.play(name)
