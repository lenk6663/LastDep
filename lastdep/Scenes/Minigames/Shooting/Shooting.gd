# Shooting.gd
extends Node2D

signal game_over

# ============== КОНСТАНТЫ И НАСТРОЙКИ ==============
const GAME_DURATION = 120.0
const FIRE_COOLDOWN = 1.0
const DART_SPEED = 500.0

# Позиции вагонеток
const PLAYER1_POS = Vector2(90, 300)    # Левая сторона
const PLAYER2_POS = Vector2(1050, 300)  # Правая сторона
const PLAYER_MOVE_RANGE = Vector2(50, 600)  # Диапазон движения по Y

# Фиксированные позиции для 6 мишеней
const TARGET_POSITIONS = [
	# Большая мишень 1: x=400, y=100, движение ВВЕРХ
	{"x": 400, "y": 100, "type": "big", "direction": "up"},
	# Средняя мишень 1: x=500, y=500, движение ВНИЗ  
	{"x": 500, "y": 500, "type": "medium", "direction": "down"},
	# Маленькая мишень 1: x=550, y=100, движение ВВЕРХ
	{"x": 550, "y": 100, "type": "small", "direction": "up"},
	# Маленькая мишень 2: x=600, y=500, движение ВНИЗ
	{"x": 600, "y": 500, "type": "small", "direction": "down"},
	# Средняя мишень 2: x=650, y=100, движение ВВЕРХ
	{"x": 650, "y": 100, "type": "medium", "direction": "up"},
	# Большая мишень 2: x=750, y=500, движение ВНИЗ
	{"x": 750, "y": 500, "type": "big", "direction": "down"}
]

# Настройки мишеней
const TARGET_SPEEDS = {
	"big": 60.0,     # Большая - медленная
	"medium": 90.0,  # Средняя - средняя скорость
	"small": 130.0   # Маленькая - быстрая
}

const TARGET_SCALES = {
	"big": 1.2,
	"medium": 1.0,
	"small": 0.8
}

const TARGET_POINTS = {
	"big": 10,
	"medium": 20,
	"small": 30
}

const TARGET_SIZE_MAP = {
	"big": 2,
	"medium": 1,
	"small": 0
}

# Настройки мультиплеера
var is_server = false
var is_client = false
var my_player_id = 1  # По умолчанию для хоста

# ============== УЗЛЫ СЦЕНЫ ==============
@onready var camera = $UI/Camera2D
@onready var players_container = $UI/Players
@onready var targets_container = $UI/Targets
@onready var darts_container = $UI/Darts
@onready var ui = $UI
@onready var timer_label = $UI/TimerLabel
@onready var player1_score_label = $UI/Player1ScoreLabel
@onready var player2_score_label = $UI/Player2ScoreLabel
@onready var winner_label = $UI/WinnerLabel

# ============== СОСТОЯНИЕ ИГРЫ ==============
var game_active = false
var time_left = GAME_DURATION
var player_scores = [0, 0]  # [игрок1, игрок2]
var player_cooldowns = [0.0, 0.0]  # Задержки выстрелов
var targets = []  # Массив ID мишеней
var target_objects = {}  # Словарь мишеней по ID

# Игроки
var player1 = null
var player2 = null

# ============== ИНИЦИАЛИЗАЦИЯ ==============
func _ready():
	print("=== SHOOTING ИГРА ЗАПУЩЕНА ===")
	print("Peer ID:", multiplayer.get_unique_id())
	print("Это сервер?", multiplayer.is_server())
	
	# Определяем роль
	is_server = multiplayer.is_server()
	is_client = not is_server
	
	# Определяем ID игрока - ВАЖНО!
	if multiplayer.has_multiplayer_peer():
		# Игрок 1 - хост, Игрок 2 - клиент
		my_player_id = 1 if is_server else 2
		print("Определен мой ID игрока:", my_player_id)
	else:
		# Для одиночного тестирования
		my_player_id = 1
		is_server = true
	
	# Создаем сигнал если его нет
	if not has_signal("game_over"):
		add_user_signal("game_over")
	
	# ВКЛЮЧАЕМ обработку ввода
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	
	# Настраиваем камеру
	setup_camera()
	
	# Настраиваем UI
	setup_ui()
	
	# Инициализируем игру
	init_game()

