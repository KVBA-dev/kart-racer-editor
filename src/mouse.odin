package main
import "clay"
import "core:math"
import la "core:math/linalg"
import "track"
import rl "vendor:raylib"

MouseData :: struct {
	cam_rotation:  rl.Quaternion,
	cam_right:     rl.Vector3,
	cam_angles:    rl.Vector2,
	cam:           ^rl.Camera3D,
	scroll_amount: f32,
}

highlightedMesh: ^rl.Mesh
selectedMesh: ^rl.Mesh
selectedLayer: ^track.StaticLayer

md: MouseData
mouse_state_idle: proc(data: ^MouseData) = mouse_state_idle_track
mouse_state: proc(data: ^MouseData) = mouse_state_idle

mouse_state_idle_track :: proc(using data: ^MouseData) {
	highlightedMesh = nil
	max_hit_dist: f32 = math.F32_MAX
	ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), cam^)
	for &r in track.modelReferences {
		m := &r
		if !rl.GetRayCollisionBox(ray, rl.GetModelBoundingBox(m.model)).hit do continue
		for i in 0 ..< m.model.meshCount {
			hitinfo := rl.GetRayCollisionMesh(ray, m.model.meshes[i], rl.Matrix(1))
			if !hitinfo.hit do continue
			if hitinfo.distance < max_hit_dist {
				max_hit_dist = hitinfo.distance
				highlightedMesh = &m.model.meshes[i]
			}
		}
	}
	scroll_amount = rl.GetMouseWheelMove()
	if clay.PointerOver(clay.ID("Sidebar")) {
		mouse_state = mouse_state_ui
		highlightedMesh = nil
		return
	}
	if rl.IsMouseButtonPressed(.RIGHT) {
		mouse_state = mouse_state_pan
		rl.HideCursor()
		return
	}
	if rl.IsMouseButtonPressed(.LEFT) {
		mouse_state = mouse_state_select_mesh
		return
	}
}

mouse_state_idle_info :: proc(using data: ^MouseData) {
	scroll_amount = rl.GetMouseWheelMove()
	if clay.PointerOver(clay.ID("Sidebar")) {
		mouse_state = mouse_state_ui
		highlightedMesh = nil
		return
	}
	if rl.IsMouseButtonPressed(.RIGHT) {
		mouse_state = mouse_state_pan
		rl.HideCursor()
		return
	}
}

mouse_state_select_mesh :: proc(using data: ^MouseData) {
	if rl.IsMouseButtonReleased(.LEFT) {
		mouse_state = mouse_state_idle
		selectedMesh = nil
		selectedLayer = nil
		selectedModelReferenceIdx = -1
		max_hit_dist: f32 = math.F32_MAX
		ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), cam^)
		for &r, ri in track.modelReferences {
			m := &r
			if !rl.GetRayCollisionBox(ray, rl.GetModelBoundingBox(m.model)).hit do continue
			for i in 0 ..< m.model.meshCount {
				hitinfo := rl.GetRayCollisionMesh(ray, m.model.meshes[i], rl.Matrix(1))
				if !hitinfo.hit do continue
				if hitinfo.distance < max_hit_dist {
					max_hit_dist = hitinfo.distance
					selectedMesh = &m.model.meshes[i]
					selectedLayer = &m.meshLayers[i]
					selectedModelReferenceIdx = ri
				}
			}
		}
		return
	}
}

mouse_state_pan :: proc(using data: ^MouseData) {
	scroll_amount = rl.GetMouseWheelMove()
	cam_angles += rl.GetMouseDelta() * la.RAD_PER_DEG * .3 * {1, -1}
	cam_rotation = la.quaternion_from_euler_angles(cam_angles.x, cam_angles.y, 0, .YXZ)
	if rl.IsMouseButtonUp(.RIGHT) {
		mouse_state = mouse_state_idle
		rl.ShowCursor()
		return
	}

}

mouse_state_ui :: proc(using data: ^MouseData) {
	if clay.PointerOver(clay.ID("Viewport")) {
		mouse_state = mouse_state_idle
		return
	}
	if clay.PointerOver(clay.ID("TrackMinimapPreview")) {
		mouse_state = mouse_state_idle_minimap
		return
	}
}

mouse_state_disabled :: proc(data: ^MouseData) {}

mouse_state_drag :: proc(using data: ^MouseData) {
	if rl.IsMouseButtonUp(.LEFT) {
		mouse_state = mouse_state_idle
		return
	}
}

mouse_state_idle_minimap :: proc(using data: ^MouseData) {
	if !clay.PointerOver(clay.ID("TrackMinimapPreview")) {
		mouse_state = mouse_state_ui
		return
	}
	if rl.IsMouseButtonDown(.LEFT) {
		mouse_state = mouse_state_drag_minimap
		return
	}
	minimapCam.fovy = math.clamp(minimapCam.fovy - rl.GetMouseWheelMove() * 3, 0, 1000)
}

mouse_state_drag_minimap :: proc(using data: ^MouseData) {
	if rl.IsMouseButtonUp(.LEFT) {
		mouse_state = mouse_state_idle
		return
	}
	delta := rl.GetMouseDelta() * minimapCam.fovy * 0.0035
	minimapCam.position.xz -= delta
	minimapCam.target.xz -= delta
}

mouse_state_idle_material :: proc(using data: ^MouseData) {
	scroll_amount = rl.GetMouseWheelMove()
	if clay.PointerOver(clay.ID("Sidebar")) {
		mouse_state = mouse_state_ui
		highlightedMesh = nil
		return
	}
	if rl.IsMouseButtonPressed(.RIGHT) {
		mouse_state = mouse_state_pan
		rl.HideCursor()
		return
	}
	if rl.IsMouseButtonPressed(.LEFT) {
		mouse_state = mouse_state_select_material
		return
	}
}

mouse_state_select_material :: proc(using data: ^MouseData) {
	if rl.IsMouseButtonReleased(.LEFT) {
		mouse_state = mouse_state_idle
		selectedMesh = nil
		selectedLayer = nil
		selectedModelReferenceIdx = -1
		max_hit_dist: f32 = math.F32_MAX
		ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), cam^)
		for &r, ri in track.modelReferences {
			m := &r
			if !rl.GetRayCollisionBox(ray, rl.GetModelBoundingBox(m.model)).hit do continue
			for i in 0 ..< m.model.meshCount {
				hitinfo := rl.GetRayCollisionMesh(ray, m.model.meshes[i], rl.Matrix(1))
				if !hitinfo.hit do continue
				if hitinfo.distance < max_hit_dist {
					max_hit_dist = hitinfo.distance
					selectedModelReferenceIdx = ri
					editedMaterialIndex = 0
				}
			}
		}
		return
	}
}

mouse_state_float_field :: proc(using data: ^MouseData) {
	if rl.IsMouseButtonPressed(.LEFT) {
		mouse_state = mouse_state_edit_float_field
		rl.HideCursor()
		return
	}
}

mouse_state_edit_float_field :: proc(using data: ^MouseData) {
	editedFloatField.val^ = math.clamp(
		-rl.GetMouseDelta().y * editedFloatField.delta + editedFloatField.val^,
		editedFloatField.bounds.min,
		editedFloatField.bounds.max,
	)

	if rl.IsMouseButtonUp(.LEFT) {
		mouse_state = mouse_state_float_field
		rl.ShowCursor()
		return
	}
}
