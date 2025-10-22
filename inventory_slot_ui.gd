extends Panel
class_name InventorySlotUI

## UI component for a single inventory slot
## Displays the item icon and quantity

var slot_index: int = -1
var slot_data = null

var icon_rect: TextureRect = null
var quantity_label: Label = null
var initialized: bool = false

func _ready():
	custom_minimum_size = Vector2(64, 64)
	_initialize_nodes()

func _initialize_nodes():
	if initialized:
		return
	# Get references to child nodes
	icon_rect = get_node_or_null("MarginContainer/VBoxContainer/IconRect")
	quantity_label = get_node_or_null("MarginContainer/VBoxContainer/QuantityLabel")
	if icon_rect != null and quantity_label != null:
		initialized = true
		update_display()

## Update the visual display of this slot
func update_display():
	if icon_rect == null or quantity_label == null:
		return

	if slot_data == null or slot_data.is_empty():
		icon_rect.texture = null
		quantity_label.text = ""
		modulate = Color(1, 1, 1, 0.5)  # Dimmed when empty
	else:
		icon_rect.texture = slot_data.item.icon
		if slot_data.item.is_stackable and slot_data.quantity > 1:
			quantity_label.text = str(slot_data.quantity)
		else:
			quantity_label.text = ""
		modulate = Color(1, 1, 1, 1)  # Full opacity when filled

## Set the slot data and update display
func set_slot(p_slot_data, index: int):
	slot_data = p_slot_data
	slot_index = index
	_initialize_nodes()
	update_display()
