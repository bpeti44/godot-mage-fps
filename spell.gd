extends Area3D

@export var speed: float = 20.0 # Movement speed of the spell
@export var damage: int = 30	# Damage value to be dealt on hit
@export var lifetime: float = 3.0 # Duration before the spell despawns

var direction: Vector3 = Vector3.FORWARD # Set by the Player's _cast_spell() function
var player_node: Node # Referencia a Player node-hoz

# SIGNAL deklarálása a Camera Shake-hez (Player.gd fogadja)
# Mivel Area3D-t használunk, a player_node-ra kell emit-elnünk, ahogy a kódodban volt, de 
# egy SIGNAL deklarációt is érdemes lehet felvenni a script elejére, ha a Player.gd a jelet fogadja.
# Megtartjuk az eredeti _emit_camera_shake_signal() hívást a tisztaság érdekében.


func _ready():
	# Csatlakoztatjuk a body_entered jelet.
	body_entered.connect(_on_body_entered)
	
	# Megpróbáljuk megtalálni a Player node-ot a 'Player' csoport alapján
	player_node = get_tree().get_first_node_in_group("player")
	
	# Időzítő indítása az élettartamhoz (Feltételezzük, hogy a Timer node létezik)
	var timer_node = $Timer
	if timer_node:
		timer_node.start(lifetime)
	
	# KRITIKUS FIX: Az azonnali ütközés elkerülése a Playerrel.
	
	# 1. Kikapcsoljuk az Area3D monitorozását (így nem érzékel ütközést).
	monitoring = false
	
	# 2. Várjunk egy rövid időt (pl. 0.05 másodperc), amíg a lövedék elindul.
	await get_tree().create_timer(0.05).timeout
	
	# 3. Visszakapcsoljuk az Area3D monitorozását. Innentől kezdve érzékelni fogja az ütközéseket.
	monitoring = true
	

func _physics_process(delta):
	# Move the spell in its set direction (linear movement)
	global_position += direction * speed * delta

# SIGNAL HANDLER: Called when the Area3D enters another Body
func _on_body_entered(body: Node3D):
	
	# Ellenőrizzük, hogy az eltalált test a "zombie" csoporthoz tartozik-e.
	if body.is_in_group("zombie"):
		if body.has_method("take_damage"):
			
			# KNOCKBACK LOGIKA (ÚJ): Kiszámoljuk az ütés irányát
			var hit_direction = (body.global_position - global_position).normalized() 
			
			# Sebzés kiosztása a zombin (MÓDOSÍTVA: átadjuk a hit_direction-t!)
			body.take_damage(damage, hit_direction) # <--- IDE KERÜLT A VÁLTOZTATÁS!
	
	# *** CAMERA SHAKE AKTIVÁLÁS ***
	_emit_camera_shake_signal()

	# Despawn the spell upon hitting ANYTHING (zombie, wall, ground)
	queue_free()

# SIGNAL HANDLER: Called when the Timer runs out
func _on_Timer_timeout():
	# Despawn the spell after its lifetime expires, if it hasn't hit anything yet
	queue_free()

# -------------------------
# CAMERA SHAKE SIGNAL EMISSION
# -------------------------
func _emit_camera_shake_signal():
	# Ellenőrizzük, hogy a player node létezik, és be van-e állítva a jelzés fogadása (start_camera_shake metódus)
	if player_node and player_node.has_method("start_camera_shake"):
		# Kibocsátjuk a hit_registered signal-t, amit a Player.gd kezel
		# Az értékek: ( 0.2 másodperc időtartam, 0.3 intenzitás )
		player_node.emit_signal("hit_registered", 0.2, 0.3)
