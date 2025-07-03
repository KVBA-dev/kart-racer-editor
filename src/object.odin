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

item_box_row := track.ItemBoxRow {
	transform = rg.GizmoIdentity(),
	count     = 5,
	spread    = 10,
}

init_track_objects :: proc() {
	objects = make([dynamic]track.TrackObject)
}

delete_track_objects :: proc() {
	delete(objects)
}

create_item_box_row :: proc() -> track.ItemBoxRow {
	return item_box_row
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
	an, ax := la.angle_axis_from_quaternion(ibr.transform.rotation)
	count := math.floor(ibr.count)
	rlgl.PushMatrix()
	rlgl.Translatef(
		ibr.transform.translation.x,
		ibr.transform.translation.y,
		ibr.transform.translation.z,
	)
	rlgl.Rotatef(an * math.DEG_PER_RAD, ax.x, ax.y, ax.z)
	if count == 1 {
		rl.DrawCubeV({0, 0, 0}, {1, 1, 1}, rl.ColorAlpha(rl.GREEN, 0.5))
		rl.DrawCubeWiresV({0, 0, 0}, {1, 1, 1}, rl.GREEN)
		rlgl.PopMatrix()
		return
	}
	delta: f32 = 1 / f32(count - 1)
	pos: f32 = -0.5
	for _ in 0 ..< count {
		rl.DrawCubeV({pos * ibr.spread, 0, 0}, {1, 1, 1}, rl.ColorAlpha(rl.GREEN, 0.5))
		rl.DrawCubeWiresV({pos * ibr.spread, 0, 0}, {1, 1, 1}, rl.GREEN)
		pos += delta
	}
	rlgl.PopMatrix()
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
		return check_ray_collision_item_box_row(ray, o)
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

check_ray_collision_item_box_row :: proc(ray: rl.Ray, ibr: track.ItemBoxRow) -> bool {
	box := rl.BoundingBox {
		min = {-ibr.spread / 2 - 0.5, -0.5, -0.5},
		max = {ibr.spread / 2 + 0.5, 0.5, 0.5},
	}

	localRight := la.quaternion_mul_vector3(ibr.transform.rotation, rl.Vector3{1, 0, 0})
	localUp := la.quaternion_mul_vector3(ibr.transform.rotation, rl.Vector3{0, 1, 0})
	localForw := la.quaternion_mul_vector3(ibr.transform.rotation, rl.Vector3{0, 0, 1})

	mat := rg.GizmoToMatrix(ibr.transform)
	localOrigin := ray.position - ibr.transform.translation

	transformedRay := rl.Ray {
		position  = {
			la.dot(localOrigin, localRight),
			la.dot(localOrigin, localUp),
			la.dot(localOrigin, localForw),
		},
		direction = {
			la.dot(ray.direction, localRight),
			la.dot(ray.direction, localUp),
			la.dot(ray.direction, localForw),
		},
	}

	return rl.GetRayCollisionBox(transformedRay, box).hit
}
