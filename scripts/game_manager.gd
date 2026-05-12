extends Node2D

enum SummonType { FLAME_SPIRIT, GOLEM, FROST_MAGE, LIGHTNING_TOTEM }
enum UpgradeType { NEW_SUMMON, UPGRADE_SUMMON, DUPLICATE_SUMMON }
enum Difficulty { STANDARD, EASY, HARD, INDIA }

const SUMMON_NAMES = {
	SummonType.FLAME_SPIRIT: "火焰精靈",
	SummonType.GOLEM: "石魔像",
	SummonType.FROST_MAGE: "冰霜法師",
	SummonType.LIGHTNING_TOTEM: "閃電圖騰"
}

const SUMMON_DESC = {
	SummonType.FLAME_SPIRIT: "環繞飛行\n自動射擊火球",
	SummonType.GOLEM: "近戰衝鋒\n撞擊敵人",
	SummonType.FROST_MAGE: "遠程冰箭\n減速效果",
	SummonType.LIGHTNING_TOTEM: "範圍雷擊\n脈衝傷害"
}

const PLAYER_MAX_HP = 100.0
const BASE_SPAWN_INTERVAL = 1.5
const DIFFICULTY_RAMP_TIME = 600.0
const XP_TO_LEVEL_BASE = 15
const XP_TO_LEVEL_SCALE = 1.25

const DIFFICULTY_NAMES = {
	Difficulty.STANDARD: "標準",
	Difficulty.EASY: "簡單",
	Difficulty.HARD: "高難度",
	Difficulty.INDIA: "印度"
}

const DIFFICULTY_DESC = {
	Difficulty.STANDARD: "正常敵人數量\n正常敵人速度",
	Difficulty.EASY: "敵人數量 -30%\n正常敵人速度",
	Difficulty.HARD: "敵人數量 +50%\n正常敵人速度",
	Difficulty.INDIA: "敵人數量 +50%\n敵人速度 +30%"
}

const BASE_W = 1152
const BASE_H = 648

var player: Area2D
var player_hp: float
var player_max_hp: float
var player_level: int = 1
var player_xp: int = 0
var xp_to_next_level: int
var game_time: float = 0.0
var is_game_over: bool = false
var game_paused: bool = false
var level_up_active: bool = false
var active_summons: Array = []
var summon_counts: Dictionary = {}
var summon_levels: Dictionary = {}
var enemy_count_mult: float = 1.0
var music_muted: bool = false

var current_difficulty: int = Difficulty.STANDARD
var enemy_speed_mult: float = 1.0
var walkable_img: Image

var enemy_container: Node2D
var xp_container: Node2D
var projectile_container: Node2D
var summon_container: Node2D

var xp_bar: ColorRect
var hp_bar: ColorRect
var level_label: Label
var time_label: Label
var music_toggle_btn: Button
var pause_btn: Button
var pause_overlay: Control
var enemy_mult_label: Label
var game_over_panel: Control
var level_up_panel: Control
var difficulty_select_panel: Control
var hud_canvas: CanvasLayer
var hud_root: Control
var custom_theme: Theme
var hud_ready: bool = false

@onready var camera: Camera2D = $Camera2D
@onready var spawn_timer: Timer = $SpawnTimer
@onready var music_player: AudioStreamPlayer = $MusicPlayer

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	randomize()
	_create_containers()
	_load_walkable_map()
	_create_hud()
	_show_difficulty_select()
	hud_ready = true

func _create_containers():
	enemy_container = Node2D.new()
	enemy_container.name = "Enemies"
	add_child(enemy_container)
	xp_container = Node2D.new()
	xp_container.name = "XP Gems"
	add_child(xp_container)
	projectile_container = Node2D.new()
	projectile_container.name = "Projectiles"
	add_child(projectile_container)
	summon_container = Node2D.new()
	summon_container.name = "Summons"
	add_child(summon_container)

