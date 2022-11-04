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
    if window.getKey(GLFWKey.LeftShift) == GLFW_Press or window.getKey(GLFWKey.RightShift) == GLFW_Press:
      cameraPos += cameraSpeed * cameraUp
    else:
      cameraPos += cameraSpeed * cameraFront

  if window.getKey(GLFWKey.A) == GLFW_Press:
    cameraPos -= normalize(cross(cameraFront, cameraUp)) * cameraSpeed

  if window.getKey(GLFWKey.S) == GLFW_Press:
    if window.getKey(GLFWKey.LeftShift) == GLFW_Press or window.getKey(GLFWKey.RightShift) == GLFW_Press:
      cameraPos -= cameraSpeed * cameraUp
    else:
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
  #[
  let argv = os.commandLineParams()
  if len(argv) == 0:
    echo "usage: render3d <objfile>"
    quit 1
  ]#

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

  glEnable(GL_DEPTH_TEST)

  #glEnable(GL_BLEND)
  #glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  #glBlendEquation(GL_ADD)

  #let shaderProgram = newShader("shader.vs", "shader.fs")
  #var myModel = loadModel(argv[0])

  var
    cubeVAO: GLuint
    cubeVBO: GLuint
    cubeVertices = [
      # positions           texture coords
      -0.5f, -0.5f, -0.5f,  0.0f, 0.0f,
       0.5f, -0.5f, -0.5f,  1.0f, 0.0f,
       0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
       0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
      -0.5f,  0.5f, -0.5f,  0.0f, 1.0f,
      -0.5f, -0.5f, -0.5f,  0.0f, 0.0f,

      -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
       0.5f, -0.5f,  0.5f,  1.0f, 0.0f,
       0.5f,  0.5f,  0.5f,  1.0f, 1.0f,
       0.5f,  0.5f,  0.5f,  1.0f, 1.0f,
      -0.5f,  0.5f,  0.5f,  0.0f, 1.0f,
      -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,

      -0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
      -0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
      -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
      -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
      -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
      -0.5f,  0.5f,  0.5f,  1.0f, 0.0f,

       0.5f,  0.5f,  0.5f,   1.0f, 0.0f,
       0.5f,  0.5f, -0.5f,   1.0f, 1.0f,
       0.5f, -0.5f, -0.5f,   0.0f, 1.0f,
       0.5f, -0.5f, -0.5f,   0.0f, 1.0f,
       0.5f, -0.5f,  0.5f,   0.0f, 0.0f,
       0.5f,  0.5f,  0.5f,   1.0f, 0.0f,

      -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
       0.5f, -0.5f, -0.5f,  1.0f, 1.0f,
       0.5f, -0.5f,  0.5f,  1.0f, 0.0f,
       0.5f, -0.5f,  0.5f,  1.0f, 0.0f,
      -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
      -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,

      -0.5f,  0.5f, -0.5f,  0.0f, 1.0f,
       0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
       0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
       0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
      -0.5f,  0.5f,  0.5f,  0.0f, 0.0f,
      -0.5f,  0.5f, -0.5f,  0.0f, 1.0f
    ]

  glGenVertexArrays(1, cubeVAO.addr)
  glGenBuffers(1, cubeVBO.addr)
  glBindVertexArray(cubeVAO)
  glBindBuffer(GL_ARRAY_BUFFER, cubeVBO)
  glBufferData(GL_ARRAY_BUFFER, cfloat.sizeof * cubeVertices.len, cubeVertices[0].addr, GL_STATIC_DRAW)
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, EGL_FLOAT, false, 5 * cfloat.sizeof, cast[pointer](0))
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(1, 2, EGL_FLOAT, false, 5 * cfloat.sizeof, cast[pointer](3 * cfloat.sizeof))
  glBindVertexArray(0)

  var
    planeVAO: GLuint
    planeVBO: GLuint
    planeVertices = [
       5.0f, -0.5f,  5.0f,  2.0f, 0.0f,
      -5.0f, -0.5f,  5.0f,  0.0f, 0.0f,
      -5.0f, -0.5f, -5.0f,  0.0f, 2.0f,

       5.0f, -0.5f,  5.0f,  2.0f, 0.0f,
      -5.0f, -0.5f, -5.0f,  0.0f, 2.0f,
       5.0f, -0.5f, -5.0f,  2.0f, 2.0f
    ]

  glGenVertexArrays(1, planeVAO.addr)
  glGenBuffers(1, planeVBO.addr)
  glBindVertexArray(planeVAO)
  glBindBuffer(GL_ARRAY_BUFFER, planeVBO)
  glBufferData(GL_ARRAY_BUFFER, cfloat.sizeof * planeVertices.len, planeVertices[0].addr, GL_STATIC_DRAW)
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, EGL_FLOAT, false, 5 * cfloat.sizeof, cast[pointer](0))
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(1, 2, EGL_FLOAT, false, 5 * cfloat.sizeof, cast[pointer](3 * cfloat.sizeof))
  glBindVertexArray(0)

  stbi.setFlipVerticallyOnLoad(true)

  var
    cubeTexture = loadTexture("container.jpg")
    floorTexture = loadTexture("metal.png")
    shaderProgram2 = newShader("shader2.vs", "shader2.fs")

  shaderProgram2.use
  shaderProgram2.setInt("texture1", 0)

  var
    quadVAO: GLuint
    quadVBO: GLuint
    quadShader = newShader("shader-quad.vs", "shader-quad.fs")
    quadVertices = [
        -1.0f,  1.0f,  0.0f, 1.0f,
        -1.0f, -1.0f,  0.0f, 0.0f,
         1.0f, -1.0f,  1.0f, 0.0f,

        -1.0f,  1.0f,  0.0f, 1.0f,
         1.0f, -1.0f,  1.0f, 0.0f,
         1.0f,  1.0f,  1.0f, 1.0f
    ]

  quadShader.use
  quadShader.setInt("screenTexture", 0)
  glGenVertexArrays(1, quadVAO.addr)
  glGenBuffers(1, quadVBO.addr)
  glBindVertexArray(quadVAO)
  glBindBuffer(GL_ARRAY_BUFFER, quadVBO)
  glBufferData(GL_ARRAY_BUFFER, cfloat.sizeof * quadVertices.len, quadVertices[0].addr, GL_STATIC_DRAW)
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 2, EGL_FLOAT, false, 4 * cfloat.sizeof, cast[pointer](0))
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(1, 2, EGL_FLOAT, false, 4 * cfloat.sizeof, cast[pointer](2 * cfloat.sizeof))

  var
    framebuffer: GLuint
    textureColorBuffer: GLuint
    rbo: GLuint

  glGenFramebuffers(1, framebuffer.addr)
  glBindFramebuffer(GL_FRAMEBUFFER, framebuffer)
  
  glGenTextures(1, textureColorBuffer.addr)
  glBindTexture(GL_TEXTURE_2D, textureColorBuffer)
  glTexImage2D(GL_TEXTURE_2D, 0, GLint(GL_RGB), ScreenWidth, ScreenHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, nil)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GLint(GL_LINEAR))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GLint(GL_LINEAR))
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textureColorBuffer, 0)

  glGenRenderbuffers(1, rbo.addr)
  glBindRenderbuffer(GL_RENDERBUFFER, rbo)
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, ScreenWidth, ScreenHeight)
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rbo)
  if glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE:
    echo "framebuffer is not complete"
    quit 1
  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  while not w.windowShouldClose:
    # Frame timing
    let currentFrame = glfwGetTime()
    deltaTime = currentFrame - lastFrame
    lastFrame = currentFrame

    # Poll for events
    processInputs(w)

    # Render
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer)
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
    var view = lookAt(
      cameraPos,
      cameraPos + cameraFront,
      cameraUp
    )
    var model = mat4f(1.0)
    var normalMat = model.inverse.transpose.normalMatrix

    #[
    shaderProgram.use
    shaderProgram.setVec3f("lightColor", vec3f(1.0, 1.0, 1.0))
    shaderProgram.setVec3f("objectColor", vec3f(1.0, 1.0, 1.0))
    shaderProgram.setVec3f("viewPos", cameraPos)
    shaderProgram.setVec3f("lightDirection", vec3f(-0.2, -1.0, -0.3))  # directional light

    shaderProgram.setVec3f("material.ambient", vec3f(1.0, 1.0, 1.0))
    shaderProgram.setVec3f("material.diffuse", vec3f(0.7, 0.5, 0.5))
    shaderProgram.setVec3f("material.specular", vec3f(0.5, 0.4, 0.3))
    shaderProgram.setFloat("material.shininess", 2.0)
    

    shaderProgram.setMat4x4f("projection", projection)
    shaderProgram.setMat4x4f("view", view)
    shaderProgram.setMat3x3f("normalMatrix", normalMat)
    ]#

    shaderProgram2.use
    shaderProgram2.setMat4x4f("view", view)
    shaderProgram2.setMat4x4f("projection", projection)
    glBindVertexArray(cubeVAO)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, cubeTexture);
    model = mat4f(1.0).translate(vec3f(-1.0, 0.0, -1.0))
    shaderProgram2.setMat4x4f("model", model)
    glDrawArrays(GL_TRIANGLES, 0, 36)

    model = mat4f(1.0).translate(vec3f(2.0, 0.0, 0.0))
    shaderProgram2.setMat4x4f("model", model)
    glDrawArrays(GL_TRIANGLES, 0, 36)

    glBindVertexArray(planeVAO)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, floorTexture)
    model = mat4f(1.0)
    shaderProgram2.setMat4x4f("model", model)
    glDrawArrays(GL_TRIANGLES, 0, 6)

    glBindVertexArray(0)

    #[
    shaderProgram.use
    model = mat4f(1.0)
      #.rotate(currentFrame * radians(-55.0f), vec3f(0.0, 1.0, 0.0))
    shaderProgram.setMat4x4f("model", model)
    myModel.draw(shaderProgram)
    ]#

    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glDisable(GL_DEPTH_TEST)
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f)
    glClear(GL_COLOR_BUFFER_BIT)

    quadShader.use
    glBindVertexArray(quadVAO)
    glBindTexture(GL_TEXTURE_2D, textureColorBuffer)
    glDrawArrays(GL_TRIANGLES, 0, 6)

    w.swapBuffers
    glfwPollEvents()

  # Clean up
  #shaderProgram.delete
  shaderProgram2.delete
  #quadShader.delete

  w.destroyWindow
  glfwTerminate()
