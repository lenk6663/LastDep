extends Area2D

class_name Dart

var player_id: int
var speed: float
var game_node: Node
var is_remote: bool = false
var direction: Vector2

func init(id: int, dart_speed: float, game: Node, remote: bool = false):
	player_id = id
	speed = dart_speed
	game_node = game
	is_remote = remote
	
	# Направление выстрела
	direction = Vector2.RIGHT if player_id == 1 else Vector2.LEFT
	
	# Загружаем текстуру дротика
	var sprite = Sprite2D.new()
	var texture = load("res://Assets/Minigames/Shooting/dart.png")
	
	if texture:
		sprite.texture = texture
	else:
		# Запасной вариант
		var image = Image.create(10, 30, false, Image.FORMAT_RGBA8)
		image.fill(Color.BLACK)
		sprite.texture = ImageTexture.create_from_image(image)
	
	sprite.scale = Vector2(0.5, 2)
	
	# Поворачиваем дротик
	if direction.x < 0:
		sprite.rotation_degrees = 180
	
	add_child(sprite)
	
	# Коллизия только для локальных дротиков
	if not is_remote:
		var collision = CollisionShape2D.new()
		collision.shape = CircleShape2D.new()
		collision.shape.radius = 3
		add_child(collision)
		body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += direction * speed * delta
	
	# Удаляем если вылетел за экран
	if position.x < -50 or position.x > 850 or position.y < -50 or position.y > 650:
		queue_free()

func _on_body_entered(body):
	if body is Area2D and body.has_method("get_target_info") and not is_remote:
		var target_info = body.get_target_info()
		if game_node.has_method("hit_target"):
			game_node.hit_target.rpc_id(1, target_info.id, player_id, target_info.size)
		queue_free()
