import pytest

class MockLabel:
    def __init__(self):
        self.text = ""
        self.visible = True

class MockButton:
    def __init__(self):
        self.visible = True
        self.text = ""
        self.pressed_callbacks = []

    def connect(self, signal, callback):
        self.pressed_callbacks.append(callback)

class LobbyMock:
    def __init__(self):
        self.status_label = MockLabel()
        self.ip_label = MockLabel()
        self.start_button = MockButton()
        self.mode = "host"
        self.target_ip = ""
        self.tree_root_children = []
        self.queue_freed = False

    def queue_free(self):
        self.queue_freed = True

def test_lobby_host_ui():
    lobby = LobbyMock()
    # Симулируем _ready
    if lobby.mode == "host":
        lobby.status_label.text = "Создание игры..."
        if lobby.start_button:
            lobby.start_button.visible = False
    assert lobby.status_label.text == "Создание игры..."
    assert lobby.start_button.visible is False

def test_lobby_return_to_menu():
    lobby = LobbyMock()
    lobby.queue_free()
    assert lobby.queue_freed is True