func _create_hud():
	hud_canvas = CanvasLayer.new()
	var canvas = hud_canvas
	canvas.layer = 10
	canvas.process_mode = PROCESS_MODE_ALWAYS
	add_child(canvas)

	hud_root = Control.new()
	canvas.add_child(hud_root)

	# Load Chinese font for all UI text in the HUD
	var noto_font = load("res://assets/fonts/NotoSansTC-Regular.ttf")
	if noto_font:
		custom_theme = Theme.new()
		custom_theme.set_font("font", "Label", noto_font)
		custom_theme.set_font("font", "Button", noto_font)
		hud_root.theme = custom_theme

	# Position HUD elements relative to viewport
	var vp_size = get_viewport().get_visible_rect().size
	hud_root.position = Vector2(0, 0)
	hud_root.size = vp_size
	var margin = 16
	var bar_w = 200
	var bar_h = 20
	var sw = vp_size.x
	var sh = vp_size.y

	# HP bar
	var hp_bg = ColorRect.new()
	hp_bg.size = Vector2(bar_w, bar_h)
	hp_bg.position = Vector2(margin, margin)
	hp_bg.color = Color(0.3, 0.1, 0.1)
	hud_root.add_child(hp_bg)
	hp_bar = ColorRect.new()
	hp_bar.size = Vector2(bar_w, bar_h)
	hp_bar.position = Vector2(margin, margin)
	hp_bar.color = Color(0.9, 0.2, 0.2)
	hp_bar.name = "HPBar"
	hud_root.add_child(hp_bar)

	# XP bar
	var xp_bg = ColorRect.new()
	xp_bg.size = Vector2(bar_w, bar_h)
	xp_bg.position = Vector2(margin, margin + bar_h + 4)
	xp_bg.color = Color(0.1, 0.1, 0.3)
	hud_root.add_child(xp_bg)
	xp_bar = ColorRect.new()
	xp_bar.size = Vector2(bar_w, bar_h)
	xp_bar.position = Vector2(margin, margin + bar_h + 4)
	xp_bar.color = Color(0.2, 0.4, 0.9)
	xp_bar.name = "XPBar"
	hud_root.add_child(xp_bar)

	# Level label
	level_label = Label.new()
	level_label.position = Vector2(margin + bar_w + 8, margin)
	level_label.add_theme_font_size_override("font_size", 23)
	level_label.text = "等級 1"
	hud_root.add_child(level_label)

	# Enemy mult label
	enemy_mult_label = Label.new()
	enemy_mult_label.position = Vector2(margin + bar_w + 8, margin + bar_h + 4)
	enemy_mult_label.add_theme_font_size_override("font_size", 18)
	enemy_mult_label.text = ""
	hud_root.add_child(enemy_mult_label)

	# Time label
	time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.position = Vector2(sw/2 - 100, margin)
	time_label.size = Vector2(200, 24)
	time_label.add_theme_font_size_override("font_size", 51)
	time_label.text = "0:00"
	hud_root.add_child(time_label)

	# Music toggle button
	music_toggle_btn = Button.new()
	music_toggle_btn.text = "♪"
	music_toggle_btn.add_theme_font_size_override("font_size", 28)
	music_toggle_btn.position = Vector2(sw - 16 - 50, 16)
	music_toggle_btn.size = Vector2(50, 50)
	music_toggle_btn.toggled.connect(_toggle_music)
	music_toggle_btn.toggle_mode = true
	hud_root.add_child(music_toggle_btn)

	# Pause button
	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.add_theme_font_size_override("font_size", 28)
	pause_btn.position = Vector2(sw - 16 - 50 - 50 - 8, 16)
	pause_btn.size = Vector2(50, 50)
	pause_btn.process_mode = PROCESS_MODE_ALWAYS
	pause_btn.pressed.connect(_toggle_pause)
	hud_root.add_child(pause_btn)

	# Pause overlay
	pause_overlay = Control.new()
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(pause_overlay)
	var p_bg = ColorRect.new()
	p_bg.color = Color(0, 0, 0, 0.6)
	p_bg.size = Vector2(sw, sh)
	p_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(p_bg)
	var p_label = Label.new()
	p_label.text = "暫停"
	p_label.add_theme_font_size_override("font_size", 72)
	p_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_label.position = Vector2(sw/2 - 150, sh/2 - 50)
	p_label.size = Vector2(300, 100)
	pause_overlay.add_child(p_label)

	# Game over panel
	game_over_panel = Control.new()
	game_over_panel.visible = false
	hud_root.add_child(game_over_panel)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = Vector2(sw, sh)
	game_over_panel.add_child(bg)
	var go_label = Label.new()
	go_label.text = "遊戲結束"
	go_label.add_theme_font_size_override("font_size", 62)
	go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_label.position = Vector2(sw/2 - 200, sh/2 - 150)
	go_label.size = Vector2(400, 80)
	game_over_panel.add_child(go_label)
	var stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.text = ""
	stats_label.add_theme_font_size_override("font_size", 51)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.position = Vector2(sw/2 - 200, sh/2 - 10)
	stats_label.size = Vector2(400, 120)
	game_over_panel.add_child(stats_label)
	var restart_btn = Button.new()
	restart_btn.text = "重新開始"
	restart_btn.add_theme_font_size_override("font_size", 24)
	restart_btn.position = Vector2(sw/2 - 84, sh/2 + 130)
	restart_btn.size = Vector2(168, 56)
	restart_btn.pressed.connect(_restart)
	game_over_panel.add_child(restart_btn)

	# Level up panel
	level_up_panel = Control.new()
	level_up_panel.visible = false
	hud_root.add_child(level_up_panel)
	var lu_bg = ColorRect.new()
	lu_bg.color = Color(0, 0, 0, 0.8)
	lu_bg.size = Vector2(sw, sh)
	level_up_panel.add_child(lu_bg)
	var lu_label = Label.new()
	lu_label.name = "LU_label"
	lu_label.text = "升級！"
	lu_label.add_theme_font_size_override("font_size", 47)
	lu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lu_label.position = Vector2(sw/2 - 150, 60)
	lu_label.size = Vector2(300, 50)
	level_up_panel.add_child(lu_label)
	var choice_container = HBoxContainer.new()
	choice_container.name = "Choices"
	choice_container.position = Vector2(sw/2 - 500, 170)
	choice_container.size = Vector2(1000, 300)
	choice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	level_up_panel.add_child(choice_container)

	var lv_mouse_hint = Label.new()
	lv_mouse_hint.name = "MouseHint"
	lv_mouse_hint.text = "請用滑鼠選擇提升項目"
	lv_mouse_hint.add_theme_font_size_override("font_size", 22)
	lv_mouse_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_mouse_hint.position = Vector2(sw/2 - 200, 480)
	lv_mouse_hint.size = Vector2(400, 30)
	level_up_panel.add_child(lv_mouse_hint)

	# Hide in-game HUD until game starts
	hud_root.visible = false

