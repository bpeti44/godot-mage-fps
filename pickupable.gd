extends Node3D
class_name Pickupable

## Marks an object as pickupable and defines what item it gives
## Attach this script to rocks, trees, or other objects that can be picked up

@export var item: Item  ## The item resource this object gives (e.g., stone.tres, wood.tres)
@export var quantity: int = 1  ## How many of the item to give when picked up
@export var display_name: String = ""  ## Display name override (leave empty to use item.item_name)

func _ready():
	# Add to pickupable group for easy raycast detection
	add_to_group("pickupable")

	# If no display name is set, use the item's name
	if display_name == "" and item:
		display_name = item.item_name

func get_display_name() -> String:
	if display_name != "":
		return display_name
	elif item:
		return item.item_name
	else:
		return "Item"

func get_item():
	return item

func get_quantity() -> int:
	return quantity
