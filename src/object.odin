package main

import "core:math"
import la "core:math/linalg"
import rg "raygizmo"
import "track"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

objects: [dynamic]track.TrackObject
selectedObject: ^track.TrackObject
activeGizmoFlags: rg.GizmoFlags = {.Translate}
activeGizmoAxes: rg.GizmoActiveAxis = {.X, .Y, .Z}

finish_line := track.FinishLine {
	transform = rg.GizmoIdentity(),
	spreadX   = 5,
	spreadZ   = 4,
}

init_track_objects :: proc() {
	objects = make([dynamic]track.TrackObject)
}

delete_track_objects :: proc() {
	delete(objects)
}

render_object :: proc(object: track.TrackObject) {
	switch o in object {
	case track.FinishLine:
		render_finish_line(o)
	case track.ItemBoxRow:
		render_item_box_row(o)
	}
}

render_finish_line :: proc(fl: track.FinishLine) {
	forw := la.quaternion_mul_vector3(fl.transform.rotation, rl.Vector3{0, 0, 1})
	scale := fl.transform.scale * {1, 1, 0}
	an, ax := la.angle_axis_from_quaternion(fl.transform.rotation)
	rlgl.PushMatrix()
	rlgl.Translatef(
		fl.transform.translation.x,
		fl.transform.translation.y,
		fl.transform.translation.z,
	)
	rlgl.Rotatef(an * math.DEG_PER_RAD, ax.x, ax.y, ax.z)
	rl.DrawCubeV({0, 0, 0}, scale, rl.Color{255, 100, 0, 128})
	rl.DrawCubeWiresV({0, 0, 0}, scale, rl.Color{255, 100, 0, 255})

	for _x in 0 ..< 4 {
		for _z in 1 ..= 3 {

			rl.DrawCubeV(
				{fl.spreadX * (f32(_x) - 1.5), 0, -fl.spreadZ * f32(_z)},
				{1, 0, 1},
				rl.ColorAlpha(rl.SKYBLUE, 0.5),
			)
			rl.DrawCubeWiresV(
				{fl.spreadX * (f32(_x) - 1.5), 0, -fl.spreadZ * f32(_z)},
				{1, 0, 1},
				rl.SKYBLUE,
			)
		}
	}
	rlgl.PopMatrix()
}

render_item_box_row :: proc(ibr: track.ItemBoxRow) {

}

get_object_transform :: proc(object: ^track.TrackObject) -> ^rl.Transform {
	switch &o in object^ {
	case track.FinishLine:
		return &o.transform
	case track.ItemBoxRow:
		return &o.transform
	case:
		return nil
	}
}

check_ray_collision :: proc(ray: rl.Ray, object: track.TrackObject) -> bool {
	switch o in object {
	case track.FinishLine:
		return check_ray_collision_finish_line(ray, o)
	case track.ItemBoxRow:
		return false
	case:
		return false
	}
}

check_ray_collision_finish_line :: proc(ray: rl.Ray, fl: track.FinishLine) -> bool {
	mat := rg.GizmoToMatrix(fl.transform)
	p1 := rl.Vector3Transform(rl.Vector3{0.5, 0.5, 0}, mat)
	p2 := rl.Vector3Transform(rl.Vector3{-0.5, 0.5, 0}, mat)
	p3 := rl.Vector3Transform(rl.Vector3{-0.5, -0.5, 0}, mat)
	p4 := rl.Vector3Transform(rl.Vector3{0.5, -0.5, 0}, mat)
	return rl.GetRayCollisionQuad(ray, p1, p2, p3, p4).hit
}
