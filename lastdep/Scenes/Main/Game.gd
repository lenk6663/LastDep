# Game.gd
extends Node2D

# ============== КОНСТАНТЫ ==============
@onready var players_container: Node = $PlayersContainer
const PLAYER_SCENE = preload("res://Player/Player.tscn")
const NPC_SCENE = preload("res://Scenes/Main/NPC.tscn")
const MEMORY_SCENE = preload("res://Scenes/Minigames/Memory/memory.tscn")
const SHOOTING_SCENE = preload("res://Scenes/Minigames/Shooting/Shooting.tscn")
const BATTLESHIP_SCENE = preload("res://Scenes/Minigames/Battleship/Battleship.tscn")

# ============== ТАБЛО ПОБЕД ==============
@onready var title_label: Label = $UI/Panel/TitleLabel
@onready var player1_label: Label = $UI/Panel/Player1WinsLabel
@onready var player2_label: Label = $UI/Panel/Player2WinsLabel

var player_wins: Dictionary = {1: 0, 2: 0}  # Счетчик побед по игрокам
var score_updated_this_game: bool = false
# ============== ПЕРЕМЕННЫЕ ==============
var current_minigame = null
var minigame_active = false
var minigame_queues = {}

# ============== ОСНОВНЫЕ ФУНКЦИИ ==============
func _ready():
	print("=== ИГРА ЗАПУЩЕНА ===")
	print("Мой peer_id:", multiplayer.get_unique_id())
	print("Это сервер?", multiplayer.is_server())
	init_scoreboard()
	var my_spawn_pos = NetworkingManager.get_spawn_position(multiplayer.get_unique_id())
	print("Моя позиция спавна:", my_spawn_pos)
	
	create_player(multiplayer.get_unique_id(), my_spawn_pos)
	
	if multiplayer.is_server():
		print("Хост: создаю игроков для подключенных клиентов")
		await get_tree().create_timer(0.3).timeout
		
		for peer_id in multiplayer.get_peers():
			if not players_container.has_node(str(peer_id)):
				var client_spawn_pos = NetworkingManager.get_spawn_position(peer_id)
				print("Хост: создаю игрока для клиента", peer_id, " в позиции:", client_spawn_pos)
				create_player(peer_id, client_spawn_pos)
	
	if not multiplayer.is_server():
		print("Клиент: создаю игрока хоста")
		await get_tree().create_timer(0.3).timeout
		
		var host_spawn_pos = NetworkingManager.get_spawn_position(1)
		create_player(1, host_spawn_pos)
		
	add_minigame_triggers()
	
func init_scoreboard():
	# Обновляем начальные значения табло
	update_scoreboard_display()

@rpc("authority", "call_remote", "reliable")
func sync_scores(wins1: int, wins2: int):
	player_wins[1] = wins1
	player_wins[2] = wins2
	update_scoreboard_display()

func _exit_tree():
	print("=== ИГРА ЗАВЕРШЕНА ===")

# ============== УПРАВЛЕНИЕ ИГРОКАМИ ==============
func create_player(peer_id: int, position: Vector2):
	print("Создание игрока:", peer_id, " в позиции:", position)
	
	if players_container.has_node(str(peer_id)):
		print("Игрок уже существует:", peer_id)
		return
	
	var player_instance = PLAYER_SCENE.instantiate()
	player_instance.name = str(peer_id)
	player_instance.position = position
	player_instance.set_multiplayer_authority(peer_id)
	
	players_container.add_child(player_instance, true)
	print("Игрок создан:", peer_id, " Authority:", player_instance.is_multiplayer_authority())

func remove_player(peer_id: int):
	print("Удаление игрока:", peer_id)
	
	var player_node = players_container.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
		print("Игрок удален:", peer_id)

