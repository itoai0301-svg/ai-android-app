extends Node3D
## ALIEN RIFT — small original, procedural 3D starship demo.
## Entire scene is made at runtime; no downloads, 3D asset licenses or API keys.

const CYAN := Color(0.11, 0.86, 1.0)
const MINT := Color(0.24, 1.0, 0.77)
const AMBER := Color(1.0, 0.64, 0.27)
const PLANETS := [
    {"name": "EARTH", "type": 0, "radius": 12.4, "class": "TERRESTRIAL WORLD", "scan": "Liquid oceans / atmosphere\nHome signal: positive\nReturn to Earth to complete mission.", "atmo": Color(0.04, 0.51, 1.0)},
    {"name": "SATURN", "type": 4, "radius": 13.6, "class": "RINGED GAS GIANT", "scan": "Multi-band planetary rings\nAmmonia cloud layers\nRadiation warning: medium", "atmo": Color(0.82, 0.59, 0.31)},
    {"name": "NEPTUNE", "type": 3, "radius": 12.0, "class": "ICE GIANT", "scan": "Methane-rich atmosphere\nDeep cobalt storm bands\nExtreme wind conditions", "atmo": Color(0.12, 0.36, 1.0)},
    {"name": "MARS", "type": 2, "radius": 11.1, "class": "ROCKY WORLD", "scan": "Iron-oxide terrain\nPolar ice signatures\nAtmosphere: thin", "atmo": Color(1.0, 0.33, 0.12)},
    {"name": "JUPITER", "type": 1, "radius": 15.0, "class": "GAS GIANT", "scan": "Immense cloud bands\nAtmospheric storm activity\nRadiation warning: high", "atmo": Color(0.91, 0.55, 0.29)}
]

var world_root: Node3D
var stars: MultiMeshInstance3D
var main_planet: MeshInstance3D
var main_mat: ShaderMaterial
var atmosphere: MeshInstance3D
var atmosphere_mat: ShaderMaterial
var moon: MeshInstance3D
var ring: MeshInstance3D
var cam: Camera3D
var overlay: Control
var location_label: Label
var class_label: Label
var nav_label: Label
var status_label: Label
var power_label: Label
var scanner_panel: ColorRect
var scanner_label: Label
var target_button: Button
var scan_button: Button
var warp_button: Button
var current_index: int = 1
var target_index: int = 2
var jumps: int = 0
var power: float = 100.0
var warp_time: float = 0.0
var warp_changed: bool = false
var scanner_open: bool = false
var total_seconds: float = 0.0

func _ready() -> void:
    seed(319991)
    _setup_space()
    _setup_cockpit()
    _setup_interface()
    _enter_world(1)
    _refresh_labels()

func _setup_space() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.002, 0.004, 0.016)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.13, 0.20, 0.35)
    env.ambient_light_energy = 0.34
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

    cam = Camera3D.new()
    cam.current = true
    cam.position = Vector3(0, 0.75, 3.2)
    cam.fov = 73.0
    cam.far = 550.0
    add_child(cam)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-24, 35, 0)
    sun.light_color = Color(1.0, 0.88, 0.70)
    sun.light_energy = 2.6
    sun.shadow_enabled = false
    add_child(sun)
    var rimlight := DirectionalLight3D.new()
    rimlight.rotation_degrees = Vector3(16, -127, 0)
    rimlight.light_color = Color(0.20, 0.50, 1.0)
    rimlight.light_energy = 0.43
    add_child(rimlight)

    world_root = Node3D.new()
    world_root.name = "DynamicSpace"
    add_child(world_root)
    _create_stars()
    _create_planets()
    _create_asteroid_belt()

