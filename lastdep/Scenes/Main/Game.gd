# Game.gd
extends Node2D

@onready var players_container: Node = $PlayersContainer
@onready var background_music = get_node("/root/BackgroundMusic")

const PLAYER_SCENE = preload("res://Player/Player.tscn")
var current_minigame = null
var minigame_active = false
var battleship_minigame_active = false
var minigame_queues = {}

# В Game.gd в функции add_minigame_triggers() замените на:
func add_minigame_triggers():
	# Создаем NPC для Memory игры
	create_npc("memory", Vector2(-100, -50))
	
	# Создаем NPC для Battleship игры
	create_npc("shooting", Vector2(105, -35))
	
	# Создаем NPC для Shooting игры
	create_npc("battleship", Vector2(250, -50))

func create_npc(minigame_type: String, position: Vector2):
	var npc_scene = preload("res://Scenes/Main/NPC.tscn")
	var npc = npc_scene.instantiate()
	
	npc.position = position
	npc.npc_name = "Ведущий " + minigame_type
	npc.minigame_type = minigame_type
	
	# Устанавливаем авторитет на сервер
	if multiplayer.is_server():
		npc.set_multiplayer_authority(1)
	
	add_child(npc)
	print("NPC для " + minigame_type + " создан на позиции:", position)
	
	return npc

func _ready():
	print("=== ИГРА ЗАПУЩЕНА ===")
	print("Мой peer_id:", multiplayer.get_unique_id())
	print("Это сервер?", multiplayer.is_server())
	
	# Включаем игровую музыку (трек 0)
	if background_music:
		background_music.start_game_music()
		print("Включена игровая музыка (трек 0)")
	
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

func _exit_tree():
	print("=== ИГРА ЗАВЕРШЕНА ===")
	# При выходе из игры возвращаемся к музыке меню
	if background_music:
		background_music.back_to_menu()
		print("Возврат к музыке меню")
	
func start_memory_minigame():
	print("=")
	print("GAME.GD: ЗАПУСК МИНИ-ИГРЫ ПАМЯТЬ")
	print("Сервер? ", multiplayer.is_server())
	print("Мой ID: ", multiplayer.get_unique_id())
	print("=")
	
	# Меняем музыку на трек 2 для Memory
	if background_music:
		background_music.play_game_2()
		print("Включена музыка для Memory (трек 2)")
		
	# И сервер, и клиент ДОЛЖНЫ создавать свою копию игры
	# Скрываем основную игру
	visible = false
	if players_container:
		players_container.visible = false
	set_process(false)
	
	if players_container:
		for player in players_container.get_children():
			player.set_process(false)
			player.set_physics_process(false)
	
	var memory_scene = preload("res://Scenes/Minigames/Memory/memory.tscn")
	if not memory_scene:
		print("ОШИБКА: Не могу загрузить сцену Memory!")
		_on_memory_game_over()
		return
	
	var game = memory_scene.instantiate()
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
	print("Мини-игра добавлена (peer: ", multiplayer.get_unique_id(), ")")

# Добавьте RPC функцию для синхронизации:
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

func _on_memory_game_over():
	print("=")
	print("GAME.GD: _on_memory_game_over ВЫЗВАНА")
	print("Время: ", Time.get_time_string_from_system())
	print("=")
	
	# Возвращаем музыку к треку 0 (основная игровая)
	if background_music:
		background_music.play_game_0()
		print("Возвращена основная игровая музыка (трек 0)")
	
	if current_minigame and is_instance_valid(current_minigame):
		print("Удаляю мини-игру...")
		current_minigame.queue_free()
		current_minigame = null
	
	visible = true
	players_container.visible = true
	set_process(true)
	
	for player in players_container.get_children():
		player.set_process(true)
		player.set_physics_process(true)
		player.visible = true
	
	print("ВОЗВРАТ В ОСНОВНУЮ ИГРУ ЗАВЕРШЕН")

func return_to_game():
	print("Аварийный возврат в игру")
	_on_memory_game_over()


@rpc("authority", "call_remote", "reliable")
func end_minigame():
	minigame_active = false
	
		# Принудительный возврат музыки
	if background_music:
		background_music.play_game_0()
		
	if current_minigame:
		current_minigame.queue_free()
		current_minigame = null
	
	players_container.visible = true
	
	for player in players_container.get_children():
		player.set_process(true)
		player.set_physics_process(true)

func _input(event):
	if event.is_action_pressed("ui_cancel") and minigame_active:
		end_minigame.rpc_id(1) 
		