func init_game():
	print("Инициализация игры...")
	
	# Очищаем все объекты
	clear_game_objects()
	
	# Сброс состояния
	game_active = false
	time_left = GAME_DURATION
	player_scores = [0, 0]
	player_cooldowns = [0.0, 0.0]
	targets = []
	target_objects = {}
	
	print("Игра инициализирована")
	
	# Только сервер создает игроков и мишени
	if is_server:
		print("Сервер: создаю игроков и мишени")
		# Создаем игроков
		create_players()
		
		# Ждем немного
		await get_tree().create_timer(0.5).timeout
		
		# Создаем начальные мишени
		create_initial_targets()
		
		# Синхронизируем с клиентами
		sync_initial_state.rpc()
	else:
		print("Клиент: жду синхронизации от сервера")
		# Клиент не создает ничего, ждет RPC от сервера
	
	# Начинаем игру
	await get_tree().create_timer(1.0).timeout
	if not game_active:
		start_game()

func setup_camera():
	print("Настраиваю камеру...")
	camera.zoom = Vector2(1, 1)
	camera.make_current()
	print("Камера установлена в центре:", camera.position)

func setup_ui():
	timer_label.text = "Время: 01:00"
	player1_score_label.text = "Игрок 1: 0"
	player2_score_label.text = "Игрок 2: 0"
	winner_label.visible = false
	winner_label.text = ""

# ============== ОСНОВНАЯ ЛОГИКА ИГРЫ ==============

func clear_game_objects():
	# Очищаем мишени и дротики
	for node in [targets_container, darts_container]:
		for child in node.get_children():
			child.queue_free()
	
	# Очищаем игроков (кроме вагонеток, они остаются)
	for child in players_container.get_children():
		if not "Cart" in child.name:
			child.queue_free()

func start_game():
	print("ИГРА НАЧИНАЕТСЯ!")
	game_active = true
	
	# Запускаем таймер игры
	$GameTimer.start(1.0)

# ============== СОЗДАНИЕ ИГРОВЫХ ОБЪЕКТОВ ==============
func create_players():
	print("Создаю игроков...")
	
	# Очищаем старых игроков
	for child in players_container.get_children():
		if "Cart" in child.name:
			child.queue_free()
	
	# Создаем игрока 1 (слева)
	player1 = create_player_cart(1, PLAYER1_POS)
	player1.z_index = 10
	
	# Создаем игрока 2 (справа)
	player2 = create_player_cart(2, PLAYER2_POS)
	player2.z_index = 10
	
	print("Игроки созданы")

func create_player_cart(player_id: int, position: Vector2):
	var existing_cart = players_container.get_node_or_null("Player%d_Cart" % player_id)
	if existing_cart:
		print("Вагонетка игрока", player_id, " уже существует, пропускаю")
		return existing_cart
	var cart_scene = preload("res://Scenes/Minigames/Shooting/PlayerCart.tscn")
	if not cart_scene:
		print("ОШИБКА: Не могу загрузить сцену вагонетки!")
		return null
	
	var cart = cart_scene.instantiate()
	cart.name = "Player%d_Cart" % player_id
	cart.position = position
	cart.scale = Vector2(2, 2)
	
	players_container.add_child(cart)
	
	# Инициализируем
	if cart.has_method("init"):
		var is_local = (player_id == my_player_id)
		cart.init(player_id, is_local, self, PLAYER_MOVE_RANGE)
	
	# Синхронизируем создание вагонетки
	if is_server:
		sync_create_cart.rpc(player_id, position)
	
	return cart

func create_initial_targets():
	print("Создаю начальные 6 мишеней...")
	
	# Создаем все 6 мишеней по заданным позициям
	for i in range(TARGET_POSITIONS.size()):
		var pos_data = TARGET_POSITIONS[i]
		await get_tree().create_timer(0.1).timeout
		create_target_at_position(pos_data, i)
	
	print("Начальные мишени созданы")

