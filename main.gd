extends Node3D

# Don Libarti - straight-road driving prototype.
# The car advances automatically; touch LEFT/RIGHT to steer.

var car: Node3D
var road_speed := 34.0
var steer := 0.0
var steer_target := 0.0
var car_x := 0.0
var camera: Camera3D
var speed_label: Label
var left_button: Button
var right_button: Button
var wheel_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	_build_world()
	_build_road()
	_build_car()
	_build_camera()
	_build_ui()

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.28, 0.48)
	sky_mat.sky_horizon_color = Color(0.66, 0.78, 0.88)
	sky_mat.ground_bottom_color = Color(0.12, 0.13, 0.15)
	sky_mat.ground_horizon_color = Color(0.48, 0.52, 0.55)
	sky.sky_material = sky_mat
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.78)
	env.ambient_light_energy = 0.65
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

func _mat(color: Color, metallic := 0.0, roughness := 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, bevel := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, rotate := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	mesh.rings = 2
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rotate
	mi.material_override = material
	parent.add_child(mi)
	return mi

func _build_road() -> void:
	var asphalt := _mat(Color(0.075, 0.083, 0.095), 0.08, 0.82)
	var ground := _mat(Color(0.24, 0.27, 0.29), 0.0, 1.0)
	var white := _mat(Color(0.92, 0.92, 0.86), 0.0, 0.7)
	var yellow := _mat(Color(1.0, 0.72, 0.12), 0.0, 0.65)
	_box(self, Vector3(260, 0.5, 22000), Vector3(0, -0.55, -9500), ground)
	_box(self, Vector3(18, 0.24, 22000), Vector3(0, -0.16, -9500), asphalt)
	# Long straight road-edge lines and a broken center line.
	_box(self, Vector3(0.16, 0.025, 22000), Vector3(-8.25, -0.025, -9500), white)
	_box(self, Vector3(0.16, 0.025, 22000), Vector3(8.25, -0.025, -9500), white)
	for i in range(220):
		_box(self, Vector3(0.13, 0.03, 22), Vector3(0, -0.015, -float(i) * 100.0), yellow)

func _build_car() -> void:
	car = Node3D.new()
	car.position = Vector3(0, 0.0, 0)
	add_child(car)
	var paint := _mat(Color(0.72, 0.035, 0.025), 0.82, 0.22)
	var dark := _mat(Color(0.018, 0.025, 0.034), 0.25, 0.2)
	var glass := _mat(Color(0.035, 0.10, 0.15), 0.72, 0.12)
	var chrome := _mat(Color(0.72, 0.76, 0.8), 0.92, 0.18)
	var rubber := _mat(Color(0.012, 0.014, 0.017), 0.0, 0.92)
	var lamp := _mat(Color(1.0, 0.91, 0.67), 0.2, 0.15)
	var tail := _mat(Color(0.8, 0.015, 0.008), 0.25, 0.2)
	# Sculpted-looking layered body, hood, roof, bumpers and trim.
	_box(car, Vector3(2.05, 0.48, 4.35), Vector3(0, 0.78, 0.0), paint)
	_box(car, Vector3(1.92, 0.22, 1.28), Vector3(0, 1.02, -1.48), paint)
	_box(car, Vector3(1.9, 0.20, 1.05), Vector3(0, 1.02, 1.55), paint)
	_box(car, Vector3(1.62, 0.72, 1.95), Vector3(0, 1.34, 0.12), paint)
	_box(car, Vector3(1.52, 0.055, 1.78), Vector3(0, 1.72, 0.12), glass)
	# Front and rear windshields; side windows.
	var windshield := _box(car, Vector3(1.58, 0.58, 0.07), Vector3(0, 1.38, -0.88), glass)
	windshield.rotation.x = deg_to_rad(-18)
	var rear_glass := _box(car, Vector3(1.58, 0.55, 0.07), Vector3(0, 1.38, 1.08), glass)
	rear_glass.rotation.x = deg_to_rad(18)
	for side in [-1.0, 1.0]:
		_box(car, Vector3(0.045, 0.42, 0.82), Vector3(side * 0.82, 1.39, -0.32), glass)
		_box(car, Vector3(0.045, 0.42, 0.72), Vector3(side * 0.82, 1.39, 0.58), glass)
		_box(car, Vector3(0.10, 0.12, 3.0), Vector3(side * 1.03, 0.91, 0), chrome)
		_box(car, Vector3(0.12, 0.16, 0.32), Vector3(side * 1.04, 1.12, -0.45), chrome)
	# Bumpers, grille, headlights, fog lamps, mirrors, handles.
	_box(car, Vector3(2.08, 0.20, 0.18), Vector3(0, 0.55, -2.18), dark)
	_box(car, Vector3(2.08, 0.18, 0.18), Vector3(0, 0.55, 2.18), dark)
	_box(car, Vector3(0.92, 0.22, 0.035), Vector3(0, 0.78, -2.205), dark)
	for x in [-0.69, 0.69]:
		_box(car, Vector3(0.48, 0.22, 0.07), Vector3(x, 0.94, -2.19), lamp)
		_box(car, Vector3(0.34, 0.18, 0.06), Vector3(x, 0.91, 2.19), tail)
		_box(car, Vector3(0.22, 0.10, 0.05), Vector3(x, 0.62, -2.20), lamp)
	for side in [-1.0, 1.0]:
		_box(car, Vector3(0.20, 0.13, 0.25), Vector3(side * 1.08, 1.44, -0.72), paint)
		_box(car, Vector3(0.055, 0.055, 0.26), Vector3(side * 1.02, 1.20, 0.05), chrome)
	# Four detailed wheels, alloy hubs and concentric rings.
	for x in [-1.08, 1.08]:
		for z in [-1.42, 1.42]:
			var w := _cylinder(car, 0.48, 0.30, Vector3(x, 0.49, z), rubber, Vector3(0, 0, 90))
			wheel_meshes.append(w)
			_cylinder(car, 0.29, 0.315, Vector3(x * 1.015, 0.49, z), chrome, Vector3(0, 0, 90))
			_cylinder(car, 0.10, 0.325, Vector3(x * 1.02, 0.49, z), dark, Vector3(0, 0, 90))
			for spoke in range(8):
				var angle := TAU * float(spoke) / 8.0
				var sp := _box(car, Vector3(0.055, 0.22, 0.035), Vector3(x * 1.025, 0.49 + cos(angle) * 0.17, z + sin(angle) * 0.17), chrome)
				sp.rotation.x = angle
	# Rear spoiler and subtle roof antenna.
	_box(car, Vector3(1.75, 0.07, 0.22), Vector3(0, 1.62, 1.92), dark)
	_box(car, Vector3(0.045, 0.20, 0.045), Vector3(0, 1.82, 0.55), dark)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 5.0, 10.5)
	camera.rotation_degrees = Vector3(-14, 0, 0)
	camera.current = true
	add_child(camera)
	camera.fov = 70.0

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.02, 0.03, 0.52)
	panel.position = Vector2(18, 18)
	panel.size = Vector2(260, 64)
	layer.add_child(panel)
	speed_label = Label.new()
	speed_label.position = Vector2(34, 27)
	speed_label.add_theme_font_size_override("font_size", 27)
	speed_label.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(speed_label)
	left_button = _make_button(layer, "◀", Vector2(28, -118))
	right_button = _make_button(layer, "▶", Vector2(164, -118))
	left_button.button_down.connect(func(): steer_target = -1.0)
	left_button.button_up.connect(func(): steer_target = 0.0)
	right_button.button_down.connect(func(): steer_target = 1.0)
	right_button.button_up.connect(func(): steer_target = 0.0)

