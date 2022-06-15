import nimgl/opengl
import glm

import sequtils
import sugar

type Shader* = object
  id*: GLuint

proc checkShaderStatus(shader: uint32) =
  var status: int32
  glGetShaderiv(shader, GL_COMPILE_STATUS, status.addr)
  if status != GL_TRUE.ord:
    var
      log_length: int32
      message = newSeq[char](1024)
    glGetShaderInfoLog(shader, 1024, log_length.addr, message[0].addr)
    for c in message.filter(c => c != '0'):
      stdout.write(c)

proc newShader*(vertexShaderFile: string, fragmentShaderFile: string): Shader =
  var vertexShaderSource = vertexShaderFile.readFile.cstring
  let vertexShader = glCreateShader(GL_VERTEX_SHADER)
  glShaderSource(vertexShader, 1, vertexShaderSource.addr, nil)
  glCompileShader(vertexShader)
  checkShaderStatus(vertexShader)

  var fragmentShaderSource = fragmentShaderFile.readFile.cstring
  let fragmentShader = glCreateShader(GL_FRAGMENT_SHADER)
  glShaderSource(fragmentShader, 1, fragmentShaderSource.addr, nil)
  glCompileShader(fragmentShader)
  checkShaderStatus(fragmentShader)

  let shaderProgram = glCreateProgram()
  glAttachShader(shaderProgram, vertexShader)
  glAttachShader(shaderProgram, fragmentShader)
  glLinkProgram(shaderProgram)

  # Verify the shader linked correctly
  var
    logLength: int32
    message = newSeq[char](1024)
    pLinked: int32

  glGetProgramiv(shaderProgram, GL_LINK_STATUS, pLinked.addr)
  if pLinked != GL_TRUE.ord:
    glGetProgramInfoLog(
      shaderProgram,
      1024,
      logLength.addr,
      message[0].addr
    )

    for c in message.filter(c => c != '0'):
      stdout.write(c)

  glDeleteShader(vertexShader)
  glDeleteShader(fragmentShader)

  return Shader(id: shaderProgram)

proc use*(shader: Shader) =
  glUseProgram(shader.id)

proc delete*(shader: Shader) =
  glDeleteProgram(shader.id)

proc setVec3f*(shader: Shader, uniform: string, data: Vec3f) =
  glUniform3f(glGetUniformLocation(shader.id, uniform), data.x, data.y, data.z)

proc setMat4x4f*(shader: Shader, uniform: string, data: var Mat4x4f) =
  glUniformMatrix4fv(glGetUniformLocation(shader.id, uniform), 1, false, data.caddr)

proc setMat3x3f*(shader: Shader, uniform: string, data: var Mat3x3f) =
  glUniformMatrix3fv(glGetUniformLocation(shader.id, uniform), 1, false, data.caddr)

proc setInt*(shader: Shader, uniform: string, data: int) =
  glUniform1i(glGetUniformLocation(shader.id, uniform), GLint(data))

proc setFloat*(shader: Shader, uniform: string, data: float32) =
  glUniform1f(glGetUniformLocation(shader.id, uniform), GLfloat(data))
