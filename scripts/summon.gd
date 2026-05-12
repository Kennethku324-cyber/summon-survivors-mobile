extends Node2D

enum State { ORBIT, CHARGE }

var gm: Node2D
var summon_type: int
var level: int = 1
var index: int = 0

var state: int = State.ORBIT
var charge_target: Area2D = null
var charge_speed: float = 600.0

var damage: float = 8.0
var attack_interval: float = 1.5
var attack_range: float = 300.0
var orbit_radius: float = 50.0
var orbit_speed: float = 2.0

var attack_timer: float = 0.0
var pulse_progress: float = -1.0
var angle: float = 0.0
var sprite_ready: bool = false
var audio_player: AudioStreamPlayer2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var magic_circle: Sprite2D = $MagicCircle

var magic_circle_timer: float = 0.0

const TYPE_COLORS = {
	0: Color(1.0, 0.5, 0.0),
	1: Color(0.6, 0.3, 0.1),
	2: Color(0.3, 0.6, 1.0),
	3: Color(1.0, 0.9, 0.1),
}

func initialize(game_manager: Node2D, type: int, lvl: int, idx: int):
	gm = game_manager
	summon_type = type
	level = lvl
	index = idx
	_apply_stats()
	if summon_type == 0 or summon_type == 1 or summon_type == 2 or summon_type == 3:
		_setup_sprite()
	_setup_audio()
	queue_redraw()

func _setup_sprite():
	var frames = SpriteFrames.new()
	var scale_val = 0.263

	match summon_type:
		0: # Flame Spirit
			frames.add_animation("idle")
			var idle_tex = load("res://assets/Fire_Monster/Fire_idle.png")
			if idle_tex:
				frames.add_frame("idle", idle_tex)
			frames.add_animation("walk")
			for i in range(1, 7):
				var tex = load("res://assets/Fire_Monster/Fire_walk/Fire_walk" + str(i) + ".png")
				if tex:
					frames.add_frame("walk", tex)
			frames.add_animation("attack")
			for i in range(1, 4):
				var tex = load("res://assets/Fire_Monster/Fire_Attack/Fire_Attack_" + str(i) + ".png")
				if tex:
					frames.add_frame("attack", tex)
		1: # Golem
			frames.add_animation("idle")
			var idle_tex = load("res://assets/Stone/Stone_idle.png")
			if idle_tex:
				frames.add_frame("idle", idle_tex)
			frames.add_animation("walk")
			for i in range(1, 7):
				var tex = load("res://assets/Stone/Stone_Walk/Stone_Walk_" + str(i) + ".png")
				if tex:
					frames.add_frame("walk", tex)
			frames.add_animation("attack")
			var atk_tex = load("res://assets/Stone/Stone_Attack.png")
			if atk_tex:
				frames.add_frame("attack", atk_tex)
		2: # Frost Mage
			frames.add_animation("idle")
			var idle_tex = load("res://assets/Forzen/Forzen_idle.png")
			if idle_tex:
				frames.add_frame("idle", idle_tex)
			frames.add_animation("walk")
			for i in range(1, 7):
				var tex = load("res://assets/Forzen/Forzen_walk/Forzen_walk_" + str(i) + ".png")
				if tex:
					frames.add_frame("walk", tex)
			frames.add_animation("attack")
			var atk_tex = load("res://assets/Forzen/Forzen_Attack.png")
			if atk_tex:
				frames.add_frame("attack", atk_tex)
		3: # Lightning Totem — Flash
			frames.add_animation("idle")
			var idle_tex = load("res://assets/Flash/Flash_idle.png")
			if idle_tex:
				frames.add_frame("idle", idle_tex)
			frames.add_animation("walk")
			for i in range(1, 7):
				var tex = load("res://assets/Flash/Flash_Walk/Flash_walk_" + str(i) + ".png")
				if tex:
					frames.add_frame("walk", tex)
			frames.add_animation("attack")
			var atk_tex = load("res://assets/Flash/Flash_Attack.png")
			if atk_tex:
				frames.add_frame("attack", atk_tex)
			# Magic circle for AoE attack, scaled to match attack range
			var magic_tex = load("res://assets/Flash/Flash_Magic.png")
			if magic_tex:
				magic_circle.texture = magic_tex
				magic_circle.scale = Vector2(attack_range / 540.0 * 1.3, attack_range / 540.0 * 1.3)

	animated_sprite.sprite_frames = frames
	animated_sprite.scale = Vector2(scale_val, scale_val)
	animated_sprite.play("walk")
	sprite_ready = true

	animated_sprite.animation_finished.connect(_on_sprite_animation_finished)

