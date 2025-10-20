extends Control

@onready var minimap_texture: TextureRect = $MinimapContainer/MinimapTexture
@onready var player_marker: Polygon2D = $PlayerMarker
@onready var sub_viewport: SubViewport = $SubViewport
@onready var map_camera: Camera3D = $SubViewport/MapCamera
@onready var minimap_container: PanelContainer = $MinimapContainer

var player: CharacterBody3D = null
var map_size: Vector2 = Vector2(200, 200)  # World size from ProceduralForestGenerator
var world_offset: Vector2 = Vector2(-100, -100)  # World offset

# Minimap settings
var minimap_small_size: Vector2 = Vector2(200, 200)
var minimap_large_size: Vector2 = Vector2(600, 600)
var is_large_map: bool = false

func _ready():
	# Set minimap texture to SubViewport's texture
	minimap_texture.texture = sub_viewport.get_texture()

	# Find player in scene
	await get_tree().process_frame  # Wait one frame for player to be ready
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		push_warning("Minimap: Player not found in 'player' group!")

func _process(_delta):
	if player:
		_update_camera_position()
		_update_player_marker()

func _update_camera_position():
	# Position camera above player
	var player_pos = player.global_position
	map_camera.global_position = Vector3(player_pos.x, 100, player_pos.z)

func _update_player_marker():
	# Calculate player position on minimap (center of MinimapContainer within the Minimap Control)
	var minimap_center = minimap_container.position + minimap_container.size / 2.0
	player_marker.position = minimap_center

	# Rotate marker based on player rotation (triangle points forward)
	player_marker.rotation = -player.rotation.y

func _input(event):
	if event.is_action_pressed("toggle_map"):
		_toggle_map_size()

func _toggle_map_size():
	is_large_map = !is_large_map

	if is_large_map:
		# Large fullscreen map
		position = Vector2(get_viewport().size.x / 2 - minimap_large_size.x / 2,
		                   get_viewport().size.y / 2 - minimap_large_size.y / 2)
		size = minimap_large_size
		sub_viewport.size = Vector2i(int(minimap_large_size.x), int(minimap_large_size.y))
		map_camera.size = 220.0  # Larger view for full map

		# Show mouse cursor and pause player input
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if player:
			player.set_process_input(false)
	else:
		# Small minimap in corner
		position = Vector2(get_viewport().size.x - 220, 20)
		size = minimap_small_size
		sub_viewport.size = Vector2i(int(minimap_small_size.x), int(minimap_small_size.y))
		map_camera.size = 100.0  # Smaller zoom for minimap

		# Capture mouse and resume player input
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if player:
			player.set_process_input(true)
