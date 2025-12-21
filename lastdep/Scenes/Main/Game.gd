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
	
	# Получаем позицию спавна из NetworkingManager
	var my_spawn_pos = NetworkingManager.get_spawn_position(multiplayer.get_unique_id())
	print("Моя позиция спавна:", my_spawn_pos)
	
	# Создаем своего игрока
	create_player(multiplayer.get_unique_id(), my_spawn_pos)
	
	# Если мы хост, создаем игроков для всех подключенных клиентов
	if multiplayer.is_server():
		print("Хост: создаю игроков для подключенных клиентов")
		await get_tree().create_timer(0.3).timeout
		
		for peer_id in multiplayer.get_peers():
			if not players_container.has_node(str(peer_id)):
				var client_spawn_pos = NetworkingManager.get_spawn_position(peer_id)
				print("Хост: создаю игрока для клиента", peer_id, " в позиции:", client_spawn_pos)
				create_player(peer_id, client_spawn_pos)
	
	# Если мы клиент, создаем игрока хоста
	if not multiplayer.is_server():
		print("Клиент: создаю игрока хоста")
		await get_tree().create_timer(0.3).timeout
		
		var host_spawn_pos = NetworkingManager.get_spawn_position(1)
		create_player(1, host_spawn_pos)

func create_player(peer_id: int, position: Vector2):
	print("Создание игрока:", peer_id, " в позиции:", position)
	
	# Проверяем, не существует ли уже игрок
	if players_container.has_node(str(peer_id)):
		print("Игрок уже существует:", peer_id)
		return
	
	# Создаем игрока
	var player_instance = PLAYER_SCENE.instantiate()
	player_instance.name = str(peer_id)
	player_instance.position = position
	
	# Устанавливаем authority
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
	
# В Game.gd исправляем функцию start_memory_minigame:
# В Game.gd ЗАМЕНИ функцию start_memory_minigame():

func start_memory_minigame():
	print("=")
	print("GAME.GD: ЗАПУСК МИНИ-ИГРЫ")
	print("=")
	
	# 1. Скрываем основную игру
	visible = false
	players_container.visible = false
	
	# 2. Останавливаем обработку
	set_process(false)
	for player in players_container.get_children():
		player.set_process(false)
		player.set_physics_process(false)
	
	# 3. Загружаем мини-игру БЕЗ CanvasLayer
	var memory_scene = preload("res://Scenes/MiniGames/Memory/Memory.tscn")
	if not memory_scene:
		print("ОШИБКА: Не могу загрузить сцену Memory!")
		return
	
	var game = memory_scene.instantiate()
	game.name = "MemoryGame"
	
	# 4. ПОДКЛЮЧАЕМ СИГНАЛ ПРОСТЫМ СПОСОБОМ
	print("Подключаю сигнал game_over...")
	
	# Способ 1: Прямое подключение
	if game.has_signal("game_over"):
		# Используем лямбду для отслеживания
		game.game_over.connect(func(): 
			print("!!! СИГНАЛ game_over ПОЛУЧЕН В GAME.GD !!!")
			_on_memory_game_over()
		)
		print("Сигнал подключен через лямбду")
	else:
		print("ОШИБКА: Сигнал game_over не найден в мини-игре!")
		# Создаем таймер для авто-возврата
		get_tree().create_timer(300.0).timeout.connect(
			func(): 
				print("АВТО-ВОЗВРАТ по таймауту")
				_on_memory_game_over()
		)
	
	# 5. Добавляем игру как дочерний узел
	add_child(game)
	
	# Сохраняем ссылку
	current_minigame = game
	print("Мини-игра добавлена")

func _on_memory_game_over():
	print("=")
	print("GAME.GD: _on_memory_game_over ВЫЗВАНА")
	print("Время: ", Time.get_time_string_from_system())
	print("=")
	
	# Удаляем мини-игру
	if current_minigame and is_instance_valid(current_minigame):
		print("Удаляю мини-игру...")
		current_minigame.queue_free()
		current_minigame = null
	
	# Показываем основную игру
	visible = true
	players_container.visible = true
	set_process(true)
	
	# Включаем игроков
	for player in players_container.get_children():
		player.set_process(true)
		player.set_physics_process(true)
		player.visible = true
	
	print("ВОЗВРАТ В ОСНОВНУЮ ИГРУ ЗАВЕРШЕН")

