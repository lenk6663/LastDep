# player.gd
extends CharacterBody2D

const SPEED = 150.0
@onready var anim = $AnimatedSprite2D

var input_direction := Vector2.ZERO
var last_direction := Vector2.DOWN
var multiplayer_active := true  # Флаг активности мультиплеера
var is_in_cart := false  # Флаг: находится ли игрок в вагонетке
var cart_player_id := 1  # ID игрока в вагонетке (1 или 2)

func _ready():
	print("Игрок создан:", name, " Authority:", is_multiplayer_authority())
	
	# Проверяем, находимся ли мы в вагонетке (сначала по метаданным)
	if has_meta("in_cart"):
		is_in_cart = get_meta("in_cart")
		if has_meta("cart_player_id"):
			cart_player_id = get_meta("cart_player_id")
			print("Игрок в вагонетке по метаданным, ID:", cart_player_id)
	
	# Дополнительная проверка по имени родителя
	var parent = get_parent()
	if parent and "Cart" in parent.name:
		print("Родитель вагонетка:", parent.name)
		is_in_cart = true
		# Определяем ID по имени родителя
		if "1" in parent.name or "Player1" in parent.name:
			cart_player_id = 1
		elif "2" in parent.name or "Player2" in parent.name:
			cart_player_id = 2
	
	if is_in_cart:
		print("Player: Я в вагонетке, ID:", cart_player_id, " Авторитет:", is_multiplayer_authority())
		
		# Отключаем коллизию
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
		
		# Отключаем обработку ввода
		set_process(false)
		set_physics_process(false)
		
		# Устанавливаем анимацию вагонетки
		# Игрок 1 смотрит вправо (flip_h = false)
		# Игрок 2 смотрит влево (flip_h = true)
		var should_flip = (cart_player_id == 2)
		print("Устанавливаю анимацию вагонетки, flip_h=", should_flip)
		set_cart_animation(should_flip)
		
		return
	
	# Обычный игрок (не в вагонетке)
	multiplayer_active = multiplayer.has_multiplayer_peer()
	set_process(is_multiplayer_authority() and multiplayer_active)
	set_physics_process(is_multiplayer_authority() and multiplayer_active)

func set_cart_animation(flip_h: bool = false):
	if anim:
		print("Player.set_cart_animation для ", name, " flip_h=", flip_h)
		
		# Принудительно устанавливаем анимацию
		is_in_cart = true
		anim.play("IDLE_SIDE2")
		anim.flip_h = flip_h
		
		# Принудительно обновляем
		anim.frame = 0
		anim.play()
	else:
		print("Player.set_cart_animation: anim не найден для ", name)

func _physics_process(delta: float) -> void:
	if is_in_cart:
		return  # В вагонетке не обновляем физику
	
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
	
	_update_animation()
	move_and_slide()

func _update_animation():
	if not anim:
		return
	
	# Если в вагонетке - специальная анимация
	if is_in_cart:
		anim.play("IDLE_SIDE2")
		anim.flip_h = (cart_player_id == 2)  # Игрок 2 смотрит влево
		return
	
	# Обычная анимация вне вагонетки
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

# Остальной код остается без изменений...
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

func force_set_animation(anim_name: String, flip: bool = false):
	if anim:
		print("Игрок ", name, ": принудительная установка анимации ", anim_name, ", flip=", flip)
		anim.stop()
		anim.animation = anim_name
		anim.flip_h = flip
		anim.frame = 0
		anim.play()
