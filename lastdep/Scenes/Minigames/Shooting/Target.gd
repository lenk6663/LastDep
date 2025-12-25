extends Area2D

class_name Target

var target_id: int
var target_size: int
var velocity: Vector2
var points: int = 10
var is_hit: bool = false

func init(id: int, size: int, vel: Vector2, start_pos: Vector2):
	target_id = id
	target_size = size
	velocity = vel
	position = start_pos
	
	# Загружаем нужную текстуру
	var texture_path = ""
	match size:
		0:  # маленькая
			texture_path = "res://Assets/Minigames/Shooting/target_small.png"
			points = 30
		1:  # средняя
			texture_path = "res://Assets/Minigames/Shooting/target_medium.png"
			points = 20
		2:  # большая
			texture_path = "res://Assets/Minigames/Shooting/target_big.png"
			points = 10
	
	# Создаем спрайт
	var sprite = Sprite2D.new()
	var texture = load(texture_path)
	
	if texture:
		sprite.texture = texture
	else:
		# Запасной вариант
		var image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
		image.fill(Color.RED)
		sprite.texture = ImageTexture.create_from_image(image)
		print("Ошибка загрузки текстуры: ", texture_path)
	
	add_child(sprite)
	
	# Создаем коллизию
	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = _get_collision_radius()
	add_child(collision)
	
	# Сигнал для обработки попаданий
	body_entered.connect(_on_body_entered)

func _get_collision_radius() -> float:
	match target_size:
		0: return 8.0   # 16x16 / 2
		1: return 16.0  # 32x32 / 2  
		2: return 24.0  # 48x48 / 2
	return 15.0

func _on_body_entered(body):
	if not is_hit and body is Dart:
		is_hit = true
		print("Мишень ", target_id, " поражена!")
		queue_free()

func get_target_info():
	return {
		"id": target_id,
		"size": target_size,
		"points": points
	}

func _physics_process(delta):
	if is_hit:
		return
	
	position += velocity * delta
	
	# Удаляем если вышла за границы
	if position.y > 650 or position.y < -50:
		queue_free()
