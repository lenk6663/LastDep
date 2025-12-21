extends Area2D

class_name PlayerCart

var player_id: int
var is_local: bool
var game_node: Node
var speed: float = 200.0
var screen_height: float = 600.0

func init(id: int, local: bool, game: Node):
	player_id = id
	is_local = local
	game_node = game
	
	# Создаем спрайт если его нет
	if get_child_count() == 0:
		var sprite = Sprite2D.new()
		# Создаем простую текстуру
		var image = Image.create(40, 20, false, Image.FORMAT_RGBA8)
		image.fill(Color.RED if player_id == 1 else Color.BLUE)
		var texture = ImageTexture.create_from_image(image)
		sprite.texture = texture
		add_child(sprite)
		
		var collision = CollisionShape2D.new()
		collision.shape = CircleShape2D.new()
		collision.shape.radius = 20
		add_child(collision)
	
	if is_local:
		set_process(true)

func _process(delta):
	if not is_local:
		return
	
	# Движение вверх/вниз
	var direction = Input.get_axis("ui_up", "ui_down")
	position.y += direction * speed * delta
	
	# Ограничиваем движение по экрану
	position.y = clamp(position.y, 50, screen_height - 50)
	
	# Стрельба по нажатию пробела
	if Input.is_action_just_pressed("ui_accept"):
		game_node.request_fire.rpc_id(1, player_id)
