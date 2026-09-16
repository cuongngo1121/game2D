extends Node2D

var game

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or game.state in ["menu", "game_over", "victory"]:
		return
	game.draw_effects(self)
