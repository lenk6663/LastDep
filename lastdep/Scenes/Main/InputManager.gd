# InputManager.gd
extends Node

signal settings_opened
signal settings_closed

var is_settings_open = false
var settings_instance = null

func _ready():
	# Делаем этот узел глобальным
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("InputManager: Инициализирован")

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # Клавиша ESC
		print("InputManager: Нажат ESC, is_settings_open =", is_settings_open)
		
		if is_settings_open:
			_close_settings()
		else:
			_open_settings()
		
		get_viewport().set_input_as_handled()

func _open_settings():
	if is_settings_open:
		return
	
	print("InputManager: Открываю настройки...")
	
	# Создаем сцену настроек
	var settings_scene = preload("res://Scenes/Main/settings/settings.tscn")  # Укажите правильный путь
	if not settings_scene:
		print("ОШИБКА: Не могу загрузить сцену настроек!")
		return
	
	settings_instance = settings_scene.instantiate()
	
	# Добавляем на самый верхний слой
	var root = get_tree().root
	root.add_child(settings_instance)
	
	# Подключаем сигнал закрытия настроек
	if settings_instance.has_signal("closed"):
		settings_instance.closed.connect(_on_settings_closed)
	elif settings_instance.has_method("_on_back_pressed"):
		# Подключаем к кнопке назад
		var back_button = settings_instance.get_node_or_null("VBoxContainer/BackButton")
		if back_button:
			back_button.pressed.connect(_on_settings_closed)
	
	is_settings_open = true
	settings_opened.emit()

func _close_settings():
	if not is_settings_open:
		return
	
	print("InputManager: Закрываю настройки...")
	
	if settings_instance:
		settings_instance.queue_free()
		settings_instance = null
	
	is_settings_open = false
	settings_closed.emit()

func _on_settings_closed():
	print("InputManager: Сигнал закрытия настроек получен")
	_close_settings()

# Методы для проверки состояния
func can_process_game_input():
	return not is_settings_open

func is_settings_active():
	return is_settings_open
