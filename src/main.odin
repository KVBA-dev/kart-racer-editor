package main

import "clay"
import "core:fmt"
import la "core:math/linalg"
import "core:mem"
import os "core:os/os2"
import fp "core:path/filepath"
import rg "raygizmo"
import "track"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

dir, file, up, home, plus, minus, cross: rl.Texture

clay_error_handler :: proc "c" (errorData: clay.ErrorData) {
}

/* TODO:
	  - track objects
		  - snap rotationto 30deg increments
*/

main :: proc() {
	when ODIN_DEBUG {
		talloc := mem.Tracking_Allocator{}
		mem.tracking_allocator_init(&talloc, context.allocator)
		context.allocator = mem.tracking_allocator(&talloc)
		defer {
			if len(talloc.allocation_map) > 0 {
				fmt.eprintfln("===== Allocations not freed: %v =====", len(talloc.allocation_map))
				for _, entry in talloc.allocation_map {
					fmt.eprintfln(" - %v bytes at %v", entry.size, entry.location)
				}
			}
			if len(talloc.bad_free_array) > 0 {
				fmt.eprintfln("===== Bad frees: %v =====", len(talloc.bad_free_array))
				for entry in talloc.bad_free_array {
					fmt.eprintfln(" = %p at @%v", entry.memory, entry.location)
				}
			}
		}
	}

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "kart-racer-editor")
	defer rl.CloseWindow()

	rl.SetWindowState({.WINDOW_RESIZABLE, .WINDOW_MAXIMIZED})
	screenSize := [2]i32{rl.GetScreenWidth(), rl.GetScreenHeight()}
	rl.SetWindowSize(screenSize.x, screenSize.y)
	cam := rl.Camera3D {
		projection = .PERSPECTIVE,
		position   = {0, 1, -5},
		up         = {0, 1, 0},
		fovy       = 75,
		target     = {0, 1, 0},
	}
	rl.SetExitKey(nil)

	load_font("res/fonts/Roboto.ttf", 50)
	dir = rl.LoadTexture("res/sprites/dir.png")
	file = rl.LoadTexture("res/sprites/file.png")
	up = rl.LoadTexture("res/sprites/up.png")
	home = rl.LoadTexture("res/sprites/home.png")
	plus = rl.LoadTexture("res/sprites/plus.png")
	minus = rl.LoadTexture("res/sprites/minus.png")
	cross = rl.LoadTexture("res/sprites/cross.png")
	rl.SetTextureFilter(dir, .BILINEAR)
	rl.SetTextureFilter(file, .BILINEAR)
	rl.SetTextureFilter(up, .BILINEAR)
	rl.SetTextureFilter(home, .BILINEAR)
	rl.SetTextureFilter(plus, .BILINEAR)
	rl.SetTextureFilter(minus, .BILINEAR)
	rl.SetTextureFilter(cross, .BILINEAR)
	defer {
		for f in rlFonts {
			rl.UnloadFont(f)
		}
		delete(rlFonts)
		rl.UnloadTexture(dir)
		rl.UnloadTexture(file)
		rl.UnloadTexture(up)
		rl.UnloadTexture(home)
		rl.UnloadTexture(plus)
		rl.UnloadTexture(minus)
		rl.UnloadTexture(cross)
	}

	init_layer_materials()
	defer destroy_layer_materials()

	init_string_buffer(&strBuf)
	defer delete_string_buffer(&strBuf)

	init_minimap()
	defer destroy_minimap()

	init_track_objects()
	defer delete_track_objects()

	append(&objects, finish_line)

	editedPath = make_path({0, 0, 5})
	defer destroy_path(editedPath)
	set_closed(editedPath, true)

	startPath: string
	oerr: os.Error
	init_files_array()
	defer delete_files_array()
	if startPath, oerr = os.get_executable_directory(context.allocator); oerr != nil {
		return
	}
	fmt.sbprint(&currentPath.builder, startPath)
	delete(startPath)
	defer destroy_input_field(&currentPath)

	clay_mem_size := clay.MinMemorySize()
	clay_mem := make([^]u8, clay_mem_size)
	defer free(clay_mem)
	clay_arena := clay.CreateArenaWithCapacityAndMemory(cast(uint)clay_mem_size, clay_mem)
	clay.Initialize(
		clay_arena,
		{width = cast(f32)screenSize.x, height = cast(f32)screenSize.y},
		{handler = clay_error_handler},
	)
	clay.SetMeasureTextFunction(measure_text, nil)
	layout: clay.ClayArray(clay.RenderCommand)

	dt: f32
	md = MouseData {
		cam_rotation = rl.Quaternion(1),
		cam          = &cam,
		cam_dist     = 5,
		cam_forw     = {0, 0, 1},
	}

	rg.SetCamera(&cam)
	selectedObject = nil

	rl.SetTargetFPS(60)

	defer track.delete_references()

	for !rl.WindowShouldClose() {
		screenSize := [2]i32{rl.GetScreenWidth(), rl.GetScreenHeight()}
		dt = rl.GetFrameTime()
		clay.SetLayoutDimensions({width = cast(f32)screenSize.x, height = cast(f32)screenSize.y})
		clay.UpdateScrollContainers(true, rl.GetMouseWheelMoveV() * 3, rl.GetFrameTime())
		clay.SetPointerState(rl.GetMousePosition(), rl.IsMouseButtonDown(.LEFT))
		if rl.IsKeyPressed(.F11) {
			clay.SetDebugModeEnabled(!clay.IsDebugModeEnabled())
		}

		if dialogVisible != nil do layout = dialogVisible()
		else do layout = base_layout()

		md.cam_forw = la.quaternion_mul_vector3(md.cam_rotation, rl.Vector3{0, 0, 1})
		md.cam_right = la.normalize(la.cross(md.cam_forw, cam.up))

		if selectedInputField == nil {
			if rl.IsKeyPressed(.ONE) {
				activeGizmoFlags = {.Translate}
			}
			if rl.IsKeyPressed(.TWO) {
				activeGizmoFlags = {.Rotate}
				rg.SetGizmoGlobalAxis({1, 0, 0}, {0, 0, 1}, {0, 1, 0})
			}
			if rl.IsKeyPressed(.THREE) {
				activeGizmoFlags = {.Scale}
			}
		} else {
			edit_input_field(selectedInputField)
		}

		mouse_state(&md)

		mouseScroll := md.scroll_amount
		md.cam_dist = la.clamp(md.cam_dist - mouseScroll, .1, 50)

		cam.position = cam.target - md.cam_forw * md.cam_dist

		rl.BeginDrawing()
		{
			render_minimap()
			rl.ClearBackground(rl.Color{40, 40, 40, 255})
			if dialogVisible == nil {
				rl.BeginMode3D(cam)
				{
					render_scene()
					rl.DrawGrid(50, 5)
				}
				rl.EndMode3D()
			}
			clay_rl_render(&layout)
		}
		rl.EndDrawing()
	}
}

