package main

import "clay"
import "core:c/libc"
import "core:fmt"
import sv "core:strconv"
import st "core:strings"
import "core:unicode/utf8"
import "track"
import rl "vendor:raylib"

Layout :: #type clay.ClayArray(clay.RenderCommand)

COLOR_CLEAR :: clay.Color{255, 255, 255, 0}
COLOR_BG :: clay.Color{43, 43, 43, 255}
COLOR_BG_2 :: clay.Color{50, 50, 50, 255}
COLOR_BUTTON :: clay.Color{85, 85, 85, 255}
COLOR_BUTTON_SELECTED :: clay.Color{106, 106, 106, 255}
COLOR_WHITE :: clay.Color{240, 240, 240, 255}

sizingExpand := clay.Sizing {
	width  = clay.SizingGrow({}),
	height = clay.SizingGrow({}),
}

sizingElem := clay.Sizing {
	width  = clay.SizingGrow({}),
	height = clay.SizingFixed(40),
}

sizingFitVert := clay.Sizing {
	width  = clay.SizingGrow({}),
	height = clay.SizingFit({}),
}

current_tab: proc() = track_tab

selectedInputField: ^InputFieldData = nil
selectorBuilder: st.Builder
selectedModelReferenceIdx: int = -1
editedMaterialIndex: int

InputFieldData :: struct {
	builder: st.Builder,
	endEdit: proc(),
	maxLen:  int,
}

init_input_field :: proc(capacity: int = 1024) -> InputFieldData {
	data := InputFieldData{}
	st.builder_init_len_cap(&data.builder, 0, capacity)
	return data
}

destroy_input_field :: proc(input: ^InputFieldData) {
	st.builder_destroy(&input.builder)
}

edit_input_field :: proc(input: ^InputFieldData) {
	if input == nil do return
	if rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressedRepeat(.BACKSPACE) {
		if len(input.builder.buf) > 0 do pop(&input.builder.buf)
		return
	}
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.ENTER) {
		input.endEdit()
		selectedInputField = nil
		return
	}
	key := rl.GetCharPressed()
	switch key {
	case 0:
		return
	case:
		fmt.println(key)
		fmt.sbprint(&input.builder, key)
	}
}

set_input_field_text :: proc(input: ^InputFieldData, text: string) {
	st.builder_reset(&input.builder)
	fmt.sbprint(&input.builder, text)
}

get_input_field_text :: proc(input: ^InputFieldData) -> string {
	return st.to_string(input.builder)
}

input_field_text :: proc {
	set_input_field_text,
	get_input_field_text,
}

