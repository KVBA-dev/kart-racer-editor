package main

import "core:fmt"
import "core:image/png"
import fp "core:path/filepath"
import st "core:strings"
import "track"
import rl "vendor:raylib"

minimapTexture: rl.RenderTexture
minimapCam: rl.Camera3D
minimapMaterials: [track.StaticLayer]rl.Material

CLEAR :: rl.Color{0, 0, 0, 0}

init_minimap :: proc() {
	minimapTexture = rl.LoadRenderTexture(500, 500)
	rl.SetTextureFilter(minimapTexture.texture, .BILINEAR)
	minimapCam = rl.Camera3D {
		up         = {0, 0, -1},
		projection = .ORTHOGRAPHIC,
		position   = {0, 500, 0},
		fovy       = 400,
	}
	minimapMaterials[.NoCollision] = rl.LoadMaterialDefault()
	minimapMaterials[.NoCollision].maps[rl.MaterialMapIndex.ALBEDO].color = CLEAR

	minimapMaterials[.Road] = rl.LoadMaterialDefault()
	minimapMaterials[.Road].maps[rl.MaterialMapIndex.ALBEDO].color = rl.WHITE

	minimapMaterials[.Ground] = rl.LoadMaterialDefault()
	minimapMaterials[.Ground].maps[rl.MaterialMapIndex.ALBEDO].color = CLEAR

	minimapMaterials[.Ice] = rl.LoadMaterialDefault()
	minimapMaterials[.Ice].maps[rl.MaterialMapIndex.ALBEDO].color = rl.SKYBLUE

	minimapMaterials[.Water] = rl.LoadMaterialDefault()
	minimapMaterials[.Water].maps[rl.MaterialMapIndex.ALBEDO].color = rl.DARKBLUE

	minimapMaterials[.Decor] = rl.LoadMaterialDefault()
	minimapMaterials[.Decor].maps[rl.MaterialMapIndex.ALBEDO].color = rl.BLACK

	renderTextures[&minimapTexture] = true
}

destroy_minimap :: proc() {
	rl.UnloadRenderTexture(minimapTexture)

	for m in minimapMaterials {
		rl.UnloadMaterial(m)
	}
}

save_minimap :: proc() {
	path := fp.join(
		{st.to_string(currentPath.builder), st.to_string(saveFileName.builder)},
		context.temp_allocator,
	)

	img := rl.LoadImageFromTexture(minimapTexture.texture)
	defer rl.UnloadImage(img)

	rl.ImageFlipVertical(&img)

	if !rl.ExportImage(img, st.clone_to_cstring(path, context.temp_allocator)) {
		fmt.println("error on exporting minimap")
	}
}

render_minimap :: proc() {
	rl.BeginTextureMode(minimapTexture)
	{
		rl.ClearBackground(rl.BLACK)
		rl.BeginMode3D(minimapCam)
		{
			for &r in track.references {
				m: ^track.ModelReference
				m_ok: bool
				if m, m_ok = &r.(track.ModelReference); !m_ok do continue

				for i in 0 ..< m.model.meshCount {
					layer := m.meshLayers[i]
					if layer == .NoCollision || layer == .Ground do continue
					matIdx := m.model.meshMaterial[i]
					mat := minimapMaterials[layer]
					rl.DrawMesh(m.model.meshes[i], mat, rl.Matrix(1))
				}

			}
		}
		rl.EndMode3D()
	}
	rl.EndTextureMode()
}