func _load_walkable_map():
	var tex = load("res://assets/Map1_walkable.png")
	if tex:
		walkable_img = tex.get_image()
	else:
		walkable_img = null
		print("Failed to load walkable map")

func is_walkable(world_pos: Vector2) -> bool:
	if walkable_img == null:
		return true
	var img_x = (world_pos.x + 1375.0) / 2750.0 * 1920.0
	var img_y = (world_pos.y + 768.0) / 1536.0 * 1080.0
	img_x = clamp(img_x, 0.0, 1919.0)
	img_y = clamp(img_y, 0.0, 1079.0)
	var pixel = walkable_img.get_pixel(int(img_x), int(img_y))
	return pixel.r > 0.5

func _show_difficulty_select():
	var vp_size = get_viewport().get_visible_rect().size
	var sw = vp_size.x
	var sh = vp_size.y
	difficulty_select_panel = Control.new()
	hud_canvas.add_child(difficulty_select_panel)
	if custom_theme:
		difficulty_select_panel.theme = custom_theme
	difficulty_select_panel.position = Vector2(0, 0)
	difficulty_select_panel.size = vp_size

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.size = Vector2(sw, sh)
	difficulty_select_panel.add_child(bg)

	var title = Label.new()
	title.text = "召喚王"
	title.add_theme_font_size_override("font_size", 102)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(sw/2 - 350, 20)
	title.size = Vector2(700, 120)
	difficulty_select_panel.add_child(title)

	var instr = Label.new()
	instr.text = "方向鍵控制"
	instr.add_theme_font_size_override("font_size", 28)
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.position = Vector2(sw/2 - 150, 150)
	instr.size = Vector2(300, 40)
	difficulty_select_panel.add_child(instr)

	var subtitle = Label.new()
	subtitle.text = "選擇難度"
	subtitle.add_theme_font_size_override("font_size", 51)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(sw/2 - 200, 200)
	subtitle.size = Vector2(400, 60)
	difficulty_select_panel.add_child(subtitle)

	var grid = GridContainer.new()
	grid.position = Vector2(sw/2 - 280, 265)
	grid.size = Vector2(560, 340)
	grid.columns = 2
	difficulty_select_panel.add_child(grid)

	var mouse_hint = Label.new()
	mouse_hint.text = "請用滑鼠選擇難度"
	mouse_hint.add_theme_font_size_override("font_size", 22)
	mouse_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_hint.position = Vector2(sw/2 - 200, 615)
	mouse_hint.size = Vector2(400, 30)
	difficulty_select_panel.add_child(mouse_hint)

	for d in [Difficulty.STANDARD, Difficulty.EASY, Difficulty.HARD, Difficulty.INDIA]:
		var btn = Button.new()
		btn.size = Vector2(270, 175)
		btn.custom_minimum_size = Vector2(270, 175)
		btn.add_theme_font_size_override("font_size", 26)
		var text = DIFFICULTY_NAMES[d] + "\n\n" + DIFFICULTY_DESC[d]
		btn.text = text
		btn.connect("pressed", Callable(self, "_on_difficulty_selected").bind(d))
		grid.add_child(btn)