func _create_stars() -> void:
    var star_mesh := SphereMesh.new()
    star_mesh.radius = 0.065
    star_mesh.height = 0.13
    star_mesh.radial_segments = 5
    star_mesh.rings = 3
    var star_mat := StandardMaterial3D.new()
    star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    star_mat.vertex_color_use_as_albedo = true
    star_mesh.material = star_mat
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = star_mesh
    multi.instance_count = 1050
    for i in range(multi.instance_count):
        var theta: float = randf_range(0.0, TAU)
        var u: float = randf_range(-0.88, 0.94)
        var radial: float = sqrt(1.0 - u * u)
        var distance: float = randf_range(180.0, 350.0)
        var spot := Vector3(cos(theta) * radial, u, sin(theta) * radial) * distance
        var sz: float = randf_range(0.55, 2.0)
        if i % 37 == 0:
            sz = 3.6
        multi.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sz), spot))
        var tint := Color(0.61, 0.78, 1.0).lerp(Color(1.0, 0.85, 0.65), randf() * 0.85)
        multi.set_instance_color(i, tint * randf_range(0.50, 1.0))
    stars = MultiMeshInstance3D.new()
    stars.multimesh = multi
    world_root.add_child(stars)

func _make_sphere() -> SphereMesh:
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    sphere.radial_segments = 112
    sphere.rings = 56
    return sphere

func _create_planets() -> void:
    var sphere := _make_sphere()
    main_mat = ShaderMaterial.new()
    main_mat.shader = preload("res://shaders/planet.gdshader")
    main_planet = MeshInstance3D.new()
    main_planet.name = "ProceduralPlanet"
    main_planet.mesh = sphere
    main_planet.material_override = main_mat
    world_root.add_child(main_planet)

    atmosphere_mat = ShaderMaterial.new()
    atmosphere_mat.shader = preload("res://shaders/atmosphere.gdshader")
    atmosphere = MeshInstance3D.new()
    atmosphere.name = "AtmosphereGlow"
    atmosphere.mesh = sphere
    atmosphere.material_override = atmosphere_mat
    world_root.add_child(atmosphere)

    var moon_mat := ShaderMaterial.new()
    moon_mat.shader = preload("res://shaders/planet.gdshader")
    moon_mat.set_shader_parameter("planet_kind", 2)
    moon = MeshInstance3D.new()
    moon.name = "SecondaryMoon"
    moon.mesh = sphere
    moon.material_override = moon_mat
    moon.position = Vector3(-24.0, 9.0, -74.0)
    moon.scale = Vector3.ONE * 3.9
    world_root.add_child(moon)
    _create_rings()

func _create_rings() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings: int = 13
    var sectors: int = 192
    for b in range(rings):
        var r0: float = 17.1 + float(b) * 0.88
        var r1: float = r0 + 0.85
        var band_color := Color(0.83, 0.72, 0.57, 0.75)
        if b % 5 == 0:
            band_color = Color(0.24, 0.18, 0.16, 0.42)
        elif b % 4 == 0:
            band_color = Color(0.99, 0.84, 0.62, 0.88)
        for j in range(sectors):
            var a0: float = float(j) * TAU / float(sectors)
            var a1: float = float(j + 1) * TAU / float(sectors)
            var p0 := Vector3(cos(a0) * r0, sin(a0) * r0, 0)
            var p1 := Vector3(cos(a1) * r0, sin(a1) * r0, 0)
            var p2 := Vector3(cos(a1) * r1, sin(a1) * r1, 0)
            var p3 := Vector3(cos(a0) * r1, sin(a0) * r1, 0)
            for p in [p0, p1, p2, p0, p2, p3]:
                st.set_color(band_color)
                st.set_normal(Vector3(0, 0, 1))
                st.add_vertex(p)
    var ring_mat := StandardMaterial3D.new()
    ring_mat.vertex_color_use_as_albedo = true
    ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring = MeshInstance3D.new()
    ring.name = "SaturnRings"
    ring.mesh = st.commit()
    ring.material_override = ring_mat
    ring.rotation_degrees = Vector3(14.0, 19.0, -23.0)
    world_root.add_child(ring)

