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
save_cbk: proc()

extensions_model := []string{".obj"}
extensions_level := []string{".klv"}

extensions: []string

FileList :: struct {
	files: st.Builder,
	dirty: bool,
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
				&home,
				{width = clay.SizingFixed(50), height = clay.SizingGrow({})},
			) {

				newPath, _ = os.get_executable_directory(context.allocator)
				input_field_text(&currentPath, newPath)
				delete(newPath)
				files.dirty = true
			}
			if ImageButton(
				"btnFileListUp",
				&up,
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
						if fp.ext(path) == ".klv" {
							st.builder_reset(&saveFileName.builder)
							fmt.sbprint(&saveFileName.builder, fp.base(path))
							load()
						} else if ref := track.try_load_file(path); ref != nil {
							append(&track.references, ref)
						}
						dialogVisible = nil
						mouse_state = mouse_state_idle
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
				&home,
				{width = clay.SizingFixed(50), height = clay.SizingGrow({})},
			) {

				newPath, _ = os.get_executable_directory(context.allocator)
				input_field_text(&currentPath, newPath)
				delete(newPath)
				files.dirty = true
			}
			if ImageButton(
				"btnFileListUp",
				&up,
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
			image = {(&dir if is_dir else &file)},
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
