extends Node3D

const Ant = preload("res://scripts/ant_model.gd")
const TouchPad = preload("res://scripts/touch_pad.gd")
const GOLD := Color("#f3cc6d")
const CREAM := Color("#fff3d1")
const GREEN := Color("#ceea86")
const INK := Color("#16382b")
const NEST := Vector3(-7.5, 0.0, 2.7)
const FOOD_SPOTS := [
	Vector3(-6.6,0,-4.2), Vector3(-1.8,0,-5.5), Vector3(5.2,0,-4.0),
	Vector3(9.4,0,0.4), Vector3(5.7,0,5.4), Vector3(-0.6,0,4.8),
	Vector3(-10.2,0,-0.9), Vector3(2.7,0,0.2)
]
const BOUNDS := Vector2(12.2, 7.5)
var rng := RandomNumberGenerator.new()
var camera: Camera3D
var sun: DirectionalLight3D
var player: Node3D
var world: Node3D
var fx_root: Node3D
var food_root: Node3D
var nav := AStarGrid2D.new()
var obstacles: Array[Dictionary] = []
var foods: Array[Dictionary] = []
var beetles: Array[Dictionary] = []
var workers: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var path: Array[Vector3] = []
var carried := -1
var round_number := 1
var delivered := 0
var target_count := 6
var health := 3
var score := 0
var best := 0
var elapsed := 0.0
var time := 0.0
var dash_left := 0.0
var dash_cooldown := 0.0
var immunity := 0.0
var state := "menu"
var previous_state := "playing"
var joystick := Vector2.ZERO
var sound_on := true
var target_ring: Node3D
var home_ring: Node3D
var canvas: CanvasLayer
var ui: Control
var quest_label: Label
var quest_detail: Label
var progress_bar: ProgressBar
var heart_label: Label
var score_label: Label
var hint_label: Label
var dash_button: Button
var home_button: Button
var pause_button: Button
var sound_button: Button
var pad: Control
var overlay: Control
var modal_card: PanelContainer
var modal_title: Label
var modal_kicker: Label
var modal_text: Label
var primary_button: Button
var secondary_button: Button
var foot_label: Label
var world_labels: Array[Label] = []
var label_anchors: Array[Vector3] = []
var hint_time := 0.0
var test_mode := false
var sfx: AudioStreamPlayer
var ambience: AudioStreamPlayer
var screen_flash: ColorRect
var tests_passed: Array[String] = []
var frame_count := 0
var capture_path := ""
var capture_play := false
var gameplay_hud: Array[Control] = []

func _ready() -> void:
	rng.seed = 74251
	test_mode = "--self-test" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
	capture_play = "--play" in OS.get_cmdline_user_args()
	_load_best()
	_build_world()
	_build_navigation()
	_build_actors()
	_build_ui()
	_spawn_food()
	_audio_setup()
	_show_menu()
	if capture_play:
		_start_game()
		player.position = Vector3(-1.2, 0, 1.6)
		player.rotation.y = -2.6
	if test_mode: call_deferred("_run_tests")

func _mat(hex_color: String, rough: float = 0.75) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex_color)
	m.roughness = rough
	return m

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, sz: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = sz
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, pos: Vector3, sz: Vector3, mat: Material, seg: int = 16) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = seg
	mesh.rings = 8
	return _mesh(parent, mesh, pos, sz, mat)

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top: float = -1.0, segments: int = 32) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return _mesh(parent, mesh, pos, Vector3.ONE, mat)

func _line(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var n := _cylinder(parent, (a+b)/2.0, radius, a.distance_to(b), mat, radius*0.8, 7)
	n.quaternion = Quaternion(Vector3.UP, (b-a).normalized())

func _torus(parent: Node3D, pos: Vector3, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 40
	mesh.ring_segments = 10
	return _mesh(parent, mesh, pos, Vector3.ONE, mat)

func _build_world() -> void:
	world = Node3D.new()
	add_child(world)
	fx_root = Node3D.new()
	add_child(fx_root)
	food_root = Node3D.new()
	add_child(food_root)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#a9c39a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#cddccd")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -27, 0)
	sun.light_color = Color("#fff3df")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65.0
	sun.shadow_blur = 1.7
	sun.shadow_bias = 0.04
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.8
	camera.position = Vector3(11, 22, 24)
	add_child(camera)
	camera.look_at(Vector3(0,0,-0.5))
	camera.current = true
	camera.far = 100.0
	var ground := PlaneMesh.new()
	ground.size = Vector2(62,62)
	var soil := ShaderMaterial.new()
	soil.shader = preload("res://scripts/ground.gdshader")
	_mesh(world, ground, Vector3(0,-0.03,0), Vector3.ONE, soil)
	# Tiny flat pebbles and clover details break up the soil at ant scale.
	_scatter_pebbles()
	_build_grass()
	_build_leaf_litter()
	_build_nest()
	_build_pond()
	_build_mushroom(Vector3(-10.6,0,-5.3), 1.35, "#d56539")
	_build_mushroom(Vector3(-9.0,0,-5.9), 0.85, "#c14d32")
	_build_mushroom(Vector3(10.8,0,5.6), 1.22, "#d7a658")
	_build_mushroom(Vector3(11.7,0,4.0), 0.7, "#df9a50")
	_build_rock(Vector3(-3.6,0,0.4), 0.95)
	_build_rock(Vector3(-4.6,0,-0.1), 0.52)
	_build_rock(Vector3(7.6,0,-5.9), 0.8)
	_build_rock(Vector3(-0.4,0,7.0), 0.5)
	_build_log(Vector3(0.3,0,-7.4))
	for i in range(32):
		var x := rng.randf_range(-15.0,15.0)
		var z := rng.randf_range(-10.7,9.4)
		if absf(x) < 10.6 and absf(z) < 6.7: continue
		_build_flower(Vector3(x,0,z), rng.randf_range(0.7,1.35), i % 4)
	# Large foreground clover gives the garden a miniature, macro-photography feel.
	for p in [Vector3(-14,0,3),Vector3(-12.8,0,6.7),Vector3(13,0,-5.7),Vector3(11.5,0,-8.8),Vector3(6,0,9.1)]:
		_build_clover(p, rng.randf_range(1.0,1.6))
	_build_motes()
	home_ring = _torus(world, NEST+Vector3(0,0.065,0),1.12,1.15,_unshaded("#ebd18d"))
	target_ring = _torus(world, Vector3(0,0.06,0),0.27,0.30,_unshaded("#ffe19a"))
	target_ring.visible = false

func _unshaded(hex_color: String) -> StandardMaterial3D:
	var m := _mat(hex_color)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _scatter_pebbles() -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.radius = 1
	mesh.height = 2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 300
	for i in range(mm.instance_count):
		var p := Vector3(rng.randf_range(-18,18),0.015,rng.randf_range(-12,12))
		var scale_v := Vector3(rng.randf_range(0.025,0.095),rng.randf_range(0.012,0.045),rng.randf_range(0.04,0.12))
		mm.set_instance_transform(i,Transform3D(Basis.from_scale(scale_v),p))
		mm.set_instance_color(i,Color("#96865b").lerp(Color("#dfcb91"),rng.randf()))
	var n := MultiMeshInstance3D.new()
	n.multimesh = mm
	var mat := _mat("#ffffff")
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(n)

func _build_grass() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [0.0, 1.05, 2.10]:
		for j in range(4):
			var h1 := float(j)/4.0
			var h2 := float(j+1)/4.0
			var w1 := 0.054*(1.0-h1)
			var w2 := 0.054*(1.0-h2)
			var d := Vector3(cos(a),0,sin(a))
			var bend := Vector3(sin(a),0,cos(a))*0.23
			var p1 := Vector3(0,h1*0.63,0)+bend*h1*h1
			var p2 := Vector3(0,h2*0.63,0)+bend*h2*h2
			var verts := [p1-d*w1,p1+d*w1,p2-d*w2,p1+d*w1,p2+d*w2,p2-d*w2]
			var uvs := [Vector2(0,h1),Vector2(1,h1),Vector2(0,h2),Vector2(1,h1),Vector2(1,h2),Vector2(0,h2)]
			for k in range(6):
				st.set_uv(uvs[k])
				st.add_vertex(verts[k])
	st.generate_normals()
	var grass_mesh := st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = grass_mesh
	mm.instance_count = 2300
	var i := 0
	while i < mm.instance_count:
		var x := rng.randf_range(-21,21)
		var z := rng.randf_range(-14,14)
		# Keep readable little trails in the inner garden.
		if absf(x)<11.8 and absf(z)<7.0 and rng.randf()<0.88: continue
		if Vector2(x-NEST.x,z-NEST.z).length()<1.4: continue
		if Vector2((x-3.6)/1.8,(z+1.7)/1.25).length()<1.2: continue
		var scale_f := rng.randf_range(0.35,1.20)
		mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_f),Vector3(x,0,z)))
		mm.set_instance_color(i,Color("#38642c").lerp(Color("#a5ba52"),rng.randf()))
		i+=1
	var n := MultiMeshInstance3D.new()
	n.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/grass.gdshader")
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(n)

