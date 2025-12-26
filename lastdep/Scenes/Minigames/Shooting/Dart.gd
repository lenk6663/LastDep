# Dart.gd - ПЕРЕПИСАННАЯ ВЕРСИЯ
extends Area2D

class_name Dart

@export var player_id: int = 1
@export var speed: float = 500.0
@export var direction: Vector2 = Vector2.RIGHT

var dart_id: String = ""
var game_node: Node = null
var has_collided: bool = false

func _ready():
	# УБИРАЕМ ВСЕ НАСТРОЙКИ СЛОЕВ ИЗ КОДА!
	# Просто включаем мониторинг
	monitoring = true
	monitorable = true
	
	# Подключаем сигналы
	body_entered.connect(_on_body_entered)
	
	# Добавляем в группу для простой проверки
	add_to_group("darts")
	
	# Добавляем спрайт
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	
	# Загружаем текстуру
	var texture_path = "res://Assets/Minigames/Shooting/dart_red.png" if player_id == 1 else "res://Assets/Minigames/Shooting/dart_blue.png"
	var texture = load(texture_path)
	
	if texture:
		sprite.texture = texture
		sprite.scale = Vector2(0.8, 0.8)
		if direction.x < 0:
			sprite.flip_h = true
	else:
		# Цветной квадрат как запасной вариант
		sprite.modulate = Color.RED if player_id == 1 else Color.BLUE
	
	add_child(sprite)
	
	# Добавляем коллизию
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	
	# Создаем форму коллизии
	var shape = RectangleShape2D.new()
	shape.size = Vector2(30, 10)  # Размер дротика
	
	collision.shape = shape
	add_child(collision)
	
	print("Дротик создан: ID=", dart_id, " в дереве:", is_inside_tree())

func init(d_id: String, p_id: int, dart_speed: float, dir: Vector2, game_ref, tex_name: String = ""):
	dart_id = d_id
	player_id = p_id
	speed = dart_speed
	direction = dir
	game_node = game_ref
	
	print("Дротик инициализирован: ID=", dart_id, " игрок=", player_id, " позиция=", position)

func _physics_process(delta):
	if has_collided:
		return
	
	# Сохраняем старую позицию
	var old_pos = position
	
	# Движение дротика
	position += direction.normalized() * speed * delta
	
	# Ручная проверка коллизий с мишенями
	check_targets_collision(old_pos, position)
	
	# Удаляем если вылетел за экран
	if position.x < -100 or position.x > 1300:
		queue_free()

func check_targets_collision(from_pos: Vector2, to_pos: Vector2):
	# Получаем все мишени на сцене
	var targets = get_tree().get_nodes_in_group("targets")
	
	# Проверяем расстояние до каждой мишени
	for target in targets:
		if not target or not is_instance_valid(target):
			continue
		
		# Проверяем расстояние между линией полета дротика и центром мишени
		var distance = point_to_line_distance(target.global_position, from_pos, to_pos)
		var target_radius = 24.0  # Максимальный радиус мишени (большая мишень)
		
		if distance < target_radius:
			print("РУЧНОЕ ОБНАРУЖЕНИЕ ПОПАДАНИЯ: Дротик ", dart_id, " в мишень ", target.name)
			_on_body_entered(target)
			return

func point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	# Вычисляет расстояние от точки до линии
	var line_vec = line_end - line_start
	var line_length = line_vec.length()
	
	if line_length == 0:
		return point.distance_to(line_start)
	
	var t = max(0, min(1, (point - line_start).dot(line_vec) / (line_length * line_length)))
	var projection = line_start + t * line_vec
	
	return point.distance_to(projection)

func _on_body_entered(body):
	print("Дротик ", dart_id, " обнаружил столкновение с: ", body.name, " тип: ", body.get_class())
	
	if has_collided:
		return
	
	# Проверяем, что это ТОЧНО мишень
	# 1. Проверяем по имени
	var is_target = false
	if "Target" in body.name:
		print("Это мишень по имени: ", body.name)
		is_target = true
	# 2. Проверяем по классу
	elif body.get_class() == "Target":
		print("Это мишень по классу: Target")
		is_target = true
	# 3. Проверяем по методу
	elif body.has_method("get_target_info"):
		print("Это мишень по методу get_target_info")
		is_target = true
	# 4. Проверяем по группе
	elif body.is_in_group("targets"):
		print("Это мишень по группе 'targets'")
		is_target = true
	
	if is_target:
		print("ПОПАДАНИЕ! Дротик ", dart_id, " в мишень ", body.name)
		has_collided = true
		
		# Получаем информацию о мишени
		var target_info = body.get_target_info()
		var target_id = target_info.get("id", "unknown")
		
		# Сообщаем игре о попадании
		if game_node and game_node.has_method("on_target_hit"):
			game_node.on_target_hit(target_id, dart_id, player_id)
		else:
			print("ОШИБКА: game_node не имеет метода on_target_hit")
		
		# Визуальный эффект
		show_hit_effect()
		
		# Удаляем дротик НЕМЕДЛЕННО
		queue_free()
	else:
		print("Столкновение с не-мишенью: ", body.name, " тип: ", body.get_class())

func show_hit_effect():
	# Создаем эффект попадания
	var effect = Sprite2D.new()
	effect.position = global_position
	effect.scale = Vector2(0.3, 0.3)
	effect.modulate = Color.YELLOW
	
	# Добавляем эффект в корень сцены
	var root = get_tree().root.get_child(0)
	if root:
		root.add_child(effect)
		
		# Удаляем через 0.2 секунды
		var timer = get_tree().create_timer(0.2)
		timer.timeout.connect(func(): 
			if is_instance_valid(effect):
				effect.queue_free()
		)