func _on_sprite_animation_finished():
	if animated_sprite.animation == "attack":
		animated_sprite.play("walk")

func _setup_audio():
	audio_player = AudioStreamPlayer2D.new()
	var path: String
	match summon_type:
		0:
			path = "res://assets/Music/fireball.ogg"
		1:
			path = "res://assets/Music/impact.ogg"
		2:
			path = "res://assets/Music/arrow_shooting.ogg"
		3:
			path = "res://assets/Music/electric_magic.ogg"
		_:
			return
	var stream = load(path)
	if stream:
		audio_player.stream = stream
		add_child(audio_player)

func _apply_stats():
	match summon_type:
		0: # Flame Spirit
			damage = 8 + (level - 1) * 4
			attack_interval = max(0.5, 1.5 - (level - 1) * 0.1)
			attack_range = 300 + (level - 1) * 20
			orbit_radius = 40 + index * 25
			orbit_speed = 2.5
		1: # Golem
			damage = 15 + (level - 1) * 8
			attack_interval = max(0.8, 2.0 - (level - 1) * 0.08)
			attack_range = 25.0
			orbit_radius = 60 + index * 20
			orbit_speed = 1.8
		2: # Frost Mage
			damage = 6 + (level - 1) * 3
			attack_interval = max(0.5, 2.0 - (level - 1) * 0.15)
			attack_range = 400 + (level - 1) * 20
			orbit_radius = 80 + index * 15
			orbit_speed = 2.0
		3: # Lightning Totem
			damage = 12 + (level - 1) * 6
			attack_interval = max(0.6, 2.0 - (level - 1) * 0.1)
			attack_range = 150 + (level - 1) * 15
			orbit_radius = 50 + index * 30
			orbit_speed = 1.2
			if magic_circle.texture:
				var scale_val = attack_range / 540.0
				magic_circle.scale = Vector2(scale_val * 1.3, scale_val * 1.3)

func upgrade(new_level: int):
	level = new_level
	_apply_stats()
	queue_redraw()

func _process(delta):
	if gm.is_game_over or gm.game_paused or gm.level_up_active or not is_instance_valid(gm.player):
		return

	var player = gm.player

	# All summons orbit as base movement
	angle += orbit_speed * delta
	var orbit_pos = player.global_position + Vector2(cos(angle), sin(angle)) * orbit_radius

	match summon_type:
		0, 2, 3: # Flame Spirit, Frost Mage, Lightning Totem — orbit
			global_position = orbit_pos
		1: # Golem — orbit, charge on attack
			match state:
				State.ORBIT:
					global_position = orbit_pos
				State.CHARGE:
					if is_instance_valid(charge_target):
						var dir = (charge_target.global_position - global_position).normalized()
						if sprite_ready:
							animated_sprite.flip_h = dir.x < 0
						global_position += dir * charge_speed * delta
						if global_position.distance_to(charge_target.global_position) <= attack_range + 10:
							if charge_target.has_method("take_damage"):
								charge_target.take_damage(damage)
							if charge_target.has_method("apply_knockback"):
								charge_target.apply_knockback(dir, 300.0)
							if charge_target.has_method("stun"):
								charge_target.stun(0.5)
							state = State.ORBIT
							charge_target = null
							if sprite_ready:
								animated_sprite.play("walk")
					else:
						state = State.ORBIT
						if sprite_ready:
							animated_sprite.play("walk")

	# Attack
	attack_timer += delta
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		_attack()

	# Lightning pulse animation
	if summon_type == 3 and pulse_progress >= 0:
		pulse_progress += delta * 3.0
		if pulse_progress > 1.0:
			pulse_progress = -1.0
		queue_redraw()

	# Magic circle show timer
	if summon_type == 3 and magic_circle.visible:
		magic_circle_timer += delta
		var alpha = 1.0 - magic_circle_timer / 0.5
		magic_circle.modulate = Color(1, 1, 1, clamp(alpha, 0, 1))
		if magic_circle_timer >= 0.5:
			magic_circle.visible = false

