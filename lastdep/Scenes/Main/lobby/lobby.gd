# lobby.gd
extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var ip_label: Label = $VBoxContainer/IPLabel
@onready var cancel_button: Button = $VBoxContainer/CancelButton
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var start_button: Button = $VBoxContainer/StartButton

# Параметры от меню
var mode: String = "host"
var target_ip: String = ""

func _ready():
	print("Лобби запущено в режиме:", mode)
	print("Лобби находится на сцене:", get_tree().current_scene.name if get_tree().current_scene else "нет")
	
	# Настраиваем UI
	if mode == "host":
		status_label.text = "Создание игры..."
		ip_label.visible = false
		cancel_button.text = "Отменить создание"
		if start_button:
			start_button.text = "Начать игру"
			start_button.visible = false  # Показываем только когда подключится игрок
	else:
		status_label.text = "Подключение к " + target_ip + "..."
		ip_label.text = "IP: " + target_ip
		cancel_button.text = "Отменить подключение"
		if start_button:
			start_button.visible = false
	
	cancel_button.pressed.connect(_on_cancel_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	
	# Подключаем сетевые сигналы
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Устанавливаем IP для хоста
	if mode == "host":
		ip_label.visible = true
		ip_label.text = "Ваш IP: " + _get_local_ip()

func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			return ip + ":" + str(NetworkingManager.PORT)
	return "127.0.0.1:" + str(NetworkingManager.PORT)

func _on_cancel_pressed():
	_return_to_menu()

func _on_back_pressed():
	_return_to_menu()

# В lobby.gd добавьте RPC для синхронизации игроков:
@rpc("authority", "call_remote", "reliable")
func sync_player_list():
	print("Синхронизация списка игроков")
	
	# Запоминаем что нужно создать игроков
	NetworkingManager.should_create_players = true

func _on_start_pressed():
	# Хост запускает игру для всех
	if multiplayer.is_server():
		print("Хост запускает игру...")
		print("Текущая сцена перед запуском:", get_tree().current_scene.name if get_tree().current_scene else "нет")
		
		# Сначала синхронизируем список игроков
		sync_player_list.rpc()
		sync_player_list()  # И локально
		
		# Ждем немного для синхронизации
		await get_tree().create_timer(0.2).timeout
		
		print("Загружаем игру у хоста...")
		# Запускаем игру у хоста (локально) - ОБЯЗАТЕЛЬНО перед отправкой клиентам
		_load_game_scene()
		
		# Потом отправляем команду клиентам
		print("Отправляем команду клиентам начать игру")
		start_game.rpc()
	else:
		print("Только хост может начать игру")

@rpc("authority", "call_remote", "reliable")
func start_game():
	print("Клиент получает команду начать игру")
	print("Клиент: Текущая сцена перед загрузкой:", get_tree().current_scene.name if get_tree().current_scene else "нет")
	
	# Ждем немного чтобы сервер успел обработать
	await get_tree().create_timer(0.2).timeout
	
	# Загружаем игровой мир у клиента
	_load_game_scene()

func _load_game_scene():
	print("Загрузка игровой сцены...")
	print("Режим:", "Хост" if multiplayer.is_server() else "Клиент")
	
	# Скрываем лобби (и у хоста, и у клиентов)
	self.visible = false
	self.queue_free()  # Помечаем на удаление сразу
	
	# Загружаем игровой мир
	var game_scene = load("res://Scenes/Main/Game.tscn")
	if game_scene:
		print("Игровая сцена загружена, меняем сцену...")
		get_tree().change_scene_to_packed(game_scene)
		print("Смена сцены завершена")
	else:
		print("Ошибка: не удалось загрузить игровую сцену")
		_return_to_menu()

func _on_peer_connected(peer_id: int):
	print("Игрок подключился:", peer_id)
	if multiplayer.is_server():
		status_label.text = "Игрок подключен! Нажмите 'Начать игру'"
		if start_button:
			start_button.visible = true

func _on_peer_disconnected(peer_id: int):
	print("Игрок отключился:", peer_id)
	if multiplayer.is_server():
		status_label.text = "Игрок отключился"
		if start_button:
			start_button.visible = false

func _on_connected_to_server():
	print("Подключились к серверу")
	status_label.text = "Подключено! Ожидание начала игры..."

func _on_connection_failed():
	print("Не удалось подключиться к серверу")
	status_label.text = "Ошибка подключения!"
	await get_tree().create_timer(2.0).timeout
	_return_to_menu()

func _on_server_disconnected():
	print("Сервер отключился")
	status_label.text = "Сервер отключился!"
	await get_tree().create_timer(2.0).timeout
	_return_to_menu()

func _return_to_menu():
	print("Возвращаемся в меню...")
	
	# Отключаемся от сети
	NetworkingManager.disconnect_all()
	
	# Находим меню и показываем его
	var menu = get_tree().get_nodes_in_group("menu")
	if menu.size() > 0:
		menu[0].show_menu()
	else:
		# Если меню не найдено в группах, ищем по типу
		for child in get_tree().root.get_children():
			# Проверяем наличие свойства filename перед доступом к нему
			if child.is_in_group("menu"):
				child.show_menu()
				break
			elif child.has_method("show_menu"):
				# Если узел имеет метод show_menu, это вероятно меню
				child.show_menu()
				break
	
	# Удаляем лобби
	queue_free()
