extends Node

func _ready():
	# Create web export preset
	var preset = EditorExportPreset.new()
	preset.name = "Web"
	preset.platform = "web"
	preset.export_path = "exports/web/index.html"

	# Add preset to editor
	var export = EditorInterface.get_editor_export()
	export.add_export_preset(preset)

	# Save presets
	# Actually, the export_presets.cfg should be saved automatically
	print("Preset created")
	get_tree().quit()
