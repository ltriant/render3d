import assimp
import glm
import nimgl/opengl
import stb_image/read as stbi

import shader

import os
import sequtils
import strformat
import strutils
import sugar

type
  Vertex = object
    ## This assumes Nim's memory layout for structs and the Vec types within is contiguous,
    ## as a sequence of these will be used directly for OpenGL's vertex array object

    # The position of the vertex
    position*: Vec3f

    # The normalized normal vector of the position
    normal*: Vec3f

    # The texture coordinates for the vertex
    texCoords*: Vec2f

  Texture = object
    # The id of the texture, as used by OpenGL
    id: GLuint

    # What kind of texture it is
    kind: string # TODO make this an enum?

    # The path on disk to the texture
    path: string

  Mesh = object
    vertices: seq[Vertex]
    indices: seq[uint32]
    textures: seq[Texture]

    vao, vbo, ebo: uint32

proc delete(mesh: var Mesh) =
  glDeleteVertexArrays(1, mesh.vao.addr)
  glDeleteBuffers(1, mesh.vbo.addr)
  glDeleteBuffers(1, mesh.ebo.addr)

proc setup(mesh: var Mesh) =
  glGenVertexArrays(1, mesh.vao.addr)
  glGenBuffers(1, mesh.vbo.addr)
  glGenBuffers(1, mesh.ebo.addr)

  # Vertex array object for the object
  glBindVertexArray(mesh.vao)

  glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo)
  glBufferData(
    GL_ARRAY_BUFFER,
    cint(cfloat.sizeof * mesh.vertices.len * sizeof(Vertex)),
    mesh.vertices[0].addr,
    GL_STATIC_DRAW
  )

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo)
  glBufferData(
    GL_ELEMENT_ARRAY_BUFFER,
    cint(cuint.sizeof * mesh.indices.len),
    mesh.indices[0].addr,
    GL_STATIC_DRAW
  )

  # positions
  glVertexAttribPointer(
    0,
    3,
    EGL_FLOAT,
    false,
    cfloat.sizeof * 8,
    cast[pointer](Vertex.offsetOf(position))
  )
  glEnableVertexAttribArray(0)

  # normals
  glVertexAttribPointer(
    1,
    3,
    EGL_FLOAT,
    false,
    cfloat.sizeof * 8,
    cast[pointer](Vertex.offsetOf(normal))
  )
  glEnableVertexAttribArray(1)

  # texture coordinates
  glVertexAttribPointer(
    2,
    2,
    EGL_FLOAT,
    false,
    cfloat.sizeof * 8,
    cast[pointer](Vertex.offsetOf(texCoords))
  )
  glEnableVertexAttribArray(2)

proc draw(mesh: Mesh, shaderProgram: Shader) =
  var
    diffuseN = 0
    specularN = 0

  for i in 0 .. high(mesh.textures):
    var number = 0
    let name = mesh.textures[i].kind

    glActiveTexture(GLenum(ord(GL_TEXTURE0) + i))

    if name == "texture_diffuse":
      number = diffuseN
      diffuseN += 1

    elif name == "texture_specular":
      number = specularN
      specularN += 1

    shaderProgram.setInt("material." & name & $number, i)
    glBindTexture(GL_TEXTURE_2D, mesh.textures[i].id)

  glBindVertexArray(mesh.vao)
  glDrawElements(GL_TRIANGLES, mesh.indices.len.cint, GL_UNSIGNED_INT, nil)
  glBindVertexArray(0)

type
  Model = object
    rootPath: string
    meshes: seq[Mesh]

    texturesLoaded: seq[Texture]

proc draw*(m: Model, s: Shader) =
  for msh in m.meshes:
    msh.draw(s)

proc loadTexture(texturePath: string): GLuint =
  var
    width, height, channels: int
    textureData: seq[uint8]
    texture: uint32

  textureData = stbi.load(texturePath, width, height, channels, stbi.Default)

  let format = case channels
    of 1:
      GL_RED
    of 3:
      GL_RGB
    of 4:
      GL_RGBA
    else:
      GL_RGB  # probably wrong

  glGenTextures(1, texture.addr)
  glBindTexture(GL_TEXTURE_2D, texture)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GLint(GL_REPEAT))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GLint(GL_REPEAT))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GLint(GL_LINEAR_MIPMAP_LINEAR))
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GLint(GL_LINEAR))
  glTexImage2D(
    GL_TEXTURE_2D,
    0,
    GLint(format),
    int32(width),
    int32(height),
    0,
    format,
    GL_UNSIGNED_BYTE,
    pointer(textureData[0].addr)
  )
  glGenerateMipmap(GL_TEXTURE_2D)

  return texture

