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

# -------------------------
# VIEW MODE SETTINGS
# -------------------------
var is_first_person: bool = false
const FP_CAMERA_HEIGHT: float = 2  # Kamera magassága FPS módban (2.5m)
const FP_FORWARD_OFFSET: float = 0.0 # Enyhe eltolás előre (-Z irányba)
const TP_CAMERA_DISTANCE: float = 4.0 # Camera distance in TP mode (Z: 4.0m) 
const TP_BASE_ROTATION_X: float = -10.5 # Default X rotation for TP mode (Downwards tilt)
const VIEW_LERP_SPEED: float = 8.0   # Speed of camera transition between views

# -------------------------
# FOV SETTINGS
# -------------------------
@export var sprint_fov: float = 85.0
const BASE_FOV: float = 75.0
const FOV_LERP_SPEED: float = 5.0 # Speed of FOV change

# -------------------------
# CAMERA SHAKE
# -------------------------
signal hit_registered(shake_duration, shake_intensity) # Signal emitted by Spell.gd on hit
@export var default_shake_duration: float = 0.2
@export var default_shake_intensity: float = 0.1
var shake_timer: float = 0.0
var shake_intensity_current: float = 0.0

# -------------------------
# CASTING & COMBAT VARIABLES
# -------------------------
@export var cast_cooldown: float = 0.5
@export var spell_cast_time: float = 0.5
var is_casting: bool = false
var can_cast: bool = true
var casting_timer: Timer = null
var cast_animation_timer: Timer = null

const SPELL_SCENE = preload("res://spell.tscn") # Ensure this path is correct

# -------------------------
# INTERNAL VARIABLES
# -------------------------
var camera: Camera3D
var rotation_x = 0.0 
var camera_offset: float = 4.384 
var is_sprinting = false
var animation_player: AnimationPlayer = null
var is_jumping = false
var has_started_jump = false

# NODE REFERENCES
var meshes_to_hide: Array[MeshInstance3D] = [] # Lista a rejtendő mesheknek

# ORBIT MODE VARIABLES
var orbiting = false
var orbit_distance = 3.0
var orbit_yaw = 0.0
var orbit_pitch = 0.0

var spell_spawn_point: Node3D = null 


# -------------------------
# READY FUNCTION (INITIALIZATION AND CONNECTIONS)
# -------------------------
func _ready():
	camera = $Camera3D
	camera.transform.origin.y = camera_offset
	camera.transform.origin.z = TP_CAMERA_DISTANCE 
	camera.rotation_degrees.x = TP_BASE_ROTATION_X
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Setup casting timers
	casting_timer = Timer.new()
	add_child(casting_timer)
	casting_timer.one_shot = true
	casting_timer.timeout.connect(_on_cast_cooldown_timeout)
	
	cast_animation_timer = Timer.new()
	add_child(cast_animation_timer)
	cast_animation_timer.one_shot = true
	cast_animation_timer.timeout.connect(_on_cast_animation_timeout)
	
	await get_tree().process_frame
	
	# Find the spell spawn point (BoneAttachment3D)
	spell_spawn_point = $"skeleton_mage/Rig/Skeleton3D/SpellSpawn"
	
	# *** AUTOMATIKUS MESH GYŰJTÉS ÉS KIVÉTELEZÉS ***
	var skeleton_node = $"skeleton_mage/Rig/Skeleton3D"
	var meshes_to_keep: Array[String] = [
		"Skeleton_Mage_ArmLeft", 
		"Skeleton_Mage_ArmRight", 
		"Skeleton_Mage_LegLeft", 
		"Skeleton_Mage_LegRight"
	]

	# Rekurzívan gyűjtjük az összes MeshInstance3D-t
	for child in skeleton_node.get_children():
		# A fejet külön kell kezelni, mert az egy "head" nevű BoneAttachment alatt van
		if child.name == "head" and child is Node:
			for head_child in child.get_children():
				if head_child is MeshInstance3D and head_child.name not in meshes_to_keep:
					meshes_to_hide.append(head_child)
		
		# Minden más, ami a Skeleton3D közvetlen gyereke
		if child is MeshInstance3D and child.name not in meshes_to_keep:
			meshes_to_hide.append(child)
			
	# **************************************************

	# Find the AnimationPlayer
	if has_node("Skeleton_Mage/AnimationPlayer"):
		animation_player = $Skeleton_Mage/AnimationPlayer
	elif has_node("skeleton_mage/AnimationPlayer"):
		animation_player = $skeleton_mage/AnimationPlayer

	if animation_player:
		animation_player.play("Idle")
		
	# Connect the custom signal for camera shake
	hit_registered.connect(start_camera_shake)


