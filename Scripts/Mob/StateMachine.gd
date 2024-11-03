class_name StateMachine
extends Node

var initial_state: State
var current_state: State
var states: Dictionary = {}
var mob: CharacterBody3D # The mob that we are enabling the behaviour for


# Initialize the StateMachine
func _ready():
	# Create instances of each state and add them to the states dictionary
	var mob_idle = create_mob_idle()
	var mob_follow = create_mob_follow()
	var mob_attack = create_mob_attack()
	var mob_terminate = create_mob_terminate()

	states["mobidle"] = mob_idle
	states["mobfollow"] = mob_follow
	states["mobattack"] = mob_attack
	states["mobterminate"] = mob_terminate
	
	# Connect transitions
	for state in states.values():
		state.Transistioned.connect(on_child_transition)
	
	# Set the initial state if specified
	if initial_state:
		initial_state.Enter()
		current_state = initial_state


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if current_state:
		current_state.Update(delta)


func _physics_process(delta):
	if current_state:
		current_state.Physics_Update(delta)


# When the mob changes from one state to another, often caused by the Detection node
func on_child_transition(state, new_state_name):
	if state != current_state:
		return
		
	var new_state = states.get(new_state_name.to_lower())
	if !new_state:
		return
	if current_state:
		current_state.Exit()
		
	new_state.Enter()
	current_state = new_state


# Create and configure MobIdle
func create_mob_idle() -> MobIdle:
	var mob_idle = MobIdle.new()
	mob_idle.mob = mob
	initial_state = mob_idle
	add_child.call_deferred(mob_idle)
	return mob_idle


# Create and configure MobFollow
func create_mob_follow() -> MobFollow:
	var mob_follow = MobFollow.new()
	mob_follow.mob = mob
	add_child.call_deferred(mob_follow)
	return mob_follow


# Create and configure MobAttack
func create_mob_attack() -> MobAttack:
	var mob_attack = MobAttack.new()
	mob_attack.mob = mob
	add_child.call_deferred(mob_attack)
	return mob_attack


# Create and configure MobTerminate
func create_mob_terminate() -> MobTerminate:
	var mob_terminate = MobTerminate.new()
	add_child.call_deferred(mob_terminate)
	return mob_terminate
