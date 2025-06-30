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
	model:        rl.Model,
	meshLayers:   []StaticLayer,
	path_obj:     string,
	materials:    []rl.Material,
	meshMaterial: []int,
	textureIdx:   []^TextureReference,
}

TextureReference :: struct {
	texture: rl.Texture,
	path:    string,
}

modelReferences := make([dynamic]ModelReference)
textureReferences := make([dynamic]TextureReference)

get_textures :: proc() -> (tex: TextureReference, ok: bool) {
	for ref in textureReferences {
		return ref, true
	}
	return {}, false
}

get_models :: proc() -> (mod: ^ModelReference, ok: bool) {
	for &ref in modelReferences {
		return &ref, true
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
		}
		mref.meshLayers = make([]StaticLayer, mref.model.meshCount)
		// unload default materials, coz we use our materials anyway
		for matIdx in 0 ..< mref.model.materialCount {
			rl.MemFree(mref.model.materials[matIdx].maps)
		}
		rl.MemFree(mref.model.materials)
		mref.model.materials = make([^]rl.Material, mref.model.meshCount)
		mref.model.materialCount = mref.model.meshCount
		for i in 0 ..< mref.model.meshCount {
			mref.model.meshMaterial[i] = i
		}
		mref.materials = make([]rl.Material, mref.model.meshCount)
		mref.meshMaterial = make([]int, mref.model.meshCount)
		for &m in mref.materials {
			m = rl.LoadMaterialDefault()
		}
		mref.textureIdx = make([]^TextureReference, mref.model.meshCount)
		ref = mref
	case ".png", ".jpg":
		for t in textureReferences {
			if t.path == path {
				return nil
			}
		}
		tref := TextureReference {
			texture = rl.LoadTexture(st.clone_to_cstring(path, allocator)),
			path    = path,
		}
		ref = tref
	}
	return ref
}

delete_model_reference :: proc(idx: int) {
	r := modelReferences[idx]
	unordered_remove(&modelReferences, idx)
	rl.MemFree(r.model.meshMaterial)
	free(r.model.materials)
	for i in 0 ..< r.model.meshCount {
		rl.UnloadMesh(r.model.meshes[i])
	}
	rl.MemFree(r.model.meshes)
	rl.MemFree(r.model.bones)
	rl.MemFree(r.model.bindPose)
	delete(r.meshLayers)
	for m in r.materials {
		rl.UnloadMaterial(m)
	}
	delete(r.materials)
	delete(r.textureIdx)
}

clear_references :: proc() {
	for ref, ri in modelReferences {
		delete_model_reference(ri)
	}
	for ref, ri in textureReferences {
		rl.UnloadTexture(ref.texture)
	}
	clear(&modelReferences)
	clear(&textureReferences)
}

delete_references :: proc() {
	clear_references()
	delete(modelReferences)
	delete(textureReferences)
}
