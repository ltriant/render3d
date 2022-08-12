# render3d

I'm learning how 3D graphics work, so this is my project for that.

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
| W | Move camera vertically upwards |
| S | Move camera vertically downwards |
| A | Move camera horizontally to the left |
| D | Move camera horizontally to the right |
| Space | Hold to toggle wireframe mode |
| Mouse button 1 / Left click | Click and drag to point the camera in another direction |