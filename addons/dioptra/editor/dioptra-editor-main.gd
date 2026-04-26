@tool
extends EditorPlugin
class_name DioptraEditorMainPlugin

#------------------------------------------------------------------------------#

enum ToolMode {
	SELECT = 0,
	BOX_TEST = 1,
	DECAL = 2,
}

enum SelectMode {
	SOLID = 0,
	FACE = 1,
	EDGE = 2,
	VERTEX = 3,
}

enum UVModePer {
	FACE = 0,
	ISLAND = 1,
	GROUP = 2,
}

#------------------------------------------------------------------------------#

const cDPG_PathNode := preload("res://addons/dioptra/editor/gizmos/DPG_PathNode.gd");
var DPGizmoPlugin_PathNode : EditorNode3DGizmoPlugin = null;

#const cDPG_ToolCube := preload("res://addons/dioptra/editor/gizmos/DPG_ToolCube.gd");
#var DPGizmoPlugin_ToolCube : EditorNode3DGizmoPlugin = null;

const cDPG_FaceHover := preload("res://addons/dioptra/editor/gizmos/DPG_FaceHover.gd");
var DPGizmoPlugin_FaceHover : EditorNode3DGizmoPlugin = null;

const cDPG_MapGlobalEditor := preload("res://addons/dioptra/editor/gizmos/DPG_MapGlobalEditor.gd");
var DPGizmoPlugin_MapGlobalEditor : EditorNode3DGizmoPlugin = null;

const cDock_Tools := preload("res://addons/dioptra/editor/panel-tools.tscn");
var DPDock_Tools : Control = null;
const cScript_Tools := preload("res://addons/dioptra/editor/DP_PanelTools.gd");

const cDock_Texturing := preload("res://addons/dioptra/editor/panel-texturing.tscn");
var DPDock_Texturing : Control = null;
const cScript_Texturing := preload("res://addons/dioptra/editor/DP_PanelTexture.gd");

const cDock_State := preload("res://addons/dioptra/editor/panel-state.tscn");
var DPDock_State : Control = null;
const cScript_State := preload("res://addons/dioptra/editor/DP_PanelState.gd");

const cDock_MaterialBrowser := preload("res://addons/dioptra/editor/panel-material-browser.tscn");
var DPDock_MaterialBrowser : Control = null;
const cScript_MaterialBrowser := preload("res://addons/dioptra/editor/DP_PanelMaterialBrowser.gd");

const cDP_MaterialPreviewGenerator := preload("res://addons/dioptra/editor/DP_MaterialPreviewGenerator.gd");
var DP_Genny_MaterialPreview : EditorResourcePreviewGenerator = null;

#------------------------------------------------------------------------------#

## Starts the given gizmo plugin, instantiating it if it's not read with the given factor
func start_gizmo_plugin(item : EditorNode3DGizmoPlugin, factory : Callable) -> EditorNode3DGizmoPlugin:
	if item == null:
		item = factory.call();
	if item:
		add_node_3d_gizmo_plugin(item);
	return item;
	
## Stops the given gizmo plugin if it's valid
func stop_gizmo_plugin(item : EditorNode3DGizmoPlugin) -> void:
	if item:
		remove_node_3d_gizmo_plugin(item);
	pass

