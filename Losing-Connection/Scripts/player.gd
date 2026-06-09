extends CharacterBody2D

@onready var AnimatedSprite = $AnimatedSprite2D

enum STATE { IDLE, WALKING, ASCENDING, DESCENDING, FLOATING, DASHING }
var state = STATE.IDLE
var justFell = false
var stateChanged = false

enum DIRECTION { UP, DOWN, LEFT, RIGHT }
@export var SPEED = 100.0
var facingDirectionX = DIRECTION.RIGHT
var facingDirectionY = DIRECTION.DOWN

@onready var DashDurationTimer = $DashDurationTimer
@onready var DashCooldownTimer = $DashCooldownTimer
@export var dashSpeed = 5
var justDashed = false

@export var JUMP_VELOCITY = -250.0
var doubleJumped = false
var timeOffFloor: float = 0.0
@export var COYOTE_TIME: float = 0.1 # Grace period (in seconds)
var timeDescending = 0.0
var isFloating = false

func _physics_process(delta: float) -> void:
	# Add the gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
		timeOffFloor += delta
	else:
		doubleJumped = false
		justDashed = false
		timeOffFloor = 0.0
	
	# Track fall time
	if state == STATE.DESCENDING:
		timeDescending += delta
		if timeDescending >= 0.39:
			justFell = true
	else:
		timeDescending = 0.0
	
	# Handle jump/float
	if is_on_floor() or timeOffFloor <= COYOTE_TIME:
		if Input.is_action_just_pressed("Jump"):
			jump()
	elif doubleJumped == false:
		if Input.is_action_just_pressed("Jump"):
			doubleJump()
			encodeDirection(velocity.normalized())
	if velocity.y < 0.0:
		if Input.is_action_just_released("Jump"): # Variable jump height
			multVelocityY(0.5)

	# Get the input direction and handle the movement/deceleration
	var direction := Input.get_axis("MoveLeft", "MoveRight")
	if direction:
		move(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# Capture movement direction
	if velocity.length() > 0.0:
		var directionNormalized = velocity.normalized()
		encodeDirection(directionNormalized)
	else:
		if state != STATE.IDLE:
			stateChanged = true
		state = STATE.IDLE
	
	# Float while falling (positioned to overwrite idle state)
	if Input.is_action_pressed("Jump") and (state == STATE.DESCENDING or state == STATE.FLOATING):
		state = STATE.FLOATING
		stateChanged = true
		multVelocityX(0.8)
		multVelocityY(0.75)
	
	# Dash forwards
	if Input.is_action_just_pressed("Dash") and justDashed == false:
		dashTimerStart()
	if not DashDurationTimer.is_stopped():
		if velocity.x == 0.0:
			direction = decodeDirectionX()
			move(direction)
			print(velocity.x)
		state = STATE.DASHING
		multVelocityX(dashSpeed)
		multVelocityY(0)
		justDashed = true
	
	move_and_slide()
	
	# Update animations
	updateAnimation()

func move(direction):
	velocity.x = direction * SPEED

func jump():
	velocity.y = JUMP_VELOCITY

func doubleJump():
	velocity.y = JUMP_VELOCITY
	doubleJumped = true

func multVelocityX(amt: float):
	velocity.x *= amt

func multVelocityY(amt: float):
	velocity.y *= amt

func encodeDirection(directionNormalized: Vector2):
	if directionNormalized.x < 0.0:
		facingDirectionX = DIRECTION.LEFT
		if directionNormalized.y == 0.0:
			if state != STATE.WALKING:
				stateChanged = true
			state = STATE.WALKING
	elif directionNormalized.x > 0.0:
		facingDirectionX = DIRECTION.RIGHT
		if directionNormalized.y == 0.0:
			if state != STATE.WALKING:
				stateChanged = true
			state = STATE.WALKING

	if directionNormalized.y < 0.0:
		facingDirectionY = DIRECTION.UP
		if state != STATE.ASCENDING:
			stateChanged = true
		state = STATE.ASCENDING
		justFell = false
	elif directionNormalized.y > 0.0:
		facingDirectionY = DIRECTION.DOWN
		if state != STATE.DESCENDING:
			stateChanged = true
		state = STATE.DESCENDING

func decodeDirectionX() -> float:
	match facingDirectionX:
		DIRECTION.LEFT:
			return -1.0
		DIRECTION.RIGHT:
			return 1.0
		_:
			return 0.0

func dashTimerStart():
	DashDurationTimer.start()

func updateAnimation():
	if facingDirectionX == DIRECTION.LEFT:
		AnimatedSprite.flip_h = true
	elif facingDirectionX == DIRECTION.RIGHT:
		AnimatedSprite.flip_h = false
	
	if stateChanged:
		match state:
			STATE.IDLE:
				if justFell:
					AnimatedSprite.play("get up")
					await AnimatedSprite.animation_finished
					justFell = false
				AnimatedSprite.play("idle")
				stateChanged = false
			STATE.WALKING:
				if justFell:
					AnimatedSprite.play("get up")
					await AnimatedSprite.animation_finished
					justFell = false
				AnimatedSprite.play("walk")
				stateChanged = false
			STATE.ASCENDING:
				AnimatedSprite.play("ascend")
				stateChanged = false
			STATE.DESCENDING:
				AnimatedSprite.play("descend")
				stateChanged = false
			STATE.FLOATING:
				AnimatedSprite.play("float")
				stateChanged = false
			_:
				if justFell:
					AnimatedSprite.play("get up")
					await AnimatedSprite.animation_finished
					justFell = false
				AnimatedSprite.play("idle")
				stateChanged = false
