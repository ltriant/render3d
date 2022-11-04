# render3d

I'm learning how 3D graphics work, so this is my project for that.

# IMPORTANT

Whatever the documentation here says may not be accurate, as I'm still using this repo to learn OpenGL and may have completely gutted the code in order to learn... whatever it is I'm learning.

## Dependencies

```plaintext
$ brew install assimp
...
```

## Usage

Takes a single argument, pointing to a [Wavefront obj file](https://en.wikipedia.org/wiki/Wavefront_.obj_file), or any other file that can be loaded by [assimp](https://github.com/assimp/assimp).

```plaintext
$ nimble run -- obj/teapot.obj
...
```

## Controls

| Key/Button | Action |
| ---------- | ------ |
| W | Move camera forwards |
| Shift + W | Move camera upwards |
| S | Move camera backwards |
| Shift + W | Move camera downwards |
| A | Strafe left |
| D | Strafe right |
| Space | Hold to toggle wireframe mode |
| Mouse button 1 / Left click | Click and drag to point the camera in another direction |