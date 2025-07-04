package main

import "core:math"
import la "core:math/linalg"
import rg "raygizmo"
import rl "vendor:raylib"

Path :: struct {
	points: [dynamic]rl.Vector3,
	closed: bool,
}

make_path :: proc(center: rl.Vector3) -> ^Path {
	path := new(Path)
	path.points = make([dynamic]rl.Vector3)
	append(
		&path.points,
		center - {6, 0, 0},
		center - {3, 0, 3},
		center + {3, 0, 3},
		center + {6, 0, 0},
	)
	path.closed = false
	return path
}

destroy_path :: proc(path: ^Path) {
	delete(path.points)
	free(path)
}

add_segment :: proc(using path: ^Path, anchor: rl.Vector3) {
	currLen := len(points)
	append(&points, 2 * points[currLen - 1] - points[currLen - 2])
	append(&points, 0.5 * (points[currLen] + anchor))
	append(&points, anchor)
}

split_segment :: proc(using path: ^Path, anchor: rl.Vector3, idx: int) {
	inject_at(&points, idx * 3 + 2, rl.Vector3{0, 0, 0})
	inject_at(&points, idx * 3 + 2, anchor)
	inject_at(&points, idx * 3 + 2, rl.Vector3{0, 0, 0})

	points[idx * 3 + 4] = 0.5 * (anchor + points[loop_idx(path, idx * 3 + 6)])
	points[idx * 3 + 2] = 0.5 * (anchor + points[loop_idx(path, idx * 3)])
}

get_points_in_segment :: proc(using path: ^Path, idx: int) -> [4]rl.Vector3 {
	return {
		points[idx * 3],
		points[idx * 3 + 1],
		points[idx * 3 + 2],
		points[loop_idx(path, idx * 3 + 3)],
	}
}

point_in_segment :: proc(using path: ^Path, segment_idx: int, t: f32) -> rl.Vector3 {
	control_points := get_points_in_segment(path, segment_idx)

	a := math.pow(1 - t, 3)
	b := 3 * math.pow(1 - t, 2) * t
	c := 3 * (1 - t) * t * t
	d := t * t * t

	return(
		a * control_points[0] +
		b * control_points[1] +
		c * control_points[2] +
		d * control_points[3] \
	)
}

get_num_segments :: proc(using path: ^Path) -> int {
	return len(points) / 3
}

loop_idx :: proc(using path: ^Path, i: int) -> int {
	return (i + len(points)) % len(points)
}

move_point :: proc(using path: ^Path, idx: int, new_pos: rl.Vector3) {
	delta := new_pos - points[idx]
	points[idx] = new_pos

	if idx % 3 == 0 { 	// anchor point
		if idx + 1 < len(points) || closed {
			points[loop_idx(path, idx + 1)] += delta
		}
		if idx > 0 || closed {
			points[loop_idx(path, idx - 1)] += delta
		}
	} else { 	// control point
		otherIdx := idx % 3 == 1 ? idx - 2 : idx + 2
		anchorIdx := idx % 3 == 1 ? idx - 1 : idx + 1

		if otherIdx >= 0 && otherIdx < len(points) || closed {
			diff := points[loop_idx(path, anchorIdx)] - points[loop_idx(path, otherIdx)]
			dist := la.length(diff)
			dir := la.normalize(points[loop_idx(path, anchorIdx)] - new_pos)
			points[loop_idx(path, otherIdx)] = points[loop_idx(path, anchorIdx)] + dir * dist
		}
	}
}

set_closed :: proc(using path: ^Path, new_closed: bool) {
	if !closed && new_closed {
		currLen := len(points)
		append(&points, 2 * points[currLen - 1] - points[currLen - 2])
		append(&points, 2 * points[0] - points[1])
	} else if closed && !new_closed {
		unordered_remove(&points, len(points) - 1)
		unordered_remove(&points, len(points) - 1)
	}
	closed = new_closed
}

delete_segment :: proc(using path: ^Path, anchorIdx: int) {
	if get_num_segments(path) <= 2 || !closed && get_num_segments(path) == 1 {
		return
	}
	if anchorIdx == 0 {
		if closed {
			points[len(points) - 1] = points[2]
		}
		ordered_remove(&points, 0)
		ordered_remove(&points, 0)
		ordered_remove(&points, 0)
		return
	}
	if anchorIdx == len(points) - 1 && !closed {
		unordered_remove(&points, len(points) - 1)
		unordered_remove(&points, len(points) - 1)
		unordered_remove(&points, len(points) - 1)
		return
	}
	ordered_remove(&points, anchorIdx - 1)
	ordered_remove(&points, anchorIdx - 1)
	ordered_remove(&points, anchorIdx - 1)
}

closest_point_on_path :: proc(
	using path: ^Path,
	segment_idx: int,
	point: rl.Vector3,
) -> rl.Vector3 {
	RESOLUTION :: 24
	path_points := get_points_in_segment(path, segment_idx)

	out := path_points[0]
	dist_sqr := la.length2(out - point)

	for i in 1 ..= RESOLUTION {
		t := f32(1) / RESOLUTION
		path_point := point_in_segment(path, segment_idx, t)

		curr_dist := la.length2(path_point - point)
		if curr_dist < dist_sqr {
			dist_sqr = curr_dist
			out = path_point
		}
	}

	return out
}

closest_point_to_ray :: proc(using path: ^Path, segment_idx: int, ray: rl.Ray) -> rl.Vector3 {
	RESOLUTION :: 24
	path_points := get_points_in_segment(path, segment_idx)

	out := path_points[0]
	dist := distance_from_point_to_ray(out, ray)

	for i in 1 ..= RESOLUTION {
		t := f32(i) / f32(RESOLUTION)
		path_point := point_in_segment(path, segment_idx, t)
		curr_dist := distance_from_point_to_ray(path_point, ray)
		if curr_dist < dist {
			dist = curr_dist
			out = path_point
		}
	}

	return out
}

distance_from_point_to_ray :: proc(point: rl.Vector3, ray: rl.Ray) -> f32 {
	t := la.dot(point - ray.position, ray.direction)
	proj := ray.position + t * ray.direction
	return la.length(proj - point)
}
