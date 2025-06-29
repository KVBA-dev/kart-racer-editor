package main

import "core:fmt"
import "track"
import rl "vendor:raylib"

layerMaterials: [track.StaticLayer]rl.Material
selectedMaterial: rl.Material
highlightMaterial: rl.Material

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
}

destroy_layer_materials :: proc() {
	rl.UnloadMaterial(selectedMaterial)
	rl.UnloadMaterial(highlightMaterial)
	for m in layerMaterials {
		rl.UnloadMaterial(m)
	}
	when ODIN_DEBUG do fmt.println("layer materials unloaded")
}

render_scene: proc() = render_track_mode

render_track_mode :: proc() {
	for &r in track.references {
		m: ^track.ModelReference
		m_ok: bool
		if m, m_ok = &r.(track.ModelReference); !m_ok do continue

		for i in 0 ..< m.model.meshCount {
			layer := m.meshLayers[i]
			matIdx := m.model.meshMaterial[i]
			if &m.model.meshes[i] == selectedMesh {
				m.model.materials[matIdx] = selectedMaterial
			} else if &m.model.meshes[i] == highlightedMesh {
				m.model.materials[matIdx] = highlightMaterial
			} else {
				m.model.materials[matIdx] = layerMaterials[layer]
			}
		}
		rl.DrawModel(m.model, {0, 0, 0}, 1, rl.WHITE)
	}
}

render_material_mode :: proc() {
	for &r in track.references {
		m: ^track.ModelReference
		m_ok: bool
		if m, m_ok = &r.(track.ModelReference); !m_ok do continue
		for i in 0 ..< m.model.meshCount {
			mat := m.materials[m.meshMaterial[i]]
			rl.DrawMesh(m.model.meshes[i], mat, rl.Matrix(1))
		}
	}
}
