extends CharacterBody3D

# Maximum airspeed
var max_flight_speed = 30
# Turn rate
@export var turn_speed = 5.0
@export var level_speed = 12.0
@export var turn_acc = 4.0
# Climb/dive rate
var pitch_speed = 2.0
# Wings "autolevel" speed
# Throttle change speed
var throttle_delta = 30
# Acceleration/deceleration
var acceleration = 6.0
# Current speed
var forward_speed = 0
# Throttle input speed
var target_speed = 0

#var velocity = Vector3.ZERO
var found_goal = false
var exited_arena = false
var cur_goal = null
@onready var environment = get_parent()
# ------- #
var turn_input = 0
var pitch_input = 0
var shoot_input = 0
var done = false
var _heuristic = "human"
var best_goal_distance := 10000.0
var transform_backup = null
var n_steps = 0
const MAX_STEPS = 200000
var needs_reset = false
var reward = 0.0
var distance_threshold = 0.6
var distance_panalty = 4


func _ready():
	transform_backup = transform
	pass
	
func reset():
	resetTimer()
	needs_reset = false
	
	cur_goal = environment.get_next_goal(null)
	transform_backup = transform_backup
	position.x = 20 + randf_range(-2,2)
	position.y = 27 + randf_range(-2,2)
	position.z = 0 + randf_range(-2,2)
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	n_steps = 0
	found_goal = false
	exited_arena = false 
	done = false
	best_goal_distance = to_local(cur_goal.position).length()
	# reset position, orientation, velocity

func reset_if_done():
	if done:
		reset()
		
func get_done():
	return done
	
func set_done_false():
	done = false
	
func get_obs():
	if cur_goal == null:
		reset()
	#var goal_vector = (cur_goal.position - position).normalized() # global frame of reference
	var goal_vector = to_local(cur_goal.position)
	var goal_distance = goal_vector.length()
	goal_vector = goal_vector.normalized()
	goal_distance = clamp(goal_distance, 0.0, 50.0)

	var obs = [
		goal_vector.x,
		goal_vector.y,
		goal_vector.z,
	] + getRCS()
	
	return { "obs": obs }

func getRCS():
	return [] + $FrontRCS.get_observation() + $LeftWingRCS.get_observation() + $RightWingRCS.get_observation()

func getCamera():
	print($SubViewport.get_texture().get_image())
	return []

func update_reward():
	reward -= 0.01 # step penalty
	reward += shaping_reward()

func get_reward():
	return reward

func shaping_reward():
	var s_reward = 0.0
	var goal_distance = to_local(cur_goal.position).length()
	if goal_distance < best_goal_distance:
		s_reward += best_goal_distance - goal_distance
		best_goal_distance = goal_distance
	
	for sensor_value in getRCS():
		if sensor_value > distance_threshold:
			s_reward -= (distance_panalty * (sensor_value / distance_threshold))
		if sensor_value == 1:
			s_reward -= 200
			self.reset()
	
	if in_range(turn_input, -0.4, 0.4):
		s_reward += (1 - abs(turn_input))
	
	if in_range(pitch_input, -0.4, 0.4):
		s_reward += (1 - abs(pitch_input))
	
	s_reward /= 1.0
	return s_reward 

func in_range(value: float, min: float, max: float):
	return value >= min and value <= max

func set_heuristic(heuristic):
	self._heuristic = heuristic

func get_obs_space():
	# typs of obs space: box, discrete, repeated
	return {
		"obs": {
			"size": [len(get_obs()["obs"])],
			"space": "box"
		}
	}

func get_action_space():
	return {
		"turn" : {
			"size": 1,
			"action_type": "continuous"
		},        
		"pitch" : {
			"size": 1,
			"action_type": "continuous"
		},
		"shoot": {
			"size": 1,
			"action_type": "discrete"
		}
	}

func set_action(action):
	turn_input = action["turn"][0]
	pitch_input = action["pitch"][0]
	shoot_input = action["shoot"][0]

func _physics_process(delta):
	#if self.name == 'Plane':
	#	printerr($TestRCS.get_observation())
	
	n_steps +=1    
	if n_steps >= MAX_STEPS:
		done = true
		needs_reset = true

	if needs_reset:
		needs_reset = false
		reset()
		return
	
	if cur_goal == null:
		reset()
	set_input()
	if Input.is_action_just_pressed("shoot"):
		environment.rewspawn_bullet(self)
		print('shoot key pressed! need read plane position and pass to rewspanw bullet')
		#var bullet_instance = preload("res://Bullet.tscn").instantiate()
		#bullet_instance.position = $".".global_position
		#bullet_instance.direction = $".".global_direction
		#add_child(bullet_instance)
	
	if Input.is_action_just_pressed("r_key"):
		reset()
	# Rotate the transform based checked the input values
	transform.basis = transform.basis.rotated(transform.basis.x.normalized(), pitch_input * pitch_speed * delta)
	transform.basis = transform.basis.rotated(Vector3.UP, turn_input * turn_speed * delta)
	$PlaneModel.rotation.z = lerp($PlaneModel.rotation.z, -float(turn_input), level_speed * delta)
	$PlaneModel.rotation.x = lerp($PlaneModel.rotation.x, -float(pitch_input), level_speed * delta)

	# Movement is always forward
	velocity = -transform.basis.z.normalized() * max_flight_speed
	# Handle landing/taking unchecked
	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()
	n_steps += 1
		
	update_reward()
		
func zero_reward():
	reward = 0.0  
	
func set_input():
	if _heuristic == "model":
		return
	else:
		turn_input = Input.get_action_strength("roll_left") - Input.get_action_strength("roll_right")
		pitch_input = Input.get_action_strength("pitch_up") - Input.get_action_strength("pitch_down")
		shoot_input = Input.get_action_strength("shoot")


func goal_reached(goal):
	resetTimer()
	if goal == cur_goal:
		reward += 1000.0
		cur_goal = environment.get_next_goal(cur_goal)

func bullet_acheved_target():
	print('bullet_acheved_target')

func resetTimer():
	$Timer.stop()
	$Timer.start()

func _on_timer_timeout():
	reward -= 2000
	self.reset()
	
func exited_game_area():
	done = true
	reward -= 2000.0
	exited_arena = true
	self.reset()
