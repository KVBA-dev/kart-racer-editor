package track

import "core:fmt"
import fp "core:path/filepath"
import st "core:strings"
import rl "vendor:raylib"

FileReference :: union {
	ModelReference,
	TextureReference,
}

ModelReference :: struct {
	model:      rl.Model,
	meshLayers: []StaticLayer,
	path_obj:   string,
	path_mtl:   string,
}

TextureReference :: struct {
	texture: rl.Texture,
	path:    string,
}

references := make([dynamic]FileReference)

get_textures :: proc() -> (tex: TextureReference, ok: bool) {
	for ref in references {
		if t, t_ok := ref.(TextureReference); t_ok {
			return t, true
		}
	}
	return {}, false
}

get_models :: proc() -> (mod: ^ModelReference, ok: bool) {
	for &ref, i in references {
		if m, m_ok := &ref.(ModelReference); m_ok {
			return m, i < len(references) - 1
		}
	}
	return {}, false
}

try_load_file :: proc(path: string) -> FileReference {
	ref: FileReference = nil
	allocator := context.temp_allocator
	switch fp.ext(path) {
	case ".obj":
		mref := ModelReference {
			model    = rl.LoadModel(st.clone_to_cstring(path, allocator)),
			path_obj = path,
			path_mtl = fp.join(
				{fp.dir(path, allocator), st.join({fp.stem(path), ".mtl"}, "", allocator)},
				allocator,
			),
		}
		mref.meshLayers = make([]StaticLayer, mref.model.meshCount)
		// unload default materials, coz we use our materials anyway
		for matIdx in 0 ..< mref.model.materialCount {
			rl.MemFree(mref.model.materials[matIdx].maps)
		}
		ref = mref
	case ".png", ".jpg":
		tref := TextureReference {
			texture = rl.LoadTexture(st.clone_to_cstring(path, allocator)),
			path    = path,
		}
		ref = tref
	}
	return ref
}

delete_reference :: proc(idx: int) {
	ref := references[idx]
	unordered_remove(&references, idx)
	switch r in ref {
	case TextureReference:
		rl.UnloadTexture(r.texture)
	case ModelReference:
		rl.MemFree(r.model.meshMaterial)
		rl.MemFree(r.model.materials)
		for i in 0 ..< r.model.meshCount {
			rl.UnloadMesh(r.model.meshes[i])
		}
		rl.MemFree(r.model.meshes)
		rl.MemFree(r.model.bones)
		rl.MemFree(r.model.bindPose)
		delete(r.meshLayers)
	}
}

clear_references :: proc() {
	when ODIN_DEBUG do fmt.println("clearing file references...")
	for ref, ri in references {
		when ODIN_DEBUG do fmt.println("clearing file reference", ref, "...")
		delete_reference(ri)
	}
	clear(&references)
}

delete_references :: proc() {
	clear_references()
	delete(references)
	when ODIN_DEBUG do fmt.println("file references unloaded")
}
