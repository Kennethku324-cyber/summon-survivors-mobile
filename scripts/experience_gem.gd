extends Area2D

var gm: Node2D
var xp_amount: int = 10

func initialize(game_manager: Node2D, amount: int):
	gm = game_manager
	xp_amount = amount
	add_to_group("xp")

func _on_area_entered(area: Area2D):
	if area == gm.player and not gm.game_paused and not gm.level_up_active:
		gm.add_xp(xp_amount)
		queue_free()

func _draw():
	var col = Color(0.2, 0.9, 0.5)
	# Diamond shape
	var top = Vector2(0, -23)
	var right = Vector2(17, 0)
	var bottom = Vector2(0, 23)
	var left = Vector2(-17, 0)
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), col)
	draw_colored_polygon(PackedVector2Array([top, right * 0.5, bottom * 0.5, left * 0.5]), Color(0.6, 1.0, 0.8))