func create_target_at_position(pos_data: Dictionary, index: int):
	var target_type = pos_data["type"]
	var x_pos = pos_data["x"]
	var start_y = pos_data["y"]
	var direction = pos_data["direction"]
	
	# Параметры мишени
	var size = TARGET_SIZE_MAP[target_type]
	var speed = TARGET_SPEEDS[target_type]
	var scale_val = TARGET_SCALES[target_type]
	
	# Направление движения
	var velocity = Vector2(0, 0)
	if direction == "up":
		velocity = Vector2(0, -speed)  # Движение ВВЕРХ
	else:
		velocity = Vector2(0, speed)   # Движение ВНИЗ
	
	# Создаем мишень
	var target_scene = preload("res://Scenes/Minigames/Shooting/Target.tscn")
	if target_scene:
		var target = target_scene.instantiate()
		var target_id = str(index) + "_" + target_type
		target.name = "Target_%s" % target_id
		
		# Позиция
		target.position = Vector2(x_pos, start_y)
		target.z_index = 2
		target.scale = Vector2(scale_val, scale_val)
		
		targets_container.add_child(target)
		
		if target.has_method("init"):
			# Устанавливаем диапазон движения
			var move_min_y = 100
			var move_max_y = 500
			
			target.set_meta("move_min_y", move_min_y)
			target.set_meta("move_max_y", move_max_y)
			target.set_meta("target_type", target_type)
			target.set_meta("target_id", target_id)
			target.set_meta("fixed_x", x_pos)
			
			target.init(target_id, size, velocity, self)
			
			# Сохраняем ссылку
			targets.append(target_id)
			target_objects[target_id] = target
			
			# Синхронизируем с клиентами
			if is_server:
				sync_create_target.rpc(target_id, x_pos, start_y, target_type, direction)
			
			print("Создана ", target_type, " мишень ID:", target_id)

# ============== СТРЕЛЬБА И ДРОТИКИ ==============
func _input(event):
	# ИГНОРИРУЕМ события мыши и джойстика
	if event is InputEventMouse or event is InputEventJoypadMotion or event is InputEventJoypadButton:
		return
	
	# Временное логирование для отладки
	if event is InputEventKey:
		print("[DEBUG] Клавиша: ",event.keycode," нажата:" ,event.pressed,)
	
	if not game_active:
		return
	
	# ОБРАБОТКА ВСЕХ ИГРОКОВ - пробел для ИГРОКА 1 (хоста)
	if event.is_action_pressed("ui_accept"):
		print("[DEBUG] ПРОБЕЛ нажат! my_player_id=",my_player_id)
		
		# Хост (игрок 1) использует пробел
		if my_player_id == 1 and player_cooldowns[0] <= 0:
			print("[DEBUG] Игрок 1 (хост) стреляет!")
			player_cooldowns[0] = FIRE_COOLDOWN
			local_shoot(my_player_id)
			if is_server:
				process_shoot(my_player_id)
			else:
				request_shoot.rpc_id(1, my_player_id)
		
		# Клиент (игрок 2) ТОЖЕ может использовать пробел, если вы хотите
		# Удалите этот блок если хотите раздельное управление
		elif my_player_id == 2 and player_cooldowns[1] <= 0:
			print("[DEBUG] Игрок 2 (клиент) использует пробел!")
			player_cooldowns[1] = FIRE_COOLDOWN
			local_shoot(my_player_id)
			request_shoot.rpc_id(1, my_player_id)
	
	# Или раздельное управление: пробел для игрока 1, F для игрока 2
	# Раскомментируйте если хотите раздельное управление:
	# elif event.is_action_pressed("ui_focus_next"):
	#     if my_player_id == 2 and player_cooldowns[1] <= 0:
	#         print("[DEBUG] Игрок 2 (клиент) нажал F!")
	#         player_cooldowns[1] = FIRE_COOLDOWN
	#         local_shoot(my_player_id)
	#         request_shoot.rpc_id(1, my_player_id)
	
	if event.is_action_pressed("ui_cancel"):
		print("[DEBUG] Выход из мини-игры по ESC")
		game_over.emit()
	
