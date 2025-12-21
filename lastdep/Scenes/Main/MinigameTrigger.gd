# MinigameTrigger.gd - полная исправленная версия
extends Area2D

@onready var status_label: Label
@onready var timer: Timer

var ready_players = []  # Будет синхронизироваться через RPC
var minigame_active = false
var all_players_ready = false

func _ready():
	# Включаем обработку ввода
	set_process_input(true)
	
	# Создаем действие если нет
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event = InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event("interact", event)
	
	# Создаем UI элементы если их нет
	_create_ui_elements()
	
	# Подключаем сигналы
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("[ТРИГГЕР] Готов. Peer:", multiplayer.get_unique_id(), " Сервер:", multiplayer.is_server())

func _create_ui_elements():
	# Создаем Label для статуса
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.position = Vector2(0, -80)
	status_label.custom_minimum_size = Vector2(200, 60)
	status_label.add_theme_font_size_override("font_size", 16)
	add_child(status_label)
	
	# Создаем таймер
	timer = Timer.new()
	timer.name = "Timer"
	timer.wait_time = 1.0
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)
	
	update_status_display()

func update_status_display():
	if not status_label:
		return
	
	var text = ""
	if minigame_active:
		if all_players_ready:
			text = "Начинаем игру..."
		else:
			text = "Игра активна"
	else:
		text = "Нажми E\nГотовы: %d/2" % ready_players.size()
	
	status_label.text = text

func _input(event):
	if event.is_action_pressed("interact") and not minigame_active:
		var local_id = multiplayer.get_unique_id()
		print("[ВВОД] Игрок", local_id, "нажал E")
		
		# Проверяем в зоне ли игрок
		for body in get_overlapping_bodies():
			if body.name.is_valid_int() and int(body.name) == local_id:
				print("[ВВОД] Игрок в зоне, отправляем на сервер")
				
				if multiplayer.is_server():
					toggle_player_ready(local_id)
				else:
					# Клиент отправляет серверу
					request_toggle_ready.rpc_id(1, local_id)
				return

@rpc("any_peer", "call_local", "reliable")
func request_toggle_ready(player_id):
	if multiplayer.is_server() and not minigame_active:
		print("[СЕРВЕР] Получен запрос от игрока", player_id)
		toggle_player_ready(player_id)

func toggle_player_ready(player_id):
	if minigame_active or player_id in ready_players and ready_players.size() >= 2:
		return
	
	if player_id in ready_players:
		# Убираем готовность
		ready_players.erase(player_id)
		print("[СЕРВЕР] Игрок", player_id, "снял готовность")
	else:
		# Добавляем готовность
		ready_players.append(player_id)
		print("[СЕРВЕР] Игрок", player_id, "готов")
	
	# Синхронизируем со всеми
	sync_ready_players.rpc(ready_players)
	
	# Проверяем можно ли начать
	if multiplayer.is_server() and ready_players.size() >= 2 and not minigame_active:
		print("[СЕРВЕР] Оба игрока готовы!")
		minigame_active = true
		all_players_ready = true
		start_countdown.rpc()

@rpc("authority", "call_local", "reliable")
func sync_ready_players(players_list):
	print("[СИНХРО] Получен список игроков:", players_list)
	ready_players = players_list
	update_status_display()

@rpc("authority", "call_local", "reliable")
func start_countdown():
	print("[ОТСЧЕТ] Начинаем обратный отсчет")
	minigame_active = true
	all_players_ready = true
	
	timer.start(1.0)
	countdown_step(3)

func countdown_step(step):
	if step > 0:
		update_countdown_display.rpc(step)
		await get_tree().create_timer(1.0).timeout
		countdown_step(step - 1)
	else:
		update_countdown_display.rpc(0)
		await get_tree().create_timer(1.0).timeout
		start_minigame_for_all.rpc()

@rpc("authority", "call_local", "reliable")
func update_countdown_display(step):
	if step > 0:
		status_label.text = "Начинаем через %d..." % step
	else:
		status_label.text = "Старт!"

@rpc("authority", "call_local", "reliable")
func start_minigame_for_all():
	print("[ЗАПУСК] Запуск мини-игры для всех")
	status_label.text = "Запуск игры..."
	
	# Даем время для отображения
	await get_tree().create_timer(0.5).timeout
	
	# Удаляем триггер
	queue_free()
	
	# Запускаем мини-игру
	var game = get_tree().current_scene
	if game and game.has_method("start_memory_minigame"):
		game.start_memory_minigame()

func _on_timer_timeout():
	# Таймер для обратного отсчета
	pass

func _on_body_entered(body):
	if body.name.is_valid_int():
		print("Игрок вошел:", body.name)

func _on_body_exited(body):
	if body.name.is_valid_int():
		print("Игрок вышел:", body.name)
