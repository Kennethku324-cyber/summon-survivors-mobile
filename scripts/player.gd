extends Area2D

var gm: Node2D
var speed: float = 300.0
var invulnerable: bool = false
var inv_time: float = 0.5
var sprite_ready: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	_setup_sprite()

func _setup_sprite():
	var frames = SpriteFrames.new()

	frames.add_animation("idle")
	var idle_tex = load("res://assets/Main_Charactor/idle.png")
	if idle_tex:
		frames.add_frame("idle", idle_tex)

	frames.add_animation("walk")
	for i in range(1, 7):
		var tex = load("res://assets/Main_Charactor/walk_cycle/" + str(i) + ".png")
		if tex:
			frames.add_frame("walk", tex)

	animated_sprite.sprite_frames = frames
	animated_sprite.scale = Vector2(0.246, 0.246)
	animated_sprite.play("idle")
	sprite_ready = true

func initialize(game_manager: Node2D):
	gm = game_manager

func _process(delta):
	if not gm or gm.is_game_over or gm.game_paused or gm.level_up_active:
		return
	var input = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input.length() > 0:
		input = input.normalized()
		if sprite_ready:
			animated_sprite.play("walk")
			animated_sprite.speed_scale = 4.0
			if input.x < 0:
				animated_sprite.flip_h = true
			elif input.x > 0:
				animated_sprite.flip_h = false
	else:
		if sprite_ready:
			animated_sprite.play("idle")
			animated_sprite.speed_scale = 1.0

	if input.length() > 0:
		var movement = input * speed * delta
		var new_pos = global_position + movement
		if gm and gm.has_method("is_walkable"):
			if gm.is_walkable(new_pos):
				global_position = new_pos
			else:
				var x_move = Vector2(new_pos.x, global_position.y)
				var y_move = Vector2(global_position.x, new_pos.y)
				if gm.is_walkable(x_move):
					global_position.x = x_move.x
				elif gm.is_walkable(y_move):
					global_position.y = y_move.y
		else:
			global_position = new_pos
	_clamp_to_view()

func _on_area_entered(area: Area2D):
	if area.is_in_group("enemies") and not invulnerable and gm and not gm.is_game_over:
		var enemy_damage = area.get("damage")
		if enemy_damage != null:
			gm.damage_player(enemy_damage)
		else:
			gm.damage_player(10)
		invulnerable = true
		modulate = Color(1, 0.4, 0.4)
		if has_node("FlashTimer"):
			$FlashTimer.start(inv_time)
		else:
			await get_tree().create_timer(inv_time).timeout
			modulate = Color.WHITE
			invulnerable = false

func end_invulnerable():
	modulate = Color.WHITE
	invulnerable = false

func _clamp_to_view():
	if not gm or not is_instance_valid(gm.camera):
		return
	var vp = get_viewport().get_visible_rect().size
	var half = vp / 2.0 / gm.camera.zoom
	var cam = gm.camera
	var margin = 16.0
	global_position.x = clamp(global_position.x, cam.global_position.x - half.x + margin, cam.global_position.x + half.x - margin)
	global_position.y = clamp(global_position.y, cam.global_position.y - half.y + margin, cam.global_position.y + half.y - margin)