func local_shoot(player_id: int):
	print("Локальный выстрел игрока", player_id)
	
	var cart = null
	var direction = Vector2.RIGHT
	
	if player_id == 1:
		cart = players_container.get_node_or_null("Player1_Cart")
		direction = Vector2.RIGHT
	else:
		cart = players_container.get_node_or_null("Player2_Cart")
		direction = Vector2.LEFT
	
	var cart_pos = Vector2.ZERO
	if cart:
		cart_pos = cart.position
		print("Позиция вагонетки игрока", player_id, ": ", cart_pos)
	else:
		# Запасная позиция
		cart_pos = PLAYER1_POS if player_id == 1 else PLAYER2_POS
		print("Вагонетка не найдена, использую запасную позицию")
	
	create_dart(player_id, cart_pos, direction)

func process_shoot(player_id: int):
	print("Сервер обрабатывает выстрел игрока", player_id)
	
	var cart = null
	var direction = Vector2.RIGHT
	
	if player_id == 1:
		cart = players_container.get_node_or_null("Player1_Cart")
		direction = Vector2.RIGHT
	else:
		cart = players_container.get_node_or_null("Player2_Cart")
		direction = Vector2.LEFT
	
	var cart_pos = Vector2.ZERO
	if cart:
		cart_pos = cart.position
	else:
		cart_pos = PLAYER1_POS if player_id == 1 else PLAYER2_POS
	
	# Создаем дротик на сервере
	create_dart(player_id, cart_pos, direction)
	
	# Синхронизируем с клиентами (даже если это хост стреляет)
	sync_create_dart.rpc(player_id, cart_pos, direction)

@rpc("any_peer", "call_remote", "reliable")
func request_shoot(player_id: int):
	# Только сервер обрабатывает запросы на стрельбу
	if not is_server:
		return
	
	print("Получен запрос на выстрел от игрока", player_id)
	process_shoot(player_id)

func create_dart(player_id: int, position: Vector2, direction: Vector2):
	var dart_scene = preload("res://Scenes/Minigames/Shooting/Dart.tscn")
	if dart_scene:
		var dart = dart_scene.instantiate()
		var dart_id = "dart_%d_%d" % [player_id, Time.get_ticks_msec()]
		dart.name = dart_id
		dart.position = position
		dart.z_index = 5
		
		# Определяем текстуру в зависимости от игрока
		var dart_texture = "res://Assets/Minigames/Shooting/dart_red.png" if player_id == 1 else "res://Assets/Minigames/Shooting/dart_blue.png"
		
		# Инициализируем дротик с правильными параметрами
		if dart.has_method("init"):
			dart.init(dart_id, player_id, DART_SPEED, direction, self, dart_texture)
		
		darts_container.add_child(dart)
		
		# ДЕБАГ: Проверяем все мишени
		print("=== ДЕБАГ СОЗДАНИЯ ДРОТИКА ===")
		print("Дротик ID: ", dart_id)
		print("Позиция дротика: ", dart.global_position)
		
		# Получаем все мишени и их позиции
		var targets = get_tree().get_nodes_in_group("targets")
		print("Найдено мишеней: ", targets.size())
		
		for target in targets:
			if target and is_instance_valid(target):
				print("  Мишень: ", target.name, " позиция: ", target.global_position, 
					  " расстояние до дротика: ", dart.global_position.distance_to(target.global_position))
		
		return dart
	return null

