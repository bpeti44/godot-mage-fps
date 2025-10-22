extends Resource
class_name InventorySlot

## Represents a single slot in the inventory
## Can hold an item and track its quantity

var item = null
var quantity: int = 0

func _init(p_item = null, p_quantity: int = 0):
	item = p_item
	quantity = p_quantity

## Check if the slot is empty
func is_empty() -> bool:
	return item == null or quantity <= 0

## Check if we can add more of this item
func can_add(p_item, amount: int = 1) -> bool:
	if is_empty():
		return true
	if item == p_item and item.is_stackable:
		return quantity + amount <= item.max_stack_size
	return false

## Add items to this slot
## Returns the amount that couldn't be added (overflow)
func add_item(p_item, amount: int = 1) -> int:
	if is_empty():
		item = p_item
		quantity = min(amount, p_item.max_stack_size)
		return max(0, amount - quantity)

	if item == p_item and item.is_stackable:
		var space_left = item.max_stack_size - quantity
		var amount_to_add = min(amount, space_left)
		quantity += amount_to_add
		return amount - amount_to_add

	return amount  # Can't add, return all

## Remove items from this slot
## Returns the amount actually removed
func remove_item(amount: int = 1) -> int:
	if is_empty():
		return 0

	var removed = min(amount, quantity)
	quantity -= removed

	if quantity <= 0:
		clear()

	return removed

## Clear the slot
func clear():
	item = null
	quantity = 0
