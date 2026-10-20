extends Node3D

var gait := 0.0
var walking := false
var body: Node3D
var legs: Array[Node3D] = []
var antennae: Array[Node3D] = []
var load_holder: Node3D
var size_factor := 1.0

func _ready() -> void:
	build()

func material(color: Color, roughness: float = 0.42) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func sphere(parent: Node3D, pos: Vector3, sz: Vector3, mat: Material) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	s.mesh = mesh
	s.material_override = mat
	s.position = pos
	s.scale = sz
	parent.add_child(s)
	return s

func bone(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var s := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 7
	s.mesh = mesh
	s.material_override = mat
	parent.add_child(s)
	s.position = (a + b) / 2.0
	var direction := (b - a).normalized()
	s.quaternion = Quaternion(Vector3.UP, direction)

func build() -> void:
	body = Node3D.new()
	add_child(body)
	var amber := material(Color("#b65d27"))
	var gold := material(Color("#df8b38"))
	var dark := material(Color("#53301e"))
	var joint := material(Color("#85502b"))
	var white := material(Color("#fff2d7"))
	var black := material(Color("#10271e"), 0.2)
	sphere(body, Vector3(0, 0.42, 0.52), Vector3(0.34, 0.32, 0.47), dark)
	sphere(body, Vector3(0, 0.45, 0.03), Vector3(0.20, 0.22, 0.29), amber)
	sphere(body, Vector3(0, 0.53, -0.46), Vector3(0.32, 0.29, 0.32), gold)
	sphere(body, Vector3(0, 0.49, 0.23), Vector3(0.12, 0.12, 0.13), joint)
	sphere(body, Vector3(-0.1, 0.62, -0.52), Vector3(0.12, 0.1, 0.20), material(Color("#f1ab50")))
	for side in [-1.0, 1.0]:
		sphere(body, Vector3(side * 0.215, 0.61, -0.64), Vector3(0.13, 0.135, 0.09), white)
		sphere(body, Vector3(side * 0.22, 0.626, -0.715), Vector3(0.068, 0.078, 0.04), black)
		sphere(body, Vector3(side * 0.22 - 0.019, 0.658, -0.748), Vector3.ONE * 0.021, white)
		for i in range(3):
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.11, 0.34, -0.16 + i * 0.25)
			body.add_child(pivot)
			var knee := Vector3(side * 0.43, 0.02, -0.22 + i * 0.20)
			var foot := Vector3(side * 0.66, -0.30, -0.29 + i * 0.28)
			bone(pivot, Vector3.ZERO, knee, 0.032, joint)
			bone(pivot, knee, foot, 0.026, dark)
			sphere(pivot, knee, Vector3.ONE * 0.044, amber)
			legs.append(pivot)
		var feeler := Node3D.new()
		feeler.position = Vector3(side * 0.18, 0.72, -0.55)
		body.add_child(feeler)
		bone(feeler, Vector3.ZERO, Vector3(side * 0.13, 0.24, -0.10), 0.018, dark)
		bone(feeler, Vector3(side * 0.13, 0.24, -0.10), Vector3(side * 0.23, 0.28, -0.34), 0.016, amber)
		sphere(feeler, Vector3(side * 0.23, 0.28, -0.34), Vector3.ONE * 0.038, gold)
		antennae.append(feeler)
	load_holder = Node3D.new()
	load_holder.position = Vector3(0, 0.58, -0.94)
	body.add_child(load_holder)

func animate(delta: float, speed: float) -> void:
	gait += delta * (13.0 if speed > 0.1 else 2.0)
	body.position.y = abs(sin(gait * 2.0)) * 0.035 if speed > 0.1 else sin(gait) * 0.009
	for i in range(legs.size()):
		var side := -1.0 if i < 3 else 1.0
		var phase := gait + (i % 3) * PI + (PI if i >= 3 else 0.0)
		legs[i].rotation.y = sin(phase) * 0.32 if speed > 0.1 else 0.0
		legs[i].rotation.z = side * maxf(0, sin(phase)) * 0.24 if speed > 0.1 else 0.0
	for i in range(antennae.size()):
		antennae[i].rotation.y = sin(gait * 0.48 + i * 1.4) * 0.16
		antennae[i].rotation.x = sin(gait * 0.32 + i) * 0.06

