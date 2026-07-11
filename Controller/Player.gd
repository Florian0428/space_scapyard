extends CharacterBody3D
class_name Player

## How fast the player moves on the ground.
@export var base_speed := 6.0
## How high the player can jump in meters.
@export var jump_height := 1.2
## How fast the player falls after reaching max jump height.
@export var fall_multiplier := 2.5

@export_category("Camera")
## How much moving the mouse moves the camera. Overwritten in settings.
@export var mouse_sensitivity: float = 0.00075
## Limits how low the player can look down.
@export var bottom_clamp: float = -90.0
## Limits how high the player can look up.
@export var top_clamp: float = 90.0

@export_category("Third Person")
## Limits how far the player can zoom in.
@export var min_zoom: float = 1.5
## Limits how far the player can zoom out.
@export var max_zoom: float = 6.0
## How quickly to zoom the camera
@export var zoom_sensitivity: float = 0.4

@export_category("Carrying")
## Maximum distance the player can pick up junk from.
@export var pickup_range: float = 3.0

@export_category("Sprint & Stamina")
## Sprint sebesség-szorzó (a base_speed-re rászorozva, míg sprintel).
@export var sprint_multiplier: float = 1.8
## A stamina bár maximális értéke.
@export var max_stamina: float = 100.0
## Mennyi stamina fogy el másodpercenként, amíg sprintel.
@export var stamina_drain_rate: float = 25.0
## Mennyi stamina regenerálódik másodpercenként, amíg NEM sprintel.
@export var stamina_regen_rate: float = 15.0
## Mennyi ideig kell várni sprintelés abbahagyása UTÁN, mire elkezd
## regenerálódni a stamina (hogy ne legyen azonnali, "olcsó" a rendszer).
@export var stamina_regen_delay: float = 1.0
## Ha a stamina teljesen kifogy, ennyit kell előbb regenerálódnia,
## mielőtt újra lehet sprintelni (elkerüli az azonnali újraindítást 0-ról).
@export var min_stamina_to_resprint: float = 20.0

# Emitted whenever the stamina value changes, so the UI stamina bar
# can update itself without polling every frame.
signal stamina_changed(current: float, max_value: float)

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
# Stores the direction the player is trying to look this frame.
var _look := Vector2.ZERO

var stamina: float = max_stamina
var is_sprinting: bool = false
# True once stamina hits 0 - blocks sprinting again until min_stamina_to_resprint.
var _stamina_exhausted: bool = false
# Counts down after sprint stops, before regen kicks in.
var _stamina_regen_timer: float = 0.0

enum VIEW {
	FIRST_PERSON,
	THIRD_PERSON_BACK
}

# Updates the cameras to swap between first and third person.
var view := VIEW.FIRST_PERSON:
	set(value):
		view = value
		match view:
			VIEW.FIRST_PERSON:
				# Get the fov of the current camera and apply it to the target.
				camera.fov = get_viewport().get_camera_3d().fov
				camera.current = true
			VIEW.THIRD_PERSON_BACK:
				# Get the fov of the current camera and apply it to the target.
				third_person_camera.fov = get_viewport().get_camera_3d().fov
				third_person_camera.current = true

# Control the target length of the third person camera arm..
var zoom := min_zoom:
	set(value):
		zoom = clamp(value, min_zoom, max_zoom)
		if value < min_zoom:
			# When the player zooms all the way in swap to first person.
			view = VIEW.FIRST_PERSON
		elif value > min_zoom:
			# When the player zooms out at all swap to third person.
			view = VIEW.THIRD_PERSON_BACK

@onready var camera: Camera3D = $SmoothCamera
@onready var third_person_camera: Camera3D = %ThirdPersonCamera
@onready var spring_arm_3d: SpringArm3D = %SpringArm3D

@onready var camera_target: Node3D = $CameraTarget
@onready var camera_origin = camera_target.position

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var run_particles: GPUParticles3D = $BasePivot/RunParticles
@onready var jump_particles: GPUParticles3D = $BasePivot/JumpParticles

@onready var jump_audio: AudioStreamPlayer3D = %JumpAudio
@onready var run_audio: AudioStreamPlayer3D = %RunAudio

@onready var hold_point: Node3D = $CameraTarget/HoldPoint
# The junk piece currently being carried, or null if hands are empty.
var held_junk: RigidBody3D = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Whenever the player loads in, give the autoload ui a reference to itself.
	UserInterface.update_player(self)