# -------------------------
# INPUT HANDLING
# -------------------------
func _unhandled_input(event):
	
	# Toggle View (FP / TP)
	if event.is_action_pressed("toggle_view"):
		is_first_person = not is_first_person
		
		# Rejtés: A korábban összegyűjtött mesheket kapcsoljuk ki/be
		for mesh in meshes_to_hide:
			if mesh:
				# Mutatja TP módban, elrejti FP módban
				mesh.visible = not is_first_person 
			
		# Disable orbit mode when switching to FPS
		if is_first_person:
			orbiting = false
		get_viewport().set_input_as_handled()
		return

	# CASTING INPUT CHECK
	if event.is_action_pressed("fire_spell") and can_cast and not orbiting:
		_cast_spell()
		get_viewport().set_input_as_handled() 
		return 
	
	# Existing Orbit and Mouse Movement Input
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			orbiting = event.pressed
			if orbiting:
				orbit_yaw = rotation.y
				orbit_pitch = rotation_x
			else:
				rotation.y = orbit_yaw
				rotation_x = orbit_pitch
				
				# IMPORTANT: In TP mode, we must restore the base tilt after orbit is disabled
				if not is_first_person:
					camera.rotation_degrees.x = rotation_x + TP_BASE_ROTATION_X
				else:
					camera.rotation_degrees.x = rotation_x
				

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
		
		pass 


func _rotate_camera_fps(relative: Vector2):
	# This rotates the whole player (Y-axis)
	rotate_y(deg_to_rad(-relative.x * mouse_sensitivity))
	
	# This stores the vertical mouse movement
	rotation_x += -relative.y * mouse_sensitivity
	rotation_x = clamp(rotation_x, -90, 90)
	
	# NOTE: camera.rotation_degrees.x is NOT set here.
	# It is set in _physics_process to enable smooth LERP transition and add TP_BASE_ROTATION_X.


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
# CAMERA SHAKE FUNCTIONS
# -------------------------
func start_camera_shake(duration: float, intensity: float):
	shake_timer = duration
	shake_intensity_current = intensity

# -------------------------
# ANIMATION HELPER FUNCTION
# -------------------------
func _play_animation(anim_name: String):
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)

# -------------------------
# CASTING FUNCTIONALITY
# -------------------------
func _cast_spell():
	print("--- SPELL FUNCTION STARTED ---") 

	is_casting = true
	can_cast = false
	_play_animation("Spellcasting")
	cast_animation_timer.start(spell_cast_time)
	
	casting_timer.start(cast_cooldown)

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000)
	query.exclude = [get_rid()] 
	
	var ray_hit = get_world_3d().direct_space_state.intersect_ray(query)

	if SPELL_SCENE == null: return
	
	var spell_instance = SPELL_SCENE.instantiate()
	if spell_instance == null: return
	
	print("Projectile: Instantiation successful.")

	var spawn_position: Vector3
	
	if spell_spawn_point:
		spawn_position = spell_spawn_point.global_position
	else:
		spawn_position = global_position + Vector3(0, camera_offset, 0)
	
	spell_instance.global_position = spawn_position

	if ray_hit:
		spell_instance.direction = (ray_hit.position - spawn_position).normalized()
	else:
		spell_instance.direction = ray_direction.normalized()
	
	get_tree().root.add_child(spell_instance)
	print("Projectile: Added to scene tree. Shot OK.")


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
	# VIEW MODE TRANSITION (FP / TP)
	# -------------------------
	var target_camera_offset_vec: Vector3
	var target_rotation_x_deg: float
	var target_z_offset: float # Distance from the character

	if is_first_person:
		# FP MODE
		target_camera_offset_vec = Vector3(0, FP_CAMERA_HEIGHT, 0)
		target_rotation_x_deg = rotation_x # Vertical mouse look (up/down)
		target_z_offset = FP_FORWARD_OFFSET 
	else:
		# TP MODE
		target_camera_offset_vec = Vector3(0, camera_offset, 0)
		target_rotation_x_deg = rotation_x + TP_BASE_ROTATION_X # Add base tilt (-10.5 deg)
		target_z_offset = TP_CAMERA_DISTANCE 
	
	# Smoothly transition camera position (Y offset)
	camera.transform.origin.y = lerp(camera.transform.origin.y, target_camera_offset_vec.y, delta * VIEW_LERP_SPEED)
	
	# Smoothly transition Z position (distance)
	camera.transform.origin.z = lerp(camera.transform.origin.z, target_z_offset, delta * VIEW_LERP_SPEED)
	
	# Smoothly transition X rotation (pitch)
	camera.rotation_degrees.x = lerp(camera.rotation_degrees.x, target_rotation_x_deg, delta * VIEW_LERP_SPEED)
	# -------------------------
	
	# -------------------------
	# DYNAMIC FOV SWITCH
	# -------------------------
	var target_fov = BASE_FOV 
	
	if is_sprinting:
		target_fov = sprint_fov 
	
	camera.fov = lerp(camera.fov, target_fov, delta * FOV_LERP_SPEED)
	# -------------------------
	
	# -------------------------
	# CAMERA SHAKE APPLICATION
	# -------------------------
	if shake_timer > 0:
		shake_timer -= delta
		
		var shake_offset = Vector3.ZERO
		shake_offset.x = randf_range(-shake_intensity_current, shake_intensity_current)
		shake_offset.y = randf_range(-shake_intensity_current, shake_intensity_current)
		
		# Apply offset (adds to the existing camera origin)
		camera.transform.origin.x += shake_offset.x * (shake_timer / default_shake_duration)
		camera.transform.origin.y += shake_offset.y * (shake_timer / default_shake_duration)
	else:
		# If no shake, smoothly return X origin to 0.0
		if abs(camera.transform.origin.x) > 0.01:
			camera.transform.origin.x = lerp(camera.transform.origin.x, 0.0, delta * 10.0)
		# The Y origin is already handled by the view transition logic above
		

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