func return_to_game():
	# Аварийный возврат
	print("Аварийный возврат в игру")
	_on_memory_game_over()


@rpc("authority", "call_remote", "reliable")
func end_minigame():
	minigame_active = false
	
	# Удаляем мини-игру
	if current_minigame:
		current_minigame.queue_free()
		current_minigame = null
	
	# Показываем игроков
	players_container.visible = true
	
	# Включаем управление
	for player in players_container.get_children():
		player.set_process(true)
		player.set_physics_process(true)

# В _process или _input Game.gd добавь:
func _input(event):
	if event.is_action_pressed("ui_cancel") and minigame_active:
		# Принудительный выход из мини-игры
		end_minigame.rpc_id(1)  # Только хост может завершить
		
func start_battleship_minigame():
	print("=")
	print("GAME.GD: ЗАПУСК МИНИ-ИГРЫ 'ПОИСК ФЕЙВЕРКОВ'")
	print("=")
	
	# 1. Скрываем основную игру
	visible = false
	players_container.visible = false
	
	# 2. Останавливаем обработку
	set_process(false)
	for player in players_container.get_children():
		player.set_process(false)
		player.set_physics_process(false)
	
	# 3. Загружаем мини-игру
	var battleship_scene = preload("res://Scenes/Minigames/Battleship/Battleship.tscn")
	if not battleship_scene:
		print("ОШИБКА: Не могу загрузить сцену Battleship!")
		return
	
	var game = battleship_scene.instantiate()
	game.name = "BattleshipGame"
	
	# 4. Подключаем сигнал
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
	
	# 5. Добавляем игру как дочерний узел
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
	
	# 1. Скрываем основную игру
	visible = false
	if players_container:
		players_container.visible = false
	set_process(false)
	
	# 2. Останавливаем игроков
	for player in players_container.get_children():
		player.set_process(false)
		player.set_physics_process(false)
	
	# 3. Загружаем сцену стрельбы
	var shooting_scene_path = "res://Scenes/Minigames/Shooting/Shooting.tscn"
	print("Пробую загрузить:", shooting_scene_path)
	
	if ResourceLoader.exists(shooting_scene_path):
		var shooting_scene = load(shooting_scene_path)
		var game_instance = shooting_scene.instantiate()
		game_instance.name = "ShootingGame"
		
		# Подключаем сигнал завершения
		if game_instance.has_signal("game_over"):
			game_instance.game_over.connect(_on_shooting_game_over)
			print("Сигнал game_over подключен")
		else:
			print("ВНИМАНИЕ: Сигнал game_over не найден!")
			# Создаем таймер для авто-возврата
			var timer = get_tree().create_timer(60.0)
			timer.timeout.connect(_on_shooting_game_over)
		
		# Добавляем на сцену
		add_child(game_instance)
		current_minigame = game_instance
		print("Мини-игра добавлена успешно!")
	else:
		print("ОШИБКА: Не могу найти файл сцены!")
		# Аварийный возврат
		_on_shooting_game_over()

func _on_shooting_game_over():
	print("=")
	print("GAME.GD: ВОЗВРАТ ИЗ СТРЕЛЬБЫ")
	print("=")
	
	# Удаляем мини-игру
	if current_minigame and is_instance_valid(current_minigame):
		current_minigame.queue_free()
		current_minigame = null
	
	# Восстанавливаем основную игру
	visible = true
	if players_container:
		players_container.visible = true
	set_process(true)
	
	# Включаем игроков
	for player in players_container.get_children():
		player.set_process(true)
		player.set_physics_process(true)
		player.visible = true
	
	print("Возврат в основную игру завершен")