func _on_difficulty_selected(difficulty: int):
	current_difficulty = difficulty
	difficulty_select_panel.queue_free()
	difficulty_select_panel = null
	hud_root.visible = true
	start_game()

func start_game():
	player_hp = PLAYER_MAX_HP
	player_max_hp = PLAYER_MAX_HP
	player_level = 1
	player_xp = 0
	xp_to_next_level = XP_TO_LEVEL_BASE
	game_time = 0.0
	is_game_over = false
	enemy_count_mult = 1.0
	active_summons.clear()
	summon_counts.clear()
	summon_levels.clear()

	match current_difficulty:
		Difficulty.EASY:
			enemy_count_mult = 0.7
			enemy_speed_mult = 1.0
		Difficulty.HARD:
			enemy_count_mult = 1.5
			enemy_speed_mult = 1.0
		Difficulty.INDIA:
			enemy_count_mult = 1.5
			enemy_speed_mult = 1.3
		_:
			enemy_count_mult = 1.0
			enemy_speed_mult = 1.0

	_play_music()
	_spawn_player()
	spawn_timer.start(BASE_SPAWN_INTERVAL)
	add_summon(SummonType.FLAME_SPIRIT)
	update_hud()

func _play_music():
	var path = "res://assets/Music/8bit.ogg"
	if current_difficulty == Difficulty.INDIA:
		path = "res://assets/Music/india.ogg"
	var stream = load(path)
	if stream:
		stream.set_loop(true)
		music_player.stream = stream
		music_player.play()

func _spawn_player():
	if is_instance_valid(player):
		player.queue_free()
	var scene = preload("res://scenes/player.tscn")
	player = scene.instantiate()
	player.position = Vector2.ZERO
	add_child(player)
	player.initialize(self)
func _process(delta):
	if not hud_ready:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()
	if game_paused or is_game_over or level_up_active:
		return
	game_time += delta
	var diff = min(game_time / DIFFICULTY_RAMP_TIME, 1.0)
	spawn_timer.wait_time = lerp(BASE_SPAWN_INTERVAL, 0.3, diff)
	if game_time - int(game_time) < delta:
		time_label.text = _format_time(game_time)

