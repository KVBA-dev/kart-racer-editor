package main

import "clay"
import "core:fmt"
import "core:io"
import os "core:os/os2"
import fp "core:path/filepath"
import st "core:strings"
import "track"
import rl "vendor:raylib"

currentPath: InputFieldData
saveFileName: InputFieldData
dialogVisible: proc() -> Layout = nil
save_cbk: proc() = nil
load_cbk: proc(_: track.FileReference) = nil

extensions_model := []string{".obj"}
extensions_level := []string{".klv"}
extensions_texture := []string{".png", ".jpg"}

extensions: []string

FileList :: struct {
	files: st.Builder,
	dirty: bool,
}

model_loaded :: proc(model: track.FileReference) {
	append(&track.modelReferences, model.(track.ModelReference))
	dialogVisible = nil
	mouse_state = mouse_state_ui
}

texture_loaded :: proc(model: track.FileReference) {
	append(&track.textureReferences, model.(track.TextureReference))
	dialogVisible = select_texture_dialog
	mouse_state = mouse_state_ui
}

file_list_walk_proc :: proc(
	info: os.File_Info,
	in_err: os.Error,
	user_data: rawptr,
) -> (
	err: os.Error,
	skip_dir: bool,
) {
	files := cast(^st.Builder)user_data
	skip_dir = false
	err = in_err
	if info.fullpath == input_field_text(&currentPath) do return

	if len(extensions) == 0 {
		fmt.sbprintln(files, info.fullpath)
	} else {
		ext := fp.ext(info.fullpath)
		if len(ext) == 0 && os.is_dir(info.fullpath) {
			fmt.sbprintln(files, info.fullpath)
		}
		for e in extensions {
			if ext == e {
				fmt.sbprintln(files, info.fullpath)
				break
			}
		}
	}
	if os.is_dir(info.fullpath) {
		skip_dir = true
	}
	return
}

files := FileList{}
init_files_array :: proc() {
	files = FileList {
		dirty = true,
	}
	st.builder_init(&files.files)
	currentPath = init_input_field(256)
	currentPath.endEdit = proc() {
		files.dirty = true
	}
	saveFileName = init_input_field(256)
	saveFileName.endEdit = proc() {}
}

delete_files_array :: proc() {
	st.builder_destroy(&files.files)
	when ODIN_DEBUG do fmt.println("file paths deleted")
}

file_dialog :: proc() -> Layout {
	if files.dirty {
		st.builder_reset(&files.files)

		walkerr := fp.walk(
			input_field_text(&currentPath),
			cast(fp.Walk_Proc)file_list_walk_proc,
			&files.files,
		)
		if walkerr != nil {
			fmt.println(walkerr)
		}
		files.dirty = false
	}
	if rl.IsKeyPressed(.ESCAPE) {
		mouse_state = mouse_state_idle
		dialogVisible = nil
	}

	clay.BeginLayout()
	if clay.UI()(
	{
		id = clay.ID("FileListBase"),
		backgroundColor = COLOR_BG,
		layout = {
			padding = clay.PaddingAll(8),
			sizing = sizingExpand,
			layoutDirection = .TopToBottom,
			childGap = 4,
		},
	},
	) {
		if clay.UI()(
		{
			id = clay.ID("FileListHeader"),
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
				layoutDirection = .LeftToRight,
				childGap = 16,
				childAlignment = {x = .Left, y = .Center},
			},
		},
		) {
			newPath: string
			clay.Text(
				"Select file",
				clay.TextConfig({fontId = 0, textColor = COLOR_WHITE, fontSize = 48}),
			)
			if ImageButton(
				"btnFileListHome",
				&icons[.Home],
				{width = clay.SizingFixed(50), height = clay.SizingGrow({})},
			) {

				newPath, _ = os.get_executable_directory(context.allocator)
				input_field_text(&currentPath, newPath)
				delete(newPath)
				files.dirty = true
			}
			if ImageButton(
				"btnFileListUp",
				&icons[.Up],
				{width = clay.SizingFixed(50), height = clay.SizingGrow({})},
			) {
				newPath = fp.dir(input_field_text(&currentPath))
				input_field_text(&currentPath, newPath)
				delete(newPath)
				files.dirty = true
			}
			InputField("inpFilePath", &currentPath, 22)
		}
		if clay.UI()(
		{layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(16)}}},
		) {}
		if clay.UI()(
		{
			id = clay.ID("FileListScroll"),
			clip = {vertical = true, childOffset = clay.GetScrollOffset()},
			layout = {
				layoutDirection = .TopToBottom,
				sizing = sizingExpand,
				padding = clay.PaddingAll(8),
				childGap = 8,
			},
		},
		) {
			paths := st.to_string(files.files)
			for f in st.split_lines_iterator(&paths) {
				if _, clicked := file_list_item(f, COLOR_BG_2); clicked {
					if os.is_dir(f) {
						when ODIN_OS == .Windows {
							fmt.sbprintf(&currentPath.builder, "\\%s", fp.base(f))
						} else {

							fmt.sbprintf(&currentPath.builder, "/%s", fp.base(f))
						}
						files.dirty = true
					} else {
						if fp.ext(f) == ".klv" {
							st.builder_reset(&saveFileName.builder)
							fmt.sbprint(&saveFileName.builder, fp.base(f))
							load()
							dialogVisible = nil
							mouse_state = mouse_state_ui
						} else if ref := track.try_load_file(st.clone(f)); ref != nil {
							if load_cbk != nil {
								load_cbk(ref)
							}
						}
					}
					break
				}
			}
		}
	}
	return clay.EndLayout()
}