axis :: proc(pos, neg: rl.KeyboardKey) -> f32 {
	return (rl.IsKeyDown(pos) ? 1 : 0) - (rl.IsKeyDown(neg) ? 1 : 0)
}

load_font :: proc(path: cstring, size: i32) -> int {
	append(&rlFonts, rl.LoadFontEx(path, size, nil, 255))
	fontIdx := len(rlFonts) - 1
	rl.SetTextureFilter(rlFonts[fontIdx].texture, .BILINEAR)
	return fontIdx
}

save :: proc() {
	save_path := fp.join(
		{input_field_text(&currentPath), input_field_text(&saveFileName)},
		context.temp_allocator,
	)
	track_def := track.Track {
		staticModels = make([]track.StaticModel, len(track.modelReferences)),
		minimap = {offset = minimapCam.position.xz, zoom = minimapCam.fovy},
		objects = make([]track.TrackObject, len(objects) - 1),
	}
	defer track.destroy_track(&track_def)

	track_def.finishLine = objects[0].(track.FinishLine)
	for &sm, i in track_def.staticModels {
		sm.filepath, _ = fp.rel(
			input_field_text(&currentPath),
			track.modelReferences[i].path_obj,
			context.temp_allocator,
		)
		sm.materials = make([]track.StaticMaterial, len(track.modelReferences[i].materials))
		sm.meshes = make([]track.StaticMesh, len(track.modelReferences[i].meshLayers))
		for &smm, ii in sm.meshes {
			smm.idx = cast(i32)ii
			smm.layer = track.modelReferences[i].meshLayers[ii]
		}
		for &smmat, ii in sm.materials {
			smmat.idx = cast(i32)ii
			if texpath := track.modelReferences[i].textureIdx[ii]; texpath == nil {
				smmat.albedo = ""
			} else {
				smmat.albedo, _ = fp.rel(
					input_field_text(&currentPath),
					track.modelReferences[i].textureIdx[ii].path,
				)
			}
		}
	}

	for o, i in objects[1:] {
		track_def.objects[i] = o
	}

	track_def.path = editedPath.points[:]

	if !save_cbor(save_path, track_def) {
		fmt.println("error on saving")
	}
}

load :: proc() {
	track_def := track.Track{}
	load_path := fp.join(
		{input_field_text(&currentPath), input_field_text(&saveFileName)},
		context.temp_allocator,
	)
	if !load_cbor(load_path, &track_def) {
		fmt.println("error on loading")
		return
	}
	defer track.destroy_track(&track_def)
	track.clear_references()
	clear(&objects)
	loaded_finish_line := track_def.finishLine
	if loaded_finish_line == {} {
		loaded_finish_line = finish_line
	}
	append(&objects, loaded_finish_line)
	for &sm in track_def.staticModels {
		fpath, err := fp.clean(
			fp.join({input_field_text(&currentPath), sm.filepath}, context.temp_allocator),
			context.temp_allocator,
		)
		if err != nil do panic(fmt.tprint("error:", sm.filepath, "doesn't exist"))
		ref := track.try_load_file(fpath)

		mref := ref.(track.ModelReference)
		for &smm in sm.meshes {
			mref.meshLayers[smm.idx] = smm.layer
		}

		matloop: for &smmat in sm.materials {
			if smmat.albedo == "" {
				continue
			}
			fpath, err := fp.clean(
				fp.join({input_field_text(&currentPath), smmat.albedo}, context.temp_allocator),
				context.temp_allocator,
			)
			for &tref in track.textureReferences {
				if fpath == tref.path {
					mref.textureIdx[smmat.idx] = &tref
					continue matloop
				}
			}
			tex_ref := track.try_load_file(fpath).(track.TextureReference)
			append(&track.textureReferences, tex_ref)
			mref.textureIdx[smmat.idx] = &track.textureReferences[len(track.textureReferences) - 1]
		}

		append(&track.modelReferences, mref)
	}

	minimapCam.position.xz = track_def.minimap.offset
	minimapCam.target.xz = track_def.minimap.offset
	minimapCam.fovy = track_def.minimap.zoom

	clear(&editedPath.points)
	append(&editedPath.points, ..track_def.path)
	defer delete(track_def.path)

	for o in track_def.objects {
		append(&objects, o)
	}

}