func _format_time(t: float) -> String:
	var m = int(t) / 60
	var s = int(t) % 60
	return "%d:%02d" % [m, s]

func _on_spawn_timer_timeout():
	# Base spawns (affected by duplication penalty)
	var base_count = int(enemy_count_mult)
	if randf() < fmod(enemy_count_mult, 1.0):
		base_count += 1
	base_count = max(1, base_count)
	for i in range(base_count):
		spawn_enemy()
	# Difficulty bonus spawns
	var diff = min(game_time / DIFFICULTY_RAMP_TIME, 1.0)
	if diff > 0.3 and randf() < diff * 0.5:
		spawn_enemy()
	if diff > 0.6 and randf() < diff * 0.3:
		spawn_enemy()

func spawn_enemy():
	if is_game_over or game_paused or level_up_active:
		return
	var scene = preload("res://scenes/enemy.tscn")
	var enemy = scene.instantiate()
	var diff = min(game_time / DIFFICULTY_RAMP_TIME, 1.0)
	var vp = get_viewport().get_visible_rect().size
	var cam_pos = camera.global_position
	var dist = max(vp.x, vp.y) * 0.6 + 50
	var pos: Vector2
	for attempt in 10:
		var angle = randf_range(0, PI * 2)
		pos = cam_pos + Vector2(cos(angle), sin(angle)) * dist
		if is_walkable(pos):
			break
	enemy.position = pos
	enemy_container.add_child(enemy)
	enemy.initialize(self, diff, enemy_speed_mult)

func spawn_boss():
	if is_game_over or game_paused or level_up_active:
		return
	var scene = preload("res://scenes/boss.tscn")
	var boss = scene.instantiate()
	var diff = min(game_time / DIFFICULTY_RAMP_TIME, 1.0)
	var vp = get_viewport().get_visible_rect().size
	var cam_pos = camera.global_position
	var dist = max(vp.x, vp.y) * 0.6 + 50
	var pos: Vector2
	for attempt in 10:
		var angle = randf_range(0, PI * 2)
		pos = cam_pos + Vector2(cos(angle), sin(angle)) * dist
		if is_walkable(pos):
			break
	boss.position = pos
	enemy_container.add_child(boss)
	boss.initialize(self, diff, enemy_speed_mult)
	boss.hp *= 2.0
	boss.max_hp = boss.hp
	boss.xp_value *= 3
	boss.modulate = Color(1.5, 0.3, 0.3)

func add_summon(type: int):
	summon_counts[type] = summon_counts.get(type, 0) + 1
	summon_levels[type] = summon_levels.get(type, 0) + 1
	var scene = preload("res://scenes/summon.tscn")
	var summon = scene.instantiate()
	summon_container.add_child(summon)
	summon.initialize(self, type, summon_levels[type], summon_counts[type])
	active_summons.append(summon)

func upgrade_summon(type: int):
	summon_levels[type] = summon_levels.get(type, 0) + 1
	for s in active_summons:
		if is_instance_valid(s) and s.summon_type == type:
			s.upgrade(summon_levels[type])

func add_xp(amount: int):
	if is_game_over or game_paused or level_up_active:
		return
	player_xp += amount
	while player_xp >= xp_to_next_level:
		player_xp -= xp_to_next_level
		level_up()
	update_hud()

func level_up():
	player_level += 1
	xp_to_next_level = int(XP_TO_LEVEL_BASE * pow(XP_TO_LEVEL_SCALE, player_level - 1))
	level_up_active = true
	show_level_up()