func _build_leaf_litter() -> void:
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	mm.mesh=_leaf_mesh()
	mm.instance_count=120
	for i in range(mm.instance_count):
		var p:=Vector3(rng.randf_range(-14,14),0.025,rng.randf_range(-9,9))
		var s:=rng.randf_range(0.12,0.34)
		mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(s,0.12,s)),p))
		mm.set_instance_color(i,Color("#4e653b").lerp(Color("#8a9758"),rng.randf()))
	var node:=MultiMeshInstance3D.new()
	node.multimesh=mm
	var mat:=_mat("#ffffff")
	mat.vertex_color_use_as_albedo=true
	mat.vertex_color_is_srgb=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)

func _build_nest() -> void:
	var soil := _mat("#aa7548")
	_sphere(world,NEST+Vector3(0,0.1,0),Vector3(1.2,0.34,1.0),soil,32)
	_sphere(world,NEST+Vector3(0,0.448,-0.10),Vector3(0.52,0.025,0.46),_mat("#30291d"),24)
	_torus(world,NEST+Vector3(0,0.445,-0.1),0.46,0.61,_mat("#be8c55"))
	for i in range(14):
		var a := i*TAU/14.0
		_sphere(world,NEST+Vector3(cos(a)*0.94,0.18,sin(a)*0.79),Vector3(0.11,0.07,0.09),_mat("#c6a56b"),8)
	var stick := NEST+Vector3(-1.35,0,-0.15)
	_line(world,stick,stick+Vector3(0,1.5,0),0.045,_mat("#80603a"))
	var leaf := _leaf_mesh()
	var sign_leaf := _mesh(world,leaf,stick+Vector3(0.27,1.26,0),Vector3(0.65,0.65,0.65),_mat("#94be56"))
	sign_leaf.rotation_degrees = Vector3(45,0,-10)

func _build_pond() -> void:
	var p := Vector3(3.6,0,-1.7)
	obstacles.append({"pos":p,"radius":1.75,"z_scale":0.72})
	_sphere(world,p+Vector3(0,-0.085,0),Vector3(2.03,0.10,1.42),_mat("#968962"),32)
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 1
	water_mesh.bottom_radius = 1
	water_mesh.height = 0.05
	water_mesh.radial_segments = 64
	var water_mat := ShaderMaterial.new()
	water_mat.shader = preload("res://scripts/water.gdshader")
	_mesh(world,water_mesh,p+Vector3(0,0.025,0),Vector3(1.83,1,1.22),water_mat)
	var edge_mat := _mat("#b5af89")
	for i in range(20):
		var a := i*TAU/20.0
		var pp := p+Vector3(cos(a)*1.99,0.06,sin(a)*1.35)
		_sphere(world,pp,Vector3(0.17,0.11,0.13)*rng.randf_range(0.7,1.4),edge_mat,10)
	for i in range(3):
		var pp := p+Vector3(-0.6+i*0.54,0.07,0.23-i*0.38)
		var leaf := _cylinder(world,pp,0.34,0.035,_mat("#567f3f"),-1.0,20)
		leaf.scale.z = 0.85
		_sphere(world,pp+Vector3(0,0.02,0),Vector3(0.05,0.015,0.05),_mat("#c7c96f"),8)
	for i in range(4):
		var pp := p+Vector3(1.55,0,-0.7+i*0.3)
		_line(world,pp,pp+Vector3(-0.14,0.95+i*0.1,0),0.018,_mat("#496332"))
		_sphere(world,pp+Vector3(-0.14,1.02+i*0.1,0),Vector3(0.06,0.18,0.06),_mat("#775037"),10)

func _leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := [Vector3(0,0,0),Vector3(-0.4,0.04,-0.5),Vector3(0,0.18,-0.62),Vector3(0.4,0.04,-0.5),Vector3(0,0,-1.22)]
	for t in [[0,1,2],[0,2,3],[1,4,2],[2,4,3]]:
		for i in t: st.add_vertex(vertices[i])
	st.generate_normals()
	return st.commit()

