# ShootingTrigger.gd - надежная версия
extends Area2D

@onready var status_label: Label

var ready_players = []
var minigame_active = false
var countdown_active = false
var is_server: bool

func _ready():
	is_server = multiplayer.is_server()
	
	# Создаем UI элементы
	_create_ui_elements()
	
	print("[SHOOTING ТРИГГЕР] Готов. Peer:", multiplayer.get_unique_id(), " Server:", is_server)

func _create_ui_elements():
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.position = Vector2(0, -80)
	status_label.custom_minimum_size = Vector2(200, 60)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.text = "Нажми E для игры в стрельбу\nГотовы: 0/2"
	add_child(status_label)

func _input(event):
	if event.is_action_pressed("interact") and not minigame_active and not countdown_active:
		var local_id = multiplayer.get_unique_id()
		print("[SHOOTING] Игрок", local_id, "нажал E")
		
		# Проверяем находится ли игрок в зоне
		var player_in_zone = false
		for body in get_overlapping_bodies():
			if body.name.is_valid_int() and int(body.name) == local_id:
				player_in_zone = true
				break
		
		if player_in_zone:
			print("[SHOOTING] Игрок в зоне, обрабатываем нажатие")
			if is_server:
				_toggle_player_ready(local_id)
			else:
				request_toggle_ready.rpc_id(1, local_id)

@rpc("any_peer", "reliable")
func request_toggle_ready(player_id):
	if multiplayer.is_server() and not minigame_active and not countdown_active:
		print("[SHOOTING СЕРВЕР] Запрос от игрока", player_id)
		_toggle_player_ready(player_id)

func _toggle_player_ready(player_id):
	if minigame_active or countdown_active:
		return
	
	if player_id in ready_players:
		ready_players.erase(player_id)
		print("[SHOOTING] Игрок", player_id, "снял готовность")
	else:
		ready_players.append(player_id)
		print("[SHOOTING] Игрок", player_id, "готов")
	
	# Обновляем всех
	_update_ui_for_all()
	
	# Если оба игрока готовы и это сервер
	if is_server and ready_players.size() >= 2:
		print("[SHOOTING] Оба игрока готовы! Начинаем отсчет")
		countdown_active = true
		_start_countdown()

func _update_ui_for_all():
	# Сервер обновляет всех, клиенты только себя
	if is_server:
		sync_ui.rpc(ready_players)
	_update_ui()

@rpc("call_local", "reliable")
func sync_ui(players_list):
	ready_players = players_list
	_update_ui()

func _update_ui():
	if status_label:
		if countdown_active:
			status_label.text = "Начинаем игру..."
		else:
			status_label.text = "Нажми E для игры в стрельбу\nГотовы: %d/2" % ready_players.size()

func _start_countdown():
	if not is_server:
		return
	
	print("[SHOOTING] Начинаем отсчет 3... 2... 1...")
	
	# Отсчет 3 секунды
	for i in range(3, 0, -1):
		_update_countdown(i)
		await get_tree().create_timer(1.0).timeout
	
	_update_countdown(0)
	await get_tree().create_timer(1.0).timeout
	
	# Запускаем игру
	_launch_game()

func _update_countdown(seconds):
	if is_server:
		update_countdown_display.rpc(seconds)

@rpc("call_local", "reliable")
func update_countdown_display(seconds):
	if seconds > 0:
		status_label.text = "Начинаем через %d..." % seconds
	else:
		status_label.text = "СТАРТ!"

func _launch_game():
	if not is_server:
		return
	
	print("[SHOOTING] Запускаем игру для всех игроков")
	minigame_active = true
	
	# Удаляем триггер с задержкой
	await get_tree().create_timer(0.5).timeout
	
	# Запускаем игру
	launch_minigame.rpc()

@rpc("call_local", "reliable")
func launch_minigame():
	print("[SHOOTING] Команда на запуск мини-игры получена")
	
	# Находим основную сцену Game
	var main_game = _find_main_game()
	if main_game and main_game.has_method("start_shooting_minigame"):
		print("[SHOOTING] Запускаем start_shooting_minigame")
		main_game.start_shooting_minigame()
	else:
		print("[SHOOTING ОШИБКА] Не могу найти основную игру!")
	
	# Удаляем триггер
	queue_free()

func _find_main_game():
	# Ищем сцену Game по разным путям
	var possible_paths = [
		"/root/Game",
		"/root/main/Game",
		get_tree().current_scene
	]
	
	for path in possible_paths:
		var node
		if path is String:
			node = get_tree().root.get_node_or_null(path)
		else:
			node = path
		
		if node and node.has_method("start_shooting_minigame"):
			return node
	
	# Пробуем найти среди дочерних узлов корня
	for child in get_tree().root.get_children():
		if child.has_method("start_shooting_minigame"):
			return child
	
	return null