# ============== ОБРАБОТКА ПОПАДАНИЙ ==============
func on_target_hit(target_id: String, dart_id: String, player_id: int):
	print("ОБРАБОТКА ПОПАДАНИЯ: Мишень:", target_id, " Дротик:", dart_id, " Игрок:", player_id)
	
	# Только сервер обрабатывает логику попадания
	if not is_server:
		print("Клиент: получено попадание, отправляю на сервер")
		report_hit_to_server.rpc_id(1, target_id, dart_id, player_id)
		return
	
	# Находим мишень
	var target = target_objects.get(target_id)
	if not target:
		print("Мишень не найдена:", target_id)
		return
	
	# Получаем тип мишени
	var target_type = "medium"
	if target.has_meta("target_type"):
		target_type = target.get_meta("target_type")
	elif target.has_method("get_target_info"):
		var info = target.get_target_info()
		match info.get("size", 1):
			0: target_type = "small"
			1: target_type = "medium"
			2: target_type = "big"
	
	# Начисляем очки
	var points = TARGET_POINTS[target_type]
	var player_index = player_id - 1
	
	if player_index >= 0 and player_index < player_scores.size():
		player_scores[player_index] += points
	
	print("Игрок", player_id, " получает", points, " очков. Новый счет:", player_scores[player_index])
	
	# Удаляем дротик на сервере
	var dart = darts_container.get_node_or_null(dart_id)
	if dart:
		dart.queue_free()
	
	# Синхронизируем попадание со всеми клиентами
	sync_target_hit.rpc(target_id, dart_id, player_id, target_type)
	
	# Обновляем UI
	update_score_display()

func update_score_display():
	player1_score_label.text = "Игрок 1: %d" % player_scores[0]
	player2_score_label.text = "Игрок 2: %d" % player_scores[1]
	
	# Синхронизируем счет
	if is_server:
		sync_scores.rpc(player_scores[0], player_scores[1])

# ============== RPC ДЛЯ СИНХРОНИЗАЦИИ ==============
@rpc("any_peer", "call_remote", "reliable")
func report_hit_to_server(target_id: String, dart_id: String, player_id: int):
	if is_server:
		print("Сервер: получен отчет о попадании от клиента")
		on_target_hit(target_id, dart_id, player_id)
# Синхронизация начального состояния
@rpc("authority", "call_remote", "reliable")
func sync_shoot(player_id: int):
	if not is_server:  # Клиенты получают синхронизацию
		print("Клиент: получаю синхронизацию выстрела игрока", player_id)
		local_shoot(player_id)
		
@rpc("authority", "call_remote", "reliable")
func sync_initial_state():
	print("Клиент: получаю начальное состояние от сервера")
	
	# Клиент создает локальные копии объектов ТОЛЬКО если они еще не созданы
	if not is_server:
		# Проверяем, не созданы ли уже вагонетки
		var existing_carts = []
		for child in players_container.get_children():
			if "Cart" in child.name:
				existing_carts.append(child.name)
		
		# Создаем вагонетки только если их нет
		if not "Player1_Cart" in existing_carts:
			create_player_cart(1, PLAYER1_POS)
		if not "Player2_Cart" in existing_carts:
			create_player_cart(2, PLAYER2_POS)

# Синхронизация создания вагонетки
@rpc("authority", "call_remote", "reliable")
func sync_create_cart(player_id: int, position: Vector2):
	# Клиенты создают вагонетки
	if not is_server:
		var cart = create_player_cart(player_id, position)
		print("Клиент: создана вагонетка игрока", player_id)

# Синхронизация создания мишени
@rpc("authority", "call_remote", "reliable")
func sync_create_target(target_id: String, x_pos: float, y_pos: float, target_type: String, direction: String):
	# Клиенты создают мишени
	if not is_server:
		var pos_data = {"x": x_pos, "y": y_pos, "type": target_type, "direction": direction}
		
		# Создаем локальную копию мишени
		var target_scene = preload("res://Scenes/Minigames/Shooting/Target.tscn")
		if target_scene:
			var target = target_scene.instantiate()
			target.name = "Target_%s" % target_id
			target.position = Vector2(x_pos, y_pos)
			target.z_index = 2
			
			# Масштаб
			var scale_val = TARGET_SCALES[target_type]
			target.scale = Vector2(scale_val, scale_val)
			
			targets_container.add_child(target)
			
			if target.has_method("init"):
				var size = TARGET_SIZE_MAP[target_type]
				var speed = TARGET_SPEEDS[target_type]
				var velocity = Vector2(0, speed if direction == "down" else -speed)
				
				target.set_meta("move_min_y", 100)
				target.set_meta("move_max_y", 500)
				target.set_meta("target_type", target_type)
				target.set_meta("target_id", target_id)
				target.set_meta("fixed_x", x_pos)
				
				target.init(target_id, size, velocity, self)
				
				targets.append(target_id)
				target_objects[target_id] = target
				
				print("Клиент: создана мишень", target_id)