func _build_clover(pos: Vector3, s: float) -> void:
	var mat := _mat("#679044")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stem := _mat("#527b37")
	for i in range(3):
		var a := i*TAU/3
		var center := pos+Vector3(cos(a)*0.5,1.4+0.13*i,sin(a)*0.5)*s
		_line(world,pos,center,0.035*s,stem)
		for j in range(3):
			var b := j*TAU/3
			var leaf := _sphere(world,center+Vector3(cos(b)*0.25,0,sin(b)*0.25)*s,Vector3(0.43,0.065,0.40)*s,mat,12)
			leaf.rotation.z = sin(b)*0.16
			_line(world,center,center+Vector3(cos(b)*0.54,0.03,sin(b)*0.54)*s,0.009*s,_mat("#a7c06a"))

func _build_flower(pos: Vector3, s: float, kind: int) -> void:
	var stem := _mat("#4c7136")
	var height := s*rng.randf_range(1.5,2.4)
	_line(world,pos,pos+Vector3(0.1,height,0),0.035*s,stem)
	var mat := _mat(["#f9e9b2","#e6a699","#b3b4df","#e4c35b"][kind])
	var center := pos+Vector3(0.1,height,0)
	var petal_mesh := SphereMesh.new()
	petal_mesh.radial_segments = 12
	petal_mesh.rings = 6
	petal_mesh.radius = 1
	petal_mesh.height = 2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = petal_mesh
	mm.instance_count = 7
	for i in range(7):
		var a := i*TAU/7
		var scale_v := Vector3(0.27,0.08,0.47)*s
		var basis := Basis(Vector3.UP,-a).scaled(scale_v)
		mm.set_instance_transform(i,Transform3D(basis,center+Vector3(sin(a)*0.32,0,cos(a)*0.32)*s))
	var petals := MultiMeshInstance3D.new()
	petals.multimesh = mm
	petals.material_override = mat
	world.add_child(petals)
	_sphere(world,center+Vector3(0,0.08,0),Vector3(0.25,0.14,0.25)*s,_mat("#cf963c"),12)
	var leaf := _mesh(world,_leaf_mesh(),pos+Vector3(0,height*0.52,0),Vector3.ONE*s*0.72,stem)
	leaf.rotation_degrees = Vector3(-22,rng.randf()*360.0,30)

func _build_mushroom(pos: Vector3, s: float, cap_color: String) -> void:
	obstacles.append({"pos":pos,"radius":0.62*s,"z_scale":1.0})
	_cylinder(world,pos+Vector3(0,0.68*s,0),0.23*s,1.36*s,_mat("#e9d8aa"),0.17*s)
	_sphere(world,pos+Vector3(0,1.4*s,0),Vector3(1.02,0.57,0.95)*s,_mat(cap_color),28)
	_sphere(world,pos+Vector3(0,1.27*s,0),Vector3(0.95,0.09,0.87)*s,_mat("#ebd5a5"),24)
	var spot := _mat("#ffe8b6")
	for i in range(11):
		var a := i*2.399
		var r := 0.78*sqrt(float(i)/11.0)
		var y := 1.42+0.53*sqrt(1.0-r*r)
		var n := _sphere(world,pos+Vector3(cos(a)*r,y,sin(a)*r)*s,Vector3(0.12,0.028,0.11)*s,spot,10)
		n.rotation.x = sin(a)*r*0.45
		n.rotation.z = -cos(a)*r*0.45
	_torus(world,pos+Vector3(0,0.94*s,0),0.17*s,0.3*s,_mat("#ead9b8"))

func _build_rock(pos: Vector3, s: float) -> void:
	obstacles.append({"pos":pos,"radius":s*0.72,"z_scale":0.8})
	var rock := _sphere(world,pos+Vector3(0,0.24*s,0),Vector3(0.9,0.56,0.68)*s,_mat("#929681"),9)
	rock.rotation.y = rng.randf()*TAU
	_sphere(world,pos+Vector3(-0.23*s,0.58*s,0.05*s),Vector3(0.44,0.06,0.29)*s,_mat("#81944a"),12)

func _build_log(pos: Vector3) -> void:
	var trunk := _cylinder(world,pos+Vector3(0,0.5,0),0.48,3.1,_mat("#795133"))
	trunk.rotation.z = PI/2
	var end := _cylinder(world,pos+Vector3(1.57,0.5,0),0.42,0.025,_mat("#cbac78"))
	end.rotation.z = PI/2
	for r in [0.12,0.23,0.34]:
		var ring := _torus(world,pos+Vector3(1.59,0.5,0),r-0.012,r+0.008,_mat("#9a784e"))
		ring.rotation.z = PI/2
	for i in range(5):
		var a := i*TAU/5
		_line(world,pos+Vector3(-1.5,0.5+sin(a)*0.44,cos(a)*0.44),pos+Vector3(1.4,0.5+sin(a)*0.44,cos(a)*0.44),0.028,_mat("#a27749"))

func _build_motes() -> void:
	var mat := _unshaded("#fff0bb")
	for i in range(22):
		var pos := Vector3(rng.randf_range(-13,13),rng.randf_range(0.8,4.0),rng.randf_range(-8,8))
		var n := _sphere(world,pos,Vector3.ONE*rng.randf_range(0.015,0.032),mat,6)
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		motes.append({"node":n,"origin":pos,"phase":rng.randf()*TAU})

func _build_navigation() -> void:
	nav.region = Rect2i(0,0,51,33)
	nav.cell_size = Vector2(0.5,0.5)
	nav.offset = Vector2(-12.5,-8.0)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for x in range(51):
		for y in range(33):
			var p := Vector3(-12.5+x*0.5,0,-8+y*0.5)
			nav.set_point_solid(Vector2i(x,y),not _walkable(p,0.23))

func _walkable(pos: Vector3, margin: float = 0.18) -> bool:
	if absf(pos.x)>BOUNDS.x or absf(pos.z)>BOUNDS.y: return false
	for obstacle in obstacles:
		var p: Vector3 = obstacle.pos
		var d := Vector2(pos.x-p.x,(pos.z-p.z)/float(obstacle.z_scale))
		if d.length()<float(obstacle.radius)+margin: return false
	return true

func _cell(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((pos.x+12.5)*2),0,50),clampi(roundi((pos.z+8)*2),0,32))

