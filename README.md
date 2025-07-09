# kart-racer-editor

This is the level editor for my kart racing game. It features loading .obj meshes, selecting their layers, editing and exporting minimaps, and (WIP) editing materials. The project files are saved in CBOR format with `.klv` extension.

I mainly did this project for myself, so the code is awful, but it's functional, so if you want to try it out, simply clone this repository and run build.sh (or just `odin run src` if you're on Windows). It *should* work.

Things to add:
- [ ] More material editor features (colour tint, shaders)
- [x] Object editor (start/finish line, item boxes, track features)
- [x] Path editor for placement calculation and bot pathfinding
- [ ] Keyboard shortcuts and other QoL features
- [ ] More that come to my mind
