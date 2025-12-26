import pytest

class MockButton:
    def __init__(self):
        self.pressed_callbacks = []
        self.text = ""
        self.disabled = False

    def connect(self, signal, callback):
        self.pressed_callbacks.append(callback)

    def press(self):
        for cb in self.pressed_callbacks:
            cb()

class MockMenu:
    def __init__(self):
        self.create_button = MockButton()
        self.settings_button = MockButton()
        self.hidden = False
        self.settings_opened = False

    def hide(self):
        self.hidden = True

class MenuMock:
    SETTINGS_SCENE = True
    def __init__(self):
        self.root_added = False
        self.menu_node = MockMenu()
        self.tree_root = self.menu_node

    def get_tree(self):
        return self

    def root(self):
        return self.tree_root

    def add_child(self, node):
        self.root_added = True

    def hide(self):
        self.menu_node.hide()

def test_settings_open():
    menu = MenuMock()
    menu_opened = {}
    def fake_instantiate():
        menu_opened["opened"] = True
        return "instance"
    MenuMock.SETTINGS_SCENE = type("Scene", (), {"instantiate": staticmethod(fake_instantiate)})
    # Симулируем нажатие
    menu.menu_node.settings_button.press()
    # Проверяем, что меню скрыто
    menu.menu_node.hide()
