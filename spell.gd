# spell.gd
extends Area3D

@export var speed: float = 20.0 # Movement speed of the spell
@export var damage: int = 30    # Damage value to be dealt on hit
@export var lifetime: float = 3.0 # Duration before the spell despawns

var direction: Vector3 = Vector3.FORWARD # Set by the Player's _cast_spell() function

func _ready():
	# Csatlakoztatjuk a body_entered jelet.
	body_entered.connect(_on_body_entered)
	
	# Időzítő indítása az élettartamhoz (Mivel a Timer node létezik, ez futni fog)
	var timer_node = $Timer
	if timer_node:
		timer_node.start(lifetime)
	
	# KRITIKUS FIX: Az azonnali ütközés elkerülése a Playerrel.
	
	# 1. Kikapcsoljuk az Area3D monitorozását (így nem érzékel ütközést).
	monitoring = false
	
	# 2. Várjunk egy rövid időt (pl. 0.05 másodperc), amíg a lövedék elindul.
	# Godot 4-ben ez a legjobb módszer kis késleltetésre.
	await get_tree().create_timer(0.05).timeout
	
	# 3. Visszakapcsoljuk az Area3D monitorozását. Innentől kezdve érzékelni fogja az ütközéseket.
	monitoring = true 
	

func _physics_process(delta):
	# Move the spell in its set direction (linear movement)
	global_position += direction * speed * delta

# SIGNAL HANDLER: Called when the Area3D enters another Body (CharacterBody3D, RigidBody3D, etc.)
func _on_body_entered(body: Node3D):
	# Ellenőrzi, hogy az eltalált test a "zombie" csoporthoz tartozik-e.
	# Ez a kulcs a sebzés kiosztásához.
	if body.is_in_group("zombie"):
		# Győződj meg róla, hogy a test rendelkezik take_damage metódussal (biztonsági ellenőrzés)
		if body.has_method("take_damage"):
			# Sebzés kiosztása a zombin
			body.take_damage(damage)
	
	# Despawn the spell upon hitting ANYTHING (zombie, wall, ground)
	queue_free()

# SIGNAL HANDLER: Called when the Timer runs out
func _on_Timer_timeout():
	# Despawn the spell after its lifetime expires, if it hasn't hit anything yet
	queue_free()
