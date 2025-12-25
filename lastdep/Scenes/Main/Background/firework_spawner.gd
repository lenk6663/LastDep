# firework_spawner.gd
extends Node2D

@export var firework_scene: PackedScene
@export var min_spawn_time: float = 0.01
@export var max_spawn_time: float = 2.0
@export var max_fireworks: int = 6

# Зона ИСКЛЮЧЕНИЯ (где не должны появляться фейерверки)
@export var exclude_center_zone: bool = true
@export var center_zone_size: Vector2 = Vector2(500, 500)  # размер зоны исключения

var active_fireworks: Array = []
var screen_size: Vector2
var center_position: Vector2

func _ready():
	# Получаем размер экрана
	screen_size = get_viewport().get_visible_rect().size
	center_position = screen_size / 2
	
	# Загружаем сцену если не задана
	if not firework_scene:
		firework_scene = preload("res://Scenes/Main/Background/firework.tscn")
	
	print("🎆 Спавнер фейерверков готов")
	print("  Экран: ", screen_size)
	print("  Центр: ", center_position)
	
	# Запускаем спавн
	_start_spawning()

func _start_spawning():
	while true:
		# Случайная задержка
		var wait_time = randf_range(min_spawn_time, max_spawn_time)
		await get_tree().create_timer(wait_time).timeout
		
		# Проверяем лимит
		if active_fireworks.size() < max_fireworks:
			_spawn_firework()

func _spawn_firework():
	if not firework_scene:
		return
	
	var spawn_position: Vector2
	var attempts = 0
	var max_attempts = 10  # Максимальное количество попыток
	
	# Пытаемся найти позицию вне центральной зоны
	while attempts < max_attempts:
		spawn_position = _get_random_position()
		
		# Если исключение центра выключено или позиция вне центральной зоны
		if not exclude_center_zone or not _is_in_center_zone(spawn_position):
			break
		
		attempts += 1
	
	if attempts == max_attempts:
		print("⚠️ Не удалось найти позицию вне центра, использую случайную")
	
	# Создаем фейерверк
	var firework = firework_scene.instantiate()
	firework.position = spawn_position
	firework.z_index = 1
	
	# Добавляем как дочерний узел
	add_child(firework)
	active_fireworks.append(firework)
	
	# Подключаем сигнал удаления
	firework.tree_exiting.connect(_on_firework_exited.bind(firework))
	
	print("✅ Фейерверк: ", Vector2(int(spawn_position.x), int(spawn_position.y)),
		  " (попыток: ", attempts, ")")

func _get_random_position() -> Vector2:
	# Отступы от краев экрана (чтобы не появлялись вплотную к краю)
	var margin = 50
	
	return Vector2(
		randf_range(margin, screen_size.x - margin),
		randf_range(margin, screen_size.y - margin)
	)

func _is_in_center_zone(position: Vector2) -> bool:
	# Проверяем, находится ли позиция в центральной зоне
	var half_zone = center_zone_size / 2
	var zone_rect = Rect2(
		center_position.x - half_zone.x,
		center_position.y - half_zone.y,
		center_zone_size.x,
		center_zone_size.y
	)
	
	return zone_rect.has_point(position)

func _on_firework_exited(firework):
	var index = active_fireworks.find(firework)
	if index != -1:
		active_fireworks.remove_at(index)

func clear_all_fireworks():
	for firework in active_fireworks:
		if is_instance_valid(firework):
			firework.queue_free()
	active_fireworks.clear()
