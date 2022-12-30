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

proc processInputs(window: GLFWWindow): void =
  if window.getKey(GLFWKey.Escape) == GLFWPress:
    window.setWindowShouldClose(true)

  if window.getKey(GLFWKey.W) == GLFW_Press:
    cam.processInput(
      if window.getKey(GLFWKey.LeftShift) == GLFW_Press or window.getKey(GLFWKey.RightShift) == GLFW_Press:
        CameraMovement.camUp
      else:
        CameraMovement.camForward,
      deltaTime)

  if window.getKey(GLFWKey.A) == GLFW_Press:
    cam.processInput(CameraMovement.camLeft, deltaTime)

  if window.getKey(GLFWKey.S) == GLFW_Press:
    cam.processInput(
      if window.getKey(GLFWKey.LeftShift) == GLFW_Press or window.getKey(GLFWKey.RightShift) == GLFW_Press:
        CameraMovement.camDown
      else:
        CameraMovement.camBackward,
      deltaTime)

  if window.getKey(GLFWKey.D) == GLFW_Press:
    cam.processInput(CameraMovement.camRight, deltaTime)

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

  cam.processMouseInput(xoffset, yoffset)


when isMainModule:
  assert glfwInit()

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE) # Used for macOS
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_FALSE)

  let w = glfwCreateWindow(
    ScreenWidth,
    ScreenHeight,
    "The 3D Model Loader From Hell!"
  )
  if w == nil:
    quit(-1)

  #w.setInputMode(GLFWCursorSpecial, GLFW_CURSOR_DISABLED)
  w.makeContextCurrent()

  discard w.setCursorPosCallback(mouseCallback)
  discard w.setScrollCallback(scrollCallback)

  assert glInit()

  glEnable(GL_DEPTH_TEST)

  var
    cubeVAO: GLuint
    cubeVBO: GLuint
    cubeVertices = [
        # positions           normals
        -0.5f, -0.5f, -0.5f,  0.0f,  0.0f, -1.0f,
         0.5f, -0.5f, -0.5f,  0.0f,  0.0f, -1.0f,
         0.5f,  0.5f, -0.5f,  0.0f,  0.0f, -1.0f,
         0.5f,  0.5f, -0.5f,  0.0f,  0.0f, -1.0f,
        -0.5f,  0.5f, -0.5f,  0.0f,  0.0f, -1.0f,
        -0.5f, -0.5f, -0.5f,  0.0f,  0.0f, -1.0f,

        -0.5f, -0.5f,  0.5f,  0.0f,  0.0f, 1.0f,
         0.5f, -0.5f,  0.5f,  0.0f,  0.0f, 1.0f,
         0.5f,  0.5f,  0.5f,  0.0f,  0.0f, 1.0f,
         0.5f,  0.5f,  0.5f,  0.0f,  0.0f, 1.0f,
        -0.5f,  0.5f,  0.5f,  0.0f,  0.0f, 1.0f,
        -0.5f, -0.5f,  0.5f,  0.0f,  0.0f, 1.0f,

        -0.5f,  0.5f,  0.5f, -1.0f,  0.0f,  0.0f,
        -0.5f,  0.5f, -0.5f, -1.0f,  0.0f,  0.0f,
        -0.5f, -0.5f, -0.5f, -1.0f,  0.0f,  0.0f,
        -0.5f, -0.5f, -0.5f, -1.0f,  0.0f,  0.0f,
        -0.5f, -0.5f,  0.5f, -1.0f,  0.0f,  0.0f,
        -0.5f,  0.5f,  0.5f, -1.0f,  0.0f,  0.0f,

         0.5f,  0.5f,  0.5f,  1.0f,  0.0f,  0.0f,
         0.5f,  0.5f, -0.5f,  1.0f,  0.0f,  0.0f,
         0.5f, -0.5f, -0.5f,  1.0f,  0.0f,  0.0f,
         0.5f, -0.5f, -0.5f,  1.0f,  0.0f,  0.0f,
         0.5f, -0.5f,  0.5f,  1.0f,  0.0f,  0.0f,
         0.5f,  0.5f,  0.5f,  1.0f,  0.0f,  0.0f,

        -0.5f, -0.5f, -0.5f,  0.0f, -1.0f,  0.0f,
         0.5f, -0.5f, -0.5f,  0.0f, -1.0f,  0.0f,
         0.5f, -0.5f,  0.5f,  0.0f, -1.0f,  0.0f,
         0.5f, -0.5f,  0.5f,  0.0f, -1.0f,  0.0f,
        -0.5f, -0.5f,  0.5f,  0.0f, -1.0f,  0.0f,
        -0.5f, -0.5f, -0.5f,  0.0f, -1.0f,  0.0f,

        -0.5f,  0.5f, -0.5f,  0.0f,  1.0f,  0.0f,
         0.5f,  0.5f, -0.5f,  0.0f,  1.0f,  0.0f,
         0.5f,  0.5f,  0.5f,  0.0f,  1.0f,  0.0f,
         0.5f,  0.5f,  0.5f,  0.0f,  1.0f,  0.0f,
        -0.5f,  0.5f,  0.5f,  0.0f,  1.0f,  0.0f,
        -0.5f,  0.5f, -0.5f,  0.0f,  1.0f,  0.0f
    ]

  glGenVertexArrays(1, cubeVAO.addr)
  glGenBuffers(1, cubeVBO.addr)
  glBindVertexArray(cubeVAO)
  glBindBuffer(GL_ARRAY_BUFFER, cubeVBO)
  glBufferData(GL_ARRAY_BUFFER, cfloat.sizeof * cubeVertices.len, cubeVertices[0].addr, GL_STATIC_DRAW)
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, EGL_FLOAT, false, 6 * cfloat.sizeof, cast[pointer](0))
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(1, 3, EGL_FLOAT, false, 6 * cfloat.sizeof, cast[pointer](3 * cfloat.sizeof))
  glBindVertexArray(0)

  #stbi.setFlipVerticallyOnLoad(true)

  var
    cubeTexture = loadTexture("container.jpg")
    shaderProgram2 = newShader("shader2.vs", "shader2.fs")

  shaderProgram2.use
  shaderProgram2.setInt("skybox", 0)

  var
    skyboxVAO, skyboxVBO: GLuint
    skyboxVertices = [
        # positions
        -1.0f,  1.0f, -1.0f,
        -1.0f, -1.0f, -1.0f,
         1.0f, -1.0f, -1.0f,
         1.0f, -1.0f, -1.0f,
         1.0f,  1.0f, -1.0f,
        -1.0f,  1.0f, -1.0f,

        -1.0f, -1.0f,  1.0f,
        -1.0f, -1.0f, -1.0f,
        -1.0f,  1.0f, -1.0f,
        -1.0f,  1.0f, -1.0f,
        -1.0f,  1.0f,  1.0f,
        -1.0f, -1.0f,  1.0f,

         1.0f, -1.0f, -1.0f,
         1.0f, -1.0f,  1.0f,
         1.0f,  1.0f,  1.0f,
         1.0f,  1.0f,  1.0f,
         1.0f,  1.0f, -1.0f,
         1.0f, -1.0f, -1.0f,

        -1.0f, -1.0f,  1.0f,
        -1.0f,  1.0f,  1.0f,
         1.0f,  1.0f,  1.0f,
         1.0f,  1.0f,  1.0f,
         1.0f, -1.0f,  1.0f,
        -1.0f, -1.0f,  1.0f,

        -1.0f,  1.0f, -1.0f,
         1.0f,  1.0f, -1.0f,
         1.0f,  1.0f,  1.0f,
         1.0f,  1.0f,  1.0f,
        -1.0f,  1.0f,  1.0f,
        -1.0f,  1.0f, -1.0f,

        -1.0f, -1.0f, -1.0f,
        -1.0f, -1.0f,  1.0f,
         1.0f, -1.0f, -1.0f,
         1.0f, -1.0f, -1.0f,
        -1.0f, -1.0f,  1.0f,
         1.0f, -1.0f,  1.0f
    ]

  glGenVertexArrays(1, skyboxVAO.addr)
  glGenBuffers(1, skyboxVBO.addr)
  glBindVertexArray(skyboxVAO)
  glBindBuffer(GL_ARRAY_BUFFER, skyboxVBO)
  glBufferData(GL_ARRAY_BUFFER, cfloat.sizeof * skyboxVertices.len, skyboxVertices[0].addr, GL_STATIC_DRAW)
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, EGL_FLOAT, false, 3 * cfloat.sizeof, cast[pointer](0))

  var
    skyboxTextures = @[
      "skybox/right.jpg",
      "skybox/left.jpg",
      "skybox/top.jpg",
      "skybox/bottom.jpg",
      "skybox/front.jpg",
      "skybox/back.jpg",
    ]
    skyboxTexture = loadCubemap(skyboxTextures)
    skyboxShader = newShader("shader-skybox.vs", "shader-skybox.fs")

  skyboxShader.use
  skyboxShader.setInt("skybox", 0)

  while not w.windowShouldClose:
    # Frame timing
    let currentFrame = glfwGetTime()
    deltaTime = currentFrame - lastFrame
    lastFrame = currentFrame

    # Poll for events
    processInputs(w)

    # Render
    glEnable(GL_DEPTH_TEST)

    glClearColor(0.20f, 0.28f, 0.35f, 1.0f)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

    # Transformation matrices
    var projection = perspective(
      fov.radians,
      ScreenWidth.float / ScreenHeight.float,
      0.1,
      100.0
    )
    var view = cam.lookAtMatrix()
    var model = mat4f(1.0)

    # Draw cubes!
    shaderProgram2.use
    shaderProgram2.setVec3f("cameraPos", cam.pos)
    shaderProgram2.setMat4x4f("view", view)
    shaderProgram2.setMat4x4f("projection", projection)
    glBindVertexArray(cubeVAO)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, cubeTexture);

    # Draw the first cube
    model = mat4f(1.0).translate(vec3f(-1.0, 0.0, -1.0))
    shaderProgram2.setMat4x4f("model", model)
    glDrawArrays(GL_TRIANGLES, 0, 36)

    # Draw another cube, translated slightly further away from the first
    model = mat4f(1.0).translate(vec3f(2.0, 0.0, 0.0))
    shaderProgram2.setMat4x4f("model", model)
    glDrawArrays(GL_TRIANGLES, 0, 36)

    # Draw the skybox
    glDepthFunc(GL_LEQUAL)
    var skyboxView = view.intoNormalMatrix.intoMat4x4
    skyboxShader.use
    skyboxShader.setMat4x4f("model", model)
    skyboxShader.setMat4x4f("view", skyboxView)
    skyboxShader.setMat4x4f("projection", projection)
    glBindVertexArray(skyboxVAO)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_CUBE_MAP, skyboxTexture)
    glDrawArrays(GL_TRIANGLES, 0, 36)
    glBindVertexArray(0)
    glDepthFunc(GL_LESS)

    w.swapBuffers
    glfwPollEvents()

  # Clean up
  shaderProgram2.delete
  skyboxShader.delete

  w.destroyWindow
  glfwTerminate()
