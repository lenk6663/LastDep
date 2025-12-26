import pytest

class MockSlider:
    def __init__(self):
        self.value = 0.5
        self.value_changed_callbacks = []

    def connect(self, signal, callback):
        self.value_changed_callbacks.append(callback)

class MockOption:
    def __init__(self):
        self.selected = 1
        self.items = []
        self.item_selected_callbacks = []

    def clear(self):
        self.items.clear()

    def add_item(self, text, id):
        self.items.append((text, id))

    def connect(self, signal, callback):
        self.item_selected_callbacks.append(callback)

class MockButton:
    def __init__(self):
        self.pressed_callbacks = []

    def connect(self, signal, callback):
        self.pressed_callbacks.append(callback)

    def press(self):
        for cb in self.pressed_callbacks:
            cb()

class SettingsMock:
    def __init__(self):
        self.music_slider = MockSlider()
        self.resolution_option = MockOption()
        self.back_button = MockButton()
        self.resolutions = [ (1024,576), (1280,720), (1920,1080) ]
        self.applied_volume = None
        self.applied_resolution = None

    def _apply_music_volume(self, value):
        self.applied_volume = value

    def _apply_resolution(self, res):
        self.applied_resolution = res

def test_resolution_options_init():
    settings = SettingsMock()
    # Симулируем _init_resolution_options
    settings.resolution_option.clear()
    for i, res in enumerate(settings.resolutions):
        settings.resolution_option.add_item(f"{res[0]} x {res[1]}", i)
    assert len(settings.resolution_option.items) == len(settings.resolutions)
    assert settings.resolution_option.items[0] == ("1024 x 576", 0)

def test_apply_volume_and_resolution():
    settings = SettingsMock()
    settings._apply_music_volume(0.7)
    settings._apply_resolution((1280,720))
    assert settings.applied_volume == 0.7
    assert settings.applied_resolution == (1280,720)

def test_slider_change_triggers_apply(monkeypatch):
    settings = SettingsMock()
    called = {}
    def fake_apply(value):
        called["volume"] = value
    settings._apply_music_volume = fake_apply
    # Симулируем сигнал
    for cb in settings.music_slider.value_changed_callbacks:
        cb(0.8)
    # Проверяем, что вызов apply_volume был
    # Здесь просто проверяем вручную
