extends Area3D

signal collected

func _ready():
	# ha a Player belép a colliderbe
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.name == "Player": # vagy ha group-ot adsz neki, akkor group check is lehet
		emit_signal("collected")
		queue_free() # eltűnik a pickup
