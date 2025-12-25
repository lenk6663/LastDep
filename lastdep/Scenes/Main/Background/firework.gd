# firework.gd
extends AnimatedSprite2D

# Варианты цветов для фейерверков
var color_variants = [
	Color(1.0, 0.3, 0.3),    # Красный
	Color(0.3, 0.6, 1.0),    # Синий
	Color(0.3, 1.0, 0.3),    # Зелёный
	Color(1.0, 1.0, 0.3),    # Жёлтый
	Color(1.0, 0.5, 1.0),    # Розовый
	Color(0.5, 1.0, 1.0),    # Голубой
	Color(1.0, 0.7, 0.3),    # Оранжевый
	Color(0.8, 0.3, 1.0)     # Фиолетовый
]

func _ready():
	# 1. Случайный размер (от 70% до 180%)
	var random_scale = randf_range(5, 8)
	scale = Vector2(random_scale, random_scale)
	
	# 2. Случайный цвет из вариантов
	var random_color = color_variants[randi() % color_variants.size()]
	modulate = random_color
	
	# 3. Случайная скорость анимации (от 80% до 130% от нормальной)
	speed_scale = randf_range(0.8, 1.3)
	
	
	# 5. Настраиваем анимацию на ОДНОКРАТНОЕ воспроизведение
	connect("animation_finished", _on_animation_finished)
	
	# 6. Начинаем анимацию
	play()

func _on_animation_finished():
	print("Фейерверк удалён (анимация завершена)")
	queue_free()
