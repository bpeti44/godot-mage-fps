extends Control
class_name InventoryUI

## Main inventory UI
## Displays a 3x3 grid of inventory slots

@export var inventory_manager: Node

@onready var grid_container: GridContainer = $Panel/MarginContainer/GridContainer
@onready var panel: Panel = $Panel

const SLOT_UI_SCENE = preload("res://inventory_slot_ui.tscn")

func _ready():
	# Hide by default
	visible = false

	# Setup grid
	grid_container.columns = 3

	# Create 9 slot UI elements
	for i in range(9):
		var slot_ui = create_slot_ui()
		grid_container.add_child(slot_ui)

	# Get inventory manager - look for it in the player node
	if not inventory_manager:
		# We're in Player/CanvasLayer/InventoryUI
		# Manager is at Player/InventoryManager
		var player = get_parent().get_parent()  # Go up to Player
		if player:
			inventory_manager = player.get_node_or_null("InventoryManager")

	# Connect to inventory manager if available
	if inventory_manager:
		inventory_manager.inventory_changed.connect(_on_inventory_changed)

	# Don't update slots here - wait until inventory is opened
	# update_all_slots()

func _input(event):
	# Toggle inventory with I key
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()

func create_slot_ui():
	# Create slot UI programmatically
	var slot_ui = Panel.new()
	slot_ui.custom_minimum_size = Vector2(64, 64)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	slot_ui.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.modulate = Color(1, 1, 1, 1)  # Full white, full opacity
	icon_rect.name = "IconRect"
	vbox.add_child(icon_rect)

	var quantity_label = Label.new()
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	quantity_label.name = "QuantityLabel"
	vbox.add_child(quantity_label)

	# Store references directly on the Panel node
	slot_ui.set_meta("icon_rect", icon_rect)
	slot_ui.set_meta("quantity_label", quantity_label)

	return slot_ui

func toggle_inventory():
	visible = !visible
	print("InventoryUI: Toggle inventory, visible=", visible)

	# Pause/unpause the game when inventory is open
	if visible:
		get_tree().paused = true
		print("InventoryUI: Calling update_all_slots")
		update_all_slots()
	else:
		get_tree().paused = false

func update_all_slots():
	if not inventory_manager:
		print("InventoryUI: No manager")
		return

	# Check if manager is ready (slots initialized)
	if inventory_manager.slots.size() == 0:
		print("InventoryUI: Manager has no slots yet")
		return

	var slot_uis = grid_container.get_children()
	print("InventoryUI: Updating ", slot_uis.size(), " slot UIs")
	for i in range(min(slot_uis.size(), 9)):
		var slot_ui = slot_uis[i]
		var slot_data = inventory_manager.get_slot(i)
		print("  Slot ", i, ": ", slot_data, " empty=", slot_data.is_empty() if slot_data else "null")

		# Get the UI elements from meta
		var icon_rect = slot_ui.get_meta("icon_rect")
		var quantity_label = slot_ui.get_meta("quantity_label")

		# Update the display
		if slot_data == null or slot_data.is_empty():
			icon_rect.texture = null
			quantity_label.text = ""
			slot_ui.modulate = Color(1, 1, 1, 0.5)  # Dimmed when empty
			print("    -> Set as empty")
		else:
			icon_rect.texture = slot_data.item.icon
			if slot_data.item.is_stackable and slot_data.quantity > 1:
				quantity_label.text = str(slot_data.quantity)
			else:
				quantity_label.text = ""
			slot_ui.modulate = Color(1, 1, 1, 1)  # Full opacity when filled
			print("    -> Set item: ", slot_data.item.item_name, " icon=", icon_rect.texture, " qty=", quantity_label.text)

func _on_inventory_changed():
	if visible:
		update_all_slots()
