extends Area2D

var gm: Node2D
var velocity: Vector2
var damage: float = 10.0
var speed: float = 400.0
var lifetime: float = 3.0
var summon_type: int = 0  # For visual variety
var age: float = 0.0
var sprite_ready: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func initialize(game_manager: Node2D, from: Vector2, to: Vector2, dmg: float, stype: int):
	gm = game_manager
	damage = dmg
	summon_type = stype
	global_position = from
	var dir = (to - from).normalized()
	velocity = dir * speed
	add_to_group("projectiles")
	rotation = dir.angle()

	# Visual variety
	match stype:
		0: # Fireball
			_setup_fireball_sprite()
		1: # Golem swing (melee, shouldn't be spawned)
			modulate = Color(0.6, 0.3, 0.1)
		2: # Ice bolt
			_setup_arrow_sprite()
		3: # Lightning
			modulate = Color(1.0, 0.9, 0.1)

func _setup_arrow_sprite():
	var tex = load("res://assets/Forzen/Forzen_Arrow.png")
	if tex:
		sprite.texture = tex
		sprite.scale = Vector2(0.21, 0.21)
		sprite_ready = true

func _setup_fireball_sprite():
	var tex = load("res://assets/FireBall.png")
	if tex:
		sprite.texture = tex
		sprite.scale = Vector2(0.21, 0.21)
		sprite_ready = true

func _process(delta):
	if gm and (gm.is_game_over or gm.game_paused or gm.level_up_active):
		return
	age += delta
	global_position += velocity * delta
	if age > lifetime:
		queue_free()

func _draw():
	if sprite_ready and (summon_type == 0 or summon_type == 2):
		return
	match summon_type:
		0: # Fireball
			draw_circle(Vector2.ZERO, 7, Color(1.0, 0.4, 0.0))
			draw_circle(Vector2.ZERO, 4, Color(1.0, 0.8, 0.2))
		1: # Melee swing (shouldn't normally spawn)
			draw_circle(Vector2.ZERO, 5, Color(0.6, 0.3, 0.1))
		2: # Ice bolt
			draw_circle(Vector2.ZERO, 7, Color(0.3, 0.7, 1.0))
			draw_circle(Vector2.ZERO, 4, Color(0.7, 0.9, 1.0))
			draw_circle(Vector2.ZERO, 2, Color(1.0, 1.0, 1.0))
		3: # Lightning
			draw_circle(Vector2.ZERO, 7, Color(1.0, 0.9, 0.1))
			draw_circle(Vector2.ZERO, 4, Color(1.0, 1.0, 0.6))

func _on_area_entered(area: Area2D):
	if area.is_in_group("enemies"):
		var dmg = damage
		var stype = summon_type
		call_deferred("_apply_damage", area, dmg, stype)


func _apply_damage(area: Area2D, dmg: float, stype: int):
	if not is_instance_valid(area):
		return
	if area.has_method("take_damage"):
		area.take_damage(dmg)
	if stype == 2 and is_instance_valid(area):
		area.speed *= 0.9  # 永久減速 10%
	queue_free()