func _physics_process(delta: float) -> void:
	frame_camera_rotation()
	smooth_camera_zoom(delta)
	
	# Add gravity.
	if not is_on_floor():
		# if holding jump and ascending be floaty.
		if velocity.y >= 0 and Input.is_action_pressed("ui_accept"):
			velocity.y -= gravity * delta
		else:
			# Double fall speed, after peak of jump or release of jump button.
			velocity.y -= gravity * delta * fall_multiplier
		
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		# Projectile motion to turn jump height into a velocity.
		velocity.y = sqrt(jump_height * 2.0 * gravity)
		jump_particles.restart()
		jump_audio.play()
		run_audio.play()
	
	handle_sprint(delta)
	
	# Handle movement.
	var direction = get_movement_direction()
	var current_speed = base_speed * sprint_multiplier if is_sprinting else base_speed
	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, current_speed * delta)
		velocity.z =  lerp(velocity.z, direction.z * current_speed, current_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, base_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0, base_speed * delta * 5.0)
	
	# Emit run particles when moving on the floor.
	run_particles.emitting = not direction.is_zero_approx() and is_on_floor()
		
	update_animation_tree()
	move_and_slide()

# Turn movent inputs into a locally oriented vector.
func get_movement_direction() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
# Apply the _look variables rotation to the camera.
func frame_camera_rotation() -> void:
	rotate_y(_look.x)
	# The smooth camera orients the camera to align with the target smoothly.
	camera_target.rotate_x(_look.y)
	camera_target.rotation.x = clamp(camera_target.rotation.x, 
		deg_to_rad(bottom_clamp), 
		deg_to_rad(top_clamp)
	)
	# Reset the _look variable so the same offset can't be reapplied.
	_look = Vector2.ZERO


# Blend the walking animation based on movement direction.
func update_animation_tree() -> void:
	# Get the local movement direction.
	var movement_direction = basis.inverse() * velocity / base_speed
	# Convert the direction to a Vector2 to select the correct movement animation.
	var animation_target = Vector2(movement_direction.x, -movement_direction.z)
	animation_tree.set("parameters/blend_position", animation_target)

func _unhandled_input(event: InputEvent) -> void:
	# Update the _look variable to the latest mouse offset.
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_look = -event.relative * mouse_sensitivity
	# Capture the mouse if it is uncaptured.
	if event.is_action_pressed("click"):
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
	# Camera controls.
	if event.is_action_pressed("toggle_view"):
		cycle_view()
	if event.is_action_pressed("zoom_in"):
		zoom -= zoom_sensitivity
	elif event.is_action_pressed("zoom_out"):
		zoom += zoom_sensitivity

	# Pick up or drop junk.
	if event.is_action_pressed("interact"):
		if held_junk:
			drop_junk()
		else:
			try_pickup_junk()
	
func cycle_view() -> void:
	# Swap from third to first person and vice versa.
	match view:
		VIEW.FIRST_PERSON:
			view = VIEW.THIRD_PERSON_BACK
			# Set the default third person zoom to halfway between min and max.
			zoom = lerp(min_zoom, max_zoom, 0.5)
		VIEW.THIRD_PERSON_BACK:
			view = VIEW.FIRST_PERSON
		_:
			view = VIEW.FIRST_PERSON

# Interpolate the third person distance to the target length.
func smooth_camera_zoom(delta: float) -> void:
	spring_arm_3d.spring_length = lerp(
		spring_arm_3d.spring_length,
		zoom,
		delta * 10.0
	)

# Play a footstep sound effect when moving.
func _on_footstep_timer_timeout() -> void:
	if is_on_floor() and get_movement_direction():
		run_audio.play()

# Cast a ray from the active camera and try to pick up whatever it hits.
func try_pickup_junk() -> void:
	var cam := get_viewport().get_camera_3d()
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * pickup_range

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if result and result.collider is RigidBody3D and result.collider.is_in_group("Junk"):
		held_junk = result.collider
		# Stop it being affected by physics and colliding while carried.
		held_junk.freeze = true
		held_junk.collision_layer = 0
		held_junk.collision_mask = 0
		# Snap it to the hold point in front of the camera.
		held_junk.reparent(hold_point)
		held_junk.position = Vector3.ZERO
		held_junk.rotation = Vector3.ZERO

# Release the currently held junk back into the world.
func drop_junk() -> void:
	if not held_junk:
		return
	held_junk.reparent(get_tree().current_scene)
	held_junk.collision_layer = 1
	held_junk.collision_mask = 1
	held_junk.freeze = false
	held_junk = null

# Handle sprint input, stamina drain and regen. Sets is_sprinting for
# the movement code to read this frame.
func handle_sprint(delta: float) -> void:
	var wants_to_sprint := (
		Input.is_action_pressed("sprint")
		and not get_movement_direction().is_zero_approx()
		and is_on_floor()
	)

	if wants_to_sprint and not _stamina_exhausted and stamina > 0.0:
		is_sprinting = true
		stamina = max(stamina - stamina_drain_rate * delta, 0.0)
		_stamina_regen_timer = stamina_regen_delay
		if stamina <= 0.0:
			_stamina_exhausted = true
	else:
		is_sprinting = false
		if _stamina_regen_timer > 0.0:
			_stamina_regen_timer -= delta
		else:
			stamina = min(stamina + stamina_regen_rate * delta, max_stamina)
			if _stamina_exhausted and stamina >= min_stamina_to_resprint:
				_stamina_exhausted = false

	stamina_changed.emit(stamina, max_stamina)