func _create_asteroid_belt() -> void:
    var stone := SphereMesh.new()
    stone.radius = 1.0
    stone.height = 2.0
    stone.radial_segments = 7
    stone.rings = 4
    var rock_mat := StandardMaterial3D.new()
    rock_mat.vertex_color_use_as_albedo = true
    rock_mat.roughness = 1.0
    stone.material = rock_mat
    var rocks := MultiMesh.new()
    rocks.transform_format = MultiMesh.TRANSFORM_3D
    rocks.use_colors = true
    rocks.mesh = stone
    rocks.instance_count = 94
    for i in range(rocks.instance_count):
        var angle: float = randf_range(0, TAU)
        var r: float = randf_range(31.0, 100.0)
        var p := Vector3(cos(angle) * r - 10.0, randf_range(-28.0, 26.0), -80.0 + sin(angle) * 22.0)
        var scale_n: float = randf_range(0.18, 0.95)
        rocks.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(scale_n, scale_n * 0.73, scale_n * 1.17)), p))
        rocks.set_instance_color(i, Color(0.21, 0.24, 0.29).lerp(Color(0.64, 0.47, 0.34), randf()))
    var belt := MultiMeshInstance3D.new()
    belt.multimesh = rocks
    world_root.add_child(belt)

func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.83
    mat.roughness = 0.27
    if glow > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = glow
    return mat

