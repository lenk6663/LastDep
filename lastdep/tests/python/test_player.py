import pytest

class MockAnim:
    def __init__(self):
        self.animation = ""
        self.flip_h = False
        self.played = []

    def play(self, anim_name):
        self.animation = anim_name
        self.played.append(anim_name)

    def stop(self):
        pass

class PlayerMock:
    def __init__(self):
        self.input_direction = (0, 0)
        self.velocity = (0, 0)
        self.last_direction = (0, 1)
        self.is_in_cart = False
        self.cart_player_id = 1
        self.anim = MockAnim()

    def _update_animation(self):
        if self.is_in_cart:
            self.anim.play("IDLE_SIDE2")
            self.anim.flip_h = (self.cart_player_id == 2)
        elif self.velocity != (0,0):
            self.anim.play("WALK_FRONT")
        else:
            self.anim.play("IDLE_FRONT2")

def test_idle_animation():
    player = PlayerMock()
    player._update_animation()
    assert player.anim.animation == "IDLE_FRONT2"

def test_cart_animation_flip():
    player = PlayerMock()
    player.is_in_cart = True
    player.cart_player_id = 2
    player._update_animation()
    assert player.anim.animation == "IDLE_SIDE2"
    assert player.anim.flip_h is True
