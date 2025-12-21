extends Area2D

class_name Target

var target_id: int
var target_size: int
var velocity: Vector2

func init(id: int, size: int, vel: Vector2):
	target_id = id
	target_size = size
	velocity = vel
	
	# Создаем спрайт
	var sprite = Sprite2D.new()
	
	# Создаем цветную текстуру в зависимости от размера
	var image_size = 40
	match size:
		0:  # маленькая
			image_size = 20
			sprite.modulate = Color.YELLOW
		1:  # средняя
			image_size = 30
			sprite.modulate = Color.ORANGE
		2:  # большая
			image_size = 40
			sprite.modulate = Color.GREEN
	
	var image = Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
	image.fill(sprite.modulate)
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	sprite.position = Vector2(image_size/2, image_size/2)
	add_child(sprite)
	
	# Создаем коллизию
	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = image_size / 2
	add_child(collision)
	
	# Добавляем сигнал для дебага
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("Мишень", target_id, "столкнулась с", body.name)

func get_target_info():
	return {"id": target_id, "size": target_size}

func _physics_process(delta):
	position += velocity * delta
	
	# Если мишень ушла за нижнюю границу, удаляем
	if position.y > 600:
		queue_free()
