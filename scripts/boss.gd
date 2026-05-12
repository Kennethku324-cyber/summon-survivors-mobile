extends Area2D

var gm: Node2D
var speed: float = 80.0
var hp: float = 20.0
var max_hp: float = 20.0
var damage: float = 10.0
var xp_value: int = 10

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_friction: float = 0.82

var stun_timer: float = 0.0
var sprite_ready: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func initialize(game_manager: Node2D, difficulty: float, speed_mult: float = 1.0):
	gm = game_manager
	add_to_group("enemies")
	speed = lerp(80.0, 200.0, difficulty) * speed_mult
	hp = lerp(20.0, 80.0, difficulty)
	hp *= pow(1.3, gm.player_level - 1)
	max_hp = hp
	damage = lerp(10.0, 30.0, difficulty)
	xp_value = int(lerp(10, 30, difficulty))
	_setup_sprite()

func _setup_sprite():
	var frames = SpriteFrames.new()

	frames.add_animation("walk")
	for i in range(1, 7):
		var tex = load("res://assets/GoblinBoss/GoblinBoss_walk/GoblinBoss_walk_" + str(i) + ".png")
		if tex:
			frames.add_frame("walk", tex)

	frames.add_animation("hurt")
	var hurt_tex = load("res://assets/GoblinBoss/GoblinBoss_hurt.png")
	if hurt_tex:
		frames.add_frame("hurt", hurt_tex)

	animated_sprite.sprite_frames = frames
	animated_sprite.scale = Vector2(0.5, 0.5)
	animated_sprite.play("walk")
	sprite_ready = true

func stun(duration: float):
	stun_timer = duration
	knockback_velocity = Vector2.ZERO
	if sprite_ready:
		animated_sprite.play("hurt")

func _process(delta):
	if gm.is_game_over or gm.game_paused or gm.level_up_active:
		return

	# Stun
	if stun_timer > 0:
		stun_timer -= delta
		if stun_timer <= 0 and sprite_ready:
			animated_sprite.play("walk")
		return  # Don't move or chase while stunned

	# Apply knockback with friction
	if knockback_velocity.length_squared() > 1.0:
		global_position += knockback_velocity * delta
		knockback_velocity *= knockback_friction
	else:
		knockback_velocity = Vector2.ZERO

	# Move toward player
	var target = gm.player
	if is_instance_valid(target):
		var dir = (target.global_position - global_position).normalized()
		var movement = dir * speed * delta
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
		if sprite_ready:
			animated_sprite.flip_h = dir.x < 0

func apply_knockback(dir: Vector2, force: float):
	knockback_velocity = dir * force

func take_damage(amount: float):
	hp -= amount
	modulate = Color(1.5, 0.5, 0.5)
	if hp <= 0:
		die()
	else:
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self):
			modulate = Color.WHITE

func _draw():
	if sprite_ready:
		return
	draw_circle(Vector2.ZERO, 18, Color(0.8, 0.2, 0.2))
	draw_circle(Vector2.ZERO, 13, Color(1.0, 0.3, 0.3))
	# Eyes
	draw_circle(Vector2(-6, -5), 3, Color(1, 1, 1))
	draw_circle(Vector2(6, -5), 3, Color(1, 1, 1))

func die():
	# 30% chance to drop heart
	if randf() < 0.3:
		var heart_scene = preload("res://scenes/heart.tscn")
		var heart = heart_scene.instantiate()
		heart.initialize(gm)
		heart.global_position = global_position
		gm.xp_container.add_child(heart)
	var scene = preload("res://scenes/experience_gem.tscn")
	var gem = scene.instantiate()
	gem.initialize(gm, xp_value)
	gem.global_position = global_position
	gm.xp_container.add_child(gem)
	call_deferred("queue_free")
