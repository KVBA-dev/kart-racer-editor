package main

import "core:math"
import la "core:math/linalg"
import rg "raygizmo"
import rl "vendor:raylib"

editedPath: ^Path
editedPointTransform: rl.Transform = rg.GizmoIdentity()
editedPointIndex: int = -1
nearestSegmentIndex: int = -1

plane_ray_intersection :: proc(
	ray: rl.Ray,
	point, normal: rl.Vector3,
) -> (
	hit_point: rl.Vector3,
	hit: bool,
) {
	denom := la.dot(normal, ray.direction)
	if abs(denom) < 1e-4 {
		return {}, false
	}

	t := la.dot(point - ray.position, normal) / denom
	if t < 1e-4 {
		return {}, false
	}
	return ray.position + t * ray.direction, true
}

render_path :: proc(using path: ^Path, render_handles := true) {
	if len(points) < 4 do return
	if render_handles {
		rl.DrawCubeWiresV(points[0], {1, 1, 1}, rl.Color{128, 255, 100, 255})
	}
	idx := 0
	for idx < get_num_segments(path) {
		render_segment(
			path,
			points[idx * 3],
			points[idx * 3 + 1],
			points[idx * 3 + 2],
			points[loop_idx(path, idx * 3 + 3)],
			idx == nearestSegmentIndex ? rl.GOLD : rl.GREEN,
		)
		if render_handles {
			rl.DrawLine3D(points[idx * 3], points[idx * 3 + 1], rl.WHITE if idx == 0 else rl.BLACK)
			rl.DrawLine3D(points[idx * 3 + 2], points[loop_idx(path, idx * 3 + 3)], rl.BLACK)
			rl.DrawSphere(points[loop_idx(path, idx * 3)], .4, rl.RED)
			rl.DrawSphere(points[idx * 3 + 1], .2, rl.BLUE)
			rl.DrawSphere(points[idx * 3 + 2], .2, rl.BLUE)
		}
		idx += 1
	}
	if !closed && render_handles {
		rl.DrawSphere(points[len(points) - 1], .4, rl.RED)
	}
}

render_segment :: proc(path: ^Path, p1, c2, c3, p4: rl.Vector3, col: rl.Color) {
	SPLINE_SEGMENT_DIVISIONS :: 24
	STEP: f32 : 1.0 / SPLINE_SEGMENT_DIVISIONS

	prev := p1
	curr := rl.Vector3{}
	t: f32 = 0

	for i in 1 ..= SPLINE_SEGMENT_DIVISIONS {
		t = STEP * f32(i)

		a := math.pow(1 - t, 3)
		b := 3 * math.pow(1 - t, 2) * t
		c := 3 * (1 - t) * t * t
		d := t * t * t

		curr = a * p1 + b * c2 + c * c3 + d * p4

		rl.DrawLine3D(prev, curr, col)
		prev = curr
	}

}