func _nearest_open(id: Vector2i) -> Vector2i:
	if not nav.is_point_solid(id): return id
	for r in range(1,9):
		for x in range(maxi(0,id.x-r),mini(50,id.x+r)+1):
			for y in range(maxi(0,id.y-r),mini(32,id.y+r)+1):
				var c := Vector2i(x,y)
				if not nav.is_point_solid(c): return c
	return Vector2i(10,21)

func _set_destination(pos: Vector3) -> void:
	if state != "playing": return
	path.clear()
	var start := _nearest_open(_cell(player.position))
	var dest := _nearest_open(_cell(pos))
	var cells := nav.get_id_path(start,dest)
	for id in cells:
		path.append(Vector3(-12.5+id.x*0.5,0,-8+id.y*0.5))
	if not path.is_empty():
		target_ring.position = path.back()+Vector3(0,0.065,0)
		target_ring.visible = true
		_hint("Bringing food home..." if carried >= 0 else "On my way!",2.0)

func _build_actors() -> void:
	player = Ant.new()
	add_child(player)
	player.position = NEST+Vector3(1.5,0,0.5)
	player.scale = Vector3.ONE*1.18
	for i in range(3):
		var ant := Ant.new()
		add_child(ant)
		ant.scale = Vector3.ONE*0.46
		ant.position = NEST+Vector3(cos(i*TAU/3)*1.6,0,sin(i*TAU/3)*1.5)
		workers.append({"node":ant,"phase":i*TAU/3})
	_build_beetle(Vector3(0.0,0,-3.0),0)
	_build_beetle(Vector3(7.7,0,3.0),1)

func _build_beetle(pos: Vector3, index: int) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	var body := _sphere(root,Vector3(0,0.32,0.12),Vector3(0.47,0.31,0.59),_mat("#455359",0.25),20)
	_sphere(root,Vector3(0,0.28,-0.42),Vector3(0.28,0.23,0.27),_mat("#304344"),16)
	_line(root,Vector3(0,0.62,-0.32),Vector3(0,0.62,0.61),0.012,_mat("#253f3b"))
	for side in [-1.0,1.0]:
		for i in range(3):
			_line(root,Vector3(side*0.22,0.21,-0.16+i*0.24),Vector3(side*0.59,0.025,-0.31+i*0.33),0.027,_mat("#31413b"))
		_sphere(root,Vector3(side*0.13,0.34,-0.63),Vector3.ONE*0.055,_mat("#ead78c"),10)
		_line(root,Vector3(side*0.12,0.38,-0.52),Vector3(side*0.29,0.45,-0.77),0.018,_mat("#3e4537"))
	beetles.append({"node":root,"origin":pos,"phase":float(index)*PI,"body":body})