func _enter_tree() -> void:
	DPGizmoPlugin_PathNode = start_gizmo_plugin(DPGizmoPlugin_PathNode, func(): return cDPG_PathNode.new(get_undo_redo()) );
	#DPGizmoPlugin_ToolCube = start_gizmo_plugin(DPGizmoPlugin_ToolCube, func(): return cDPG_ToolCube.new(get_undo_redo()) );
	DPGizmoPlugin_FaceHover = start_gizmo_plugin(DPGizmoPlugin_FaceHover, func(): return cDPG_FaceHover.new(self) );
	DPGizmoPlugin_MapGlobalEditor = start_gizmo_plugin(DPGizmoPlugin_MapGlobalEditor, func(): return cDPG_MapGlobalEditor.new(self, get_undo_redo()) );
	
	if DPDock_Tools == null:
		DPDock_Tools = cDock_Tools.instantiate()
	if DPDock_Tools:
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, DPDock_Tools);
		var tools := DPDock_Tools as cScript_Tools;
		tools.setPlugin(self);
		
	if DPDock_State == null:
		DPDock_State = cDock_State.instantiate()
	if DPDock_State:
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, DPDock_State);
		var state := DPDock_State as cScript_State;
		state.setPlugin(self);
		
	if DPDock_Texturing == null:
		DPDock_Texturing = cDock_Texturing.instantiate()
	if DPDock_Texturing:
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, DPDock_Texturing);
		var textures := DPDock_Texturing as cScript_Texturing;
		textures.setPlugin(self);
		
	if DPDock_MaterialBrowser == null:
		DPDock_MaterialBrowser = cDock_MaterialBrowser.instantiate()
	if DPDock_MaterialBrowser:
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BR, DPDock_MaterialBrowser);
		var matbrowser := DPDock_MaterialBrowser as cScript_MaterialBrowser;
		matbrowser.setPlugin(self);
		
	#if DP_Genny_MaterialPreview == null:
		#DP_Genny_MaterialPreview = cDP_MaterialPreviewGenerator.new(self);
	#if DP_Genny_MaterialPreview:
		#EditorInterface.get_resource_previewer().add_preview_generator(DP_Genny_MaterialPreview);
	# Since this is the way that materials are already rendered, we can't simply add something to override it w/o going into source.
	# Better off making a material browser
		
	EditorInterface.get_resource_previewer().preview_invalidated.connect(on_resource_preview_invalidated);
		
	pass

func _exit_tree() -> void:
	stop_gizmo_plugin(DPGizmoPlugin_PathNode);
	DPGizmoPlugin_PathNode = null;
	#stop_gizmo_plugin(DPGizmoPlugin_ToolCube);
	#DPGizmoPlugin_ToolCube = null;
	stop_gizmo_plugin(DPGizmoPlugin_FaceHover);
	DPGizmoPlugin_FaceHover = null;
	stop_gizmo_plugin(DPGizmoPlugin_MapGlobalEditor);
	DPGizmoPlugin_MapGlobalEditor = null;
	
	if DPDock_Tools:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, DPDock_Tools);
		DPDock_Tools.queue_free()
	if DPDock_State:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, DPDock_State);
		DPDock_State.queue_free()
	if DPDock_Texturing:
		remove_control_from_docks(DPDock_Texturing);
		DPDock_Texturing.queue_free()
	if DPDock_MaterialBrowser:
		remove_control_from_docks(DPDock_MaterialBrowser);
		DPDock_MaterialBrowser.queue_free()
		
	if DP_Genny_MaterialPreview:
		EditorInterface.get_resource_previewer().remove_preview_generator(DP_Genny_MaterialPreview);
		DP_Genny_MaterialPreview = null;
	pass

#------------------------------------------------------------------------------#

var _editorNode : EditorDP_InternalTool = null;
var _currentTool : DPUTool = null;

var _last_edited_map : DP_Map = null;
var _last_material : Material = null;

var _plugin_maphelper : DioptraEditorMaphelperPlugin = null;

var _selectionMode : SelectMode = SelectMode.SOLID; # todo
var _uvModePer : UVModePer = UVModePer.FACE;

var _last_2d_mouse_position : Vector2;
var _last_3d_mouse_position : Vector3;

#------------------------------------------------------------------------------#

func get_selection_mode() -> SelectMode:
	return _selectionMode;

#------------------------------------------------------------------------------#

func onToolSelect(tool : ToolMode) -> void:
	# We want to make a EditorDP_InternalTool node.
	if _editorNode == null:
		# Create the new node
		_editorNode = EditorDP_InternalTool.new();
		# We need this node in the scene so it can update the sizes of items
		EditorInterface.get_edited_scene_root().add_child(_editorNode, false, Node.INTERNAL_MODE_FRONT);
	
	# Switch to the editor mode
	EditorInterface.get_selection().clear();
	if tool != ToolMode.SELECT:
		_editorNode.basis = Basis.IDENTITY;
		_editorNode.global_position = Vector3.ZERO;
		EditorInterface.get_selection().add_node(_editorNode);
	else:
		_editorNode.queue_free();
	
	var newTool : DPUTool = null;
	# Select the type of tool:
	if tool == ToolMode.SELECT:
		if _currentTool != null:
			_currentTool.cleanup();
		_currentTool = null;
	elif tool == ToolMode.BOX_TEST:
		if not (_currentTool is DPUTool_BoxTest):
			newTool = DPUTool_BoxTest.new(self);
	elif tool == ToolMode.DECAL:
		if not (_currentTool is DPUTool_Decal):
			newTool = DPUTool_Decal.new(self);
			
	# Switch to the new tool after cleaning up
	if newTool != null:
		if _currentTool != null:
			_currentTool.cleanup();
		_currentTool = newTool;
	
	# Tools will be automatically cleared as they are RefCounted.
	
	pass

