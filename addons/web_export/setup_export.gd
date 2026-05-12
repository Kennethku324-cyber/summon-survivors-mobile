@tool
extends EditorPlugin

func _enter_tree():
	# Wait a frame to ensure editor is fully initialized
	await get_tree().process_frame

	var export = EditorInterface.get_export()

	# Check if Web preset already exists
	for p in export.get_export_presets():
		if p.name == "Web":
			print("Web preset already exists")
			get_tree().quit()
			return

	# Create new web export preset
	var preset = ExportPreset.new()
	preset.name = "Web"
	preset.platform = "web"
	preset.runnable = true
	preset.export_path = "exports/web/index.html"
	preset.set("variant", "nothreads")

	export.add_export_preset(preset)
	export.save_presets()
	print("Created Web export preset")
	get_tree().quit()
