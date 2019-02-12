extends Spatial

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
var tex_width = 1024
var male_raster = []
var female_raster = []
var rect_size = Vector2(tex_width, tex_width)
var orig_mesh: ArrayMesh
func update_mesh(value, who):
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(orig_mesh, 0)
	if who == "male":
		for k in range(mdt.get_vertex_count()):
			var uv = mdt.get_vertex_uv(k)
			var coords = uv * rect_size
			var v = mdt.get_vertex(k)
			v += male_raster[coords.y * rect_size.x + coords.x] * value
			mdt.set_vertex(k, v)
	elif who == "female":
		for k in range(mdt.get_vertex_count()):
			var uv = mdt.get_vertex_uv(k)
			var coords = uv * rect_size
			var v = mdt.get_vertex(k)
			v += female_raster[coords.y * rect_size.x + coords.x] * value
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
	orig_mesh = $MeshInstance.mesh.duplicate()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