save_file_dialog :: proc() -> Layout {
	if files.dirty {
		st.builder_reset(&files.files)

		walkerr := fp.walk(
			input_field_text(&currentPath),
			cast(fp.Walk_Proc)file_list_walk_proc,
			&files.files,
		)
		if walkerr != nil {
			fmt.println(walkerr)
		}
		files.dirty = false
	}
	if rl.IsKeyPressed(.ESCAPE) {
		mouse_state = mouse_state_idle
		dialogVisible = nil
	}

	clay.BeginLayout()
	if clay.UI()(
	{
		id = clay.ID("FileListBase"),
		backgroundColor = COLOR_BG,
		layout = {
			padding = clay.PaddingAll(8),
			sizing = sizingExpand,
			layoutDirection = .TopToBottom,
			childGap = 4,
		},
	},
	) {
		if clay.UI()(
		{
			id = clay.ID("FileListHeader"),
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
				layoutDirection = .LeftToRight,
				childGap = 16,
				childAlignment = {x = .Left, y = .Center},
			},
		},
		) {
			newPath: string
			clay.Text(
				"Save file",
				clay.TextConfig({fontId = 0, textColor = COLOR_WHITE, fontSize = 48}),
			)
			if ImageButton(
				"btnFileListHome",
				&icons[.Home],
				{width = clay.SizingFixed(50), height = clay.SizingGrow({})},
			) {

				newPath, _ = os.get_executable_directory(context.allocator)
				input_field_text(&currentPath, newPath)
				delete(newPath)
				files.dirty = true
			}
			if ImageButton(
				"btnFileListUp",
				&icons[.Up],
				{width = clay.SizingFixed(50), height = clay.SizingGrow({})},
			) {
				newPath = fp.dir(input_field_text(&currentPath))
				input_field_text(&currentPath, newPath)
				delete(newPath)
				files.dirty = true
			}
			InputField("inpFilePath", &currentPath, 22)
		}
		if clay.UI()(
		{layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(16)}}},
		) {}
		if clay.UI()(
		{
			id = clay.ID("FileListScroll"),
			clip = {vertical = true, childOffset = clay.GetScrollOffset()},
			layout = {
				layoutDirection = .TopToBottom,
				sizing = sizingExpand,
				padding = clay.PaddingAll(8),
				childGap = 8,
			},
		},
		) {
			paths := st.to_string(files.files)
			for f in st.split_lines_iterator(&paths) {
				if path, clicked := file_list_item(f, COLOR_BG_2); clicked {
					if os.is_dir(path) {
						fmt.sbprintf(&currentPath.builder, "/%s", fp.base(path))
						files.dirty = true
					} else {
						st.builder_reset(&saveFileName.builder)
						fmt.sbprintf(&saveFileName.builder, fp.base(path))
					}
					break
				}
			}
		}
		if clay.UI()(
		{
			id = clay.ID("FileListFooter"),
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
				padding = clay.PaddingAll(8),
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Left, y = .Center},
				childGap = 8,
			},
		},
		) {
			clay.Text("File name:", &text_default)
			InputField("SaveFileName", &saveFileName, 20, sizingElem)
			if Button(
				"SaveButton",
				"Save",
				{width = clay.SizingPercent(.1), height = clay.SizingFixed(40)},
			) {
				save_cbk()
				dialogVisible = nil
				mouse_state = mouse_state_idle_info
			}
		}
	}
	return clay.EndLayout()
}

