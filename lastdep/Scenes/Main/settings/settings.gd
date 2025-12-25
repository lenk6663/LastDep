# settings.gd
extends Control

# Привязка узлов из вашей сцены
@onready var music_slider: HSlider = $VBoxContainer/HBoxContainer/MusicSlider
@onready var resolution_option: OptionButton = $VBoxContainer/HBoxContainer2/ResolutionOption
@onready var back_button: Button = $VBoxContainer/BackButton

# Предопределенные разрешения
var resolutions = [
	Vector2i(1024, 576),   # 16:9
	Vector2i(1280, 720),   # HD
	Vector2i(1366, 768),   # HD+
	Vector2i(1600, 900),   # HD+
	Vector2i(1920, 1080),  # Full HD
	Vector2i(2560, 1440)   # 2K
]

func _ready():
	print("Настройки загружены")
	
	# Инициализация элементов
	_init_resolution_options()
	_load_settings()
	
	# Подключение сигналов
	music_slider.value_changed.connect(_on_music_slider_changed)
	resolution_option.item_selected.connect(_on_resolution_selected)
	back_button.pressed.connect(_on_back_pressed)
	
	print("Слайдер музыки:", music_slider)
	print("Кнопка разрешения:", resolution_option)
	print("Кнопка назад:", back_button)

func _init_resolution_options():
	resolution_option.clear()
	for i in range(resolutions.size()):
		var res = resolutions[i]
		resolution_option.add_item("%d x %d" % [res.x, res.y], i)
	print("Опции разрешения инициализированы")

func _load_settings():
	# Загружаем сохраненные настройки
	var config = ConfigFile.new()
	
	if config.load("user://settings.cfg") == OK:
		print("Настройки загружены из файла")
		
		# Громкость музыки (0.0-1.0)
		var music_volume = config.get_value("audio", "music_volume", 0.8)
		music_slider.value = music_volume
		print("Громкость музыки:", music_volume)
		
		# Разрешение экрана
		var resolution_index = config.get_value("video", "resolution", 1)  # По умолчанию 1280x720
		resolution_index = clamp(resolution_index, 0, resolutions.size() - 1)
		resolution_option.selected = resolution_index
		print("Разрешение:", resolution_index)
		
		# Применяем загруженные настройки
		_apply_settings()
	else:
		print("Создаем настройки по умолчанию")
		# Настройки по умолчанию
		music_slider.value = 0.01
		resolution_option.selected = 1  # 1280x720
		
		# Сохраняем настройки по умолчанию
		_save_settings()
		_apply_settings()

func _apply_settings():
	# Применяем громкость музыки через AudioBus
	_apply_music_volume(music_slider.value)
	
	# Применяем разрешение экрана
	var res_index = resolution_option.selected
	if res_index >= 0 and res_index < resolutions.size():
		_apply_resolution(resolutions[res_index])
	
	print("Настройки применены")

func _apply_music_volume(value: float):
	# Конвертируем из 0.0-1.0 в децибелы (-80 до 0)
	var db_value = linear_to_db(value)
	print("Устанавливаем громкость музыки:", value, "->", db_value, "dB")
	
	# 1. Пробуем через шину Music
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx != -1:
		AudioServer.set_bus_volume_db(music_bus_idx, db_value)
		print("Громкость установлена через шину Music")
	else:
		print("ВНИМАНИЕ: Шина Music не найдена!")
		print("Доступные шины:", AudioServer.bus_count, "штук")
		
		# 2. Если шины нет, меняем напрямую у BackgroundMusic
		if get_tree().root.has_node("/root/BackgroundMusic"):
			var music_player = get_node("/root/BackgroundMusic")
			music_player.volume_db = db_value
			print("Громкость установлена напрямую у BackgroundMusic")

func _apply_resolution(resolution: Vector2i):
	print("Устанавливаем разрешение:", resolution)
	
	# Проверяем текущий режим
	var current_mode = DisplayServer.window_get_mode()
	
	if current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		# Меняем размер окна
		DisplayServer.window_set_size(resolution)
		
		# Центрируем окно
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - resolution) / 2
		DisplayServer.window_set_position(window_pos)
		
		print("Окно изменено на размер:", resolution, "позиция:", window_pos)

func _save_settings():
	var config = ConfigFile.new()
	
	# Сохраняем настройки
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("video", "resolution", resolution_option.selected)
	
	# Сохраняем файл
	var result = config.save("user://settings.cfg")
	if result == OK:
		print("Настройки сохранены в user://settings.cfg")
	else:
		print("ОШИБКА сохранения настроек:", result)

# ================== СИГНАЛЫ ==================

func _on_music_slider_changed(value: float):
	print("Слайдер музыки изменен:", value)
	_apply_music_volume(value)
	_save_settings()

func _on_resolution_selected(index: int):
	print("Выбрано разрешение:", index, "->", resolutions[index])
	if index >= 0 and index < resolutions.size():
		_apply_resolution(resolutions[index])
		_save_settings()

func _on_back_pressed():
	print("Закрытие настроек")	
	var menu = get_tree().root.get_node("Menu")  # Предполагая что меню называется "Menu"
	if menu and menu.has_method("show_menu"):
		menu.show_menu()
		print("Меню показано")
	
	queue_free()
