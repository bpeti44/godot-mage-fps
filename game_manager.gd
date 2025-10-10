extends Node3D # Vagy a fő jeleneted gyökér csomópontjának típusa (pl. Node3D)

# Előre betöltjük a zombi jelenetet, hogy ne kelljen minden spawnoláskor tölteni
const ZOMBIE_SCENE = preload("res://zombie.tscn")

# Aktív zombikat tároló lista (opcionális, de jó nyomon követni)
var active_zombies: Array = []
var max_zombies: int = 1 # Beállíthatod, hány zombi legyen egyszerre a pályán

# Játékos referencia
var player_target: CharacterBody3D = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# Keressük meg a Playert, és elmentjük a referenciáját
	player_target = get_tree().get_first_node_in_group("player")
	
	if not player_target or not player_target is CharacterBody3D:
		print("FATAL ERROR: Player node not found or not in 'player' group.")
		return # Megállítjuk a scriptet, ha nincs player
	
	# Spawnoljunk egy zombit a játék indulásakor
	spawn_zombie(Vector3(22, 0.5, 0))


func spawn_zombie(position: Vector3):
	# 1. Példányosítjuk a Zombi jelenetet
	var zombie_instance = ZOMBIE_SCENE.instantiate()
	
	# 2. Beállítjuk a pozícióját a pályán
	zombie_instance.global_position = position
	
	# 3. Összekötjük a Zombi halál jelzését a _on_zombie_died függvénnyel (ÚJ)
	# Feltételezzük, hogy a Zombi scriptben a 'signal zombie_died(zombie_position)' definiálva van
	zombie_instance.zombie_died.connect(_on_zombie_died) 
	
	# 4. Beállítjuk a Player referenciát
	zombie_instance.player_target = player_target
	
	# 5. Hozzáadjuk a jelenet fához
	add_child(zombie_instance)
	active_zombies.append(zombie_instance)


# ÚJ FÜGGVÉNY: Ezt hívja meg a Zombi, amikor meghal
func _on_zombie_died(zombie_position: Vector3):
	print("Zombi megölve. Új spawnolása 1 másodperc múlva...")
	
	# Eltávolítjuk a listából az inaktív zombikat (a queue_free() nem távolítja el automatikusan)
	active_zombies.clear() 
	
	# Opcionális késleltetés a respawn előtt (szebb látvány)
	await get_tree().create_timer(1.0).timeout
	
	# Spawnoljunk egy újat a meghalt zombi helyén
	# Ha egyedi spawn helyet akarsz, cseréld le a zombie_position-t egy másik Vector3-ra.
	spawn_zombie(zombie_position)
