extends Resource
class_name Item

## Base item class for inventory system
## Represents any item that can be stored in the player's inventory

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var max_stack_size: int = 99
@export var is_stackable: bool = true

## Item types for future categorization
enum ItemType {
	RESOURCE,  # Materials like wood, stone
	CONSUMABLE,  # Potions, food
	WEAPON,  # Swords, staffs
	MISC  # Other items
}

@export var item_type: ItemType = ItemType.RESOURCE
