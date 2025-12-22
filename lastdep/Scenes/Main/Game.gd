# Game.gd
extends Node2D

@onready var players_container: Node = $PlayersContainer
const PLAYER_SCENE = preload("res://Player/Player.tscn")
var current_minigame = null
var minigame_active = false
var battleship_minigame_active = false

func _ready():
	print("=== ИГРА ЗАПУЩЕНА ===")
	print("Мой peer_id:", multiplayer.get_unique_id())
	print("Это сервер?", multiplayer.is_server())
	
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
	
func start_memory_minigame():
	print("=")
	print("GAME.GD: ЗАПУСК МИНИ-ИГРЫ")
	print("=")
	
	visible = false
	players_container.visible = false
	
	set_process(false)
	for player in players_container.get_children():
		player.set_process(false)
		player.set_physics_process(false)
	
	var memory_scene = preload("res://Scenes/MiniGames/Memory/Memory.tscn")
	if not memory_scene:
		print("ОШИБКА: Не могу загрузить сцену Memory!")
		return
	
	var game = memory_scene.instantiate()
	game.name = "MemoryGame"
	print("Подключаю сигнал game_over...")
	
	if game.has_signal("game_over"):
		game.game_over.connect(func(): 
			print("!!! СИГНАЛ game_over ПОЛУЧЕН В GAME.GD !!!")
			_on_memory_game_over()
		)
		print("Сигнал подключен через лямбду")
	else:
		print("ОШИБКА: Сигнал game_over не найден в мини-игре!")
		get_tree().create_timer(300.0).timeout.connect(
			func(): 
				print("АВТО-ВОЗВРАТ по таймауту")
				_on_memory_game_over()
		)
	
	add_child(game)
	current_minigame = game
	print("Мини-игра добавлена")

func _on_memory_game_over():
	print("=")
	print("GAME.GD: _on_memory_game_over ВЫЗВАНА")
	print("Время: ", Time.get_time_string_from_system())
	print("=")
	
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
