# Target.gd
extends Area2D

class_name Target

var target_id: String
var target_size: int
var velocity: Vector2
var points: int = 10
var is_hit: bool = false
var shooting_game = null
var move_range_y = Vector2(100, 500)
var fixed_x: float = 0.0

func _ready():
	# УБИРАЕМ ВСЕ НАСТРОЙКИ СЛОЕВ ИЗ КОДА!
	# Просто включаем мониторинг
	monitoring = true
	monitorable = true
	
	# Добавляем в группу для простой проверки
	add_to_group("targets")
	
	# Подключаем сигнал
	body_entered.connect(_on_body_entered)
	
	print("Мишень создана: ID=", target_id, " в дереве:", is_inside_tree())

func init(id: String, size: int, vel: Vector2, game_ref):
	target_id = id
	target_size = size
	velocity = vel
	shooting_game = game_ref
	
	# Получаем диапазон движения
	if has_meta("move_min_y") and has_meta("move_max_y"):
		move_range_y = Vector2(get_meta("move_min_y"), get_meta("move_max_y"))
	else:
		move_range_y = Vector2(100, 500)
	
	# Получаем фиксированную позицию X
	if has_meta("fixed_x"):
		fixed_x = get_meta("fixed_x")
		position.x = fixed_x
	else:
		fixed_x = position.x
	
	print("Мишень инициализирована: ID=", id, " размер=", size, " позиция=", position)
	
	# Настраиваем спрайт
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	
	var texture_path = ""
	match size:
		0:  # маленькая
			texture_path = "res://Assets/Minigames/Shooting/target_small.png"
			points = 30
			sprite.scale = Vector2(2.2, 2.2)
		1:  # средняя
			texture_path = "res://Assets/Minigames/Shooting/target_medium.png"
			points = 20
			sprite.scale = Vector2(1.5, 1.5)
		2:  # большая
			texture_path = "res://Assets/Minigames/Shooting/target_big.png"
			points = 10
			sprite.scale = Vector2(2.0, 2.0)
	
	var texture = load(texture_path)
	if texture:
		sprite.texture = texture
		print("Текстура мишени загружена: ", texture_path)
	else:
		print("Не удалось загрузить текстуру мишени: ", texture_path)
		# Создаем цветной круг как запасной вариант
		sprite.modulate = Color(1, 0.5, 0.5) if size == 0 else Color(1, 1, 0.5) if size == 1 else Color(0.5, 1, 0.5)
	
	add_child(sprite)
	
	# Коллизия - CircleShape2D для мишени
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	
	# Размер в зависимости от типа мишени
	match size:
		0: shape.radius = 12.0  # Маленькая
		1: shape.radius = 18.0  # Средняя
		2: shape.radius = 24.0  # Большая
	
	collision.shape = shape
	collision.name = "CollisionShape2D"
	add_child(collision)

func _on_body_entered(body):	
	var is_dart = false
	
	# 1. По имени
	if "dart" in body.name.to_lower():
		is_dart = true
	# 2. По классу
	elif body.get_class() == "Dart":
		is_dart = true
	# 3. По методу
	elif body.has_method("get_dart_info"):
		is_dart = true
	# 4. По группе
	elif body.is_in_group("darts"):
		is_dart = true
	
	if is_dart:		
		if is_hit:
			return
		
		is_hit = true
		
		# Визуальный эффект попадания
		sync_flash_hit()
		
		# Сообщаем игре о попадании
		if shooting_game and shooting_game.has_method("on_target_hit"):
			# Получаем ID дротика
			var dart_id = ""
			var player_id = 0
			
			if body.has_method("get_dart_info"):
				var info = body.get_dart_info()
				dart_id = info.get("dart_id", "unknown")
				player_id = info.get("player_id", 0)
			elif body.has("dart_id"):
				dart_id = body.dart_id
			if body.has("player_id"):
				player_id = body.player_id
			
			shooting_game.on_target_hit(target_id, dart_id, player_id)
		
		# Сбрасываем флаг попадания через короткое время
		await get_tree().create_timer(0.5).timeout
		is_hit = false
	else:
		print("Столкновение с не-дротиком: ", body.name, " тип: ", body.get_class())

func flash_hit():
	# Эта функция вызывается локально на каждом экземпляре
	var sprite = $Sprite2D
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1, 0, 0, 1)  # Красный
		
		# Возвращаем нормальный цвет через 0.2 секунды
		await get_tree().create_timer(0.2).timeout
		sprite.modulate = original_modulate

# Новая функция для синхронизации эффекта с клиентами
func sync_flash_hit():
	# Если это сервер, отправляем команду клиентам
	if multiplayer.is_server():
		# Сначала делаем локально
		flash_hit()
		# Потом отправляем клиентам
		rpc("remote_flash_hit")
	else:
		# Клиенты просто делают локально
		flash_hit()

@rpc("authority", "call_local", "reliable")
func remote_flash_hit():
	# Клиенты получают команду и мигают
	flash_hit()

func _physics_process(delta):
	if is_hit:
		return  # На время мигания не двигаемся
	
	# Сохраняем фиксированную позицию X
	position.x = fixed_x
	
	# Движение ТОЛЬКО по Y
	position.y += velocity.y * delta
	
	# Меняем направление при достижении границ
	if position.y <= move_range_y.x:
		position.y = move_range_y.x
		velocity.y = abs(velocity.y)  # Двигаемся вниз
	elif position.y >= move_range_y.y:
		position.y = move_range_y.y
		velocity.y = -abs(velocity.y)  # Двигаемся вверх

func get_target_info():
	return {
		"id": target_id,
		"size": target_size,
		"points": points,
		"position": position,
		"velocity": velocity
	}
