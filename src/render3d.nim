import glm
import nimgl/[glfw, opengl]
import stb_image/read as stbi

import camera
import model
import shader

import math
import os

# Screen dimensions
const ScreenWidth  = 800
const ScreenHeight = 600

# Camera
var cam = createCamera()

# Field of view
var fov = 45.0f

# Frame timing
var deltaTime = 0.0f  # Time between current frame and last frame
var lastFrame = 0.0f  # Time of last frame

func intoNormalMatrix[A](m: Mat4x4[A]): Mat3x3[A] =
  mat3(
    vec3(m[0].arr[0], m[0].arr[1], m[0].arr[2]),
    vec3(m[1].arr[0], m[1].arr[1], m[1].arr[2]),
    vec3(m[2].arr[0], m[2].arr[1], m[2].arr[2])
  )

func intoMat4x4(m: Mat3x3[float32]): Mat4x4[float32] =
  mat4(
    vec4(m[0].arr[0], m[0].arr[1], m[0].arr[2], 0.0f),
    vec4(m[1].arr[0], m[1].arr[1], m[1].arr[2], 0.0f),
    vec4(m[2].arr[0], m[2].arr[1], m[2].arr[2], 0.0f),
    vec4(0.0f, 0.0f, 0.0f, 0.0f),
  )

var blinn = false

proc processInputs(window: GLFWWindow): void =
  if window.getKey(GLFWKey.Escape) == GLFWPress:
    window.setWindowShouldClose true

  if window.getKey(GLFWKey.W) == GLFW_Press:
    cam.processInput(
      if window.getKey(GLFWKey.LeftShift) == GLFW_Press or window.getKey(GLFWKey.RightShift) == GLFW_Press:
        CameraMovement.camUp
      else:
        CameraMovement.camForward,
      deltaTime)

  if window.getKey(GLFWKey.A) == GLFW_Press:
    cam.processInput CameraMovement.camLeft, deltaTime

  if window.getKey(GLFWKey.S) == GLFW_Press:
    cam.processInput(
      if window.getKey(GLFWKey.LeftShift) == GLFW_Press or window.getKey(GLFWKey.RightShift) == GLFW_Press:
        CameraMovement.camDown
      else:
        CameraMovement.camBackward,
      deltaTime)

  if window.getKey(GLFWKey.D) == GLFW_Press:
    cam.processInput CameraMovement.camRight, deltaTime

  blinn = window.getKey(GLFWKey.B) == GLFW_Press

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

  cam.processMouseInput xoffset, yoffset


when isMainModule:
  assert glfwInit()

  glfwWindowHint GLFWContextVersionMajor, 3
  glfwWindowHint GLFWContextVersionMinor, 3
  glfwWindowHint GLFWOpenglForwardCompat, GLFW_TRUE # Used for macOS
  glfwWindowHint GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE
  glfwWindowHint GLFWResizable, GLFW_FALSE

  let w = glfwCreateWindow(
    ScreenWidth,
    ScreenHeight,
    "The 3D Model Loader From Hell!"
  )
  if w == nil:
    quit -1

  #w.setInputMode(GLFWCursorSpecial, GLFW_CURSOR_DISABLED)
  w.makeContextCurrent

  discard w.setCursorPosCallback mouseCallback
  discard w.setScrollCallback scrollCallback

  assert glInit()
  glEnable GL_DEPTH_TEST

  var
    #myModel = loadModel("obj/backpack/backpack.obj")
    myShader = newShader("shader-advanced.vs", "shader-advanced.fs")

  var
    planeVAO: GLuint
    planeVBO: GLuint
    planeVertices = [
      10.0f, -0.5f,  10.0f,  0.0f, 1.0f, 0.0f,  10.0f,  0.0f,
      -10.0f, -0.5f,  10.0f,  0.0f, 1.0f, 0.0f,   0.0f,  0.0f,
      -10.0f, -0.5f, -10.0f,  0.0f, 1.0f, 0.0f,   0.0f, 10.0f,

      10.0f, -0.5f,  10.0f,  0.0f, 1.0f, 0.0f,  10.0f,  0.0f,
      -10.0f, -0.5f, -10.0f,  0.0f, 1.0f, 0.0f,   0.0f, 10.0f,
      10.0f, -0.5f, -10.0f,  0.0f, 1.0f, 0.0f,  10.0f, 10.0f
    ]

  glGenVertexArrays(1, planeVAO.addr);
  glGenBuffers(1, planeVBO.addr);
  glBindVertexArray(planeVAO);
  glBindBuffer(GL_ARRAY_BUFFER, planeVBO);
  glBufferData(GL_ARRAY_BUFFER, cfloat.sizeof * planeVertices.len, planeVertices[0].addr, GL_STATIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, EGL_FLOAT, false, 8 * sizeof(cfloat), cast[pointer](0));
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 3, EGL_FLOAT, false, 8 * sizeof(cfloat), cast[pointer](3 * sizeof(cfloat)));
  glEnableVertexAttribArray(2);
  glVertexAttribPointer(2, 2, EGL_FLOAT, false, 8 * sizeof(cfloat), cast[pointer](6 * sizeof(cfloat)));
  glBindVertexArray(0);

  var floorTexture = loadTexture("wood.png")
  myShader.setInt("texture1", 0)


  var lightPos = vec3f(0.0, 0.0, 0.0)
  while not w.windowShouldClose:
    # Frame timing
    let currentFrame = glfwGetTime()
    deltaTime = currentFrame - lastFrame
    lastFrame = currentFrame

    # Poll for events
    processInputs w

    # Render
    glEnable GL_DEPTH_TEST

    glClearColor 0.20f, 0.28f, 0.35f, 1.0f
    glClear GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT

    # Transformation matrices
    var projection = perspective(
      fov.radians,
      ScreenWidth.float / ScreenHeight.float,
      0.1,
      100.0
    )
    var view = cam.lookAtMatrix()
    var model = mat4f(1.0)

    myShader.use
    
    myShader.setMat4x4f "projection", projection
    myShader.setMat4x4f "view", view
    myShader.setMat4x4f "model", model

    #myShader.setVec3f "material.ambient", vec3f(1.0, 0.5, 0.31)
    #myShader.setVec3f "material.diffuse", vec3f(1.0, 0.5, 0.31)
    #myShader.setVec3f "material.specular", vec3f(0.5, 0.5, 0.5)
    #myShader.setFloat "material.shininess", 32.0f
    myShader.setVec3f "lightPos", lightPos
    myShader.setVec3f "viewPos", cam.position
    myShader.setInt "blinn", blinn.int

    glBindVertexArray(planeVAO);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, floorTexture);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    #myModel.draw myShader

    w.swapBuffers
    glfwPollEvents()

  # Clean up
  #delete myModel

  w.destroyWindow
  glfwTerminate()
