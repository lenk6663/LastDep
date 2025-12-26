# menu.gd
extends Control

@onready var create_button: Button = $Panel/VBoxContainer/CreateButton
@onready var ip_panel: PanelContainer = $Panel/VBoxContainer/IPPanel
@onready var connect_ip_input: LineEdit = $Panel/VBoxContainer/ConnectContainer/ConnectIPInput
@onready var connect_button: Button = $Panel/VBoxContainer/ConnectContainer/ConnectButton
@onready var my_ip_input: LineEdit = $Panel/VBoxContainer/MyIPContainer/MyIPInput
@onready var copy_my_ip_button: Button = $Panel/VBoxContainer/MyIPContainer/CopyMyIPButton
@onready var exit_button: Button = $Panel/VBoxContainer/ExitButton
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var port_input: LineEdit = $Panel/VBoxContainer/PortContainer/PortInput
@onready var port_panel: PanelContainer = $Panel/VBoxContainer/PortContainer
@onready var background_music = get_node("/root/BackgroundMusic") if get_tree().root.has_node("/root/BackgroundMusic") else null

# Добавляем загрузку сцен
const SETTINGS_SCENE = preload("res://Scenes/Main/settings/settings.tscn")
const LOBBY_SCENE = preload("res://Scenes/Main/lobby/lobby.tscn") 

func _ready():
	add_to_group("menu")
	print("Меню загружено")
	
	if background_music:
		background_music.back_to_menu()
		print("Музыка меню включена")
		
	# Начальное состояние
	ip_panel.visible = false
	
	# Автозаполнение IP
	_setup_ip_fields()
	
	# Подключаем кнопки
	create_button.pressed.connect(_on_create_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	copy_my_ip_button.pressed.connect(_on_copy_my_ip_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	
	port_input.text = str(NetworkingManager.PORT)
	port_panel.visible = true
func _setup_ip_fields():
	# Заполняем поле "Подключиться к IP"
	var connect_ip = _get_my_ip_for_connection()
	if connect_ip:
		connect_ip_input.placeholder_text = connect_ip
	
	# Заполняем поле "Мой IP для подключения"
	var my_ip = _get_my_ip_for_sharing()
	if my_ip:
		my_ip_input.text = my_ip
		my_ip_input.placeholder_text = my_ip
		
func _on_settings_pressed():
	print("Открытие настроек...")
	if SETTINGS_SCENE:
		var settings_instance = SETTINGS_SCENE.instantiate()
		get_tree().root.add_child(settings_instance)
		# Скрываем меню
		hide()
		print("Окно настроек открыто")
	else:
		print("ОШИБКА: Не могу загрузить сцену настроек!")

func _get_my_ip_for_connection() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168."):
			return ip
		elif ip.begins_with("10."):
			return ip
	return "127.0.0.1"

func _get_my_ip_for_sharing() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168."):
			return ip + ":" + str(port_input.text)
		elif ip.begins_with("10."):
			return ip + ":" + str(port_input.text)
	return "127.0.0.1:" + str(port_input.text)

func _on_create_pressed() -> void:
	print("Создание игры...")
	
	# Получаем порт из поля ввода
	var port = int(port_input.text)
	if port <= 0 or port > 65535:
		port = NetworkingManager.PORT  # Значение по умолчанию
	
	if NetworkingManager.create_host(port):
		# Переходим в лобби как хост
		_go_to_lobby("host")
	else:
		print("Ошибка создания сервера")

func _on_connect_pressed() -> void:
	var ip = connect_ip_input.text.strip_edges()
	if ip.is_empty():
		ip = connect_ip_input.placeholder_text
	
	# Получаем порт
	var port = int(port_input.text)
	if port <= 0 or port > 65535:
		port = NetworkingManager.PORT  # Значение по умолчанию
	
	print("Подключение к:", ip, ":", port)
	
	# Если IP содержит порт, разделяем их
	var clean_ip = ip
	if ":" in ip:
		var parts = ip.split(":")
		clean_ip = parts[0]
		port = int(parts[1]) if parts[1].is_valid_int() else port
	
	if NetworkingManager.connect_to_host(clean_ip, port):
		# Переходим в лобби как клиент
		_go_to_lobby("client", ip)
	else:
		print("Ошибка подключения")

func _go_to_lobby(mode: String, ip: String = ""):
	# Загружаем лобби
	var lobby_instance = LOBBY_SCENE.instantiate()
	
	# Устанавливаем параметры
	lobby_instance.mode = mode
	if ip:
		lobby_instance.target_ip = ip
	
	# Добавляем на сцену
	get_tree().root.add_child(lobby_instance)
	
	# Скрываем меню
	hide()
	
	print("Переход в лобби в режиме:", mode)

func _on_copy_my_ip_pressed():
	var ip_to_copy = my_ip_input.text
	if ip_to_copy.is_empty():
		ip_to_copy = my_ip_input.placeholder_text
	
	_copy_to_clipboard(ip_to_copy, copy_my_ip_button)

func _on_exit_pressed():
	get_tree().quit()

func _copy_to_clipboard(text: String, button: Button):
	if text.is_empty():
		return
	
	DisplayServer.clipboard_set(text)
	
	# Визуальная обратная связь
	var original_text = button.text
	button.text = "✓"
	button.disabled = true
	
	await get_tree().create_timer(1.5).timeout
	
	button.text = original_text
	button.disabled = false
	
	print("IP скопирован:", text)

func show_menu():
	# Показываем меню обратно
	show()
