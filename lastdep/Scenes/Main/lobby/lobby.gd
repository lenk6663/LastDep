# lobby.gd
extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var ip_label: Label = $VBoxContainer/IPLabel
@onready var cancel_button: Button = $VBoxContainer/CancelButton
@onready var start_button: Button = $VBoxContainer/StartButton

# Параметры от меню
var mode: String = "host"
var target_ip: String = ""

func _ready():
	print("Лобби запущено в режиме:", mode)
	
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
		
		# Сначала синхронизируем список игроков
		sync_player_list.rpc()
		sync_player_list()  # И локально
		
		# Ждем немного
		await get_tree().create_timer(0.1).timeout
		
		# Затем запускаем игру
		_start_game_local()
		
		# Потом отправляем команду клиентам
		start_game.rpc()
	else:
		print("Только хост может начать игру")

@rpc("authority", "call_remote", "reliable")
func start_game():
	print("Клиент получает команду начать игру")
	
	# Ждем немного чтобы сервер успел обработать
	await get_tree().create_timer(0.1).timeout
	
	# Загружаем игровой мир
	var game_scene = load("res://Scenes/Main/Game.tscn")
	if game_scene:
		get_tree().change_scene_to_packed(game_scene)
	else:
		print("Ошибка: не удалось загрузить игровую сцену")

func _start_game_local():
	print("Локальный запуск игры...")
	
	# Ждем немного
	await get_tree().create_timer(0.1).timeout
	
	# Загружаем игровой мир
	var game_scene = load("res://Scenes/Main/Game.tscn")
	if game_scene:
		get_tree().change_scene_to_packed(game_scene)
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
