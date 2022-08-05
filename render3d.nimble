# Package

version       = "0.1.0"
author        = "Luke Triantafyllidis"
description   = "Render 3D Models"
license       = "MIT"
srcDir        = "src"
bin           = @["render3d"]


# Dependencies

requires "nim >= 1.6.2"
requires "nimgl >= 1.3.2"
requires "stb_image >= 2.5"
requires "glm >= 1.1.0"
requires "https://github.com/beef331/nimassimp.git >= 0.1.4"
