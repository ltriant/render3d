import glm
import nimgl/[glfw, opengl]

import camera
import model
import shader

import math
import options
import sugar

const
  ScreenWidth  = 800
  ScreenHeight = 600

const
  ShadowWidth = 1024
  ShadowHeight = 1024


# Camera
var cam = createCamera()

# Frame timing
var deltaTime = 0.0f  # Time between current frame and last frame
var lastFrame = 0.0f  # Time of last frame


var shadows = true
var shadowsKeyPressed = false

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

  if window.getKey(GLFWKey.Space) == GLFW_Press and not shadowsKeyPressed:
    shadows = not shadows
    shadowsKeyPressed = true
  if window.getKey(GLFWKey.Space) == GLFW_Release:
    shadowsKeyPressed = false


# Field of view
var fov = 45.0f

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


var
  cubeVAO: GLuint = 0
  cubeVBO: GLuint = 0

proc renderCube() =
  if cubeVAO == 0:
    var cubeVertices = [
      # back face
      -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, # bottom-left
       1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, # top-right
       1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 0.0f, # bottom-right
       1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, # top-right
      -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, # bottom-left
      -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 1.0f, # top-left
      # front face
      -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, # bottom-left
       1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 0.0f, # bottom-right
       1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, # top-right
       1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, # top-right
      -1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 1.0f, # top-left
      -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, # bottom-left
      # left face
      -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, # top-right
      -1.0f,  1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 1.0f, # top-left
      -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, # bottom-left
      -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, # bottom-left
      -1.0f, -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 0.0f, # bottom-right
      -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, # top-right
      # right face
       1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, # top-left
       1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, # bottom-right
       1.0f,  1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 1.0f, # top-right
       1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, # bottom-right
       1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, # top-left
       1.0f, -1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 0.0f, # bottom-left
      # bottom face
      -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, # top-right
       1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 1.0f, # top-left
       1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, # bottom-left
       1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, # bottom-left
      -1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 0.0f, # bottom-right
      -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, # top-right
      # top face
      -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, # top-left
       1.0f,  1.0f , 1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, # bottom-right
       1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 1.0f, # top-right
       1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, # bottom-right
      -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, # top-left
      -1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 0.0f  # bottom-left
    ]

    glGenVertexArrays 1, cubeVAO.addr
    glGenBuffers 1, cubeVBO.addr

    glBindBuffer GL_ARRAY_BUFFER, cubeVBO
    glBufferData GL_ARRAY_BUFFER, sizeof(cfloat) * len(cubeVertices), cubeVertices[0].addr, GL_STATIC_DRAW
    
    glBindVertexArray cubeVAO
    glEnableVertexAttribArray 0
    glVertexAttribPointer 0, 3, EGL_FLOAT, false, 8 * sizeof(cfloat), cast[pointer](0)
    glEnableVertexAttribArray 1
    glVertexAttribPointer 1, 3, EGL_FLOAT, false, 8 * sizeof(cfloat), cast[pointer](3 * sizeof(cfloat))
    glEnableVertexAttribArray 2
    glVertexAttribPointer 2, 2, EGL_FLOAT, false, 8 * sizeof(cfloat), cast[pointer](6 * sizeof(cfloat))
    glBindBuffer GL_ARRAY_BUFFER, 0
    glBindVertexArray 0

  glBindVertexArray cubeVAO
  glDrawArrays GL_TRIANGLES, 0, 36
  glBindVertexArray 0