func show_level_up():
	level_up_panel.visible = true
	level_up_panel.get_node("LU_label").text = "等級 " + str(player_level)
	var container = level_up_panel.get_node("Choices")
	for c in container.get_children():
		c.queue_free()

	var choices = _generate_choices(3)
	for choice in choices:
		var btn = Button.new()
		btn.size = Vector2(300, 260)
		btn.custom_minimum_size = Vector2(300, 260)
		btn.add_theme_font_size_override("font_size", 26)
		btn.connect("pressed", Callable(self, "_on_choice").bind(choice))
		var type = choice.summon_type
		var text = SUMMON_NAMES.get(type, "Unknown")
		match choice.type:
			UpgradeType.NEW_SUMMON:
				text += "\n（解鎖）"
			UpgradeType.UPGRADE_SUMMON:
				text += "\n（升級）"
			UpgradeType.DUPLICATE_SUMMON:
				text += "\n（複製）"
		text += "\n\n" + SUMMON_DESC.get(type, "")
		if choice.type == UpgradeType.DUPLICATE_SUMMON:
			text += "\n敵人數 x1.5"
		if summon_levels.has(type) and summon_levels[type] > 0:
			var lv = summon_levels[type]
			if choice.type == UpgradeType.UPGRADE_SUMMON:
				lv += 1
			text += "\nLv." + str(lv)
		btn.text = text
		container.add_child(btn)

func _generate_choices(count: int) -> Array:
	var pool = []
	var unlocked = []
	var locked = []

	for t in SummonType.values():
		if summon_counts.get(t, 0) > 0:
			unlocked.append(t)
		else:
			locked.append(t)

	# Unlock options
	for t in locked:
		pool.append({"type": UpgradeType.NEW_SUMMON, "summon_type": t})
	# Upgrade options
	for t in unlocked:
		pool.append({"type": UpgradeType.UPGRADE_SUMMON, "summon_type": t})
	# Duplicate options (cost: +50% enemies)
	for t in unlocked:
		pool.append({"type": UpgradeType.DUPLICATE_SUMMON, "summon_type": t})

	pool.shuffle()
	var choices = pool.slice(0, count)

	# Fallback if not enough
	while choices.size() < count:
		if unlocked.size() > 0:
			choices.append({"type": UpgradeType.UPGRADE_SUMMON, "summon_type": unlocked[randi() % unlocked.size()]})
		elif locked.size() > 0:
			choices.append({"type": UpgradeType.NEW_SUMMON, "summon_type": locked[randi() % locked.size()]})
		else:
			choices.append({"type": UpgradeType.UPGRADE_SUMMON, "summon_type": SummonType.FLAME_SPIRIT})

	return choices

func _on_choice(choice):
	level_up_active = false
	level_up_panel.visible = false
	match choice.type:
		UpgradeType.NEW_SUMMON:
			add_summon(choice.summon_type)
		UpgradeType.UPGRADE_SUMMON:
			upgrade_summon(choice.summon_type)
		UpgradeType.DUPLICATE_SUMMON:
			add_summon(choice.summon_type)
			enemy_count_mult += 0.5
	if player_level % 5 == 0:
		spawn_boss()
	update_hud()

func damage_player(amount: float):
	if is_game_over:
		return
	player_hp -= amount
	if player_hp <= 0:
		player_hp = 0
		game_over()
	update_hud()

func game_over():
	is_game_over = true
	spawn_timer.stop()
	game_over_panel.get_node("StatsLabel").text = "時間：" + _format_time(game_time) + "\n等級：" + str(player_level)
	game_over_panel.visible = true

func _restart():
	get_tree().reload_current_scene()

func _toggle_pause():
	if level_up_active:
		return
	game_paused = not game_paused
	pause_overlay.visible = game_paused
	if music_player:
		music_player.stream_paused = game_paused

func _toggle_music(toggled: bool):
	music_muted = toggled
	if music_player:
		music_player.volume_db = -80 if music_muted else 0
	music_toggle_btn.text = "♪" if not music_muted else "✕"

func update_hud():
	hp_bar.size.x = 200 * (player_hp / player_max_hp)
	xp_bar.size.x = 200 * float(player_xp) / float(xp_to_next_level) if xp_to_next_level > 0 else 0
	level_label.text = "等級 " + str(player_level)
	if enemy_count_mult > 1.0:
		enemy_mult_label.text = "敵 x" + str(enemy_count_mult)
	else:
		enemy_mult_label.text = ""