func _make_food(parent: Node3D, kind: int, scale_f: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.scale = Vector3.ONE*scale_f
	if kind % 3 == 0:
		_sphere(root,Vector3(0,0.28,0),Vector3(0.34,0.34,0.31),_mat("#c44947",0.32),18)
		var leaf_mat := _mat("#658d3b")
		for i in range(4):
			var leaf := _mesh(root,_leaf_mesh(),Vector3(0,0.55,0),Vector3.ONE*0.28,leaf_mat)
			leaf.rotation.y = i*TAU/4
		var seed_mat := _mat("#f5c778")
		for i in range(12):
			var a := i*2.399
			var yy := 0.1+(i%4)*0.1
			var r := sqrt(maxf(0.01,0.34*0.34-pow(yy-0.28,2)))
			_sphere(root,Vector3(cos(a)*r,yy,sin(a)*r),Vector3(0.018,0.029,0.014),seed_mat,6)
	elif kind % 3 == 1:
		var mat := _mat("#62649a",0.31)
		for p in [Vector3(-0.13,0.22,0.1),Vector3(0.14,0.22,0.06),Vector3(0,0.4,-0.12)]:
			_sphere(root,p,Vector3.ONE*0.23,mat,16)
			_torus(root,p+Vector3(0,0.208,0),0.044,0.073,_mat("#8b8ba8"))
	else:
		var crumb := _sphere(root,Vector3(0,0.24,0),Vector3(0.34,0.26,0.30),_mat("#e8bb66"),7)
		crumb.rotation.y = 0.6
		for i in range(5):
			_sphere(root,Vector3(rng.randf_range(-0.2,0.2),0.47,rng.randf_range(-0.15,0.15)),Vector3.ONE*0.025,_mat("#a57b3c"),6)
	return root

func _spawn_food() -> void:
	for child in food_root.get_children(): child.queue_free()
	foods.clear()
	var count := mini(8,6+round_number-1)
	target_count = count
	for i in range(count):
		var p: Vector3 = FOOD_SPOTS[i]
		var root := Node3D.new()
		food_root.add_child(root)
		root.position = p
		var model := _make_food(root,i,1.15)
		var ring := _torus(root,Vector3(0,0.045,0),0.47,0.495,_unshaded("#e5d6a1"))
		foods.append({"node":root,"model":model,"ring":ring,"pos":p,"active":true,"kind":i,"phase":float(i)})
	_update_hud()

func _style(bg: Color, radius: int = 20, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left=radius
	s.corner_radius_top_right=radius
	s.corner_radius_bottom_left=radius
	s.corner_radius_bottom_right=radius
	s.border_color=border
	s.set_border_width_all(1)
	s.content_margin_left=20
	s.content_margin_right=20
	s.content_margin_top=14
	s.content_margin_bottom=14
	return s

func _label(text: String, size_px: int, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",size_px)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, min_size: Vector2, color: Color = GREEN) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size=min_size
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",INK)
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_color_override("font_disabled_color",Color("#8fa385"))
	b.add_theme_stylebox_override("normal",_style(color,18))
	b.add_theme_stylebox_override("hover",_style(color.lightened(0.1),18))
	b.add_theme_stylebox_override("pressed",_style(color.darkened(0.13),18))
	b.add_theme_stylebox_override("disabled",_style(Color("#345441"),18))
	b.focus_mode=Control.FOCUS_NONE
	b.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.pressed and not b.disabled:
			b.pressed.emit()
			b.accept_event()
	)
	return b

func _anchor(node: Control, left: float, top: float, right: float, bottom: float, offsets: Vector4) -> void:
	node.anchor_left=left
	node.anchor_top=top
	node.anchor_right=right
	node.anchor_bottom=bottom
	node.offset_left=offsets.x
	node.offset_top=offsets.y
	node.offset_right=offsets.z
	node.offset_bottom=offsets.w

func _build_ui() -> void:
	canvas=CanvasLayer.new()
	add_child(canvas)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var brand := PanelContainer.new()
	brand.add_theme_stylebox_override("panel",_style(Color("#173d2fe8"),20,Color("#dce5ab24")))
	ui.add_child(brand)
	_anchor(brand,0,0,0,0,Vector4(26,24,264,104))
	var brand_box := VBoxContainer.new()
	brand_box.add_theme_constant_override("separation",1)
	brand.add_child(brand_box)
	brand_box.add_child(_label("ANT MEADOW",23,GREEN))
	brand_box.add_child(_label("little world, big adventure",12,Color("#e2e5bf")))
	var quest := PanelContainer.new()
	ui.add_child(quest)
	_anchor(quest,0.5,0,0.5,0,Vector4(-185,24,185,124))
	quest.add_theme_stylebox_override("panel",_style(Color("#173d2fe8"),22,Color("#dce5ab24")))
	gameplay_hud.append(quest)
	var qbox := VBoxContainer.new()
	qbox.add_theme_constant_override("separation",5)
	quest.add_child(qbox)
	quest_label=_label("THE COLONY IS COUNTING ON YOU",15,GREEN)
	qbox.add_child(quest_label)
	quest_detail=_label("Gather food and bring it home.",18,CREAM)
	qbox.add_child(quest_detail)
	progress_bar=ProgressBar.new()
	progress_bar.custom_minimum_size=Vector2(0,5)
	progress_bar.show_percentage=false
	progress_bar.add_theme_stylebox_override("background",_style(Color("#4b6441"),3))
	progress_bar.add_theme_stylebox_override("fill",_style(GOLD,3))
	qbox.add_child(progress_bar)
	var right := VBoxContainer.new()
	right.alignment=BoxContainer.ALIGNMENT_END
	ui.add_child(right)
	_anchor(right,1,0,1,0,Vector4(-228,24,-26,122))
	var buttons := HBoxContainer.new()
	buttons.alignment=BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation",10)
	right.add_child(buttons)
	sound_button=_button("SOUND ON",Vector2(118,44),Color("#e5dfb9"))
	sound_button.add_theme_font_size_override("font_size",13)
	sound_button.pressed.connect(_toggle_sound)
	buttons.add_child(sound_button)
	pause_button=_button("II",Vector2(48,44),Color("#e5dfb9"))
	pause_button.pressed.connect(_toggle_pause)
	buttons.add_child(pause_button)
	heart_label=_label("♥  ♥  ♥",26,Color("#f8df9e"))
	heart_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	heart_label.add_theme_color_override("font_shadow_color",Color("#173d2f"))
	heart_label.add_theme_constant_override("shadow_offset_y",2)
	gameplay_hud.append(heart_label)
	right.add_child(heart_label)
	score_label=_label("BEST 0  /  DAY 01",12,CREAM)
	score_label.add_theme_color_override("font_shadow_color",INK)
	score_label.add_theme_constant_override("shadow_offset_y",1)
	gameplay_hud.append(score_label)
	score_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(score_label)
	pad=TouchPad.new()
	ui.add_child(pad)
	_anchor(pad,0,1,0,1,Vector4(33,-179,177,-35))
	pad.direction_changed.connect(func(value: Vector2): joystick=value; path.clear(); target_ring.visible=false)
	var movement_text := _label("DRAG TO MOVE",11,Color("#fff3d1b0"))
	pad.add_child(movement_text)
	movement_text.position=Vector2(17,140)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	gameplay_hud.append(actions)
	ui.add_child(actions)
	_anchor(actions,1,1,1,1,Vector4(-340,-100,-26,-32))
	home_button=_button("⌂  GO HOME",Vector2(146,60),Color("#f1e6bd"))
	home_button.pressed.connect(_go_home)
	actions.add_child(home_button)
	dash_button=_button("BURST  ››",Vector2(148,60),GREEN)
	dash_button.pressed.connect(_dash)
	actions.add_child(dash_button)
	var hint_panel := PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel",_style(Color("#173d2fd9"),18))
	gameplay_hud.append(hint_panel)
	ui.add_child(hint_panel)
	_anchor(hint_panel,0.5,1,0.5,1,Vector4(-240,-79,190,-28))
	hint_label=_label("Tap anywhere to explore.",15,CREAM)
	hint_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.add_child(hint_label)
	screen_flash=ColorRect.new()
	screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_flash.color=Color(0.85,0.22,0.12,0)
	screen_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen_flash)
	_world_tag("HOME",NEST+Vector3(0,1.25,0),GOLD)
	_build_overlay()

func _world_tag(text: String, pos: Vector3, color: Color) -> void:
	var l := _label(text,12,color)
	l.add_theme_color_override("font_shadow_color",Color("#16382bd0"))
	l.add_theme_constant_override("shadow_offset_y",2)
	ui.add_child(l)
	world_labels.append(l)
	label_anchors.append(pos)

func _build_overlay() -> void:
	overlay=Control.new()
	ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color=Color(0.02,0.10,0.06,0.18)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(veil)
	modal_card=PanelContainer.new()
	overlay.add_child(modal_card)
	_anchor(modal_card,0,0.5,0,0.5,Vector4(52,-222,508,222))
	var box_style := _style(Color("#12392bf5"),28,Color("#e8e8ba35"))
	box_style.content_margin_left=32
	box_style.content_margin_right=32
	box_style.content_margin_top=30
	box_style.content_margin_bottom=26
	modal_card.add_theme_stylebox_override("panel",box_style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",16)
	modal_card.add_child(v)
	modal_kicker=_label("A LITTLE GARDEN ADVENTURE",13,GREEN)
	v.add_child(modal_kicker)
	modal_title=_label("A tiny hero.\nA whole garden.",42,CREAM)
	modal_title.add_theme_constant_override("line_spacing",-3)
	v.add_child(modal_title)
	modal_text=_label("Gather berries. Dodge the beetles.\nBring a little goodness back home.",18,Color("#dbdfbe"))
	modal_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	v.add_child(modal_text)
	primary_button=_button("LET'S EXPLORE  →",Vector2(0,58),GREEN)
	primary_button.pressed.connect(_primary_action)
	v.add_child(primary_button)
	secondary_button=_button("START AGAIN",Vector2(0,48),Color("#e5dbb6"))
	secondary_button.pressed.connect(_secondary_action)
	v.add_child(secondary_button)
	secondary_button.visible=false
	foot_label=_label("Tap to walk  ·  Drag to steer  ·  Burst to escape",12,Color("#c5d19b"))
	v.add_child(foot_label)

func _show_menu() -> void:
	state="menu"
	print("ANT_STATE:menu")
	player.position=Vector3(0.0,0,1.4)
	player.rotation.y=-2.6
	player.scale=Vector3.ONE*1.65
	for control in gameplay_hud: control.visible=false
	overlay.visible=true
	pad.visible=false
	home_button.disabled=true
	dash_button.disabled=true
	pause_button.disabled=true

func _start_game() -> void:
	if state=="menu":
		player.position=NEST+Vector3(1.5,0,0.5)
		player.rotation.y=-2.6
		player.scale=Vector3.ONE*1.18
	state="playing"
	print("ANT_STATE:playing")
	for control in gameplay_hud: control.visible=true
	overlay.visible=false
	pad.visible=true
	home_button.disabled=false
	dash_button.disabled=false
	pause_button.disabled=false
	_hint("Tap a berry to collect it, then tap GO HOME.",7.0)

func _reset_game() -> void:
	carried=-1
	for child in player.load_holder.get_children(): child.queue_free()
	score=0
	health=3
	delivered=0
	round_number=1
	elapsed=0
	immunity=0
	dash_left=0
	dash_cooldown=0
	path.clear()
	joystick=Vector2.ZERO
	pad.release()
	player.position=NEST+Vector3(1.5,0,0.5)
	player.rotation.y=0
	target_ring.visible=false
	_spawn_food()
	_start_game()

func _primary_action() -> void:
	match state:
		"menu": _start_game()
		"paused": _resume()
		"won": _next_round()
		"gameover": _reset_game()

func _secondary_action() -> void:
	_reset_game()

func _go_home() -> void:
	if state!="playing": return
	_set_destination(NEST+Vector3(0.8,0,0.5))
	_hint("Heading home with a tasty delivery!" if carried>=0 else "Back to the nest. Find food along the way.",3.0)

func _dash() -> void:
	if state!="playing" or dash_cooldown>0: return
	dash_left=0.65
	print("ANT_BURST")
	dash_cooldown=4.0
	immunity=maxf(immunity,0.8)
	_hint("Quick little feet!",1.2)
	_play_sound("burst")

func _toggle_sound() -> void:
	sound_on=not sound_on
	sound_button.text="SOUND ON" if sound_on else "SOUND OFF"
	if is_instance_valid(ambience): ambience.volume_db=-25.0 if sound_on else -80.0

func _toggle_pause() -> void:
	if state=="playing":
		state="paused"
		print("ANT_STATE:paused")
		joystick=Vector2.ZERO
		pad.release()
		_show_modal("TAKE A BREATHER","A little pause.","Your garden will be right here.","BACK TO THE GARDEN",true)
	elif state=="paused": _resume()

func _resume() -> void:
	state="playing"
	print("ANT_STATE:playing")
	print("ANT_RESUMED:",score)
	overlay.visible=false
	pad.visible=true

func _show_modal(kicker: String,title: String,body: String,button: String,show_again: bool) -> void:
	modal_kicker.text=kicker
	modal_title.text=title
	modal_text.text=body
	primary_button.text=button
	secondary_button.visible=show_again
	foot_label.text="Your best score is saved on this device."
	overlay.visible=true
	pad.visible=false

func _next_round() -> void:
	round_number+=1
	delivered=0
	health=mini(3,health+1)
	path.clear()
	immunity=2.0
	_spawn_food()
	_start_game()
	_hint("A new day! The beetles are a little quicker.",4.0)

func _win() -> void:
	state="won"
	path.clear()
	target_ring.visible=false
	score+=50*round_number
	_store_best()
	_update_hud()
	_burst_particles(NEST+Vector3(0,0.5,0),GOLD,32)
	_play_sound("win")
	_show_modal("A GOOD DAY FOR THE COLONY","Little ant.\nBig delivery.","All %d snacks are home! Score: %d\nReady for another day in the garden?"%[target_count,score],"ONE MORE ADVENTURE  →",false)

func _take_hit() -> void:
	if immunity>0 or state!="playing": return
	health-=1
	immunity=2.5
	screen_flash.color.a=0.24
	_burst_particles(player.position+Vector3(0,0.4,0),Color("#e5ac70"),10)
	_play_sound("hit")
	if carried>=0:
		var food: Dictionary=foods[carried]
		food.active=true
		food.node.visible=true
		carried=-1
		for child in player.load_holder.get_children(): child.queue_free()
		_hint("Oops! Your snack is back where you found it.",4.0)
	else:
		_hint("Watch those beetles! Use BURST to escape.",4.0)
	player.position=NEST+Vector3(1.4,0,0.8)
	path.clear()
	target_ring.visible=false
	_update_hud()
	if health<=0:
		state="gameover"
		_store_best()
		_show_modal("EVERY ANT NEEDS A REST","Try a new trail.","You brought home %d snacks. Score: %d\nThe next little adventure is waiting."%[delivered,score],"LET'S TRY AGAIN  →",false)

func _pickup(index: int) -> void:
	if carried>=0 or not foods[index].active: return
	carried=index
	print("ANT_PICKUP:",index)
	foods[index].active=false
	foods[index].node.visible=false
	_make_food(player.load_holder,index,0.65)
	path.clear()
	target_ring.visible=false
	_burst_particles(player.position+Vector3(0,0.6,0),GOLD,12)
	_play_sound("pickup")
	_hint("Got a snack! Tap GO HOME to deliver it.",6.0)
	_update_hud()

func _deliver() -> void:
	if carried<0: return
	carried=-1
	for child in player.load_holder.get_children(): child.queue_free()
	delivered+=1
	print("ANT_DELIVER:",delivered)
	score+=10*round_number
	_burst_particles(NEST+Vector3(0,0.5,0),GREEN,18)
	_play_sound("delivery")
	_hint("Delivered! %d more snacks to find."%(target_count-delivered),4.0)
	_update_hud()
	if delivered>=target_count: _win()

func _update_hud() -> void:
	if not is_instance_valid(quest_detail): return
	quest_label.text="DAY %02d  ·  FEED THE COLONY"%round_number
	quest_detail.text="%d / %d home  ·  %s"%[delivered,target_count,"carrying a snack" if carried>=0 else "find something tasty"]
	progress_bar.max_value=target_count
	progress_bar.value=delivered
	var hearts := PackedStringArray()
	for i in range(3): hearts.append("♥" if i<health else "♡")
	heart_label.text="  ".join(hearts)
	score_label.text="SCORE %d  /  BEST %d"%[score,maxi(best,score)]
	home_button.text="⌂  DELIVER" if carried>=0 else "⌂  GO HOME"

func _hint(message: String,duration: float) -> void:
	if is_instance_valid(hint_label): hint_label.text=message
	hint_time=duration

func _physics_process(delta: float) -> void:
	if test_mode: return
	_step_game(minf(delta,0.05))

func _step_game(delta: float) -> void:
	if state!="playing": return
	elapsed+=delta
	dash_left=maxf(0,dash_left-delta)
	dash_cooldown=maxf(0,dash_cooldown-delta)
	immunity=maxf(0,immunity-delta)
	hint_time=maxf(0,hint_time-delta)
	if hint_time<=0:
		hint_label.text="Carrying a snack. Take it home!" if carried>=0 else "Find food. Bring it home. Mind the beetles."
	dash_button.disabled=dash_cooldown>0
	dash_button.text="%.1fs"%dash_cooldown if dash_cooldown>0 else "BURST  ››"
	var direction := Vector3.ZERO
	var move_input := joystick
	var keys := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if keys.length()>0:
		move_input=keys.limit_length()
		path.clear()
	if move_input.length()>0.1:
		var right := camera.global_basis.x
		var forward := camera.global_basis.z
		right.y=0
		forward.y=0
		direction=(right.normalized()*move_input.x+forward.normalized()*move_input.y).limit_length()
		target_ring.visible=false
	elif not path.is_empty():
		while not path.is_empty() and player.position.distance_to(path[0])<0.18:
			path.pop_front()
		if not path.is_empty(): direction=(path[0]-player.position).normalized()
		else: target_ring.visible=false
	var speed := 7.4 if dash_left>0 else 3.55
	if carried>=0: speed*=0.91
	var next := player.position+direction*speed*delta
	if _walkable(next,0.12):
		player.position=next
	elif direction.length()>0:
		var xx := Vector3(next.x,0,player.position.z)
		var zz := Vector3(player.position.x,0,next.z)
		if _walkable(xx,0.12): player.position=xx
		elif _walkable(zz,0.12): player.position=zz
	player.position.y=0
	if direction.length()>0.05: player.rotation.y=lerp_angle(player.rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*13))
	player.animate(delta,direction.length()*speed)
	player.visible=immunity<=0 or fmod(immunity,0.2)>0.06
	# Automatic collection and delivery keep the controls simple.
	if carried<0:
		for i in range(foods.size()):
			if foods[i].active and player.position.distance_to(foods[i].pos)<0.74:
				_pickup(i)
				break
	if carried>=0 and player.position.distance_to(NEST)<1.35: _deliver()
	for beetle in beetles:
		var p: Vector3=beetle.origin
		var phase := elapsed*(0.42+round_number*0.035)+float(beetle.phase)
		var next_pos := p+Vector3(sin(phase)*2.0,0,cos(phase*0.87)*1.15)
		var node: Node3D=beetle.node
		var diff := next_pos-node.position
		if diff.length()>0.001: node.rotation.y=atan2(-diff.x,-diff.z)
		node.position=next_pos
		beetle.body.position.y=0.32+sin(elapsed*14)*0.014
		if player.position.distance_to(next_pos)<0.82: _take_hit()
	if dash_left>0 and int(elapsed*45)%3==0:
		_burst_particles(player.position+Vector3(0,0.12,0),Color("#e3d598"),1)

func _process(delta: float) -> void:
	time+=delta
	frame_count+=1
	screen_flash.color.a=maxf(0,screen_flash.color.a-delta*0.9)
	# UI follows projection, including ultrawide Android aspect ratios.
	for i in range(world_labels.size()):
		world_labels[i].position=camera.unproject_position(label_anchors[i])-world_labels[i].size/2
	for f in foods:
		if f.active:
			f.model.position.y=0.06+sin(time*2.0+f.phase)*0.045
			f.model.rotation.y=time*0.24+f.phase
			f.ring.scale=Vector3.ONE*(1.0+sin(time*2+f.phase)*0.04)
	home_ring.visible=state!="menu"
	home_ring.scale=Vector3.ONE*(1+sin(time*2.2)*0.035) if carried>=0 else Vector3.ONE
	for worker in workers:
		var phase := time*0.28+float(worker.phase)
		var ant: Node3D=worker.node
		var pp := NEST+Vector3(cos(phase)*1.75,0,sin(phase)*1.4)
		var d := pp-ant.position
		ant.position=pp
		if d.length()>0.0001: ant.rotation.y=atan2(-d.x,-d.z)
		ant.animate(delta,1.2)
	if state!="playing":
		player.visible=true
		player.animate(delta,0)
	for mote in motes:
		var origin: Vector3=mote.origin
		mote.node.position=origin+Vector3(sin(time*0.3+mote.phase)*0.4,sin(time*0.5+mote.phase)*0.15,cos(time*0.25+mote.phase)*0.3)
	_update_effects(delta)
	if not capture_path.is_empty() and frame_count==32:
		call_deferred("_capture")

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var error := img.save_png(capture_path)
	print("CAPTURE_RESULT ",error," ",capture_path)
	await _safe_quit(0 if error==OK else 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE: _toggle_pause()
		elif event.physical_keycode==KEY_SPACE: _dash()
		elif event.physical_keycode==KEY_H: _go_home()
	if state!="playing": return
	if event is InputEventScreenTouch and event.pressed:
		_tap_world(event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_tap_world(event.position)

func _tap_world(point: Vector2) -> void:
	var origin := camera.project_ray_origin(point)
	var ray := camera.project_ray_normal(point)
	if absf(ray.y)<0.001: return
	var hit := origin+ray*(-origin.y/ray.y)
	_set_destination(Vector3(hit.x,0,hit.z))

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and state=="playing": _toggle_pause()

func _burst_particles(pos: Vector3,color: Color,count: int) -> void:
	var mat := _unshaded(color.to_html())
	for i in range(count):
		var n := _sphere(fx_root,pos,Vector3.ONE*rng.randf_range(0.025,0.065),mat,5)
		n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effects.append({"node":n,"v":Vector3(rng.randf_range(-1.5,1.5),rng.randf_range(0.7,2.0),rng.randf_range(-1.5,1.5)),"life":rng.randf_range(0.4,0.8)})

func _update_effects(delta: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var f: Dictionary=effects[i]
		f.life-=delta
		if f.life<=0:
			f.node.queue_free()
			effects.remove_at(i)
		else:
			f.v.y-=delta*3.0
			f.node.position+=f.v*delta
			f.node.scale*=maxf(0,1-delta*1.1)

func _audio_setup() -> void:
	sfx=AudioStreamPlayer.new()
	add_child(sfx)
	sfx.volume_db=-14
	ambience=AudioStreamPlayer.new()
	add_child(ambience)
	var stream=load("res://assets/garden.wav")
	if stream:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=int(stream.get_length()*stream.mix_rate)
		ambience.stream=stream
		ambience.volume_db=-25
		ambience.play()

func _play_sound(which: String) -> void:
	if not sound_on or test_mode: return
	var file := "res://assets/"+which+".wav"
	if ResourceLoader.exists(file):
		sfx.stream=load(file)
		sfx.play()

func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load("user://meadow.cfg")==OK:
		best=int(config.get_value("game","best",0))

func _store_best() -> void:
	best=maxi(best,score)
	if test_mode: return
	var config := ConfigFile.new()
	config.set_value("game","best",best)
	config.save("user://meadow.cfg")

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream=null
	if is_instance_valid(sfx):
		sfx.stop()
		sfx.stream=null

func _safe_quit(code: int) -> void:
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream=null
	if is_instance_valid(sfx):
		sfx.stop()
		sfx.stream=null
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(code)

func _check(condition: bool,description: String) -> void:
	if not condition:
		push_error("TEST FAILED: "+description)
		get_tree().quit(2)
		assert(condition,description)
	tests_passed.append(description)
	print("PASS: ",description)

func _test_touch_at(point: Vector2,index: int=0,pressed: bool=true) -> void:
	var touch:=InputEventScreenTouch.new()
	touch.index=index
	touch.position=point
	touch.pressed=pressed
	get_viewport().push_input(touch,true)
	await get_tree().process_frame

func _run_tests() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_check(state=="menu","title screen loads")
	_check(foods.size()==6,"six snacks exist in first expedition")
	_check(player.get_child_count()>0 and world.get_child_count()>100,"garden and ant geometry constructed")
	var play_point:=primary_button.get_global_rect().get_center()
	await _test_touch_at(play_point)
	await _test_touch_at(play_point,0,false)
	_check(state=="playing","real touch activates the play button")
	_check(state=="playing" and not overlay.visible,"play button starts the game")
	var pad_point:=pad.get_global_rect().get_center()+Vector2(34,0)
	await _test_touch_at(pad_point,1,true)
	_check(joystick.length()>0.2,"touch pad steers the ant")
	await _test_touch_at(pad_point,1,false)
	_check(joystick==Vector2.ZERO,"releasing the touch pad stops manual movement")
	# Exercise the real world-tap projection and navigation.
	var food_point_test:=camera.unproject_position(FOOD_SPOTS[0])
	await _test_touch_at(food_point_test)
	await _test_touch_at(food_point_test,0,false)
	_check(not path.is_empty(),"world tap builds a navigation path")
	var start_pos: Vector3=player.position
	_step_game(0.1)
	_check(player.position.distance_to(start_pos)>0.01,"ant follows a tapped destination")
	for f in foods:
		var cells:=nav.get_id_path(_nearest_open(_cell(NEST)),_nearest_open(_cell(f.pos)))
		_check(cells.size()>1,"food %d reachable from home"%int(f.kind))
	_set_destination(Vector3(3.6,0,-1.7))
	_check(not path.is_empty() and _walkable(path.back()),"pond tap resolves to reachable shoreline")
	var before:=elapsed
	_toggle_pause()
	_step_game(1.0)
	_check(state=="paused" and elapsed==before,"pause freezes game simulation")
	await get_tree().process_frame
	await get_tree().process_frame
	var resume_point_test:=primary_button.get_global_rect().get_center()
	await _test_touch_at(resume_point_test)
	await _test_touch_at(resume_point_test,0,false)
	_check(state=="playing","resume works")
	_check(elapsed==before,"touching resume preserves the current expedition")
	var burst_point_test:=dash_button.get_global_rect().get_center()
	await _test_touch_at(burst_point_test)
	await _test_touch_at(burst_point_test,0,false)
	_check(dash_left>0 and dash_cooldown>0,"burst starts and enters cooldown")
	_dash()
	_check(dash_cooldown==4.0,"burst cannot bypass cooldown")
	immunity=0
	_take_hit()
	_check(health==2 and immunity>0,"beetle hit removes one heart and grants protection")
	_take_hit()
	_check(health==2,"protection prevents repeated contact damage")
	# Walk every actual route with the real movement, pickup and delivery code.
	health=3
	for beetle in beetles: beetle.node.position=Vector3(50,0,50)
	for i in range(6):
		immunity=1000
		_set_destination(FOOD_SPOTS[i])
		var ticks:=0
		while carried<0 and ticks<2600:
			_step_game(1.0/60.0)
			ticks+=1
		_check(carried==i,"walk to and collect snack %d"%i)
		_go_home()
		ticks=0
		while carried>=0 and ticks<2600:
			_step_game(1.0/60.0)
			ticks+=1
		_check(carried<0 and delivered==i+1,"return and deliver snack %d"%i)
		await get_tree().process_frame
	_check(state=="won" and score==110,"complete expedition reaches victory with correct score")
	_primary_action()
	_check(state=="playing" and round_number==2 and target_count==7,"next day adds food and continues game")
	_pickup(0)
	immunity=0
	_take_hit()
	_check(carried<0 and foods[0].active,"a hit returns carried food to its source")
	immunity=0
	_take_hit()
	immunity=0
	_take_hit()
	_check(state=="gameover","losing all hearts reaches retry screen")
	_primary_action()
	_check(state=="playing" and health==3 and score==0 and round_number==1,"retry resets all game state")
	_check(_walkable(player.position),"restart puts ant on safe ground")
	_toggle_sound()
	_check(not sound_on,"sound control works")
	_toggle_sound()
	_check(sound_on,"sound can be restored")
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var food_point := camera.unproject_position(FOOD_SPOTS[0])/viewport_size
	var home_point := home_button.get_global_rect().get_center()/viewport_size
	var burst_point := dash_button.get_global_rect().get_center()/viewport_size
	var resume_point:=resume_point_test/viewport_size
	var report := {"passed":tests_passed.size(),"tests":tests_passed,"engine":Engine.get_version_info().string,"status":"PASS","touch_targets":{"food0":[food_point.x,food_point.y],"home":[home_point.x,home_point.y],"burst":[burst_point.x,burst_point.y],"resume":[resume_point.x,resume_point.y]}}
	var file:=FileAccess.open("res://../out/gameplay-tests.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"  "))
	print("ALL GAMEPLAY TESTS PASSED: ",tests_passed.size())
	await _safe_quit(0)

