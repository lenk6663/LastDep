# NetworkingManager.gd
extends Node

const PORT = 9999

var multiplayer_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var connected_peer_ids = []
var should_create_players = false 
# Единый массив позиций спавна
var spawn_positions = [
	Vector2(0, 0),   # Хост (peer_id=1)
	Vector2(300, 100),   # Клиент 1
]

func _ready():
	print("NetworkingManager загружен (Autoload)")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func create_host() -> bool:
	print("Создание хоста на порту", PORT)
	
	var err = multiplayer_peer.create_server(PORT)
	if err != OK:
		print("Ошибка создания сервера:", error_string(err))
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# Хост всегда имеет peer_id = 1
	connected_peer_ids = [1]
	print("Хост создан. Peer ID:", multiplayer.get_unique_id())
	return true

func connect_to_host(ip_address: String) -> bool:
	print("Подключение к:", ip_address)
	
	# Убираем порт если он есть
	var clean_ip = ip_address
	if ":" in ip_address:
		var parts = ip_address.split(":")
		clean_ip = parts[0]
	
	print("Чистый IP:", clean_ip, "Порт:", PORT)
	
	var err = multiplayer_peer.create_client(clean_ip, PORT)
	if err != OK:
		print("Ошибка подключения:", error_string(err))
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Подключение инициировано")
	return true

func _on_peer_connected(peer_id: int):
	print("Игрок подключен:", peer_id)
	
	if multiplayer.is_server():
		# Добавляем в список
		if not connected_peer_ids.has(peer_id):
			connected_peer_ids.append(peer_id)
		
		print("Новый список игроков:", connected_peer_ids)
		
		# Ждем чтобы клиент успел загрузить сцену
		await get_tree().create_timer(0.5).timeout
		
		# Получаем позицию спавна для этого игрока
		var spawn_pos = get_spawn_position(peer_id)
		print("Позиция спавна для игрока", peer_id, ":", spawn_pos)
		
		# Создаем игрока клиента на сервере
		create_player_on_server(peer_id, spawn_pos)
		
		# Сообщаем всем о новом игроке
		spawn_player.rpc(peer_id, spawn_pos)

func create_player_on_server(peer_id: int, position: Vector2):
	print("Сервер: создаю игрока клиента на сервере:", peer_id, " в позиции:", position)
	
	# Ждем пока загрузится игровая сцена
	if get_tree().current_scene and get_tree().current_scene.name == "Menu":
		print("Сервер еще в меню/лобби, откладываем создание игрока")
		# Игрок будет создан позже в Game.gd
		return
	
	var game = get_tree().current_scene
	if game and game.has_method("create_player"):
		game.create_player(peer_id, position)
	else:
		print("Сервер: игровая сцена еще не загружена")

@rpc("authority", "call_remote", "reliable")
func spawn_player(peer_id: int, position: Vector2):
	print("Получена команда создать игрока:", peer_id, " в позиции:", position)
	
	# Не создаем себя - мы уже создали себя в Game._ready()
	if peer_id == multiplayer.get_unique_id():
		print("Это я сам, игнорирую")
		return
	
	var game = get_tree().current_scene
	if game and game.has_method("create_player"):
		game.create_player(peer_id, position)

func _on_peer_disconnected(peer_id: int):
	print("Игрок отключен:", peer_id)
	
	if multiplayer.is_server():
		var index = connected_peer_ids.find(peer_id)
		if index != -1:
			connected_peer_ids.remove_at(index)
		
		print("Обновленный список игроков:", connected_peer_ids)
		
		# Удаляем игрока у всех
		despawn_player.rpc(peer_id)

func _on_connected_to_server():
	print("Успешно подключено к серверу")
	print("Мой peer_id:", multiplayer.get_unique_id())
	
	# Ждем немного и создаем игроков если нужно
	await get_tree().create_timer(0.5).timeout
	if should_create_players:
		print("Создаю игроков после синхронизации из лобби")
		should_create_players = false
		# Здесь можно добавить логику создания игроков если нужно

func _on_connection_failed():
	print("Не удалось подключиться к серверу")

func get_player_list() -> Array:
	return connected_peer_ids

func get_spawn_position(peer_id: int) -> Vector2:
	# Находим индекс игрока в списке
	var index = connected_peer_ids.find(peer_id)
	
	# Если индекс найден и есть позиция для него
	if index >= 0 and index < spawn_positions.size():
		print("Позиция спавна для peer_id", peer_id, " (индекс", index, "):", spawn_positions[index])
		return spawn_positions[index]
	
	# По умолчанию возвращаем первую позицию
	print("Позиция спавна по умолчанию для peer_id", peer_id, ":", spawn_positions[0])
	return spawn_positions[0]

@rpc("authority", "call_remote", "reliable")
func despawn_player(peer_id: int):
	# Все удаляют игрока
	var game = get_tree().current_scene
	if game and game.has_method("remove_player"):
		game.remove_player(peer_id)

func disconnect_all():
	print("Отключение от сети")
	multiplayer_peer.close()
	connected_peer_ids.clear()
	
	# Сбрасываем multiplayer_peer
	multiplayer.multiplayer_peer = null
	print("Соединение закрыто")