## Returns editor node, mostly for updating gizmos
#func get_editor_node() -> EditorDP_InternalTool:
	#return _editorNode;

#------------------------------------------------------------------------------#

# Handle the DP_InternalTool, which lets us actually perform work with the editor
func _handles(object: Object) -> bool:
	if object is EditorDP_InternalTool:
		return true;
	return false;
	
func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	# Forward the input to the tool
	var input_action : EditorPlugin.AfterGUIInput = EditorPlugin.AFTER_GUI_INPUT_PASS;
	if _currentTool != null:
		input_action = _currentTool.forward_3d_gui_input(viewport_camera, event);
		
	# Update mouse position
	if input_action == EditorPlugin.AFTER_GUI_INPUT_PASS:
		if event is InputEventMouseMotion:
			_last_2d_mouse_position = event.position;
			
			# Raycast and update:
			var map := get_last_edited_map();
			var subgizmo_id := DPEditorSelection.subgizmo_intersect_ray(map, viewport_camera, event.position, DioptraEditorMainPlugin.SelectMode.FACE);
			var selection_type := DPHelpers.get_selection_type(map, subgizmo_id);
			var selection := DPHelpers.get_selection(map, subgizmo_id);
			if selection_type == DPHelpers.SelectionType.FACE or selection_type == DPHelpers.SelectionType.SOLID:
				var solid := selection.solid;
				var face := selection.face;
				var normal : Vector3 = -(solid.points[face.corners[1]].v3 - solid.points[face.corners[0]].v3).cross(
					solid.points[face.corners[2]].v3 - solid.points[face.corners[0]].v3).normalized();
					
				var collision_plane := Plane(normal, solid.points[face.corners[0]].v3);
				var collision := collision_plane.intersects_ray(viewport_camera.project_ray_origin(event.position), viewport_camera.project_ray_normal(event.position));
				if collision != null:
					var collision_point := collision as Vector3;
					_last_3d_mouse_position = collision_point;
					
			pass # End InputEventMouseMotion
		pass # End input pass
		
	return input_action;
	
func _edit(object: Object) -> void:
	if object is DP_Map:
		_last_edited_map = object as DP_Map;
	
#------------------------------------------------------------------------------#

func _get_current_map() -> DP_Map:
	if _last_edited_map != null:
		return _last_edited_map;
	
	var editor_selection := EditorInterface.get_selection();
	for item in editor_selection.get_selected_nodes():
		if item is DP_Map:
			return item as DP_Map;
			
	var root := EditorInterface.get_edited_scene_root();
	for node in root.get_children():
		if node is DP_Map:
			return node;
	
	return null;
	
## Returns the last edited map, or the first one found in the scene if not
func get_last_edited_map() -> DP_Map:
	if _last_edited_map == null:
		_last_edited_map = _get_current_map();
	return _last_edited_map;
	
## Adds a new solid to the last edited map, or first map found.
func add_new_solid(solid : DPMapSolid) -> void:
	var map := _get_current_map();
	_last_edited_map = map;
	if map == null:
		push_warning("Tried to edit a map with no existing DP_Map instance in the scene.");
		# Create new map
		if DioptraInterface.FutureSettingTrue:
			push_warning("Creating DP_Map instance.");
			map = DP_Map.new();
			EditorInterface.get_edited_scene_root().add_child(map);
			map.set_owner(EditorInterface.get_edited_scene_root());
			_last_edited_map = map;
		else:
			push_warning("Create a DP_Map instance in order to edit a map.");
			return;
		pass
	
	# Add it to the map. Map will handle partitioning
	map.editor_add_solid(solid);
	
	# Request a map rebuild
	map.rebuild_editor_map(solid);
	
	pass
	
## Adds a new decal to the last edited map, or first map found.
func add_new_decal(decal : DPMapDecal) -> void:
	var map := _get_current_map();
	
	# Add it to the map.
	map.editor_add_decal(decal);
	
	# Request a map rebuild
	map.rebuild_editor_decals(decal);
	
	pass;

#------------------------------------------------------------------------------#

func on_resource_preview_invalidated(path : String) -> void:
	#print(path);
	# TODO: have material browser connect to the signal
	pass
