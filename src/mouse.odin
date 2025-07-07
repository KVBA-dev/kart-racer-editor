package main
import "clay"
import "core:math"
import la "core:math/linalg"
import "track"
import rl "vendor:raylib"

MouseData :: struct {
	cam_rotation:    rl.Quaternion,
	cam_right:       rl.Vector3,
	cam_forw:        rl.Vector3,
	cam_angles:      rl.Vector2,
	cam:             ^rl.Camera3D,
	scroll_amount:   f32,
	cam_dist:        f32,
	is_gizmo_active: bool,
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
	if rl.IsMouseButtonPressed(.MIDDLE) {
		mouse_state = mouse_state_move
		rl.HideCursor()
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
	if rl.IsMouseButtonPressed(.MIDDLE) {
		mouse_state = mouse_state_move
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
	if rl.IsMouseButtonPressed(.MIDDLE) {
		mouse_state = mouse_state_move
		rl.HideCursor()
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
		mouse_state = mouse_state_ui
		rl.ShowCursor()
		return
	}
}

mouse_state_idle_object :: proc(using data: ^MouseData) {
	scroll_amount = rl.GetMouseWheelMove()
	if clay.PointerOver(clay.ID("Sidebar")) {
		mouse_state = mouse_state_ui
		return
	}
	if rl.IsMouseButtonPressed(.LEFT) {
		mouse_state = mouse_state_select_object
		return
	}
	if rl.IsMouseButtonPressed(.RIGHT) {
		mouse_state = mouse_state_pan
		rl.HideCursor()
		return
	}
	if rl.IsMouseButtonPressed(.MIDDLE) {
		mouse_state = mouse_state_move
		rl.HideCursor()
		return
	}
}

mouse_state_select_object :: proc(using data: ^MouseData) {
	if rl.IsMouseButtonReleased(.LEFT) {
		if md.is_gizmo_active {
			md.is_gizmo_active = false
		} else {
			newSelectedObject: ^track.TrackObject = nil
			ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), md.cam^)
			for &to in objects {
				if check_ray_collision(ray, to) {
					newSelectedObject = &to
					break
				}
			}
			if newSelectedObject != nil && selectedObject == newSelectedObject {
				data.cam.target = get_object_transform(selectedObject).translation
			}
			selectedObject = newSelectedObject
		}
		mouse_state = mouse_state_idle
		return
	}
}

mouse_state_idle_path :: proc(using data: ^MouseData) {
	scroll_amount = rl.GetMouseWheelMove()
	closest_point: rl.Vector3
	if editedPath != nil {
		nearestSegmentIndex = -1
		min_screen_dist: f32 = 1
		mouse_pos := rl.GetMousePosition()
		ray := rl.GetScreenToWorldRay(mouse_pos, cam^)
		for i in 0 ..< get_num_segments(editedPath) {
			nearest_w := closest_point_to_ray(editedPath, i, ray)
			dist_s := distance_from_point_to_ray(nearest_w, ray)
			if dist_s < min_screen_dist {
				min_screen_dist = dist_s
				nearestSegmentIndex = i
				closest_point = nearest_w
			}
		}
	}
	if clay.PointerOver(clay.ID("Sidebar")) {
		mouse_state = mouse_state_ui
		return
	}
	if rl.IsMouseButtonPressed(.LEFT) {
		point, _ := plane_ray_intersection(
			rl.GetScreenToWorldRay(rl.GetMousePosition(), cam^),
			cam.target,
			la.normalize(cam.position - cam.target),
		)
		if rl.IsKeyDown(.LEFT_SHIFT) && editedPath != nil {
			if !editedPath.closed {
				add_segment(editedPath, point)
			} else if nearestSegmentIndex != -1 {
				split_segment(editedPath, closest_point, nearestSegmentIndex)
			}
		} else {
			mouse_state = mouse_state_select_path
		}
		return
	}
	if rl.IsMouseButtonPressed(.RIGHT) {
		found := false
		if rl.IsKeyDown(.LEFT_SHIFT) && editedPath != nil {
			ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), cam^)
			idx := 0
			for idx < len(editedPath.points) {
				if rl.GetRayCollisionSphere(ray, editedPath.points[idx], 0.4).hit {
					delete_segment(editedPath, idx)
					editedPointIndex = -1
					found = true
					break
				}
				idx += 3
			}

		}
		if found {
			mouse_state = mouse_state_delete_path
		} else {
			mouse_state = mouse_state_pan
			rl.HideCursor()
		}
		return
	}
	if rl.IsMouseButtonPressed(.MIDDLE) {
		mouse_state = mouse_state_move
		rl.HideCursor()
		return
	}
}

mouse_state_select_path :: proc(using data: ^MouseData) {
	if rl.IsMouseButtonReleased(.LEFT) {
		if md.is_gizmo_active {
			md.is_gizmo_active = false
		} else {
			editedPointIndex = -1
			ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), md.cam^)
			for &p, i in editedPath.points {
				if rl.GetRayCollisionSphere(ray, p, .4).hit {
					editedPointTransform.translation = p
					editedPointIndex = i
					break
				}
			}
		}
		mouse_state = mouse_state_idle
		return
	}
}

mouse_state_delete_path :: proc(using data: ^MouseData) {
	if rl.IsMouseButtonReleased(.RIGHT) {
		mouse_state = mouse_state_idle
		return
	}
}

mouse_state_move :: proc(using data: ^MouseData) {
	if rl.IsMouseButtonReleased(.MIDDLE) {
		mouse_state = mouse_state_idle
		rl.ShowCursor()
		return
	}
	up := la.cross(cam_right, cam_forw)
	delta := rl.GetMouseDelta() * la.lerp(f32(.01), f32(0.25), f32(md.cam_dist / 50))
	cam.target -= (up * -delta.y + cam_right * delta.x)
}
