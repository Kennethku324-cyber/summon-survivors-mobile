extends Area2D

var gm: Node2D
var heal_amount: float = 20.0

func initialize(game_manager: Node2D):
	gm = game_manager
	add_to_group("pickups")

func _on_area_entered(area: Area2D):
	if area == gm.player and not gm.game_paused and not gm.level_up_active:
		gm.player_hp = min(gm.player_hp + heal_amount, gm.player_max_hp)
		gm.update_hud()
		queue_free()

func _draw():
	var c = Color(1.0, 0.2, 0.3)
	draw_circle(Vector2(-9, -6), 11, c)
	draw_circle(Vector2(9, -6), 11, c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, -3), Vector2(17, -3), Vector2(0, 18)
	]), c)