func _box(parent: Node3D, pos: Vector3, dims: Vector3, mat: Material, angles: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = dims
    var item := MeshInstance3D.new()
    item.mesh = mesh
    item.material_override = mat
    item.position = pos
    item.rotation_degrees = angles
    parent.add_child(item)
    return item

func _rod(parent: Node3D, start: Vector3, finish: Vector3, width: float, mat: Material) -> void:
    var rod_mesh := CylinderMesh.new()
    rod_mesh.top_radius = width
    rod_mesh.bottom_radius = width * 1.08
    rod_mesh.height = start.distance_to(finish)
    rod_mesh.radial_segments = 10
    var item := MeshInstance3D.new()
    item.mesh = rod_mesh
    item.material_override = mat
    item.position = (start + finish) * 0.5
    item.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
    parent.add_child(item)

func _setup_cockpit() -> void:
    var frame := _material(Color(0.045, 0.073, 0.12))
    var armor := _material(Color(0.09, 0.13, 0.19))
    var dark := _material(Color(0.009, 0.023, 0.047))
    var edge := _material(Color(0.04, 0.53, 0.72), 2.7)
    var gold := _material(Color(0.65, 0.34, 0.12), 1.0)
    var display := _material(Color(0.01, 0.19, 0.27), 1.6)
    var green := _material(Color(0.05, 0.76, 0.51), 2.2)
    var cockpit := Node3D.new()
    cockpit.name = "AlienCockpitGeometry"
    add_child(cockpit)

    # Window skeleton: thin angular gunmetal rails frame the planetary vista.
    for side in [-1.0, 1.0]:
        _rod(cockpit, Vector3(side * 2.65, -1.35, 1.3), Vector3(side * 2.65, 2.13, -5.0), 0.15, frame)
        _rod(cockpit, Vector3(side * 2.65, 2.13, -5.0), Vector3(side * 0.75, 2.65, -7.0), 0.11, armor)
        _rod(cockpit, Vector3(side * 2.6, -1.02, 0.3), Vector3(side * 3.45, -0.78, -5.9), 0.12, armor)
        _rod(cockpit, Vector3(side * 2.48, -1.21, 0.3), Vector3(side * 3.29, -0.96, -5.8), 0.024, edge)
        _rod(cockpit, Vector3(side * 2.64, 2.03, -5.0), Vector3(side * 0.77, 2.53, -6.9), 0.026, edge)
        _box(cockpit, Vector3(side * 3.33, -0.9, -3.1), Vector3(0.8, 0.29, 4.5), armor, Vector3(0, 0, side * 8))
        for k in range(6):
            var z: float = -0.30 - float(k) * 0.66
            _box(cockpit, Vector3(side * 3.18, -0.72, z), Vector3(0.17, 0.025, 0.30), edge)
    _rod(cockpit, Vector3(-0.75, 2.65, -7.0), Vector3(0.75, 2.65, -7.0), 0.115, frame)
    _rod(cockpit, Vector3(-3.05, -1.08, -5.7), Vector3(3.05, -1.08, -5.7), 0.10, armor)
    _rod(cockpit, Vector3(-3.05, -1.01, -5.66), Vector3(3.05, -1.01, -5.66), 0.022, edge)

    # Multifaceted armored dashboard and recessed luminous displays.
    _box(cockpit, Vector3(0, -1.64, -1.7), Vector3(6.3, 0.91, 2.65), armor, Vector3(-8, 0, 0))
    _box(cockpit, Vector3(0, -1.18, -2.72), Vector3(4.5, 0.065, 1.3), dark, Vector3(12, 0, 0))
    _box(cockpit, Vector3(0, -1.133, -2.70), Vector3(3.86, 0.017, 0.76), display, Vector3(12, 0, 0))
    _box(cockpit, Vector3(-2.24, -1.06, -2.75), Vector3(0.022, 0.035, 1.01), edge, Vector3(12, 0, 0))
    _box(cockpit, Vector3(2.24, -1.06, -2.75), Vector3(0.022, 0.035, 1.01), edge, Vector3(12, 0, 0))
    _box(cockpit, Vector3(0, -1.35, -1.27), Vector3(6.5, 0.09, 0.095), edge)
    _box(cockpit, Vector3(0, -1.48, -0.25), Vector3(6.7, 0.15, 0.3), frame)
    for side in [-1.0, 1.0]:
        _box(cockpit, Vector3(side * 2.46, -0.94, -2.22), Vector3(1.11, 0.06, 0.89), dark, Vector3(13, side * 15.0, 0))
        for j in range(6):
            _box(cockpit, Vector3(side * (2.1 + 0.17 * float(j % 3)), -0.896, -2.48 + float(j / 3) * 0.31), Vector3(0.09, 0.012, 0.08), green if j % 4 == 0 else gold)
        _box(cockpit, Vector3(side * 2.85, -1.65, -0.64), Vector3(1.28, 0.43, 1.7), armor, Vector3(0, side * 14.0, 0))
        _box(cockpit, Vector3(side * 2.8, -1.39, -0.72), Vector3(0.93, 0.02, 0.92), display)
        _rod(cockpit, Vector3(side * 3.13, -1.2, -0.9), Vector3(side * 2.57, -0.6, -1.9), 0.08, frame)
    for k in range(19):
        var px: float = -1.68 + float(k) * 0.186
        _box(cockpit, Vector3(px, -1.073, -2.7), Vector3(0.068, 0.024, 0.11), green if k % 6 == 0 else edge)
    for k in range(4):
        _box(cockpit, Vector3(-0.9 + float(k) * 0.57, -1.06, -2.33), Vector3(0.29, 0.022, 0.08), gold if k == 0 else edge)

    # Tiny cockpit point lights deliver alien-blue reflections.
    for side in [-1.0, 1.0]:
        var light := OmniLight3D.new()
        light.position = Vector3(side * 2.52, -0.75, -1.9)
        light.light_color = Color(0.12, 0.79, 1.0)
        light.light_energy = 0.9
        light.omni_range = 5.0
        cockpit.add_child(light)

func _make_label(message: String, font_size: int, color: Color, left: float, top: float, width: float, height: float, bottom: bool = false) -> Label:
    var label := Label.new()
    label.text = message
    label.anchor_top = 1.0 if bottom else 0.0
    label.anchor_bottom = 1.0 if bottom else 0.0
    label.offset_left = left
    label.offset_top = top
    label.offset_right = left + width
    label.offset_bottom = top + height
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _button(message: String, width: float, right_gap: float, color: Color) -> Button:
    var btn := Button.new()
    btn.text = message
    btn.anchor_left = 1.0
    btn.anchor_right = 1.0
    btn.anchor_top = 1.0
    btn.anchor_bottom = 1.0
    btn.offset_left = -(right_gap + width)
    btn.offset_right = -right_gap
    btn.offset_top = -112.0
    btn.offset_bottom = -36.0
    btn.add_theme_font_size_override("font_size", 20)
    btn.add_theme_color_override("font_color", Color(0.80, 0.99, 1.0))
    btn.add_theme_color_override("font_hover_color", Color.WHITE)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.025, 0.11, 0.17, 0.84)
    normal.border_color = color
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(13)
    normal.content_margin_left = 12
    normal.content_margin_right = 12
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.055, 0.30, 0.37, 0.93)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.07, 0.46, 0.53, 0.97)
    btn.add_theme_stylebox_override("normal", normal)
    btn.add_theme_stylebox_override("hover", hover)
    btn.add_theme_stylebox_override("pressed", pressed)
    btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    return btn

