@tool
extends EditorResourcePreviewGenerator
class_name DP_MaterialPreviewGenerator;

var _plugin : DioptraEditorMainPlugin = null;

var _viewport : RID;
var _canvas : RID;
var _canvas_item : RID;

func _init(plugin : DioptraEditorMainPlugin) -> void:
	_plugin = plugin;
	# EditorSettings.filesystem/file_dialog/thumbnail_size
	
	# Set up the rendering server w/ a 2D canvas:
	_viewport = RenderingServer.viewport_create();
	RenderingServer.viewport_set_update_mode(_viewport, RenderingServer.VIEWPORT_UPDATE_DISABLED);
	RenderingServer.viewport_set_size(_viewport, 128, 128);
	RenderingServer.viewport_set_transparent_background(_viewport, true);
	RenderingServer.viewport_set_active(_viewport, true);
	
	# just do a canvas for now and copy-pasta the albedo.
	# TODO: camera with lighting w/ proper material use instead of just albedo. Or see if canvasitem meshes are good enough
	_canvas = RenderingServer.canvas_create();
	RenderingServer.viewport_attach_canvas(_viewport, _canvas);
	
	_canvas_item = RenderingServer.canvas_item_create();
	RenderingServer.canvas_item_set_parent(_canvas_item, _canvas);

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		#RenderingServer.free_rid(viewport_texture); # Don't do this, this is the viewport's texture
		RenderingServer.free_rid(_canvas_item);
		RenderingServer.free_rid(_canvas);
		RenderingServer.free_rid(_viewport); # this seems to be too early to free it
	

func _can_generate_small_preview() -> bool:
	print("_can_generate_small_preview");
	return true;
	
func _handles(type: String) -> bool:
	print(type);
	return false;

func _generate(resource: Resource, size: Vector2i, metadata: Dictionary) -> Texture2D:
	var material : Material;

	
	# Grab material
	material = resource as Material;
	if material == null:
		return null;
	
	# Set up the viewport
	RenderingServer.viewport_set_active(_viewport, false);
	RenderingServer.viewport_set_size(_viewport, size.x, size.y);
	RenderingServer.viewport_set_active(_viewport, true);
	
	# Build the command list
	var sm := material as StandardMaterial3D;
	if sm and sm.albedo_texture:
		RenderingServer.canvas_item_add_texture_rect(_canvas_item, Rect2(0, 0, size.x, size.y), sm.albedo_texture.get_rid());
	else:
		RenderingServer.canvas_item_add_circle(_canvas_item, Vector2(size.x, size.y) * 0.5, size.x * 0.5, Color.RED);
		var font := EditorInterface.get_editor_theme().get_font("font", "CodeEdit");
		font.draw_string(_canvas_item, Vector2(size.x, size.y) * 0.25, "NOPE");
	
	# Now execute the command list:
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		var main_loop := Engine.get_main_loop();
		assert(main_loop is SceneTree);
		var root_vp := (main_loop as SceneTree).root.get_viewport_rid();
		RenderingServer.viewport_set_active(root_vp, false);
		RenderingServer.viewport_set_update_mode(_viewport, RenderingServer.VIEWPORT_UPDATE_ONCE);
		RenderingServer.force_draw(false);
		RenderingServer.viewport_set_active(root_vp, true);
	else:
		var semaphore := Semaphore.new()
		var frame_pre_draw_callback = func():
			RenderingServer.viewport_set_update_mode(_viewport, RenderingServer.VIEWPORT_UPDATE_ONCE);
		var request_frame_drawn_callback = func():
			semaphore.post();
		RenderingServer.frame_pre_draw.connect(frame_pre_draw_callback, ConnectFlags.CONNECT_ONE_SHOT);
		RenderingServer.request_frame_drawn_callback(request_frame_drawn_callback);
		semaphore.wait();
		
	# Get rendered image:
	var viewport_texture : RID;
	viewport_texture = RenderingServer.viewport_get_texture(_viewport);
	var image := RenderingServer.texture_2d_get(viewport_texture);
	RenderingServer.canvas_item_clear(_canvas_item);
	image.convert(Image.FORMAT_RGBA8);
	var result : Texture2D = ImageTexture.create_from_image(image);

	return result;
