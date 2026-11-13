@tool
extends Node3D
## P0a：只验证渲染管线。
## 5000 个随机朝向的碎片，位置一次性写死；P0b 会把位置来源换成 compute 纹理。

@export var count: int = 5000
@export var flake_size: float = 0.03
@export var half_extents: Vector3 = Vector3(2.0, 1.5, 0.4)

@onready var mmi: MultiMeshInstance3D = $MultiMeshInstance3D


var _hud: Label


func _ready() -> void:
	_build()
	_make_hud()
	if not Engine.is_editor_hint() and OS.is_debug_build():
		_capture_after_start()


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	layer.add_child(label)
	add_child(layer)
	_hud = label


func _process(_delta: float) -> void:
	if _hud != null:
		_hud.text = "FPS %d  |  flakes %d" % [Engine.get_frames_per_second(), count]


## 调试用：启动 1 秒后把视口存成 PNG，方便在没有窗口焦点时验收画面。
func _capture_after_start() -> void:
	await get_tree().create_timer(3.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://p0a_shot.png")


func _build() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(flake_size, flake_size)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = count

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	for i in count:
		var pos := Vector3(
			rng.randf_range(-half_extents.x, half_extents.x),
			rng.randf_range(-half_extents.y, half_extents.y),
			rng.randf_range(-half_extents.z, half_extents.z))
		var axis := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)).normalized()
		var basis := Basis(axis, rng.randf_range(0.0, TAU))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		mm.set_instance_color(i, Color(rng.randf(), 0.0, 0.0, 1.0))

	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/flake_sparkle.gdshader")
	mmi.material_override = mat