proc renderScene(shader: Shader) =
  # Room cube
  var model = mat4f(1.0)
    .scale(vec3f(5.0))
  shader.setMat4x4f "model", model
  glDisable GL_CULL_FACE
  shader.setInt "reverse_normals", 1
  renderCube()
  shader.setInt "reverse_normals", 0
  glEnable GL_CULL_FACE

  # Cubes
  model = mat4f(1.0)
    .translate(vec3f(4.0, -3.5, 0.0))
    .scale(vec3f(0.5))
  shader.setMat4x4f "model", model
  renderCube()

  model = mat4f(1.0)
    .translate(vec3f(2.0, 3.0, 1.0))
    .scale(vec3f(0.75))
  shader.setMat4x4f "model", model
  renderCube()

  model = mat4f(1.0)
    .translate(vec3f(-3.0, -1.0, 0.0))
    .scale(vec3f(0.5))
  shader.setMat4x4f "model", model
  renderCube()

  model = mat4f(1.0)
    .translate(vec3f(-1.5, 1.0, 1.5))
    .scale(vec3f(0.5))
  shader.setMat4x4f "model", model
  renderCube()

  model = mat4f(1.0)
    .translate(vec3f(-1.5, 2.0, -3.0))
    .rotate(radians(60.0f), normalize(vec3f(1.0, 0.0, 1.0)))
    .scale(vec3f(0.75))
  shader.setMat4x4f "model", model
  renderCube()


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
    # Load shaders
    myShader = newShader(
      "shader-pointShadows.vs",
      "shader-pointShadows.fs"
    )
    simpleDepthShader = newShader(
      "shader-pointShadowsDepth.vs",
      "shader-pointShadowsDepth.fs",
      some("shader-pointShadowsDepth.gs")
    )

    # Load textures
    woodTexture = loadTexture("wood.png")


  #
  # Depth map FBO
  #
  var
    depthMapFBO: GLuint
    depthCubemap: GLuint

  glGenFramebuffers 1, depthMapFBO.addr
  glGenTextures 1, depthCubemap.addr
  glBindTexture GL_TEXTURE_CUBE_MAP, depthCubemap
  for i in 0 ..< 6:
    glTexImage2D(
      GLenum(GL_TEXTURE_CUBE_MAP_POSITIVE_X.ord + i),
      0,
      GLint(GL_DEPTH_COMPONENT),
      ShadowWidth,
      ShadowHeight,
      0,
      GL_DEPTH_COMPONENT,
      EGL_FLOAT,
      nil
    )
  glTexParameteri GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GLint(GL_NEAREST)
  glTexParameteri GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GLint(GL_NEAREST)
  glTexParameteri GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GLint(GL_CLAMP_TO_EDGE)
  glTexParameteri GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GLint(GL_CLAMP_TO_EDGE)
  glTexParameteri GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GLint(GL_CLAMP_TO_EDGE)

  glBindFramebuffer GL_FRAMEBUFFER, depthMapFBO
  glFramebufferTexture GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, depthCubemap, 0
  glDrawBuffer GL_NONE
  glReadBuffer GL_NONE
  glBindFramebuffer GL_FRAMEBUFFER, 0


  #
  # Shader configuration
  #
  myShader.use
  myShader.setInt "diffuseTexture", 0
  myShader.setInt "depthMap", 1


  #
  # Light info
  #
  var lightPos = vec3f(0.0, 0.0, 0.0)

  while not w.windowShouldClose:
    # Frame timing
    let currentFrame = glfwGetTime()
    deltaTime = currentFrame - lastFrame
    lastFrame = currentFrame

    # Poll for events
    processInputs w

    # Move light over time
    lightPos.z = sin(glfwGetTime() * 0.5) * 3.0

    # Render
    glClearColor 0.1f, 0.1f, 0.1f, 1.0f
    glClear GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT

    let
      aspect = ShadowWidth.float32 / ShadowHeight.float32
      nearPlane = 1.0f
      farPlane = 25.0f

    var
      shadowProjection = perspective(radians(90.0f), aspect, nearPlane, farPlane)
      transforms = [
        (vec3f( 1.0,  0.0,  0.0), vec3f(0.0, -1.0,  0.0)),
        (vec3f(-1.0,  0.0,  0.0), vec3f(0.0, -1.0,  0.0)),
        (vec3f( 0.0,  1.0,  0.0), vec3f(0.0,  0.0,  1.0)),
        (vec3f( 0.0, -1.0,  0.0), vec3f(0.0,  0.0, -1.0)),
        (vec3f( 0.0,  0.0,  1.0), vec3f(0.0, -1.0,  0.0)),
        (vec3f( 0.0,  0.0, -1.0), vec3f(0.0, -1.0,  0.0)),
      ]
      shadowTransforms = collect(newSeq):
        for vs in transforms:
          shadowProjection * lookAt(lightPos, lightPos + vs[0], vs[1])

    #
    # 1. Render the depth cubemap
    #
    glViewport 0, 0, ShadowWidth, ShadowHeight
    glBindFramebuffer GL_FRAMEBUFFER, depthMapFBO
    glClear GL_DEPTH_BUFFER_BIT
    simpleDepthShader.use
    for i in 0 ..< 6:
      var t = shadowTransforms[i]
      simpleDepthShader.setMat4x4f "shadowMatrices[" & $i & "]", t
    simpleDepthShader.setFloat "far_plane", farPlane
    simpleDepthShader.setVec3f "lightPos", lightPos
    renderScene simpleDepthShader
    glBindFramebuffer GL_FRAMEBUFFER, 0

    # Reset the viewport
    # I don't know why I need to do it this way, but for some reason at this point the screen
    # width has changed from 800 to 1600, and the screen heigh has changed from 600 to 1200. So if
    # I try to use the original constants, everything is only rendered to the bottom left quadrant
    # of the window.
    var
      scrWidth: int32
      scrHeight: int32
    w.getFramebufferSize scrWidth.addr, scrHeight.addr
    glViewport 0, 0, scrWidth, scrHeight

    glClear GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT

    #
    # 2. Render the scene
    #
    var projection = perspective(
      fov.radians,
      scrWidth.float / scrHeight.float,
      0.1,
      100.0
    )
    var view = cam.lookAtMatrix()
    myShader.use
    myShader.setMat4x4f "projection", projection
    myShader.setMat4x4f "view", view

    # Set light uniforms
    myShader.setVec3f "lightPos", lightPos
    myShader.setVec3f "viewPos", cam.position
    myShader.setInt "shadows", int(shadows)
    myShader.setFloat "far_plane", farPlane

    # Bind textures and render
    glActiveTexture GL_TEXTURE0
    glBindTexture GL_TEXTURE_2D, woodTexture
    glActiveTexture GL_TEXTURE1
    glBindTexture GL_TEXTURE_CUBE_MAP, depthCubemap
    renderScene myShader

    w.swapBuffers
    glfwPollEvents()

  w.destroyWindow
  glfwTerminate()