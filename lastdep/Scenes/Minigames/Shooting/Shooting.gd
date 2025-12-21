extends Node2D

signal game_over

const GAME_DURATION = 60.0
const TARGET_SPAWN_INTERVAL = 1.0
const PLAYER_SPEED = 200.0
const DART_SPEED = 500.0
const FIRE_COOLDOWN = 1.0

enum TargetSize { SMALL, MEDIUM, LARGE }

var target_points = {
	TargetSize.SMALL: 30,
	TargetSize.MEDIUM: 20,
	TargetSize.LARGE: 10
}

var target_speeds = {
	TargetSize.SMALL: 150,
	TargetSize.MEDIUM: 100,
	TargetSize.LARGE: 50
}

var target_scales = {
	TargetSize.SMALL: Vector2(0.5, 0.5),
	TargetSize.MEDIUM: Vector2(0.75, 0.75),
	TargetSize.LARGE: Vector2(1.0, 1.0)
}

# Сетевые переменные
var player_scores = {}
var game_active = false
var time_left = GAME_DURATION
var targets = []
var player_positions = {}
var player_cooldowns = {}

# Ссылки на узлы
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var player1_score_label: Label = $CanvasLayer/Player1ScoreLabel
@onready var player2_score_label: Label = $CanvasLayer/Player2ScoreLabel
@onready var winner_label: Label = $CanvasLayer/WinnerLabel
@onready var game_timer: Timer = $GameTimer
@onready var spawn_timer: Timer = $SpawnTimer
@onready var players_container: Node2D = $GameArea/Players
@onready var targets_container: Node2D = $GameArea/TargetsContainer

var my_id: int
var is_host: bool

func _ready():
	print("=== СТРЕЛЬБА ЗАПУЩЕНА ===")
	print("Мой ID:", multiplayer.get_unique_id())
	print("Это сервер?", multiplayer.is_server())
	
	# Инициализация
	my_id = multiplayer.get_unique_id()
	is_host = multiplayer.is_server()
	
	# Инициализация счета
	if is_host:
		set_multiplayer_authority(1)
		player_scores[1] = 0
		var peers = multiplayer.get_peers()
		if peers.size() > 0:
			player_scores[peers[0]] = 0
	else:
		player_scores[my_id] = 0
	
	# Инициализация позиций игроков
	player_positions[1] = Vector2(100, 300) if is_host else Vector2(100, 300)
	var peers = multiplayer.get_peers()
	if peers.size() > 0:
		player_positions[peers[0]] = Vector2(700, 300) if is_host else Vector2(700, 300)
	
	# Инициализация задержек
	player_cooldowns[1] = 0.0
	if peers.size() > 0:
		player_cooldowns[peers[0]] = 0.0
	
	# Создание игроков
	create_players()
	
	# Обновление UI
	update_ui()
	
	# Только хост управляет игрой
	if is_host:
		start_game.rpc()

@rpc("authority", "call_local", "reliable")
func start_game():
	game_active = true
	time_left = GAME_DURATION
	game_timer.start(1.0)
	spawn_timer.start(TARGET_SPAWN_INTERVAL)
	
	# Сигнал готовности для всех игроков
	game_started.rpc()

@rpc("authority", "call_local", "reliable")
func game_started():
	print("Игра началась!")
	winner_label.visible = false

func create_players():
	for player_id in player_positions:
		create_player_cart(player_id, player_positions[player_id])

func create_player_cart(player_id: int, position: Vector2):
	var cart = Area2D.new()
	cart.name = str(player_id)
	cart.position = position
	
	var sprite = Sprite2D.new()
	# Загрузите текстуру вагонетки
	# sprite.texture = preload("res://assets/cart.png")
	cart.add_child(sprite)
	
	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 20
	cart.add_child(collision)
	
	players_container.add_child(cart)
	
	# Если это наш игрок, добавляем управление
	if player_id == my_id:
		cart.set_script(preload("res://Scenes/Minigames/Shooting/PlayerCart.gd"))
		cart.init(player_id, true, self)
	else:
		cart.set_script(preload("res://Scenes/Minigames/Shooting/PlayerCart.gd"))
		cart.init(player_id, false, self)

func _process(delta):
	if not game_active:
		return
	
	# Обновляем задержки выстрелов
	for player_id in player_cooldowns:
		if player_cooldowns[player_id] > 0:
			player_cooldowns[player_id] -= delta
	
	# Обновляем таймер
	if is_host:
		time_left -= delta
		if time_left <= 0:
			end_game.rpc()
		else:
			update_timer.rpc(time_left)

@rpc("authority", "call_local", "reliable")
func update_timer(current_time: float):
	time_left = current_time
	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60
	timer_label.text = "Время: %02d:%02d" % [minutes, seconds]

@rpc("any_peer", "call_local", "reliable")
func request_fire(player_id: int):
	if not game_active:
		return
	
	# Проверяем задержку
	if player_cooldowns.get(player_id, 0) > 0:
		return
	
	# Устанавливаем задержку
	player_cooldowns[player_id] = FIRE_COOLDOWN
	
	# Создаем дротик
	create_dart(player_id)

