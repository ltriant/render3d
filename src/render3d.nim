import glm
import nimgl/[glfw, opengl]
import stb_image/read as stbi

import model
import shader

import math
import os

# Screen dimensions
const ScreenWidth  = 800
const ScreenHeight = 600

# Camera position
var cameraPos   = vec3f(0.0, 0.0, 3.0)
var cameraFront = vec3f(0.0, 0.0, -1.0)
var cameraUp    = vec3f(0.0, 1.0, 0.0)

# Field of view
var fov = 45.0f

# Frame timing
var deltaTime = 0.0f  # Time between current frame and last frame
var lastFrame = 0.0f  # Time of last frame

func normalMatrix[A](m: Mat4x4[A]): Mat3x3[A] =
  mat3(
    vec3(m[0].arr[0], m[0].arr[1], m[0].arr[2]),
    vec3(m[1].arr[0], m[1].arr[1], m[1].arr[2]),
    vec3(m[2].arr[0], m[2].arr[1], m[2].arr[2])
  )

proc processInputs(window: GLFWWindow): void =
  if window.getKey(GLFWKey.Escape) == GLFWPress:
    window.setWindowShouldClose(true)

  var cameraSpeed = 5.0f * deltaTime
  if window.getKey(GLFWKey.W) == GLFW_Press:
    cameraPos += cameraSpeed * cameraFront

  if window.getKey(GLFWKey.A) == GLFW_Press:
    cameraPos -= normalize(cross(cameraFront, cameraUp)) * cameraSpeed

  if window.getKey(GLFWKey.S) == GLFW_Press:
    cameraPos -= cameraSpeed * cameraFront

  if window.getKey(GLFWKey.D) == GLFW_Press:
    cameraPos += normalize(cross(cameraFront, cameraUp)) * cameraSpeed

  glPolygonMode(
    GL_FRONT_AND_BACK,
    if window.getKey(GLFWKey.Space) == GLFW_Press:
      GL_LINE
    else:
      GL_FILL
  )

proc scrollCallback(window: GLFWWindow, xoffset: float64, yoffset: float64): void {.cdecl.} =
  fov -= yoffset.float

  if fov < 1.0f:
    fov = 1.0f
  elif fov > 45.0f:
    fov = 45.0f

var firstMouse = true
var lastX = 400.0f
var lastY = 300.0f
var yaw = -90.0f
var pitch = 0.0f

proc mouseCallback(window: GLFWWindow, xpos: float64, ypos: float64): void {.cdecl.} =
  if firstMouse:
    lastX = xpos
    lastY = ypos
    firstMouse = false

  let sensitivity = 0.2f
  var
    xoffset = xpos - lastX
    yoffset = lastY - ypos

  lastX = xpos
  lastY = ypos

  xoffset *= sensitivity
  yoffset *= sensitivity

  if window.getMouseButton(GLFWMouseButton.Button1) != GLFW_Press:
    return

  yaw += xoffset
  pitch += yoffset

  if pitch > 89.0f:
    pitch = 89.0f
  elif pitch < -89.0f:
    pitch = -89.0f

  let direction = vec3f(
    cos(radians(yaw)) * cos(radians(pitch)),
    sin(radians(pitch)),
    sin(radians(yaw)) * cos(radians(pitch))
  )

  cameraFront = normalize(direction)


when isMainModule:
  let argv = os.commandLineParams()
  if len(argv) == 0:
    echo "usage: render3d <objfile>"
    quit 1

  assert glfwInit()

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE) # Used for macOS
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_FALSE)

  let w: GLFWWindow = glfwCreateWindow(ScreenWidth, ScreenHeight, "The 3D Model Loader From Hell!")
  if w == nil:
    quit(-1)

  #w.setInputMode(GLFWCursorSpecial, GLFW_CURSOR_DISABLED)
  w.makeContextCurrent()

  discard w.setCursorPosCallback(mouseCallback)
  discard w.setScrollCallback(scrollCallback)

  assert glInit()

  stbi.setFlipVerticallyOnLoad(true)

  let shaderProgram = newShader("shader.vs", "shader.fs")
  var myModel = loadModel(argv[0])

  #var myMesh = argv[0].fromObjFile

  glEnable(GL_DEPTH_TEST)

  while not w.windowShouldClose:
    # Frame timing
    let currentFrame = glfwGetTime()
    deltaTime = currentFrame - lastFrame
    lastFrame = currentFrame

    # Poll for events
    glfwPollEvents()
    processInputs(w)

    # Render
    glClearColor(0.05f, 0.05f, 0.05f, 1.0f)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

    shaderProgram.use
    shaderProgram.setVec3f("lightColor", vec3f(1.0, 1.0, 1.0))
    shaderProgram.setVec3f("objectColor", vec3f(1.0, 1.0, 1.0))
    shaderProgram.setVec3f("viewPos", cameraPos)
    shaderProgram.setVec3f("lightDirection", vec3f(-0.2, -1.0, -0.3));  # directional light

    shaderProgram.setVec3f("material.ambient", vec3f(1.0, 1.0, 1.0));
    shaderProgram.setVec3f("material.diffuse", vec3f(1.0, 0.5, 0.9));
    shaderProgram.setVec3f("material.specular", vec3f(0.0, 0.2, 0.8));
    shaderProgram.setFloat("material.shininess", 16.0);

    # Transformation matrices
    var projection = perspective(
      radians(fov),
      ScreenWidth.float / ScreenHeight.float,
      0.1,
      100.0
    )
    shaderProgram.setMat4x4f("projection", projection)

    var view = lookAt(
      cameraPos,
      cameraPos + cameraFront,
      cameraUp
    )
    shaderProgram.setMat4x4f("view", view)

    var model = mat4f(1.0)
      #.rotate(currentFrame * radians(-55.0f), vec3f(0.1, 1.0, 0.2))
    shaderProgram.setMat4x4f("model", model)

    var normalMat = model.inverse.transpose.normalMatrix
    shaderProgram.setMat3x3f("normalMatrix", normalMat)

    myModel.draw(shaderProgram)
    #myMesh.draw(shaderProgram)

    w.swapBuffers

  # Clean up
  #myMesh.delete
  shaderProgram.delete

  w.destroyWindow
  glfwTerminate()