file_list_item :: proc(filepath: string, col: clay.Color) -> (path: string, clicked: bool) {
	abspath := filepath
	id := clay.ID(abspath)
	is_dir := os.is_dir(abspath)
	col := COLOR_BUTTON if clay.PointerOver(id) else col
	if clay.UI()(
	{
		id = id,
		layout = {
			padding = clay.PaddingAll(8),
			layoutDirection = .LeftToRight,
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(40)},
			childAlignment = {x = .Left, y = .Center},
			childGap = 8,
		},
		backgroundColor = col,
	},
	) {
		if clay.UI()(
		{
			layout = {sizing = {clay.SizingFixed(32), clay.SizingFixed(32)}},
			image = {&icons[.Directory if is_dir else .File]},
		},
		) {}
		clay.TextDynamic(
			fp.base(filepath),
			clay.TextConfig(
				{textColor = COLOR_WHITE, fontId = 0, fontSize = 18, textAlignment = .Left},
			),
		)
	}

	clicked = clay.PointerOver(id) && rl.IsMouseButtonPressed(.LEFT)
	path = abspath if clicked else ""
	return
}

deleted_idx := -1
select_texture_dialog :: proc() -> Layout {
	if rl.IsKeyPressed(.ESCAPE) {
		mouse_state = mouse_state_idle
		dialogVisible = nil
	}
	clay.BeginLayout()
	if clay.UI()(
	{
		id = clay.ID("TextureSelectorBase"),
		backgroundColor = COLOR_BG,
		layout = {
			padding = clay.PaddingAll(8),
			sizing = sizingExpand,
			layoutDirection = .TopToBottom,
			childGap = 4,
		},
	},
	) {
		if clay.UI()(
		{
			id = clay.ID("TextureSelectorHeader"),
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingFit({})},
				layoutDirection = .LeftToRight,
				childGap = 16,
				childAlignment = {x = .Left, y = .Center},
			},
		},
		) {
			clay.Text(
				"Select texture",
				clay.TextConfig({fontId = 0, textColor = COLOR_WHITE, fontSize = 48}),
			)
			if ImageButton(
				"AddTexture",
				&icons[.Plus],
				{width = clay.SizingFixed(50), height = clay.SizingGrow({})},
			) {
				dialogVisible = file_dialog
				files.dirty = true
				extensions = extensions_texture
				load_cbk = texture_loaded
			}
		}
		if clay.UI()(
		{layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(16)}}},
		) {}
		if clay.UI()(
		{
			id = clay.ID("TextureSelectorScroll"),
			clip = {vertical = true, childOffset = clay.GetScrollOffset()},
			layout = {
				layoutDirection = .TopToBottom,
				sizing = sizingExpand,
				padding = clay.PaddingAll(8),
				childGap = 8,
			},
		},
		) {
			out_ref: ^track.TextureReference
			clicked: bool
			out_ref, clicked = select_texture_item(nil, COLOR_BG_2)
			if clicked {
				track.modelReferences[selectedModelReferenceIdx].textureIdx[editedMaterialIndex] =
					out_ref
				dialogVisible = nil
				mouse_state = mouse_state_ui

			} else {
				for &ref in track.textureReferences {
					if out_ref, clicked = select_texture_item(&ref, COLOR_BG_2); clicked {
						track.modelReferences[selectedModelReferenceIdx].textureIdx[editedMaterialIndex] =
							out_ref
						dialogVisible = nil
						mouse_state = mouse_state_ui
						break
					}
				}
			}
		}
	}
	if deleted_idx > -1 {
		track.delete_texture_reference(deleted_idx)
		deleted_idx = -1
	}
	return clay.EndLayout()
}

select_texture_item :: proc(
	ref: ^track.TextureReference,
	col: clay.Color,
) -> (
	out_ref: ^track.TextureReference,
	clicked: bool,
) {
	_id := ref.path if ref != nil else "NoTexture"
	id := clay.ID(_id)
	out_ref = ref
	del_clicked: bool = false
	col := COLOR_BUTTON if clay.PointerOver(id) else col
	if clay.UI()(
	{
		id = id,
		layout = {
			padding = clay.PaddingAll(8),
			layoutDirection = .LeftToRight,
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(70)},
			childAlignment = {x = .Left, y = .Center},
			childGap = 8,
		},
		backgroundColor = col,
	},
	) {
		if clay.UI()(
		{
			layout = {sizing = {clay.SizingFixed(64), clay.SizingFixed(64)}},
			image = {&ref.texture if ref != nil else nil},
			aspectRatio = {1},
		},
		) {}
		clay.TextDynamic(
			ref.path if ref != nil else "No texture",
			clay.TextConfig(
				{textColor = COLOR_WHITE, fontId = 0, fontSize = 18, textAlignment = .Left},
			),
		)
		if clay.UI()({layout = {sizing = sizingExpand}}) {}
		if ImageButton(
			st.join({_id, "_delete"}, "", context.temp_allocator),
			&icons[.Minus],
			{clay.SizingFixed(64), clay.SizingFixed(64)},
		) {
			for &tr, i in track.textureReferences {
				if &tr == ref {
					deleted_idx = i
					del_clicked = true
					break
				}
			}
		}
	}

	clicked = clay.PointerOver(id) && rl.IsMouseButtonPressed(.LEFT) && !del_clicked
	return
}
