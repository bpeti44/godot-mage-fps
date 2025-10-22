extends Node
class_name InventoryManager

## Manages the player's inventory
## Handles adding, removing, and organizing items in a 3x3 grid

signal inventory_changed
signal item_added(item, quantity)
signal item_removed(item, quantity)

const INVENTORY_SIZE = 9  # 3x3 grid
const InventorySlotScript = preload("res://inventory_slot.gd")

var slots: Array = []

func _ready():
	# Initialize 9 empty slots
	for i in range(INVENTORY_SIZE):
		slots.append(InventorySlotScript.new())

## Add an item to the inventory
## Returns true if the item was fully added, false if it couldn't fit
func add_item(item, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false

	var remaining = quantity

	# First, try to add to existing stacks
	if item.is_stackable:
		for slot in slots:
			if not slot.is_empty() and slot.item == item:
				remaining = slot.add_item(item, remaining)
				if remaining <= 0:
					item_added.emit(item, quantity)
					inventory_changed.emit()
					return true

	# Then, try to add to empty slots
	for slot in slots:
		if slot.is_empty():
			remaining = slot.add_item(item, remaining)
			if remaining <= 0:
				item_added.emit(item, quantity)
				inventory_changed.emit()
				return true

	# If we still have items left, we couldn't fit everything
	if remaining < quantity:
		item_added.emit(item, quantity - remaining)
		inventory_changed.emit()

	return remaining == 0

## Remove an item from the inventory
## Returns the amount actually removed
func remove_item(item, quantity: int = 1) -> int:
	if item == null or quantity <= 0:
		return 0

	var total_removed = 0
	var remaining = quantity

	# Remove from slots that contain this item
	for slot in slots:
		if not slot.is_empty() and slot.item == item:
			var removed = slot.remove_item(remaining)
			total_removed += removed
			remaining -= removed

			if remaining <= 0:
				break

	if total_removed > 0:
		item_removed.emit(item, total_removed)
		inventory_changed.emit()

	return total_removed

## Get the total quantity of an item in the inventory
func get_item_count(item) -> int:
	if item == null:
		return 0

	var count = 0
	for slot in slots:
		if not slot.is_empty() and slot.item == item:
			count += slot.quantity

	return count

## Check if the inventory has at least the specified quantity of an item
func has_item(item, quantity: int = 1) -> bool:
	return get_item_count(item) >= quantity

## Get a slot by index (0-8 for 3x3 grid)
func get_slot(index: int):
	if index >= 0 and index < INVENTORY_SIZE:
		return slots[index]
	return null

## Clear the entire inventory
func clear_inventory():
	for slot in slots:
		slot.clear()
	inventory_changed.emit()

## Check if the inventory is full
func is_full() -> bool:
	for slot in slots:
		if slot.is_empty():
			return false
	return true
