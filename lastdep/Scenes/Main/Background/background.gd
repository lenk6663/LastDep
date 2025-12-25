# background.gd
extends CanvasLayer

@export var show_fireworks: bool = true
@export var firework_scene: PackedScene

var firework_spawner: Node

func _ready():
	# Настраиваем фон на весь экран
	$Background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	$Background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	$Background.size = get_viewport().size
	
	# Если нужно - добавляем фейерверки
	if show_fireworks and firework_scene:
		_setup_fireworks()

func _setup_fireworks():
	firework_spawner = Node2D.new()
	firework_spawner.name = "FireworkSpawner"
	$Background.add_child(firework_spawner)
	
	# Копируем скрипт спавнера
	firework_spawner.set_script(load("res://Scenes/Main/menu/firework_spawner.gd"))
	
	# Настраиваем параметры
	firework_spawner.firework_scene = firework_scene
	firework_spawner.min_spawn_time = 1.0
	firework_spawner.max_spawn_time = 2.5
	firework_spawner.max_fireworks = 4
	firework_spawner.exclude_center_zone = true
	firework_spawner.center_zone_size = Vector2(500, 350)

# Переименованные функции (не используем show()/hide())
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