InputField :: proc(id: string, data: ^InputFieldData, text_size: u16, sizing := sizingExpand) {
	if clay.UI()(
	{
		id = clay.ID(id),
		layout = {
			padding = clay.PaddingAll(8),
			sizing = sizing,
			layoutDirection = .LeftToRight,
			childAlignment = {x = .Left, y = .Center},
		},
		backgroundColor = COLOR_BUTTON if data == selectedInputField else COLOR_BG_2,
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		clay.TextDynamic(
			input_field_text(data),
			clay.TextConfig({fontSize = text_size, fontId = 0, textColor = COLOR_WHITE}),
		)
	}
	if rl.IsMouseButtonPressed(.LEFT) {
		if clay.PointerOver(clay.ID(id)) {
			selectedInputField = data
		} else if selectedInputField == data {
			selectedInputField = nil
		}
	}
}

Button :: proc(id, caption: string, sizing := sizingExpand) -> bool {
	if clay.UI()(
	{
		id = clay.ID(id),
		layout = {
			sizing = sizing,
			padding = clay.PaddingAll(8),
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = clay.PointerOver(clay.ID(id)) ? COLOR_BUTTON_SELECTED : COLOR_BUTTON,
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		clay.TextDynamic(
			caption,
			clay.TextConfig(
				{textColor = COLOR_WHITE, fontSize = 18, fontId = 0, textAlignment = .Left},
			),
		)
	}
	return clay.PointerOver(clay.ID(id)) && rl.IsMouseButtonPressed(.LEFT)
}

ImageButton :: proc(id: string, texture: ^rl.Texture, sizing := sizingExpand) -> bool {
	if clay.UI()(
	{
		id = clay.ID(id),
		layout = {
			sizing = sizing,
			padding = clay.PaddingAll(8),
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = clay.PointerOver(clay.ID(id)) ? COLOR_BUTTON_SELECTED : COLOR_BUTTON,
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		if clay.UI()({image = {texture}, layout = {sizing = sizingExpand}}) {}
	}
	return clay.PointerOver(clay.ID(id)) && rl.IsMouseButtonPressed(.LEFT)
}

selectorButtonSizing := clay.Sizing {
	width  = clay.SizingPercent(0.05),
	height = clay.SizingGrow({}),
}

init_selector_builder :: proc() {
	st.builder_init(&selectorBuilder)
}

destroy_selector_builder :: proc() {
	st.builder_destroy(&selectorBuilder)
}

EnumSelector :: proc(
	id: string,
	val: $E/^$T,
	max_val: T,
	nameproc: proc(_: T) -> string,
	builder: ^st.Builder,
) {
	if clay.UI()(
	{
		id = clay.ID(id),
		layout = {
			layoutDirection = .LeftToRight,
			sizing = sizingFitVert,
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = COLOR_BG_2,
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		st.builder_reset(builder)
		fmt.sbprintf(builder, "%s_prev", id)
		if Button(st.to_string(builder^), "<", selectorButtonSizing) {
			if val^ == cast(T)0 {
				val^ = max_val
			} else {
				val^ -= cast(T)1
			}
		}
		if clay.UI()(
		{layout = {sizing = sizingExpand, childAlignment = {x = .Center, y = .Center}}},
		) {
			clay.TextDynamic(
				nameproc(val^),
				clay.TextConfig(
					{fontId = 0, fontSize = 20, textColor = COLOR_WHITE, textAlignment = .Center},
				),
			)
		}
		st.builder_reset(builder)
		fmt.sbprintf(builder, "%s_next", id)
		if Button(st.to_string(builder^), ">", selectorButtonSizing) {
			if val^ == max_val {
				val^ = cast(T)0
			} else {
				val^ += cast(T)1
			}
		}
	}
}

NumberSelector :: proc(id: string, val: ^int, max_val: int, builder: ^st.Builder) {
	if clay.UI()(
	{
		id = clay.ID(id),
		layout = {
			layoutDirection = .LeftToRight,
			sizing = sizingFitVert,
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = COLOR_BG_2,
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		st.builder_reset(builder)
		fmt.sbprintf(builder, "%s_prev", id)
		if Button(st.to_string(builder^), "<", selectorButtonSizing) {
			if val^ == 0 {
				val^ = max_val
			} else {
				val^ -= 1
			}
		}
		if clay.UI()(
		{layout = {sizing = sizingExpand, childAlignment = {x = .Center, y = .Center}}},
		) {
			st.builder_reset(builder)
			st.write_int(builder, val^)

			clay.TextDynamic(
				st.clone(st.to_string(builder^), context.temp_allocator),
				clay.TextConfig(
					{fontId = 0, fontSize = 20, textColor = COLOR_WHITE, textAlignment = .Center},
				),
			)
		}
		st.builder_reset(builder)
		fmt.sbprintf(builder, "%s_next", id)
		if Button(st.to_string(builder^), ">", selectorButtonSizing) {
			if val^ == max_val {
				val^ = 0
			} else {
				val^ += 1
			}
		}
	}
}

VerticalSeparator :: proc(size: clay.SizingAxis) {
	if clay.UI()({layout = {sizing = {width = clay.SizingGrow({}), height = size}}}) {}
}

base_layout :: proc() -> Layout {
	clay.BeginLayout()
	if clay.UI()(
	{
		id = clay.ID("Viewport"),
		layout = {sizing = {width = clay.SizingPercent(0.78), height = clay.SizingGrow({})}},
		backgroundColor = COLOR_CLEAR,
	},
	) {}
	if clay.UI()(
	{
		id = clay.ID("Sidebar"),
		layout = {sizing = sizingExpand, layoutDirection = .TopToBottom},
		backgroundColor = COLOR_BG,
	},
	) {
		if clay.UI()(
		{
			id = clay.ID("TabButtons"),
			layout = {
				padding = clay.PaddingAll(8),
				childGap = 8,
				sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(50)},
			},
		},
		) {
			if Button("btnTabTrack", "Track") {
				current_tab = track_tab
				mouse_state_idle = mouse_state_idle_track
				render_scene = render_track_mode
			}
			if Button("btnTabStart", "Objects") {
				current_tab = object_tab
				render_scene = render_material_mode
			}
			if Button("btnTabPath", "Path") {
				current_tab = path_tab
				render_scene = render_material_mode
			}
			if Button("btnTabMaterials", "Materials") {
				current_tab = materials_tab
				mouse_state_idle = mouse_state_idle_material
				render_scene = render_material_mode
			}
			if Button("btnTabInfo", "Info") {
				current_tab = info_tab
				mouse_state_idle = mouse_state_idle_info
				render_scene = render_material_mode
			}
		}
		if clay.UI()(
		{
			id = clay.ID("TabContainer"),
			layout = {sizing = sizingExpand, padding = clay.PaddingAll(8)},
		},
		) {
			current_tab()
		}
	}
	return clay.EndLayout()
}

tab_layout := clay.LayoutConfig {
	sizing          = sizingExpand,
	childGap        = 8,
	layoutDirection = .TopToBottom,
}

text_header := clay.TextElementConfig {
	textColor     = COLOR_WHITE,
	fontSize      = 50,
	fontId        = 0,
	textAlignment = .Left,
}

text_default := clay.TextElementConfig {
	textColor     = COLOR_WHITE,
	fontSize      = 18,
	fontId        = 0,
	textAlignment = .Center,
}

track_tab :: proc() {
	if clay.UI()({id = clay.ID("TrackContainer"), layout = tab_layout}) {
		clay.Text("Track", &text_header)
		if Button("TrackAddModel", "Add model", sizingElem) {
			extensions = extensions_model
			dialogVisible = file_dialog
			files.dirty = true
		}
		VerticalSeparator(clay.SizingFixed(20))
		clay.Text("Minimap", &text_default)
		if clay.UI()(
		{
			id = clay.ID("TrackMinimapContainer"),
			layout = {
				sizing = sizingFitVert,
				padding = {60, 60, 0, 0},
				layoutDirection = .TopToBottom,
				childGap = 8,
			},
		},
		) {
			if clay.UI()(
			{
				id = clay.ID("TrackMinimapPreview"),
				layout = {sizing = sizingFitVert},
				image = {imageData = &minimapTexture},
				aspectRatio = {aspectRatio = 1},
			},
			) {}
			if Button("TrackSaveMinimap", "Save minimap", sizingElem) {
				dialogVisible = save_file_dialog
				extensions = extensions_texture
				files.dirty = true
				mouse_state = mouse_state_disabled
				save_cbk = save_minimap
			}
		}
		VerticalSeparator(clay.SizingFixed(20))
		if selectedMesh == nil {
			clay.Text("Select a mesh to edit its properties", &text_default)
		} else {
			clay.Text("Layer", &text_default)
			EnumSelector(
				"TrackMeshLayerSelector",
				selectedLayer,
				track.StaticLayer.Decor,
				track.get_layer_name,
				&selectorBuilder,
			)
			if Button("TrackDeleteReference", "Delete model", sizingElem) {
				if selectedModelReferenceIdx >= 0 {
					track.delete_reference(selectedModelReferenceIdx)
					selectedModelReferenceIdx = -1
					selectedLayer = nil
					selectedMesh = nil
				}
			}
		}
	}
}
object_tab :: proc() {
	if clay.UI()({id = clay.ID("ObjectContainer"), layout = tab_layout}) {
		clay.Text("Objects", &text_header)
	}
}
path_tab :: proc() {
	if clay.UI()({id = clay.ID("PathContainer"), layout = tab_layout}) {
		clay.Text("Path", &text_header)
	}
}
materials_tab :: proc() {
	if clay.UI()({id = clay.ID("MaterialsContainer"), layout = tab_layout}) {
		clay.Text("Materials", &text_header)
		if selectedModelReferenceIdx == -1 {
			clay.Text("Select a model to edit materials", &text_default)
		} else {
			ref := &(track.references[selectedModelReferenceIdx].(track.ModelReference))
			clay.Text("Material index", &text_default)
			NumberSelector(
				"MaterialIndexSelector",
				&editedMaterialIndex,
				len(track.references[selectedModelReferenceIdx].(track.ModelReference).materials) -
				1,
				&selectorBuilder,
			)
			if clay.UI()(
			{
				layout = {
					sizing = sizingFitVert,
					layoutDirection = .TopToBottom,
					childGap = 8,
					padding = clay.PaddingAll(8),
				},
				backgroundColor = COLOR_BG_2,
			},
			) {
				if clay.UI()(
				{layout = {sizing = sizingElem, childAlignment = {x = .Left, y = .Center}}},
				) {
					clay.Text("Texture", &text_default)
					if clay.UI()({layout = {sizing = sizingExpand}}) {}
					if clay.UI()(
					{
						id = clay.ID("MaterialTexturePicker"),
						layout = {},
						image = {&ref.textureIdx[editedMaterialIndex].texture},
						aspectRatio = {1},
					},
					) {}
				}
			}
		}
	}
}
info_tab :: proc() {
	if clay.UI()({id = clay.ID("InfoContainer"), layout = tab_layout}) {
		clay.Text("Info", &text_header)
		if clay.UI()(
		{layout = {layoutDirection = .LeftToRight, childGap = 8, sizing = sizingElem}},
		) {
			if Button("btnInfoNew", "New") {
				track.clear_references()
			}
			if Button("btnInfoOpen", "Open") {
				extensions = extensions_level
				dialogVisible = file_dialog
				files.dirty = true
			}
			if Button("btnInfoSave", "Save") {
				extensions = extensions_level
				dialogVisible = save_file_dialog
				save_cbk = save
				files.dirty = true
			}
		}
	}
}