# ============== NPC И ТРИГГЕРЫ МИНИ-ИГР ==============
func add_minigame_triggers():
	# Создаем NPC для Memory игры
	create_npc("memory", Vector2(-100, -50))
	
	# Создаем NPC для Shooting игры
	create_npc("shooting", Vector2(105, -35))
	
	# Создаем NPC для Battleship игры
	create_npc("battleship", Vector2(250, -50))

func create_npc(minigame_type: String, position: Vector2):
	var npc = NPC_SCENE.instantiate()
	npc.position = position
	npc.npc_name = "Ведущий " + minigame_type
	npc.minigame_type = minigame_type
	
	if multiplayer.is_server():
		npc.set_multiplayer_authority(1)
	
	add_child(npc)
	print("NPC для " + minigame_type + " создан на позиции:", position)
	
	return npc

# ============== ФУНКЦИИ ЗАПУСКА МИНИ-ИГР ==============
func start_memory_minigame():
	print("=")
	print("GAME.GD: ЗАПУСК МИНИ-ИГРЫ ПАМЯТЬ")
	print("Сервер? ", multiplayer.is_server())
	print("Мой ID: ", multiplayer.get_unique_id())
	print("=")
	
	# Скрываем основную игру
	visible = false
	if players_container:
		players_container.visible = false
	set_process(false)
	
	if players_container:
		for player in players_container.get_children():
			player.set_process(false)
			player.set_physics_process(false)
	
	# Загружаем и создаем игру
	if not MEMORY_SCENE:
		print("ОШИБКА: Не могу загрузить сцену Memory!")
		_on_memory_game_over()
		return
	
	var game = MEMORY_SCENE.instantiate()
	game.name = "MemoryGame"
	
	print("Подключаю сигнал game_over...")
	
	# Подключаем сигнал
	var callable = Callable(self, "_on_memory_game_over")
	if game.has_signal("game_over"):
		game.game_over.connect(callable)
		print("Сигнал game_over подключен")
	else:
		print("ОШИБКА: Сигнал game_over не найден!")
		game.add_user_signal("game_over")
	
	add_child(game)
	current_minigame = game
	minigame_active = true
	print("Мини-игра Memory добавлена (peer: ", multiplayer.get_unique_id(), ")")

func start_shooting_minigame():
	print("=")
	print("GAME.GD: ЗАПУСК МИНИ-ИГРЫ СТРЕЛЬБА")
	print("Сервер? ", multiplayer.is_server())
	print("Мой ID: ", multiplayer.get_unique_id())
	print("=")
	
	# Скрываем основную игру
	visible = false
	if players_container:
		players_container.visible = false
	
	hide_scoreboard()
	set_process_input(false)
	set_process(false)
	
	if players_container:
		for player in players_container.get_children():
			player.set_process(false)
			player.set_physics_process(false)
	
	if not SHOOTING_SCENE:
		print("ОШИБКА: Не могу загрузить сцену Shooting!")
		_on_shooting_game_over()
		return
	
	var game = SHOOTING_SCENE.instantiate()
	game.name = "ShootingGame"
	
	print("Подключаю сигнал game_over...")
	
	# Подключаем сигнал
	var callable = Callable(self, "_on_shooting_game_over")
	if game.has_signal("game_over"):
		game.game_over.connect(callable)
		print("Сигнал game_over подключен")
	else:
		print("ОШИБКА: Сигнал game_over не найден!")
		game.add_user_signal("game_over")
	
	add_child(game)
	
	# ВКЛЮЧАЕМ обработку ввода в самой мини-игре
	game.set_process_input(true)
	game.set_process_unhandled_input(true)
	game.set_process(true)
	game.set_physics_process(true)
	
	current_minigame = game
	minigame_active = true
	
	print("Мини-игра Shooting добавлена (peer: ", multiplayer.get_unique_id(), ")")

