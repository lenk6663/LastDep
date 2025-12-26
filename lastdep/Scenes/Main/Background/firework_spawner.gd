# firework_spawner.gd
extends Node2D

@export var firework_scene: PackedScene
@export var min_spawn_time: float = 0.01
@export var max_spawn_time: float = 2.0
@export var max_fireworks: int = 6

# Зона ИСКЛЮЧЕНИЯ (где не должны появляться фейерверки)
@export var exclude_center_zone: bool = true
@export var center_zone_size: Vector2 = Vector2(500, 500)

var active_fireworks: Array = []
var screen_size: Vector2
var center_position: Vector2

func _ready():
	# Подписываемся на изменение размера окна
	get_tree().root.size_changed.connect(_on_window_resized)
	
	# Первоначальная настройка
	_update_screen_size()
	
	# Загружаем сцену если не задана
	if not firework_scene:
		firework_scene = preload("res://Scenes/Main/Background/firework.tscn")
	
	print("🎆 Спавнер фейерверков готов")
	
	# Запускаем спавн
	_start_spawning()

func _on_window_resized():
	print("🔄 Спавнер: размер окна изменился")
	_update_screen_size()
	_clear_all_fireworks()  # Очищаем старые фейерверки

func _update_screen_size():
	# Получаем текущий размер экрана
	screen_size = get_viewport().get_visible_rect().size
	center_position = screen_size / 2
	
	print("  Новый размер экрана: ", screen_size)
	print("  Новый центр: ", center_position)

# Функция для вызова извне
func update_screen_size():
	_update_screen_size()

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
	var max_attempts = 10
	
	# Пытаемся найти позицию вне центральной зоны
	while attempts < max_attempts:
		spawn_position = _get_random_position()
		
		if not exclude_center_zone or not _is_in_center_zone(spawn_position):
			break
		
		attempts += 1
	
	if attempts == max_attempts:
		print("⚠️ Не удалось найти позицию вне центра")
	
	# Создаем фейерверк
	var firework = firework_scene.instantiate()
	firework.position = spawn_position
	firework.z_index = 1
	
	# Масштабируем относительно размера экрана
	var scale_factor = min(screen_size.x, screen_size.y) / 720.0
	firework.scale = Vector2.ONE * scale_factor * randf_range(1.5, 2.5)
	
	add_child(firework)
	active_fireworks.append(firework)
	
	firework.tree_exiting.connect(_on_firework_exited.bind(firework))
	
	print("✅ Фейерверк: ", Vector2(int(spawn_position.x), int(spawn_position.y)))

func _get_random_position() -> Vector2:
	# Отступы от краев экрана
	var margin = min(50, screen_size.x * 0.05)
	
	return Vector2(
		randf_range(margin, screen_size.x - margin),
		randf_range(margin, screen_size.y - margin)
	)

func _is_in_center_zone(position: Vector2) -> bool:
	# Масштабируем зону исключения относительно размера экрана
	var scaled_zone_size = Vector2(
		center_zone_size.x * (screen_size.x / 1152.0),
		center_zone_size.y * (screen_size.y / 648.0)
	)
	
	var half_zone = scaled_zone_size / 2
	var zone_rect = Rect2(
		center_position.x - half_zone.x,
		center_position.y - half_zone.y,
		scaled_zone_size.x,
		scaled_zone_size.y
	)
	
	return zone_rect.has_point(position)

func _on_firework_exited(firework):
	var index = active_fireworks.find(firework)
	if index != -1:
		active_fireworks.remove_at(index)

func _clear_all_fireworks():
	for firework in active_fireworks:
		if is_instance_valid(firework):
			firework.queue_free()
	active_fireworks.clear()
	print("🧹 Все фейерверки очищены из-за изменения разрешения")

func clear_all_fireworks():
	_clear_all_fireworks()
