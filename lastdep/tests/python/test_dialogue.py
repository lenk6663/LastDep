import pytest

class MockLabel:
    def __init__(self):
        self.text = ""
        self.visible = True

class MockButton:
    def __init__(self):
        self.text = ""
        self.disabled = False
        self.pressed_callbacks = []

    def pressed(self, func):
        self.pressed_callbacks.append(func)

    def press(self):
        for cb in self.pressed_callbacks:
            cb()

class DialogueMock:
    def __init__(self):
        self.current_player_id = 1
        self.ready_players = []
        self.is_player_ready = False
        self.minigame_type = "memory"
        self.title_label = MockLabel()
        self.content_label = MockLabel()
        self.ready_button = MockButton()
        self.ready_status_label = MockLabel()

    def update_ready_status(self):
        self.ready_button.text = "ГОТОВ" if self.is_player_ready else "ПРИГОТОВИТЬСЯ"
        self.ready_status_label.text = f"Готовы: {len(self.ready_players)}/2 игрока"

    def _on_ready_pressed(self):
        self.is_player_ready = not self.is_player_ready
        self.update_ready_status()

    def set_ready_players(self, players_list):
        self.ready_players = players_list.copy()
        self.is_player_ready = self.current_player_id in self.ready_players
        self.update_ready_status()

@pytest.fixture
def dialogue():
    return DialogueMock()

def test_initial_ready_status(dialogue):
    dialogue.update_ready_status()
    assert dialogue.ready_button.text == "ПРИГОТОВИТЬСЯ"
    assert dialogue.ready_status_label.text == "Готовы: 0/2 игрока"

def test_toggle_ready(dialogue):
    dialogue._on_ready_pressed()
    assert dialogue.is_player_ready is True
    assert dialogue.ready_button.text == "ГОТОВ"

    dialogue._on_ready_pressed()
    assert dialogue.is_player_ready is False
    assert dialogue.ready_button.text == "ПРИГОТОВИТЬСЯ"

def test_set_ready_players(dialogue):
    dialogue.set_ready_players([1,2])
    assert dialogue.is_player_ready is True
    assert dialogue.ready_status_label.text == "Готовы: 2/2 игрока"

    dialogue.set_ready_players([2])
    assert dialogue.is_player_ready is False
    assert dialogue.ready_status_label.text == "Готовы: 1/2 игрока"
