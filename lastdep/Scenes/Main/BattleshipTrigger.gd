# BattleshipTrigger.gd
extends Area2D

@onready var status_label: Label
@onready var timer: Timer

var ready_players = []
var minigame_active = false
var all_players_ready = false

func _ready():
	set_process_input(true)
	
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event = InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event("interact", event)
	
	_create_ui_elements()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("[BATTLESHIP ТРИГГЕР] Готов. Peer:", multiplayer.get_unique_id())

func _create_ui_elements():
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.position = Vector2(0, -80)
	status_label.custom_minimum_size = Vector2(200, 60)
	status_label.add_theme_font_size_override("font_size", 16)
	add_child(status_label)
	
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
			text = "Начинаем поиск фейверков..."
		else:
			text = "Игра активна"
	else:
		text = "Нажми E для поиска фейверков\nГотовы: %d/2" % ready_players.size()
	
	status_label.text = text

func _input(event):
	if event.is_action_pressed("interact") and not minigame_active:
		var local_id = multiplayer.get_unique_id()
		print("[BATTLESHIP ВВОД] Игрок", local_id, "нажал E")
		
		for body in get_overlapping_bodies():
			if body.name.is_valid_int() and int(body.name) == local_id:
				if multiplayer.is_server():
					toggle_player_ready(local_id)
				else:
					request_toggle_ready.rpc_id(1, local_id)
				return

@rpc("any_peer", "call_local", "reliable")
func request_toggle_ready(player_id):
	if multiplayer.is_server() and not minigame_active:
		print("[BATTLESHIP СЕРВЕР] Запрос от игрока", player_id)
		toggle_player_ready(player_id)

func toggle_player_ready(player_id):
	if minigame_active or player_id in ready_players and ready_players.size() >= 2:
		return
	
	if player_id in ready_players:
		ready_players.erase(player_id)
		print("[BATTLESHIP СЕРВЕР] Игрок", player_id, "снял готовность")
	else:
		ready_players.append(player_id)
		print("[BATTLESHIP СЕРВЕР] Игрок", player_id, "готов")
	
	sync_ready_players.rpc(ready_players)
	
	if multiplayer.is_server() and ready_players.size() >= 2 and not minigame_active:
		print("[BATTLESHIP СЕРВЕР] Оба игрока готовы!")
		minigame_active = true
		all_players_ready = true
		start_countdown.rpc()

@rpc("authority", "call_local", "reliable")
func sync_ready_players(players_list):
	print("[BATTLESHIP СИНХРО] Список игроков:", players_list)
	ready_players = players_list
	update_status_display()

@rpc("authority", "call_local", "reliable")
func start_countdown():
	print("[BATTLESHIP ОТСЧЕТ] Начинаем обратный отсчет")
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
	print("[BATTLESHIP ЗАПУСК] Запуск поиска фейверков для всех")
	status_label.text = "Запуск игры..."
	
	await get_tree().create_timer(0.5).timeout
	queue_free()
	
	var game = get_tree().current_scene
	if game and game.has_method("start_battleship_minigame"):
		game.start_battleship_minigame()

func _on_timer_timeout():
	pass

func _on_body_entered(body):
	if body.name.is_valid_int():
		print("Игрок вошел в зону поиска фейверков:", body.name)

func _on_body_exited(body):
	if body.name.is_valid_int():
		print("Игрок вышел из зоны поиска фейверков:", body.name)