func start_battleship_minigame():
	print("=")
	print("GAME.GD: ЗАПУСК МИНИ-ИГРЫ 'ПОИСК ФЕЙВЕРКОВ'")
	print("Сервер? ", multiplayer.is_server())
	print("Мой ID: ", multiplayer.get_unique_id())
	print("=")
	
	# Скрываем основную игру
	visible = false
	if players_container:
		players_container.visible = false
	set_process(false)
	hide_scoreboard()
	if players_container:
		for player in players_container.get_children():
			player.set_process(false)
			player.set_physics_process(false)
	
	# Загружаем и создаем игру
	if not BATTLESHIP_SCENE:
		print("ОШИБКА: Не могу загрузить сцену Battleship!")
		_on_battleship_game_over()
		return
	
	var game = BATTLESHIP_SCENE.instantiate()
	game.name = "BattleshipGame"
	
	print("Подключаю сигнал game_over...")
	
	# Подключаем сигнал
	var callable = Callable(self, "_on_battleship_game_over")
	if game.has_signal("game_over"):
		game.game_over.connect(callable)
		print("Сигнал game_over подключен")
	else:
		print("ОШИБКА: Сигнал game_over не найден!")
		game.add_user_signal("game_over")
	
	add_child(game)
	current_minigame = game
	minigame_active = true
	print("Мини-игра Battleship добавлена (peer: ", multiplayer.get_unique_id(), ")")

# ============== ФУНКЦИИ ВОЗВРАТА ИЗ МИНИ-ИГР ==============
func _on_memory_game_over():
	print("=")
	print("GAME.GD: _on_memory_game_over ВЫЗВАНА")
	print("Время: ", Time.get_time_string_from_system())
	print("=")
	
	if multiplayer.is_server():
		# Сервер определяет победителя сам
		var winner_id = determine_winner_from_memory()
		if winner_id > 0:
			update_scoreboard(winner_id)
	else:
		# Клиент отправляет результат на сервер
		var winner_id = determine_winner_from_memory()
		if winner_id > 0:
			report_game_result.rpc_id(1, "memory", winner_id)
	
	# Все равно очищаем игру
	if current_minigame and is_instance_valid(current_minigame):
		print("Удаляю мини-игру Memory...")
		current_minigame.queue_free()
		current_minigame = null
	
	restore_main_game()

func _on_shooting_game_over():
	print("=")
	print("GAME.GD: _on_shooting_game_over ВЫЗВАНА")
	print("Время: ", Time.get_time_string_from_system())
	print("=")
	
	if multiplayer.is_server():
		# Сервер определяет победителя сам
		var winner_id = determine_winner_from_shooting()
		if winner_id > 0:
			update_scoreboard(winner_id)
	else:
		# Клиент отправляет результат на сервер
		var winner_id = determine_winner_from_shooting()
		if winner_id > 0:
			report_game_result.rpc_id(1, "shooting", winner_id)
	
	# Все равно очищаем игру
	if current_minigame and is_instance_valid(current_minigame):
		print("Удаляю мини-игру Shooting...")
		current_minigame.queue_free()
		current_minigame = null
	
	restore_main_game()

func _on_battleship_game_over():
	print("=")
	print("GAME.GD: _on_battleship_game_over ВЫЗВАНА")
	print("Время: ", Time.get_time_string_from_system())
	print("=")
	
	# Только клиент отправляет результат на сервер
	if not multiplayer.is_server():
		var winner_id = determine_winner_from_battleship()
		if winner_id > 0:
			# Клиент отправляет результат серверу
			report_game_result.rpc_id(1, "battleship", winner_id)
	
	# Все равно очищаем игру
	if current_minigame and is_instance_valid(current_minigame):
		print("Удаляю мини-игру Battleship...")
		current_minigame.queue_free()
		current_minigame = null
	
	restore_main_game()

