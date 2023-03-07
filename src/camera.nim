import glm

type
  CameraMovement* = enum
    camUp
    camDown
    camForward
    camBackward
    camLeft
    camRight

  Camera* = object
    pos: Vec3f
    front: Vec3f
    up: Vec3f

    yaw: float32
    pitch: float32

proc createCamera*(): Camera =
  Camera(
    pos: vec3f(0.0, 0.0, 3.0),
    front: vec3f(0.0, 0.0, -1.0),
    up: vec3f(0.0, 1.0, 0.0),

    yaw: -90.0f,
    pitch: 0.0f
  )

func position*(c: Camera): Vec3f =
  c.pos

func lookAtMatrix*(c: Camera): Mat4[float32] =
  lookAt(
    c.pos,
    c.pos + c.front,
    c.up
  )

proc processInput*(c: var Camera, cm: CameraMovement, deltaTime: float32) =
  let cameraSpeed = 5.0f * deltaTime

  case cm:
  of camUp:       c.pos += cameraSpeed * c.up
  of camDown:     c.pos -= cameraSpeed * c.up
  of camForward:  c.pos += cameraSpeed * c.front
  of camBackward: c.pos -= cameraSpeed * c.front
  of camLeft:     c.pos -= normalize(cross(c.front, c.up)) * cameraSpeed
  of camRight:    c.pos += normalize(cross(c.front, c.up)) * cameraSpeed

proc processMouseInput*(c: var Camera, xoffset: float32, yoffset: float32) =
  c.yaw += xoffset
  c.pitch += yoffset

  if c.pitch > 89.0f:
    c.pitch = 89.0f
  elif c.pitch < -89.0f:
    c.pitch = -89.0f

  let direction = vec3f(
    cos(radians(c.yaw)) * cos(radians(c.pitch)),
    sin(radians(c.pitch)),
    sin(radians(c.yaw)) * cos(radians(c.pitch))
  )

  c.front = normalize(direction)