import pytest

class MockLabel:
    def __init__(self):
        self.text = ""
        self.visible = False

class NPCMock:
    def __init__(self):
        self.ready_players = []
        self.players_in_zone = []
        self.minigame_active = False
        self.interaction_label = MockLabel()

    def toggle_player_ready(self, player_id):
        if self.minigame_active:
            return
        if player_id in self.ready_players:
            self.ready_players.remove(player_id)
        else:
            self.ready_players.append(player_id)

def test_toggle_ready():
    npc = NPCMock()
    npc.toggle_player_ready(1)
    assert npc.ready_players == [1]

    npc.toggle_player_ready(1)
    assert npc.ready_players == []

def test_multiple_players():
    npc = NPCMock()
    npc.toggle_player_ready(1)
    npc.toggle_player_ready(2)
    assert npc.ready_players == [1,2]
