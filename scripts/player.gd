extends CharacterBody3D

# player nodes

@onready var head: Node3D = $Head
@onready var eyes: Node3D = $Head/Eyes
@onready var camera_3d: Camera3D = $Head/Eyes/Camera3D
@onready var standing_collision_shape: CollisionShape3D = $standing_collision_shape
@onready var crouching_collision_shape: CollisionShape3D = $crouching_collision_shape
@onready var bonk_raycast: RayCast3D = $RayCast3D
@onready var animation_player: AnimationPlayer = $Head/Eyes/Camera3D/AnimationPlayer


# speed vars

var current_speed = 5.0

@export var walk_speed = 5.0
@export var sprint_speed = 8.0
@export var crouch_speed = 3.0

# movement vars
const jump_velocity = 4.5
var lerp_speed = 10.0
var air_lerp_speed = 1.5
var crouch_depth = -0.5
var last_velocity = Vector3.ZERO

# stair & slope detection vars

#head tilt vars
var camera_tilt_left = 1.5
var camera_tilt_right = -1.5
var _lerp_angle = 6

# head bob vars
const bob_freq = 2.0
const bob_amp = 0.08
var t_bob = 0.0

# input vars

var direction = Vector3.ZERO
const mouse_sens = 0.4

func _ready():	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	#mouse looking logic
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x,deg_to_rad(-89),deg_to_rad (89))
	
	# stairs logic
var _was_on_floor_last_frame = false
var _snapped_to_stairs_last_frame = false
func _snap_down_to_stairs_check():
	var did_snap = false
	if not is_on_floor() and velocity.y <= 0 and (_was_on_floor_last_frame or _snapped_to_stairs_last_frame) and $StairsBelowRaycast3D.is_colliding():
		var body_test_result = PhysicsTestMotionResult3D.new()
		var params = PhysicsTestMotionParameters3D.new()
		var max_step_down = -0.5
		params.from = self.global_transform
		params.motion = Vector3(0,max_step_down,0)
		if PhysicsServer3D.body_test_motion(self.get_rid(), params, body_test_result):
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
		
		
	_was_on_floor_last_frame = is_on_floor()
	_snapped_to_stairs_last_frame = did_snap
	
@onready var _initial_seperation_ray_dist =abs($StepUpSeparationRay_F.position.z)
func _rotate_step_up_seperation_ray():
	var xz_vel = velocity * Vector3(1,0,1)
	var xz_f_ray_pos = xz_vel.normalized() * _initial_seperation_ray_dist
	$StepUpSeparationRay_F.global_position.x = self.global_position.x + xz_f_ray_pos.x
	$StepUpSeparationRay_F.global_position.z = self.global_position.z + xz_f_ray_pos.z
	
	
func _physics_process(delta): 
	
	# handle movement state
	
	current_speed = walk_speed
	if Input.is_action_pressed("Sprint") and is_on_floor():
		current_speed = sprint_speed
	#crouching
	if (Input.is_action_pressed("Crouch") or bonk_raycast.is_colliding()) and is_on_floor():	
		current_speed = crouch_speed
		head.position.y = lerp(head.position.y,1.8 + crouch_depth,delta*lerp_speed)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
	elif !bonk_raycast.is_colliding():
	#standing
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y,1.8,delta*lerp_speed)
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if is_on_floor():
			if Input.is_action_just_pressed("ui_accept") and is_on_floor() and ! bonk_raycast.is_colliding():
				velocity.y = jump_velocity
				animation_player.play("Jump")
	# Handle Landing
	if is_on_floor():
		if last_velocity.y < 0.0:
			animation_player.play("Landing")
		 
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	
	if is_on_floor():
		direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),delta*lerp_speed)
	else:
		if input_dir !=Vector2.ZERO:
			direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),delta*air_lerp_speed)
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	
	#handle headtilt left & right
	
	if Input.is_action_pressed("Left"):
		camera_3d.rotation.z = lerp(camera_3d.rotation.z, deg_to_rad(camera_tilt_left), delta * _lerp_angle)
	elif Input.is_action_pressed("Right"):
		camera_3d.rotation.z = lerp(camera_3d.rotation.z, deg_to_rad(camera_tilt_right), delta * _lerp_angle)
	else:
		camera_3d.rotation.z = lerp(camera_3d.rotation.z, deg_to_rad(0), delta * _lerp_angle)
	
	_rotate_step_up_seperation_ray()
	
	move_and_slide()
	
	_snap_down_to_stairs_check()
	
	#handle headbob
	
	t_bob += delta * velocity.length() * float(is_on_floor())
	eyes.transform.origin = _headbob(t_bob)
	last_velocity = velocity
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * bob_amp
	pos.x = cos(time * bob_freq /2) * bob_amp
	return pos
	
