extends Spatial

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
var male_raster = {}
var female_raster = {}
var orig_mesh: ArrayMesh
func get_avg(raster:Dictionary, x:int, y:int):
	var rect_size = raster.size
	var v = raster.raster[y * rect_size.x + x]
	return v
func update_mesh(value, who):
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(orig_mesh.duplicate(true), 0)
	print(who, ": ", value)
	if who == "male":
		var rect_size = male_raster.size
		for k in range(mdt.get_vertex_count()):
			var uv = mdt.get_vertex_uv(k)
			var coords = uv * rect_size
			var v = mdt.get_vertex(k)
			v += get_avg(male_raster, coords.x, coords.y) * value
			mdt.set_vertex(k, v)
	elif who == "female":
		var rect_size = female_raster.size
		for k in range(mdt.get_vertex_count()):
			var uv = mdt.get_vertex_uv(k)
			var coords = uv * rect_size
			var v = mdt.get_vertex(k)
			v += get_avg(female_raster, coords.x, coords.y) * value
			mdt.set_vertex(k, v)
	var mesh = ArrayMesh.new()
	$MeshInstance.hide()
	yield(get_tree(), "idle_frame")
	mdt.commit_to_surface(mesh)
	$MeshInstance.mesh = mesh
	$MeshInstance.show()

func _ready():
	var fd = File.new()
	fd.open("res://male-base.raster", File.READ)
	male_raster = fd.get_var()
	fd.close()
	fd.open("res://female-base.raster", File.READ)
	female_raster = fd.get_var()
	fd.close()
	print(male_raster.size())
	print(female_raster.size())
	$Control/VBoxContainer/female.connect("value_changed", self, "update_mesh", ["female"])
	$Control/VBoxContainer/male.connect("value_changed", self, "update_mesh", ["male"])
	orig_mesh = load("res://obj/base_data.obj")

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