# ============== ФУНКЦИИ ОПРЕДЕЛЕНИЯ ПОБЕДИТЕЛЯ ==============
func determine_winner_from_memory() -> int:
	if not current_minigame:
		return 0
	
	# Пытаемся получить данные из мини-игры
	if current_minigame.has_method("get_winner_id"):
		return current_minigame.get_winner_id()
	
	# Пытаемся получить из метаданных
	if current_minigame.has_meta("winner_id"):
		return current_minigame.get_meta("winner_id")
	
	# Пытаемся получить из переменных игры
	if current_minigame.has_node("GridContainer") and current_minigame.get_node("GridContainer").has_method("get_winner_id"):
		return current_minigame.get_node("GridContainer").get_winner_id()
	
	return 0  # Ничья или ошибка

func determine_winner_from_shooting() -> int:
	if not current_minigame:
		return 0
	
	# Пытаемся получить данные из мини-игры
	if current_minigame.has_method("get_winner_id"):
		return current_minigame.get_winner_id()
	
	# Пытаемся получить из метаданных
	if current_minigame.has_meta("winner_id"):
		return current_minigame.get_meta("winner_id")
	
	return 0  # Ничья или ошибка

func determine_winner_from_battleship() -> int:
	if not current_minigame:
		return 0
	
	# Пытаемся получить данные из мини-игры
	if current_minigame.has_method("get_winner_id"):
		return current_minigame.get_winner_id()
	
	# Пытаемся получить из метаданных
	if current_minigame.has_meta("winner_id"):
		return current_minigame.get_meta("winner_id")
	
	return 0  # Ничья или ошибка

func restore_main_game():
	print("Восстанавливаю основную игру...")
	
	# Если мини-игра еще существует, удаляем ее
	if current_minigame and is_instance_valid(current_minigame):
		print("Удаляю мини-игру...")
		current_minigame.queue_free()
		current_minigame = null
	
	# Сбрасываем флаг обновления счета
	score_updated_this_game = false
	
	# Показываем основную игру
	visible = true
	if players_container:
		players_container.visible = true
	
	# Показываем табло
	show_scoreboard()
	
	# Возобновляем обработку ввода
	set_process_input(true)
	set_process(true)
	set_physics_process(true)
	
	# Возобновляем игроков
	if players_container:
		for player in players_container.get_children():
			player.set_process(true)
			player.set_physics_process(true)
			player.visible = true
	
	minigame_active = false
	print("Основная игра восстановлена")

# ============== RPC СИНХРОНИЗАЦИЯ ==============
@rpc("any_peer", "call_local", "reliable")
func report_game_result(game_type: String, winner_id: int):
	if multiplayer.is_server():
		print("Сервер получил результат игры ", game_type, " от игрока ", multiplayer.get_remote_sender_id())
		print("Победитель: Игрок ", winner_id)
		
		# Проверяем, чтобы winner_id был валидным (1 или 2)
		if winner_id not in [1, 2]:
			print("ОШИБКА: Неверный winner_id:", winner_id)
			return
		
		# Обновляем счет на сервере
		player_wins[winner_id] += 1
		print("Обновление счета на сервере: Игрок %d теперь имеет %d побед" % [winner_id, player_wins[winner_id]])
		
		# Обновляем отображение на сервере
		update_scoreboard_display()
		
		# Синхронизируем с клиентами
		sync_scores_to_clients.rpc(player_wins[1], player_wins[2])
			
@rpc("authority", "call_local", "reliable")
func start_minigame_on_client(minigame_type: String):
	if multiplayer.is_server():
		return  # Сервер уже создал игру
	
	print("КЛИЕНТ: получаю команду запустить ", minigame_type)
	
	match minigame_type:
		"memory":
			start_memory_minigame()
		"battleship":
			start_battleship_minigame()
		"shooting":
			start_shooting_minigame()

@rpc("authority", "call_local", "reliable")
func end_minigame_on_client():
	if multiplayer.is_server():
		return
	
	print("КЛИЕНТ: получаю команду завершить мини-игру")
	restore_main_game()

# ============== ОБРАБОТКА ВВОДА ==============
func _input(event):
	if event.is_action_pressed("ui_cancel") and minigame_active:
		print("Аварийный выход из мини-игры")
		
		if multiplayer.is_server():
			end_minigame_on_client.rpc()
		
		restore_main_game()