func create_dart(player_id: int):
	var cart = players_container.get_node_or_null(str(player_id))
	if not cart:
		return
	
	var dart = Area2D.new()
	dart.position = cart.position
	dart.set_script(preload("res://Scenes/Minigames/Shooting/Dart.gd"))
	dart.init(player_id, DART_SPEED, self)
	
	add_child(dart)
	fire_dart.rpc(player_id, dart.position)

@rpc("authority", "call_local", "reliable")
func fire_dart(player_id: int, position: Vector2):
	# Создаем дротик для всех игроков
	if player_id != my_id:
		var dart = Area2D.new()
		dart.position = position
		dart.set_script(preload("res://Scenes/Minigames/Shooting/Dart.gd"))
		dart.init(player_id, DART_SPEED, self, true)
		add_child(dart)

func create_target():
	if not is_host:
		return
	
	var size = randi() % 3
	var x_pos = randf_range(200, 600)
	var target = {
		"id": randi() % 1000000,
		"size": size,
		"position": Vector2(x_pos, 0),
		"velocity": Vector2(0, target_speeds[size]),
		"scale": target_scales[size]
	}
	
	targets.append(target)
	spawn_target.rpc(target)

@rpc("authority", "call_local", "reliable")
func spawn_target(target_data: Dictionary):
	# Создаем мишень визуально
	var target = Area2D.new()
	target.name = "target_%d" % target_data.id
	target.position = target_data.position
	
	var sprite = Sprite2D.new()
	# Загрузите текстуру мишени
	# sprite.texture = preload("res://assets/target.png")
	sprite.scale = target_data.scale
	target.add_child(sprite)
	
	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 20 * target_data.scale.x
	target.add_child(collision)
	
	target.set_script(preload("res://Scenes/Minigames/Shooting/Target.gd"))
	target.init(target_data.id, target_data.size, target_data.velocity)
	
	targets_container.add_child(target)

func hit_target(target_id: int, player_id: int, target_size: int):
	if not is_host or not game_active:
		return
	
	# Начисляем очки
	var points = target_points[target_size]
	player_scores[player_id] = player_scores.get(player_id, 0) + points
	
	# Удаляем мишень
	remove_target(target_id)
	
	# Обновляем UI
	update_score(player_id, player_scores[player_id])
	
	# Отправляем обновление всем
	target_hit.rpc(target_id, player_id, points, player_scores[player_id])

@rpc("authority", "call_local", "reliable")
func target_hit(target_id: int, player_id: int, points: int, new_score: int):
	# Удаляем мишень у всех
	var target = targets_container.get_node_or_null("target_%d" % target_id)
	if target:
		target.queue_free()
	
	# Обновляем счет
	player_scores[player_id] = new_score
	update_score(player_id, new_score)
	
	# Эффект попадания (можно добавить частицы)

func remove_target(target_id: int):
	var target = targets_container.get_node_or_null("target_%d" % target_id)
	if target:
		target.queue_free()
	
	# Удаляем из массива на хосте
	if is_host:
		for i in range(targets.size()):
			if targets[i].id == target_id:
				targets.remove_at(i)
				break

func update_score(player_id: int, score: int):
	if player_id == 1:
		player1_score_label.text = "Игрок 1: %d" % score
	else:
		player2_score_label.text = "Игрок 2: %d" % score

func update_ui():
	if player1_score_label:
		player1_score_label.text = "Игрок 1: 0"
	if player2_score_label:
		player2_score_label.text = "Игрок 2: 0"
	if timer_label:
		timer_label.text = "Время: 01:00"

@rpc("authority", "call_local", "reliable")
func end_game():
	game_active = false
	game_timer.stop()
	spawn_timer.stop()
	
	# Определяем победителя
	var winner_id = 1
	var max_score = -1
	
	for player_id in player_scores:
		if player_scores[player_id] > max_score:
			max_score = player_scores[player_id]
			winner_id = player_id
	
	var winner_text = ""
	if player_scores.get(1, 0) == player_scores.get(multiplayer.get_peers()[0] if multiplayer.get_peers().size() > 0 else 2, 0):
		winner_text = "НИЧЬЯ!"
	elif winner_id == 1:
		winner_text = "ПОБЕДИЛ ИГРОК 1!"
	else:
		winner_text = "ПОБЕДИЛ ИГРОК 2!"
	
	show_winner.rpc(winner_text)

@rpc("authority", "call_local", "reliable")
func show_winner(winner_text: String):
	winner_label.text = winner_text
	winner_label.visible = true
	
	# Ждем 5 секунд и возвращаемся
	await get_tree().create_timer(5.0).timeout
	game_over.emit()

func _on_spawn_timer_timeout():
	if game_active and is_host:
		create_target()

func _on_game_timer_timeout():
	if game_active and is_host:
		update_timer.rpc(time_left)
