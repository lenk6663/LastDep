# Dart.gd
extends Area2D

class_name Dart

var player_id: int
var speed: float
var direction: Vector2
var shooting_game = null

func init(id: int, dart_speed: float, dir: Vector2, game_ref):
	player_id = id
	speed = dart_speed
	direction = dir
	shooting_game = game_ref
	
	# Настраиваем спрайт
	var sprite = Sprite2D.new()
	var texture = load("res://Assets/Minigames/Shooting/dart.png")
	if texture:
		sprite.texture = texture
		sprite.scale = Vector2(0.5, 0.5)
		if direction.x < 0:  # Если летит влево
			sprite.rotation_degrees = 180
	else:
		# Запасной вариант
		var image = Image.create(20, 10, false, Image.FORMAT_RGBA8)
		var colors = [Color.RED, Color.BLUE]
		image.fill(colors[0] if player_id == 1 else colors[1])
		sprite.texture = ImageTexture.create_from_image(image)
	
	add_child(sprite)
	
	# Коллизия
	var collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = Vector2(15, 5)
	add_child(collision)
	
	# Сигнал
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += direction * speed * delta
	
	# Удаляем если вылетел за экран
	if position.x < -100 or position.x > 1124 or position.y < -100 or position.y > 700:
		queue_free()

func _on_body_entered(body):
	if body is Target and not body.is_hit:
		queue_free()  # Дротик исчезает при попадании
