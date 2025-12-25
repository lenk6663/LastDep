# Target.gd
extends Area2D

class_name Target

var target_id: int
var target_size: int
var velocity: Vector2
var points: int = 10
var is_hit: bool = false
var shooting_game = null

func init(id: int, size: int, vel: Vector2, game_ref):
	target_id = id
	target_size = size
	velocity = vel
	shooting_game = game_ref
	
	# Настраиваем спрайт
	var sprite = Sprite2D.new()
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
	
	var texture = load(texture_path)
	if texture:
		sprite.texture = texture
	else:
		# Запасной вариант
		var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var colors = [Color.RED, Color.YELLOW, Color.GREEN]
		image.fill(colors[size])
		sprite.texture = ImageTexture.create_from_image(image)
	
	add_child(sprite)
	
	# Коллизия
	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = [12.0, 16.0, 20.0][size]
	add_child(collision)
	
	# Сигнал для обработки попаданий
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if not is_hit and body is Dart:
		is_hit = true
		print("Мишень ", target_id, " поражена!")
		
		# Сообщаем игре о попадании
		if shooting_game and shooting_game.has_method("on_target_hit"):
			shooting_game.on_target_hit(target_id, body.player_id, target_size)
		
		queue_free()

func get_target_info():
	return {
		"id": target_id,
		"size": target_size,
		"points": points
	}

# В Target.gd обновите _physics_process:
func _physics_process(delta):
	if is_hit:
		return
	
	position += velocity * delta
	
	# Удаляем если вышли за боковые границы
	if position.x < -100 or position.x > 1124:
		queue_free()
