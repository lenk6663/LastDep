# player.gd
extends CharacterBody2D

const SPEED = 150.0
@onready var anim = $AnimatedSprite2D

var input_direction := Vector2.ZERO
var last_direction := Vector2.DOWN
var multiplayer_active := true  # Флаг активности мультиплеера

func _ready():
	print("Игрок создан:", name, " Authority:", is_multiplayer_authority())
	
	# Проверяем активность мультиплеера
	multiplayer_active = multiplayer.has_multiplayer_peer()
	
	# Только локальный игрок обрабатывает ввод
	set_process(is_multiplayer_authority() and multiplayer_active)
	set_physics_process(is_multiplayer_authority() and multiplayer_active)
	

func _process(delta: float) -> void:
	if not is_multiplayer_authority() or not multiplayer_active:
		return
	
	# Проверяем активность мультиплеера
	if not multiplayer.has_multiplayer_peer():
		multiplayer_active = false
		set_process(false)
		return
	
	# Считываем ввод
	input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Отправляем движение всем
	if input_direction != Vector2.ZERO:
		sync_movement.rpc(input_direction, position)
		last_direction = input_direction
	elif input_direction == Vector2.ZERO and last_direction != Vector2.ZERO:
		# Останавливаемся
		sync_movement.rpc(Vector2.ZERO, position)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or not multiplayer_active:
		return
	
	# Проверяем активность мультиплеера
	if not multiplayer.has_multiplayer_peer():
		multiplayer_active = false
		set_physics_process(false)
		return
	
	# Локальное движение для авторитетного игрока
	if input_direction:
		velocity = input_direction * SPEED
	else:
		velocity = Vector2.ZERO
	
	_update_animation_local()
	move_and_slide()

func _update_animation_local():
	if not anim:
		return
	
	if velocity.length() > 0:
		# Горизонтальное движение
		if abs(velocity.x) > abs(velocity.y):
			anim.play("WALK_SIDE")
			anim.flip_h = velocity.x > 0
		# Движение вверх
		elif velocity.y < 0:
			anim.play("WALK_BACK")
			anim.flip_h = false
		# Движение вниз
		elif velocity.y > 0:
			anim.play("WALK_FRONT")
			anim.flip_h = false
	else:
		# Проигрываем idle анимацию в зависимости от последнего направления
		if abs(last_direction.x) > abs(last_direction.y):
			anim.play("IDLE_SIDE2")
			anim.flip_h = last_direction.x > 0
		elif last_direction.y < 0:
			anim.play("IDLE_BACK2")
			anim.flip_h = false
		else:
			anim.play("IDLE_FRONT2")
			anim.flip_h = false

@rpc("any_peer", "call_remote", "unreliable")
func sync_movement(direction: Vector2, new_position: Vector2):
	# Только если это не наш игрок
	if not is_multiplayer_authority():
		velocity = direction * SPEED
		position = new_position
		
		# Обновляем анимацию
		if direction != Vector2.ZERO:
			last_direction = direction
			if abs(direction.x) > abs(direction.y):
				anim.play("WALK_SIDE")
				anim.flip_h = direction.x > 0
			elif direction.y < 0:
				anim.play("WALK_BACK")
				anim.flip_h = false
			elif direction.y > 0:
				anim.play("WALK_FRONT")
				anim.flip_h = false
		else:
			# В idle анимацию
			if abs(last_direction.x) > abs(last_direction.y):
				anim.play("IDLE_SIDE2")
				anim.flip_h = last_direction.x > 0
			elif last_direction.y < 0:
				anim.play("IDLE_BACK2")
				anim.flip_h = false
			else:
				anim.play("IDLE_FRONT2")
				anim.flip_h = false
		
		move_and_slide()
