import pytest

class NetworkingManagerMock:
    def __init__(self):
        self.connected_peer_ids = []
        self.spawn_positions = [(0,0),(300,100)]

    def _on_peer_connected(self, peer_id):
        if peer_id not in self.connected_peer_ids:
            self.connected_peer_ids.append(peer_id)

    def _on_peer_disconnected(self, peer_id):
        if peer_id in self.connected_peer_ids:
            self.connected_peer_ids.remove(peer_id)

    def get_player_list(self):
        return self.connected_peer_ids.copy()

    def get_spawn_position(self, peer_id):
        index = self.connected_peer_ids.index(peer_id) if peer_id in self.connected_peer_ids else 0
        return self.spawn_positions[index]

def test_connect_disconnect():
    netmgr = NetworkingManagerMock()
    netmgr._on_peer_connected(1)
    netmgr._on_peer_connected(2)
    assert netmgr.get_player_list() == [1,2]

    netmgr._on_peer_disconnected(1)
    assert netmgr.get_player_list() == [2]

def test_spawn_positions():
    netmgr = NetworkingManagerMock()
    netmgr._on_peer_connected(1)
    netmgr._on_peer_connected(2)
    assert netmgr.get_spawn_position(1) == (0,0)
    assert netmgr.get_spawn_position(2) == (300,100)
    assert netmgr.get_spawn_position(999) == (0,0)
