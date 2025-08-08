extends CharacterBody3D

# player nodes

@onready var head: Node3D = $Head
@onready var camera_3d: Camera3D = $Head/Camera3D
@onready var standing_collision_shape: CollisionShape3D = $standing_collision_shape
@onready var crouching_collision_shape: CollisionShape3D = $crouching_collision_shape
@onready var ray_cast_3d: RayCast3D = $RayCast3D

# speed vars

var current_speed = 5.0
const walk_speed = 5.0
const sprint_speed = 8.0
const crouch_speed = 3.0

# movement vars
const jump_velocity = 4.5

var lerp_speed = 10.0
var air_lerp_speed = 3.0
var crouch_depth = -0.5

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

func _physics_process(delta): 
	
	# handle movement state
	
	#crouching
	
	if Input.is_action_pressed("Crouch") and is_on_floor():	
		current_speed = crouch_speed
		head.position.y = lerp(head.position.y,1.8 + crouch_depth,delta*lerp_speed)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
	elif !ray_cast_3d.is_colliding():
	#standing
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y,1.8,delta*lerp_speed)
		
	if Input.is_action_pressed("Sprint"):
			current_speed = sprint_speed
	else:
			current_speed = walk_speed
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and ! ray_cast_3d.is_colliding():
		velocity.y = jump_velocity

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
	
	#handle headbob
	
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera_3d.transform.origin = _headbob(t_bob)
	
	move_and_slide()
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * bob_amp
	pos.x = cos(time * bob_freq /2) * bob_amp
	return pos