func _make_button(parent: CanvasLayer, caption: String, offset: Vector2) -> Button:
	var b := Button.new()
	b.text = caption
	b.position = Vector2(0, 0)
	b.anchor_left = 0.0
	b.anchor_top = 1.0
	b.anchor_right = 0.0
	b.anchor_bottom = 1.0
	b.offset_left = offset.x + 28
	b.offset_top = offset.y
	b.offset_right = offset.x + 142
	b.offset_bottom = offset.y + 88
	b.add_theme_font_size_override("font_size", 38)
	b.modulate = Color(1, 1, 1, 0.92)
	parent.add_child(b)
	return b

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		steer_target = -1.0
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		steer_target = 1.0
	elif not (left_button.button_pressed or right_button.button_pressed):
		steer_target = 0.0
	steer = move_toward(steer, steer_target, delta * 4.5)
	car_x = clampf(car_x + steer * delta * 7.0, -6.2, 6.2)
	car.position.x = lerpf(car.position.x, car_x, delta * 7.0)
	car.position.z -= road_speed * delta
	for w in wheel_meshes:
		w.rotate_object_local(Vector3.RIGHT, delta * 7.0)
	camera.position = camera.position.lerp(Vector3(car.position.x * 0.42, 5.0, car.position.z + 10.5), delta * 3.0)
	camera.look_at(Vector3(car.position.x, 0.85, car.position.z - 8.0), Vector3.UP)
	speed_label.text = "DON LIBARTI     %d km/h" % int(road_speed * 3.6)