func _setup_interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)
    overlay = Control.new()
    overlay.set_script(preload("res://scripts/flight_hud.gd"))
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(overlay)

    var heading := _make_label("A L I E N   R I F T", 31, Color(0.77, 0.97, 1.0), 32, 21, 420, 45)
    ui.add_child(heading)
    var small := _make_label("UNKNOWN CRAFT   /   NAVIGATION ONLINE", 14, CYAN, 34, 65, 470, 26)
    ui.add_child(small)
    location_label = _make_label("SATURN  /  ORBIT", 25, Color(0.86, 0.98, 1.0), 30, -208, 440, 36, true)
    ui.add_child(location_label)
    class_label = _make_label("RINGED GAS GIANT", 15, CYAN, 32, -175, 390, 28, true)
    ui.add_child(class_label)
    nav_label = _make_label("NEXT TARGET: NEPTUNE", 17, MINT, 32, -144, 400, 26, true)
    ui.add_child(nav_label)
    power_label = _make_label("POWER 100%   /   FTL READY", 15, Color(0.65, 0.95, 0.97), 32, -113, 450, 28, true)
    ui.add_child(power_label)
    status_label = _make_label("DRAG TO LOOK  ·  SELECT TARGET  ·  WARP TO TRAVEL", 15, Color(0.57, 0.80, 0.90), 32, -77, 620, 26, true)
    ui.add_child(status_label)

    target_button = _button("TARGET  ◈", 166, 425, CYAN)
    target_button.pressed.connect(_on_target)
    ui.add_child(target_button)
    scan_button = _button("SCAN  ◉", 158, 243, MINT)
    scan_button.pressed.connect(_on_scan)
    ui.add_child(scan_button)
    warp_button = _button("WARP  ➜", 206, 20, AMBER)
    warp_button.pressed.connect(_on_warp)
    ui.add_child(warp_button)

    scanner_panel = ColorRect.new()
    scanner_panel.color = Color(0.01, 0.06, 0.105, 0.89)
    scanner_panel.offset_left = 31
    scanner_panel.offset_top = 120
    scanner_panel.offset_right = 350
    scanner_panel.offset_bottom = 315
    scanner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scanner_panel.visible = false
    ui.add_child(scanner_panel)
    scanner_label = _make_label("", 17, Color(0.60, 0.95, 1.0), 15, 14, 290, 175)
    scanner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    scanner_panel.add_child(scanner_label)
    var help := _make_label("PROCEDURAL 3D  ·  ORIGINAL DEMO  ·  NOT AN ASTRONOMICAL SIMULATOR", 12, Color(0.48, 0.66, 0.72), 32, 103, 690, 25)
    ui.add_child(help)

func _enter_world(index: int) -> void:
    current_index = index
    var data: Dictionary = PLANETS[index]
    var radius: float = float(data["radius"])
    main_planet.scale = Vector3.ONE * radius
    main_planet.position = Vector3(8.0, 5.0, -62.0)
    main_mat.set_shader_parameter("planet_kind", int(data["type"]))
    atmosphere.scale = Vector3.ONE * (radius * 1.062)
    atmosphere.position = main_planet.position
    atmosphere_mat.set_shader_parameter("atmosphere_color", data["atmo"])
    ring.visible = int(data["type"]) == 4
    ring.position = main_planet.position
    moon.position = Vector3(-23.0, 7.6, -77.0)
    moon.visible = index != 3
    world_root.rotation = Vector3.ZERO
    scanner_open = false
    scanner_panel.visible = false
    _refresh_labels()