func start_battleship_minigame():
	print("=")
	print("GAME.GD: ЗАПУСК МИНИ-ИГРЫ 'ПОИСК ФЕЙВЕРКОВ'")
	print("=")
	
	# Меняем музыку на трек 1 для Battleship
	if background_music:
		background_music.play_game_1()
		print("Включена музыка для Battleship (трек 1)")
	
	visible = false
	players_container.visible = false
	
	set_process(false)
	for player in players_container.get_children():
		player.set_process(false)
		player.set_physics_process(false)
	
	var battleship_scene = preload("res://Scenes/Minigames/Battleship/Battleship.tscn")
	if not battleship_scene:
		print("ОШИБКА: Не могу загрузить сцену Battleship!")
		return
	
	var game = battleship_scene.instantiate()
	game.name = "BattleshipGame"
	
	print("Подключаю сигнал game_over...")
	
	if game.has_signal("game_over"):
		game.game_over.connect(func(): 
			print("!!! СИГНАЛ game_over ПОЛУЧЕН В GAME.GD !!!")
			_on_battleship_game_over()
		)
		print("Сигнал подключен")
	else:
		print("ОШИБКА: Сигнал game_over не найден в мини-игре!")
		get_tree().create_timer(300.0).timeout.connect(
			func(): 
				print("АВТО-ВОЗВРАТ по таймауту")
				_on_battleship_game_over()
		)
	
	add_child(game)
	current_minigame = game
	print("Мини-игра 'Поиск фейверков' добавлена")

func _on_battleship_game_over():
	print("=")
	print("GAME.GD: _on_battleship_game_over ВЫЗВАНА")
	print("=")
	
	# Возвращаем музыку к треку 0 (основная игровая)
	if background_music:
		background_music.play_game_0()
		print("Возвращена основная игровая музыка (трек 0)")
	
	if current_minigame and is_instance_valid(current_minigame):
		print("Удаляю мини-игру 'Поиск фейверков'...")
		current_minigame.queue_free()
		current_minigame = null
	
	visible = true
	players_container.visible = true
	set_process(true)
	
	for player in players_container.get_children():
		player.set_process(true)
		player.set_physics_process(true)
		player.visible = true
	
	print("ВОЗВРАТ В ОСНОВНУЮ ИГРУ ЗАВЕРШЕН")
	
func start_shooting_minigame():
	print("=")
	print("GAME.GD: ЗАПУСК СТРЕЛЬБЫ")
	print("Текущая сцена:", get_tree().current_scene.name)
	print("Мой ID:", multiplayer.get_unique_id())
	print("=")
	
	# Меняем музыку на трек 3 для Shooting
	if background_music:
		background_music.play_game_3()
		print("Включена музыка для Shooting (трек 3)")
	
	visible = false
	if players_container:
		players_container.visible = false
	set_process(false)
	
	for player in players_container.get_children():
		player.set_process(false)
		player.set_physics_process(false)
	
	var shooting_scene_path = "res://Scenes/Minigames/Shooting/Shooting.tscn"
	print("Пробую загрузить:", shooting_scene_path)
	
	if ResourceLoader.exists(shooting_scene_path):
		var shooting_scene = load(shooting_scene_path)
		var game_instance = shooting_scene.instantiate()
		game_instance.name = "ShootingGame"
		
		if game_instance.has_signal("game_over"):
			game_instance.game_over.connect(_on_shooting_game_over)
			print("Сигнал game_over подключен")
		else:
			print("ВНИМАНИЕ: Сигнал game_over не найден!")
			# Создаем таймер для авто-возврата
			var timer = get_tree().create_timer(60.0)
			timer.timeout.connect(_on_shooting_game_over)
		
		add_child(game_instance)
		current_minigame = game_instance
		print("Мини-игра добавлена успешно!")
	else:
		print("ОШИБКА: Не могу найти файл сцены!")
		_on_shooting_game_over()

func _on_shooting_game_over():
	print("=")
	print("GAME.GD: ВОЗВРАТ ИЗ СТРЕЛЬБЫ")
	print("=")

	# Возвращаем музыку к треку 0 (основная игровая)
	if background_music:
		background_music.play_game_0()
		print("Возвращена основная игровая музыка (трек 0)")
	
	if current_minigame and is_instance_valid(current_minigame):
		current_minigame.queue_free()
		current_minigame = null
	
	visible = true
	if players_container:
		players_container.visible = true
	set_process(true)
	
	for player in players_container.get_children():
		player.set_process(true)
		player.set_physics_process(true)
		player.visible = true
	
	print("Возврат в основную игру завершен")

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
