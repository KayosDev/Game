extends Node2D
class_name StateClass

# Signal to notify the state machine about transitions between states
signal TransitionSignal(new_state_name)

# These are the base functions that should be overridden by child state classes
func enter():
    pass

func exit():
    pass

func handle_input(_event):
    pass

func Update(_delta):
    pass

func Physics_Update(_delta):
    pass 