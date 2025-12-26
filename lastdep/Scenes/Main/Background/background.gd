# background.gd
extends CanvasLayer

@export var show_fireworks: bool = true
@export var firework_scene: PackedScene
@export var dim_color: Color = Color(0, 0, 0, 0.3)  # Цвет затемнения

var firework_spawner: Node

func _ready():
	# Подписываемся на изменение размера окна
	get_tree().root.size_changed.connect(_on_window_resized)
	
	# Первоначальная настройка
	_update_all_sizes()
	
	# Если нужно - добавляем фейерверки
	if show_fireworks and firework_scene:
		_setup_fireworks()

func _on_window_resized():
	print("🔄 Размер окна изменился: ", get_viewport().size)
	_update_all_sizes()
	
	# Обновляем спавнер фейерверков если он есть
	if firework_spawner and firework_spawner.has_method("update_screen_size"):
		firework_spawner.update_screen_size()

func _update_all_sizes():
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Обновляем фон (TextureRect)
	$Background.size = viewport_size
	$Background.position = Vector2.ZERO
	
	# Обновляем ColorRect (затемнение/оверлей)
	if has_node("ColorRect"):
		$ColorRect.size = viewport_size
		$ColorRect.position = Vector2.ZERO
		$ColorRect.color = dim_color
	
	print("📐 Все элементы фона обновлены: ", viewport_size)

func _setup_fireworks():
	firework_spawner = Node2D.new()
	firework_spawner.name = "FireworkSpawner"
	
	# Добавляем как дочерний к CanvasLayer
	add_child(firework_spawner)
	firework_spawner.z_index = 2  # Поверх ColorRect но под UI
	
	# Копируем скрипт спавнера
	firework_spawner.set_script(load("res://Scenes/Main/menu/firework_spawner.gd"))
	
	# Настраиваем параметры
	firework_spawner.firework_scene = firework_scene
	firework_spawner.min_spawn_time = 1.0
	firework_spawner.max_spawn_time = 2.5
	firework_spawner.max_fireworks = 4
	firework_spawner.exclude_center_zone = true
	firework_spawner.center_zone_size = Vector2(500, 350)

# Для управления прозрачностью ColorRect
func set_dim_strength(alpha: float):
	if has_node("ColorRect"):
		dim_color.a = alpha
		$ColorRect.color = dim_color

func set_dim_color(color: Color):
	if has_node("ColorRect"):
		dim_color = color
		$ColorRect.color = dim_color

func show_dim(show: bool = true):
	if has_node("ColorRect"):
		$ColorRect.visible = show
		
func show_background():
	visible = true

func hide_background():
	visible = false

# Для изменения фона
func change_background(texture_path: String):
	var texture = load(texture_path)
	if texture:
		$Background.texture = texture

# Для включения/выключения фейерверков
func set_fireworks_enabled(enabled: bool):
	if firework_spawner:
		firework_spawner.visible = enabled
		firework_spawner.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