func _refresh_labels() -> void:
    var location: Dictionary = PLANETS[current_index]
    var target: Dictionary = PLANETS[target_index]
    location_label.text = "SECTOR   /   " + str(location["name"])
    class_label.text = str(location["class"]) + "   ·   JUMPS " + str(jumps)
    nav_label.text = "DESTINATION  ➜  " + str(target["name"])
    power_label.text = "REACTOR  %03d%%    /    FTL %s" % [int(power), "CHARGING" if power < 30 else "READY"]
    target_button.text = "TARGET  ◈"

func _on_target() -> void:
    if warp_time > 0.0:
        return
    target_index = (target_index + 1) % PLANETS.size()
    if target_index == current_index:
        target_index = (target_index + 1) % PLANETS.size()
    status_label.text = "NAV COMPUTER: DESTINATION UPDATED"
    _refresh_labels()

func _on_scan() -> void:
    scanner_open = not scanner_open
    scanner_panel.visible = scanner_open
    if scanner_open:
        var data: Dictionary = PLANETS[current_index]
        scanner_label.text = "◈  LONG RANGE SCAN\n\n" + str(data["name"]) + "  /  " + str(data["class"]) + "\n\n" + str(data["scan"])
        status_label.text = "SCAN COMPLETE — PLANETARY SPECTRUM READY"
    else:
        status_label.text = "SCANNER STANDBY"

func _on_warp() -> void:
    if warp_time > 0.0:
        return
    if power < 30.0:
        status_label.text = "LOW REACTOR POWER — RECHARGING"
        return
    power -= 30.0
    warp_time = 2.25
    warp_changed = false
    warp_button.disabled = true
    target_button.disabled = true
    status_label.text = "FTL DRIVE ENGAGED — SPACETIME DISTORTION"
    _refresh_labels()

func _process(delta: float) -> void:
    total_seconds += delta
    if main_planet != null:
        main_planet.rotate_y(delta * 0.022)
        moon.rotate_y(delta * 0.035)
        main_mat.set_shader_parameter("time_phase", total_seconds)
    if stars != null:
        stars.rotate_y(delta * 0.0015)
    if power < 100.0:
        power = minf(100.0, power + delta * 5.3)
    if warp_time > 0.0:
        warp_time = maxf(0.0, warp_time - delta)
        var progress: float = 1.0 - warp_time / 2.25
        var intensity: float = sin(progress * PI)
        overlay.set("warp_amount", intensity)
        cam.fov = 73.0 + intensity * 22.0
        if not warp_changed and progress >= 0.54:
            warp_changed = true
            jumps += 1
            _enter_world(target_index)
            target_index = (target_index + 1) % PLANETS.size()
            if target_index == current_index:
                target_index = (target_index + 1) % PLANETS.size()
            if current_index == 0:
                status_label.text = "EARTH FOUND — HOME SIGNAL ACQUIRED!"
            else:
                status_label.text = "ARRIVAL CONFIRMED — NAV SYSTEM STABLE"
            _refresh_labels()
        if warp_time <= 0.0:
            overlay.set("warp_amount", 0.0)
            warp_button.disabled = false
            target_button.disabled = false
    else:
        cam.fov = lerpf(cam.fov, 73.0, minf(1.0, delta * 4.0))
    power_label.text = "REACTOR  %03d%%    /    FTL %s" % [int(power), "CHARGING" if power < 30 else "READY"]

func _unhandled_input(event: InputEvent) -> void:
    if warp_time > 0.0:
        return
    if event is InputEventScreenDrag:
        world_root.rotation.y = clampf(world_root.rotation.y + event.relative.x * 0.0013, -0.48, 0.48)
        world_root.rotation.x = clampf(world_root.rotation.x + event.relative.y * 0.0010, -0.25, 0.25)
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        world_root.rotation.y = clampf(world_root.rotation.y + event.relative.x * 0.0013, -0.48, 0.48)
        world_root.rotation.x = clampf(world_root.rotation.x + event.relative.y * 0.0010, -0.25, 0.25)
