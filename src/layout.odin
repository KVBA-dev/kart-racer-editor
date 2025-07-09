package main

import "clay"
import "core:c/libc"
import "core:fmt"
import "core:math"
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
COLOR_BUTTON_ACTIVE :: clay.Color{6, 184, 0, 255}
COLOR_BUTTON_ACTIVE_SELECTED :: clay.Color{35, 204, 0, 255}
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
sizingFitHori := clay.Sizing {
	width  = clay.SizingFit({}),
	height = clay.SizingGrow({}),
}

sizingTopbarButton := clay.Sizing {
	width  = clay.SizingFixed(34),
	height = clay.SizingGrow({}),
}

tab_layout := clay.LayoutConfig {
	sizing          = sizingExpand,
	childGap        = 8,
	layoutDirection = .TopToBottom,
}

horizontal_container := clay.ElementDeclaration {
	layout = {
		sizing = sizingFitVert,
		childAlignment = {x = .Center, y = .Center},
		layoutDirection = .LeftToRight,
		childGap = 8,
	},
}

horizontal_container_fit := clay.ElementDeclaration {
	layout = {
		sizing = sizingFitHori,
		childAlignment = {x = .Center, y = .Center},
		layoutDirection = .LeftToRight,
		childGap = 8,
	},
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

current_tab: proc() = track_tab

selectedInputField: ^InputFieldData = nil
selectedModelReferenceIdx: int = -1
editedMaterialIndex: int

strBuf: StringBuffer

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
		clay.TextDynamic(caption, &text_default)
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

ValueButton :: proc(id, caption: string, var: ^$T, value: T, sizing := sizingExpand) -> bool {
	col: clay.Color
	if var^ == value {
		col =
			COLOR_BUTTON_ACTIVE_SELECTED if clay.PointerOver(clay.ID(id)) else COLOR_BUTTON_ACTIVE
	} else {
		col = COLOR_BUTTON_SELECTED if clay.PointerOver(clay.ID(id)) else COLOR_BUTTON
	}
	if clay.UI()(
	{
		id = clay.ID(id),
		layout = {
			sizing = sizing,
			padding = clay.PaddingAll(8),
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = col,
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		clay.TextDynamic(caption, &text_default)
	}
	return clay.PointerOver(clay.ID(id)) && rl.IsMouseButtonPressed(.LEFT)
}
selectorButtonSizing := clay.Sizing {
	width  = clay.SizingPercent(0.05),
	height = clay.SizingGrow({}),
}

EnumSelector :: proc(id: string, val: $E/^$T, max_val: T, nameproc: proc(_: T) -> string) {
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
		append_string_buffer(&strBuf, fmt.tprintf("%s_prev", id))
		if Button(strBuf.current_substring, "<", selectorButtonSizing) {
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
		append_string_buffer(&strBuf, fmt.tprintf("%s_next", id))
		if Button(strBuf.current_substring, ">", selectorButtonSizing) {
			if val^ == max_val {
				val^ = cast(T)0
			} else {
				val^ += cast(T)1
			}
		}
	}
}

NumberSelector :: proc(id: string, val: ^int, max_val: int) {
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
		append_string_buffer(&strBuf, fmt.tprintf("%s_prev", id))
		if Button(strBuf.current_substring, "<", selectorButtonSizing) {
			if val^ == 0 {
				val^ = max_val
			} else {
				val^ -= 1
			}
		}
		if clay.UI()(
		{layout = {sizing = sizingExpand, childAlignment = {x = .Center, y = .Center}}},
		) {
			append_string_buffer(&strBuf, fmt.tprintf("%d", val^))

			clay.TextDynamic(
				strBuf.current_substring,
				clay.TextConfig(
					{fontId = 0, fontSize = 20, textColor = COLOR_WHITE, textAlignment = .Center},
				),
			)
		}
		append_string_buffer(&strBuf, fmt.tprintf("%s_next", id))
		if Button(strBuf.current_substring, ">", selectorButtonSizing) {
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

HorizontalSeparator :: proc(size: clay.SizingAxis) {
	if clay.UI()({layout = {sizing = {width = size, height = clay.SizingGrow({})}}}) {}
}

FloatFieldBounds :: struct {
	min, max: f32,
}

FF_NO_BOUNDS := FloatFieldBounds {
	min = -math.F32_MAX,
	max = math.F32_MAX,
}

FF_ABOVE_ZERO := FloatFieldBounds {
	min = 0,
	max = math.F32_MAX,
}

editedFloatField: struct {
	bounds: FloatFieldBounds,
	val:    ^f32,
	delta:  f32,
} = {}

FloatField :: proc(
	id: string,
	val: ^f32,
	bounds: ^FloatFieldBounds = nil,
	delta: f32 = 0.1,
	sizing := sizingElem,
	format := "%.3f",
) {

	bounds := bounds
	if bounds == nil {
		bounds = &FF_NO_BOUNDS
	}
	if clay.UI()(
	{
		id = clay.ID(id),
		layout = {sizing = sizing, childAlignment = {x = .Center, y = .Center}},
		backgroundColor = COLOR_BG_2,
		cornerRadius = clay.CornerRadiusAll(4),
	},
	) {
		if format == FORMAT_WHOLE {
			append_string_buffer(&strBuf, fmt.tprintf(format, math.floor(val^)))
		} else {
			append_string_buffer(&strBuf, fmt.tprintf(format, val^))
		}
		clay.TextDynamic(strBuf.current_substring, &text_default)
	}
	if clay.PointerOver(clay.ID(id)) && rl.IsMouseButtonPressed(.LEFT) {
		mouse_state = mouse_state_edit_float_field
		editedFloatField.bounds = bounds^
		editedFloatField.val = val
		editedFloatField.delta = delta
	}
}

base_layout :: proc() -> Layout {
	reset_string_buffer(&strBuf)
	clay.BeginLayout()
	if clay.UI()(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingPercent(0.78), height = clay.SizingGrow({})},
		},
	},
	) {
		if clay.UI()(
		{
			id = clay.ID("Topbar"),
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(50)},
				padding = clay.PaddingAll(8),
				childGap = 8,
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = COLOR_BG,
		},
		) {
			if ImageButton("TopbarNew", &icons[.File], sizingTopbarButton) {
				track.clear_references()
				clear(&objects)
				append(&objects, finish_line)
				destroy_path(editedPath)
				editedPath = make_path({})
				set_closed(editedPath, true)
			}
			if ImageButton("TopbarOpen", &icons[.Directory], sizingTopbarButton) {
				extensions = extensions_level
				dialogVisible = file_dialog
				files.dirty = true
			}
			if ImageButton("TopbarSave", &icons[.Save], sizingTopbarButton) {
				extensions = extensions_level
				dialogVisible = save_file_dialog
				save_cbk = save
				files.dirty = true
			}
			HorizontalSeparator(clay.SizingGrow({}))
			clay.Text("Gizmo", &text_default)
			if ValueButton(
				"TopbarTranslate",
				"T",
				&gizmoMode,
				GizmoMode.Translate,
				sizingTopbarButton,
			) {
				gizmoMode = .Translate
			}
			if ValueButton("TopbarRotate", "R", &gizmoMode, GizmoMode.Rotate, sizingTopbarButton) {
				gizmoMode = .Rotate
			}
			if ValueButton("TopbarScale", "S", &gizmoMode, GizmoMode.Scale, sizingTopbarButton) {
				gizmoMode = .Scale
			}
			HorizontalSeparator(clay.SizingFixed(8))
			if ValueButton(
				"TopbarGlobal",
				"G",
				&viewSetting,
				ViewSetting.Global,
				sizingTopbarButton,
			) {
				viewSetting = .Global
			}
			if ValueButton(
				"TopbarLocal",
				"L",
				&viewSetting,
				ViewSetting.Local,
				sizingTopbarButton,
			) {
				viewSetting = .Local
			}
			if ValueButton("TopbarView", "V", &viewSetting, ViewSetting.View, sizingTopbarButton) {
				viewSetting = .View
			}
		}
		if clay.UI()(
		{
			id = clay.ID("Viewport"),
			layout = {sizing = sizingExpand},
			backgroundColor = COLOR_CLEAR,
		},
		) {}
	}
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
			if Button("btnTabObjects", "Objects") {
				current_tab = object_tab
				selectedObject = nil
				mouse_state_idle = mouse_state_idle_object
				render_scene = render_object_mode
			}
			if Button("btnTabPath", "Path") {
				current_tab = path_tab
				mouse_state_idle = mouse_state_idle_path
				nearestSegmentIndex = -1
				editedPointIndex = -1
				render_scene = render_path_mode
			}
			if Button("btnTabMaterials", "Materials") {
				current_tab = materials_tab
				mouse_state_idle = mouse_state_idle_material
				selectedModelReferenceIdx = -1
				editedMaterialIndex = 0
				render_scene = render_material_mode
			}
			if Button("btnTabInfo", "Info") {
				current_tab = info_tab
				mouse_state_idle = mouse_state_idle_info
				render_scene = render_info_mode
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


track_tab :: proc() {
	if clay.UI()({id = clay.ID("TrackContainer"), layout = tab_layout}) {
		clay.Text("Track", &text_header)
		if Button("TrackAddModel", "Add model", sizingElem) {
			extensions = extensions_model
			dialogVisible = file_dialog
			load_cbk = model_loaded
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
			)
			if Button("TrackDeleteReference", "Delete model", sizingElem) {
				if selectedModelReferenceIdx >= 0 {
					track.delete_model_reference(selectedModelReferenceIdx)
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
		if Button("AddObject", "Add object", sizingElem) {
			// TODO: add different types of objects
			append(&objects, create_item_box_row())
			selectedObject = &objects[len(objects) - 1]
		}
		VerticalSeparator(clay.SizingFixed(8))
		if selectedObject == nil {
			clay.Text("Select an object to edit its properties", &text_default)
		} else {
			switch &o in selectedObject^ {
			case track.FinishLine:
				finish_line_editor(&o)
			case track.ItemBoxRow:
				item_box_row_editor(&o)
			case:
			}
		}
	}
}

finish_line_editor :: proc(fl: ^track.FinishLine) {
	if clay.UI()(horizontal_container) {
		clay.Text("Spread X", &text_default)
		HorizontalSeparator(clay.SizingGrow({}))
		FloatField("FinishLineSpreadXField", &fl.spreadX, &FF_ABOVE_ZERO, 0.05)
	}
	if clay.UI()(horizontal_container) {
		clay.Text("Spread Z", &text_default)
		HorizontalSeparator(clay.SizingGrow({}))
		FloatField("FinishLineSpreadZField", &fl.spreadZ, &FF_ABOVE_ZERO, 0.05)
	}
}

item_box_row_count := FloatFieldBounds {
	min = 1,
	max = 12,
}

FORMAT_WHOLE :: "%.0f"

item_box_row_editor :: proc(ibr: ^track.ItemBoxRow) {
	if clay.UI()(horizontal_container) {
		clay.Text("Count", &text_default)
		HorizontalSeparator(clay.SizingGrow({}))
		FloatField(
			"ItemBoxRowCountField",
			&ibr.count,
			&item_box_row_count,
			.1,
			format = FORMAT_WHOLE,
		)
	}
	if clay.UI()(horizontal_container) {
		clay.Text("Spread", &text_default)
		HorizontalSeparator(clay.SizingGrow({}))
		FloatField("ItemBoxRowSpreadField", &ibr.spread, &FF_ABOVE_ZERO, 0.05)
	}
	if clay.UI()(horizontal_container) {
		if Button("CloneItemBoxRow", "Clone") {
			append(&objects, ibr^)
			selectedObject = &objects[len(objects) - 1]
		}
		if Button("DeleteItemBoxRow", "Delete") {
			for &o, i in objects {
				if &o == cast(^track.TrackObject)ibr {
					unordered_remove(&objects, i)
					selectedObject = nil
					break
				}
			}
		}
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
			ref := &(track.modelReferences[selectedModelReferenceIdx])
			clay.Text("Material index", &text_default)
			NumberSelector(
				"MaterialIndexSelector",
				&editedMaterialIndex,
				len(track.modelReferences[selectedModelReferenceIdx].materials) - 1,
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
				// TODO: colour picker
				if clay.UI()(
				{layout = {sizing = sizingElem, childAlignment = {x = .Left, y = .Center}}},
				) {
					clay.Text("Texture", &text_default)
					if clay.UI()({layout = {sizing = sizingExpand}}) {}
					img := &ref.textureIdx[editedMaterialIndex].texture
					if img == nil do img = &icons[.Plus]
					if clay.UI()(
					{
						id = clay.ID("MaterialTexturePicker"),
						layout = {
							sizing = {width = clay.SizingFixed(40), height = clay.SizingGrow({})},
						},
						image = {img},
						aspectRatio = {1},
					},
					) {}
					if clay.PointerOver(clay.ID("MaterialTexturePicker")) &&
					   rl.IsMouseButtonPressed(.LEFT) {
						dialogVisible = select_texture_dialog
						mouse_state = mouse_state_disabled
					}
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
				clear(&objects)
				append(&objects, finish_line)
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
