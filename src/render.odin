package main

import "core:fmt"
import rg "raygizmo"
import "track"
import rl "vendor:raylib"

layerMaterials: [track.StaticLayer]rl.Material
selectedMaterial: rl.Material
highlightMaterial: rl.Material
whitePixel: rl.Texture

init_layer_materials :: proc() {
	layerMaterials[.NoCollision] = rl.LoadMaterialDefault()
	layerMaterials[.NoCollision].maps[rl.MaterialMapIndex.ALBEDO].color = rl.RED

	layerMaterials[.Road] = rl.LoadMaterialDefault()
	layerMaterials[.Road].maps[rl.MaterialMapIndex.ALBEDO].color = rl.LIGHTGRAY

	layerMaterials[.Ground] = rl.LoadMaterialDefault()
	layerMaterials[.Ground].maps[rl.MaterialMapIndex.ALBEDO].color = rl.GREEN

	layerMaterials[.Ice] = rl.LoadMaterialDefault()
	layerMaterials[.Ice].maps[rl.MaterialMapIndex.ALBEDO].color = rl.SKYBLUE

	layerMaterials[.Water] = rl.LoadMaterialDefault()
	layerMaterials[.Water].maps[rl.MaterialMapIndex.ALBEDO].color = rl.DARKBLUE

	layerMaterials[.Decor] = rl.LoadMaterialDefault()
	layerMaterials[.Decor].maps[rl.MaterialMapIndex.ALBEDO].color = rl.DARKGRAY

	selectedMaterial = rl.LoadMaterialDefault()
	selectedMaterial.maps[rl.MaterialMapIndex.ALBEDO].color = rl.MAGENTA

	highlightMaterial = rl.LoadMaterialDefault()
	highlightMaterial.maps[rl.MaterialMapIndex.ALBEDO].color = rl.YELLOW

	img := rl.GenImageColor(1, 1, rl.WHITE)
	defer rl.UnloadImage(img)
	whitePixel = rl.LoadTextureFromImage(img)
}

destroy_layer_materials :: proc() {
	rl.UnloadMaterial(selectedMaterial)
	rl.UnloadMaterial(highlightMaterial)
	rl.UnloadTexture(whitePixel)
	for m in layerMaterials {
		rl.UnloadMaterial(m)
	}
	when ODIN_DEBUG do fmt.println("layer materials unloaded")
}

render_scene: proc() = render_track_mode

render_track_mode :: proc() {
	for &r in track.modelReferences {
		for i in 0 ..< r.model.meshCount {
			layer := r.meshLayers[i]
			matIdx := r.model.meshMaterial[i]
			if &r.model.meshes[i] == selectedMesh {
				r.model.materials[matIdx] = selectedMaterial
			} else if &r.model.meshes[i] == highlightedMesh {
				r.model.materials[matIdx] = highlightMaterial
			} else {
				r.model.materials[matIdx] = layerMaterials[layer]
			}
		}
		rl.DrawModel(r.model, {0, 0, 0}, 1, rl.WHITE)
	}
}

render_material_mode :: proc() {
	for &r in track.modelReferences {
		for i in 0 ..< r.model.meshCount {
			mat := r.materials[r.meshMaterial[i]]
			if r.textureIdx[i] != nil {
				mat.maps[rl.MaterialMapIndex.ALBEDO].texture = r.textureIdx[i].texture
			} else {
				mat.maps[rl.MaterialMapIndex.ALBEDO].texture = whitePixel
			}
			col := rl.WHITE
			if selectedModelReferenceIdx >= 0 && int(i) == editedMaterialIndex {
				col = rl.ColorTint(col, rl.SKYBLUE)
			}
			mat.maps[rl.MaterialMapIndex.ALBEDO].color = col
			rl.DrawMesh(r.model.meshes[i], mat, rl.Matrix(1))
		}
	}
}

render_object_mode :: proc() {
	for &r in track.modelReferences {
		for i in 0 ..< r.model.meshCount {
			mat := r.materials[r.meshMaterial[i]]
			if r.textureIdx[i] != nil {
				mat.maps[rl.MaterialMapIndex.ALBEDO].texture = r.textureIdx[i].texture
			} else {
				mat.maps[rl.MaterialMapIndex.ALBEDO].texture = whitePixel
			}
			mat.maps[rl.MaterialMapIndex.ALBEDO].color = rl.WHITE
			rl.DrawMesh(r.model.meshes[i], mat, rl.Matrix(1))
		}
	}

	for &o in objects {
		render_object(o)
	}
	if selectedObject != nil {
		transform := get_object_transform(selectedObject)
		md.is_gizmo_active |= rg.DrawGizmo3D(activeGizmoFlags, transform)
	}
}

render_info_mode :: proc() {
	for &r in track.modelReferences {
		for i in 0 ..< r.model.meshCount {
			mat := r.materials[r.meshMaterial[i]]
			if r.textureIdx[i] != nil {
				mat.maps[rl.MaterialMapIndex.ALBEDO].texture = r.textureIdx[i].texture
			} else {
				mat.maps[rl.MaterialMapIndex.ALBEDO].texture = whitePixel
			}
			mat.maps[rl.MaterialMapIndex.ALBEDO].color = rl.WHITE
			rl.DrawMesh(r.model.meshes[i], mat, rl.Matrix(1))
		}
	}

	for &o in objects {
		render_object(o)
	}
}

render_path_mode :: proc() {
	for &r in track.modelReferences {
		for i in 0 ..< r.model.meshCount {
			mat := r.materials[r.meshMaterial[i]]
			if r.textureIdx[i] != nil {
				mat.maps[rl.MaterialMapIndex.ALBEDO].texture = r.textureIdx[i].texture
			} else {
				mat.maps[rl.MaterialMapIndex.ALBEDO].texture = whitePixel
			}
			mat.maps[rl.MaterialMapIndex.ALBEDO].color = rl.WHITE
			rl.DrawMesh(r.model.meshes[i], mat, rl.Matrix(1))
		}
	}
}