func _nearest_enemy() -> Area2D:
	var nearest = null
	var min_dist = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_squared_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e
	return nearest

func _attack():
	match summon_type:
		0: # Flame Spirit — ranged
			var target = _nearest_enemy()
			if target and global_position.distance_to(target.global_position) <= attack_range:
				if sprite_ready:
					animated_sprite.play("attack")
				_spawn_projectile(target)
				if audio_player:
					audio_player.play()
		1: # Golem — charge
			if state == State.ORBIT:
				var target = _nearest_enemy()
				if target and global_position.distance_to(target.global_position) <= 400:
					state = State.CHARGE
					charge_target = target
					if sprite_ready:
						var charge_dir = (target.global_position - global_position).normalized()
						animated_sprite.flip_h = charge_dir.x < 0
						animated_sprite.play("attack")
		2: # Frost Mage — ranged
			var target = _nearest_enemy()
			if target and global_position.distance_to(target.global_position) <= attack_range:
				_spawn_projectile(target)
				if audio_player:
					audio_player.play()
		3: # Lightning Totem — AoE（傷害-50%）
			var aoe_damage = damage * 0.5
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and global_position.distance_to(e.global_position) <= attack_range:
					e.take_damage(aoe_damage)
			# Visual pulse
			pulse_progress = 0.0
			if audio_player:
				audio_player.play()
			queue_redraw()
			# Show magic circle
			if magic_circle.texture:
				magic_circle.visible = true
				magic_circle_timer = 0.0
				magic_circle.modulate = Color(1, 1, 1, 1)

func _spawn_projectile(target):
	var scene = preload("res://scenes/projectile.tscn")
	var proj = scene.instantiate()
	gm.projectile_container.add_child(proj)
	proj.initialize(gm, global_position, target.global_position, damage, summon_type)

func _draw():
	if (summon_type == 0 or summon_type == 2) and sprite_ready:
		return
	var color = TYPE_COLORS.get(summon_type, Color.WHITE)
	match summon_type:
		0: # Flame Spirit
			draw_circle(Vector2.ZERO, 8, color)
			draw_circle(Vector2.ZERO, 5, Color(1, 0.8, 0.3))
		1: # Golem
			draw_rect(Rect2(-10, -10, 20, 20), color)
			draw_rect(Rect2(-7, -7, 14, 14), Color(0.8, 0.5, 0.2))
		2: # Frost Mage
			draw_circle(Vector2.ZERO, 9, color)
			draw_circle(Vector2.ZERO, 6, Color(0.7, 0.8, 1.0))
		3: # Lightning Totem
			if not sprite_ready:
				draw_circle(Vector2.ZERO, 12, color)
				draw_circle(Vector2.ZERO, 8, Color(1, 0.95, 0.5))
			# AoE pulse effect
			if pulse_progress >= 0:
				var pulse_r = attack_range * pulse_progress
				var alpha = 1.0 - pulse_progress
				draw_circle(Vector2.ZERO, pulse_r, Color(1.0, 0.9, 0.1, alpha * 0.25))
				draw_arc(Vector2.ZERO, pulse_r, 0, TAU, 48, Color(1.0, 1.0, 0.5, alpha * 0.6), 2.0)
