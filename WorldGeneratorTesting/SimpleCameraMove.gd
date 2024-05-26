extends CharacterBody2D

# Speed of the character
@export var speed : float = 2000.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    var input_dir = Input.get_vector("left", "right", "up", "down")
    velocity = input_dir.normalized() * speed
    move_and_slide()

# Optional: If you want to handle physics in _physics_process instead
# Uncomment the following lines and comment out the _process function above

# func _physics_process(delta):
#     var input_dir = Input.get_vector("left", "right", "up", "down")
#     var velocity = input_dir.normalized() * speed
#     velocity = move_and_slide(velocity)