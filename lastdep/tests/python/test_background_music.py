import pytest

class MusicMock:
    def __init__(self):
        self.stream = None
        self.playing = False
        self.current_game_track = 0
        self.is_in_game = False

    def _play_track_from_path(self, path):
        self.stream = path
        self.playing = True

    def play_game_track(self, track):
        if not self.is_in_game:
            return
        self.current_game_track = track
        self._play_track_from_path(f"track_{track}.ogg")

def test_start_game_track():
    music = MusicMock()
    music.is_in_game = True
    music.play_game_track(2)
    assert music.current_game_track == 2
    assert music.stream == "track_2.ogg"

def test_menu_track_not_in_game():
    music = MusicMock()
    music.is_in_game = False
    music.play_game_track(1)
    # Игровая музыка не должна играть вне игры
    assert music.stream is None