# ============== ДОПОЛНИТЕЛЬНЫЕ ФУНКЦИИ ==============
@rpc("authority", "call_remote", "reliable")
func sync_memory_game_state(is_active: bool, current_player: int, game_data: Array):
	if not multiplayer.is_server():
		print("КЛИЕНТ: получено состояние игры. Активна:", is_active, " Текущий игрок:", current_player)
		
		# Проверяем, создана ли уже игра на клиенте
		if not current_minigame:
			print("КЛИЕНТ: создаю локальную копию игры для отображения")
			var memory_scene = preload("res://Scenes/Minigames/Memory/memory.tscn")
			if memory_scene:
				var game = memory_scene.instantiate()
				game.name = "MemoryGame"
				add_child(game)
				current_minigame = game
				
				# Подключаем сигнал завершения
				if game.has_signal("game_over"):
					game.game_over.connect(Callable(self, "_on_memory_game_over"))
		
		# Обновляем состояние игры на клиенте
		if current_minigame and current_minigame.has_method("update_game_state"):
			current_minigame.update_game_state(is_active, current_player, game_data)

@rpc("authority", "call_remote", "reliable")
func sync_minigame_start(minigame_type: String, players: Array):
	print("СИНХРОНИЗАЦИЯ ЗАПУСКА: ", minigame_type, " для игроков: ", players)
	
	match minigame_type:
		"memory":
			start_memory_minigame()
		"battleship":
			start_battleship_minigame()
		"shooting":
			start_shooting_minigame()

func queue_minigame_start(minigame_type: String, players: Array):
	if multiplayer.is_server():
		print("СЕРВЕР: Ставлю в очередь мини-игру ", minigame_type)
		minigame_queues[minigame_type] = players
		sync_minigame_start.rpc(minigame_type, players)
		# Запускаем локально на сервере
		match minigame_type:
			"memory":
				start_memory_minigame()
			"battleship":
				start_battleship_minigame()
			"shooting":
				start_shooting_minigame()
				

func update_scoreboard_display():
	if title_label:
		title_label.text = "Победы в минииграх:"
	
	if player1_label:
		player1_label.text = "Игрок 1: %d" % player_wins.get(1, 0)
	
	if player2_label:
		player2_label.text = "Игрок 2: %d" % player_wins.get(2, 0)
	
	print("Табло обновлено: Игрок 1=%d, Игрок 2=%d" % [player_wins.get(1, 0), player_wins.get(2, 0)])

func hide_scoreboard():
	# Скрываем весь UI
	var ui = get_node_or_null("UI")
	if ui:
		ui.visible = false
		print("UI скрыт")
	else:
		print("UI не найден для скрытия")

func show_scoreboard():
	# Показываем весь UI
	var ui = get_node_or_null("UI")
	if ui:
		ui.visible = true
		print("UI показан")
	else:
		print("UI не найден для показа")

@rpc("authority", "call_remote", "reliable")
func sync_scores_to_clients(wins1: int, wins2: int):
	# Только обновляем данные, если мы на клиенте
	if not multiplayer.is_server():
		player_wins[1] = wins1
		player_wins[2] = wins2
		update_scoreboard_display()
		print("Клиент получил обновленные счета: ", wins1, ", ", wins2)

func update_scoreboard(winner_id: int):
	if winner_id in player_wins:
		player_wins[winner_id] += 1
		print("Обновление счета: Игрок %d теперь имеет %d побед" % [winner_id, player_wins[winner_id]])
	
	# Обновляем отображение
	update_scoreboard_display()
	
	# Синхронизируем со всеми клиентами (только сервер делает это)
	if multiplayer.is_server():
		print("Сервер: синхронизирую счета с клиентами")
		sync_scores_to_clients.rpc(player_wins[1], player_wins[2])

func get_player_wins() -> Dictionary:
	return player_wins.duplicate()