# Синхронизация создания дротика
@rpc("authority", "call_remote", "reliable")
func sync_create_dart(player_id: int, position: Vector2, direction: Vector2):
	# Клиенты создают дротики
	if not is_server:
		create_dart(player_id, position, direction)

# Синхронизация попадания
@rpc("authority", "call_local", "reliable")
func sync_target_hit(target_id: String, dart_id: String, player_id: int, target_type: String):
	print("Клиент: получено синхронизированное попадание в мишень", target_id)
	
	# Удаляем дротик на клиенте
	var dart = darts_container.get_node_or_null(dart_id)
	if dart:
		dart.queue_free()
	var target = target_objects.get(target_id)

	var points = TARGET_POINTS[target_type]
	var player_index = player_id - 1
	
	if player_index >= 0 and player_index < player_scores.size():
		player_scores[player_index] += points
		update_score_display()
	
	print("Клиент: обновлен счет игрока", player_id, " на", points, " очков")

# Синхронизация счета
@rpc("authority", "call_remote", "reliable")
func sync_scores(score1: int, score2: int):
	if not is_server:
		player_scores = [score1, score2]
		update_score_display()

# Синхронизация позиций мишеней (периодическая)
@rpc("authority", "call_remote", "unreliable")
func sync_target_positions(positions: Dictionary):
	if not is_server:
		for target_id in positions:
			var target = target_objects.get(target_id)
			if target:
				target.position = positions[target_id]

# ============== ИГРОВОЙ ЦИКЛ ==============
func _process(delta):
	if not game_active:
		return
	
	# Обновляем задержки выстрелов
	for i in range(2):
		if player_cooldowns[i] > 0:
			player_cooldowns[i] -= delta
	
	# Обновляем таймер
	time_left -= delta
	if time_left <= 0:
		end_game()
	else:
		update_timer_display()
	
	# Сервер периодически синхронизирует позиции мишеней
	if is_server and Engine.get_frames_drawn() % 30 == 0:  # Каждые 30 кадров
		sync_targets_positions()

func sync_targets_positions():
	if not is_server:
		return
	
	var positions = {}
	for target_id in targets:
		var target = target_objects.get(target_id)
		if target:
			positions[target_id] = target.position
	
	# Отправляем клиентам
	if positions.size() > 0:
		sync_target_positions.rpc(positions)

func update_timer_display():
	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60
	timer_label.text = "Время: %02d:%02d" % [minutes, seconds]

func _on_game_timer_timeout():
	if game_active:
		update_timer_display()

# ============== ЗАВЕРШЕНИЕ ИГРЫ ==============
func get_winner_id() -> int:
	# Определяем победителя
	if player_scores[0] > player_scores[1]:
		return 1
	elif player_scores[1] > player_scores[0]:
		return 2
	else:
		return 0  # Ничья

func end_game():
	print("ИГРА ЗАВЕРШЕНА!")
	game_active = false
	
	# Останавливаем таймер
	$GameTimer.stop()
	
	# Определяем победителя
	var winner_id = get_winner_id()
	
	print("Результат: Победил игрок", winner_id)
	
	# Сохраняем результат в метаданные для передачи
	set_meta("winner_id", winner_id)
	
	# Показываем победителя
	show_winner(winner_id)

func show_winner(winner_id: int):
	var winner_text = ""
	if winner_id == 1:
		winner_text = "ПОБЕДИЛ ИГРОК 1!"
	elif winner_id == 2:
		winner_text = "ПОБЕДИЛ ИГРОК 2!"
	else:
		winner_text = "НИЧЬЯ!"
	
	winner_label.text = winner_text
	winner_label.visible = true
	
	# Ждем 3 секунды и завершаем игру
	await get_tree().create_timer(3.0).timeout
	
	print("Отправляю сигнал завершения игры с победителем", winner_id)
	game_over.emit()

func _exit_tree():
	print("Shooting игра завершена")
