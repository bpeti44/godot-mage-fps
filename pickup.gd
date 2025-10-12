extends Area3D

signal collected

func _ready():
	# If the Player enters the collider
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.name == "Player": # Or you can use a group check if you assign it to a group
		emit_signal("collected")
		queue_free() # The pickup disappears