proc loadMaterialTextures(model: var Model, material: PMaterial, texType: TTextureType, typeName: string): seq[Texture] =
  echo fmt"before loadMaterialTextures: {$texType} (mem: {getOccupiedMem()})"
  var textures = newSeq[Texture]()

  echo "  material count: ", material.getTextureCount(texType)
  for i in 0 ..< material.getTextureCount(texType):
    var texPath: AIstring
    let rv = material.getTexture(texType, i.cint, texPath.addr)

    if not rv.toBool:
      echo "    loading texture failed: ", repr(rv)

    let fullTexturePath = model.rootPath / $texPath
    let alreadyLoadedTextures = model.texturesLoaded.filter t => t.path == fullTexturePath

    if len(alreadyLoadedTextures) > 0:
      textures.add(alreadyLoadedTextures[0])
    else:
      echo "    loading texture: ", fullTexturePath
      let newTexture = Texture(
        id: loadTexture(fullTexturePath),
        kind: typeName,
        path: fullTexturePath
      )
      textures.add(newTexture)
      model.texturesLoaded.add(newTexture)

  echo fmt"after loadMaterialTextures (mem: {getOccupiedMem()})"
  return textures

proc processMesh(model: var Model, mesh: PMesh, scene: PScene): Mesh =
  echo fmt"processMesh: (mem: {getOccupiedMem()})"
  var
    vertices = newSeq[Vertex]()
    indices = newSeq[uint32]()
    textures = newSeq[Texture]()

  if mesh.hasPositions:
    echo fmt"  before vertex count: {mesh.vertexCount} (mem: {getOccupiedMem()})"
    for i in 0 ..< mesh.vertexCount:
      # mesh.vertices is a `ptr TVector3d`, so it needs to be cast to an int, indexed by the size of
      # `TVector3d`, and then cast back to a pointer.
      # Ew. Vomit.
      let vert = cast[ptr TVector3d](cast[int](mesh.vertices) + i * sizeof(TVector3d))
      let pos = vec3f(vert.x.float32, vert.y.float32, vert.z.float32)

      var v = Vertex(
        position: pos
      )

      if mesh.normals == nil:
        v.normal = pos.normalize
      else:
        let norm = cast[ptr TVector3d](cast[int](mesh.normals) + i * sizeof(TVector3d))
        v.normal = vec3f(norm.x.float32, norm.y.float32, norm.z.float32)

      if mesh.texCoords[0] != nil:
        let texc = cast[ptr TVector3d](cast[int](mesh.texCoords[0]) + i * sizeof(TVector3d))
        v.texCoords = vec2f(texc.x.float32, texc.y.float32)

      vertices.add(v)
    echo fmt"  after vertex count (mem: {getOccupiedMem()})"

  # process indices
  echo fmt"  before face count: {mesh.faceCount} (mem: {getOccupiedMem()})"
  for i in 0 ..< mesh.faceCount:
    let face = mesh.faces[i]
    for j in 0 ..< face.indexCount:
      indices.add(face.indices[j].uint32)
  echo fmt"  after face count (mem: {getOccupiedMem()})"

  # process textures
  if mesh.materialIndex >= 0:
    let material = scene.materials[mesh.materialIndex]

    let diffuse_maps = model.loadMaterialTextures(
      material,
      TTextureType.TexDiffuse,
      "texture_diffuse"
    )

    textures = textures.concat(diffuse_maps)

    let specular_maps = model.loadMaterialTextures(
      material,
      TTextureType.TexSpecular,
      "texture_specular"
    )

    textures = textures.concat(specular_maps)

  var mesh = Mesh(
    vertices: vertices,
    indices: indices,
    textures: textures
  )

  mesh.setup()

  return mesh

proc processNode(model: var Model, node: PNode, scene: PScene) =
  for i in 0 ..< node.meshCount:
    let mesh = model.processMesh(scene.meshes[node.meshes[i]], scene)
    model.meshes.add(mesh)

  for i in 0 ..< node.childrenCount:
    model.processNode(node.children[i], scene)

proc loadModel*(filePath: string): Model =
  echo fmt"loadModel (max mem: {getMaxMem()}, free mem: {getFreeMem()})"
  let scene = aiImportFile(
    filePath.cstring,
    { ImportProcess.triangulate, ImportProcess.flipUvs }
  )

  if (scene == nil) or (scene.rootNode == nil):
    echo "Error: Assimp: " & $assimp.getError()
    return

  var model = Model(
    rootPath: parentDir(filePath),
    meshes: newSeq[Mesh](),
    texturesLoaded: newSeq[Texture](),
  )

  model.processNode(scene.rootNode, scene)

  return model
