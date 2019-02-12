extends Node

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.

var tex_width = 1024

func substract_image(img: Image, base: Image) -> Image:
	var result: Image = Image.new()
	result.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGB8)
	result.lock()
	img.lock()
	base.lock()
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var main = img.get_pixel(x, y)
			var subs = base.get_pixel(x, y)
			var r = Vector3(main.r - subs.r, main.g - subs.g, main.b - subs.b)
			r = Vector3(r.x + 0.5, r.y + 0.5, r.z + 0.5)
			print(r)
			result.set_pixel(x, y, Color(r.x, r.y, r.z))
	base.unlock()
	img.unlock()
	result.unlock()
	return result
func raster2png(raster: Array, rect_size: Vector2) -> Image:
	var result : = Image.new()
	result.create(rect_size.x, rect_size.y, false, Image.FORMAT_RGBF)
	result.lock()
	for k in range(rect_size.y):
		for l in range(rect_size.x):
			result.set_pixel(l, k, Color(raster[k * rect_size.x + l].x * 0.5 + 0.5, raster[k * rect_size.x + l].y * 0.5 + 0.5, raster[k * rect_size.x + l].z * 0.5 + 0.5))
	result.unlock()
	return result
func substract_raster(raster: Array, base: Array) -> Array:
	var result = raster.duplicate(true)
	for k in range(raster.size()):
		result[k] = raster[k] - base[k]
	return result

func rasterize_triangle(raster: Array, polygon: Array, colors: Array, rect_size: Vector2) -> void:
	var queue = [[polygon, colors]]
	while queue.size() > 0:
		var poly = queue[0][0]
		var col = queue[0][1]
		queue.pop_front()
		var v1 = poly[0]
		var v2 = poly[1]
		var v3 = poly[2]
		var edges = [[0, 1], [1, 2], [2, 0]]
		var l = 0.0
		var largest = -1
		for k in range(edges.size()):
			var ls = (poly[edges[k][1]] - poly[edges[k][0]]).length()
			if ls > l && ls > 0.5:
				l = ls
				largest = k
		if largest < 0:
			continue
		var psplit: Vector2 = poly[edges[largest][0]].linear_interpolate(poly[edges[largest][1]], 0.5)
		var csplit: Vector3 = col[edges[largest][0]].linear_interpolate(col[edges[largest][1]], 0.5)
		raster[rect_size.x * int(psplit.y) + int(psplit.x)] = csplit
		var new_poly1 = []
		var new_colors1 = []
		var new_poly2 = []
		var new_colors2 = []
		match(largest):
			0:
				new_poly1 = [poly[0], psplit, poly[2]]
				new_colors1 = [col[0], csplit, col[2]]
				new_poly2 = [psplit, poly[1], poly[2]]
				new_colors2 = [csplit, col[1], col[2]]
			1:
				new_poly1 = [poly[0], poly[1], psplit]
				new_colors1 = [col[0], col[1], csplit]
				new_poly2 = [poly[0], psplit, poly[2]]
				new_colors2 = [col[0], csplit, col[2]]
			2:
				new_poly1 = [poly[0], poly[1], psplit]
				new_colors1 = [col[0], col[1], csplit]
				new_poly2 = [psplit, poly[1], poly[2]]
				new_colors2 = [csplit, col[1], col[2]]
		queue.push_back([new_poly1, new_colors1])
		queue.push_back([new_poly2, new_colors2])

func build(mesh: ArrayMesh, rect_size: Vector2) -> Array:
	var raster = []
	raster.resize(rect_size.x * rect_size.y)
	for k in range(raster.size()):
		raster[k] = Vector3()
	var mdt: = MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	var aabb = AABB()
	print("rendering vertices: ", mdt.get_vertex_count())
	for k in range(mdt.get_vertex_count()):
		aabb = aabb.expand(mdt.get_vertex(k))
	for k in range(mdt.get_face_count()):
		var polygon = []
		var fcolors = []
		for h in range(3):
			var e = mdt.get_face_vertex(k, h)
			var v = (mdt.get_vertex(e) - aabb.position) / (aabb.size.length() * 2.0)
			var uv = mdt.get_vertex_uv(e) * rect_size
			polygon.push_back(uv)
			fcolors.push_back(mdt.get_vertex(e))
		print("polygon: ", k, " ", mdt.get_face_count())
		rasterize_triangle(raster, polygon, fcolors, rect_size)
	return raster

func thread_runner(userdata):
	var raster = build(userdata, Vector2(tex_width, tex_width))
	return raster
func _ready():
	var meshes = {
		"base": {
			"path": "res://base.png",
			"mesh": load("res://obj/base_data.obj")
		},
		"female": {
			"path": "res://female.png",
			"mesh": load("res://obj/female_data.obj")
		},
		"male": {
			"path": "res://male.png",
			"mesh": load("res://obj/male_data.obj")
		}
	}
	for k in meshes.keys():
		var thread = Thread.new()
		thread.start(self, "thread_runner", meshes[k].mesh)
		meshes[k].thread = thread
	for k in meshes.keys():
		var thread = meshes[k].thread
		var raster = thread.wait_to_finish()
		var img: Image = Image.new()
		img.create(tex_width, tex_width, false, Image.FORMAT_RGBF)
		img.lock()
		for k in range(tex_width):
			for l in range(tex_width):
				img.set_pixel(l, k, Color(raster[k * tex_width + l].x, raster[k * tex_width + l].y, raster[k * tex_width + l].z))
		img.unlock()
		img.save_png(meshes[k].path)
		meshes[k].img = img
		meshes[k].raster = raster
	for k in meshes.keys():
		if k == "base":
			continue
		var raster = substract_raster(meshes[k].raster, meshes.base.raster)
		var img = raster2png(raster, Vector2(tex_width, tex_width))
		img.save_png("res://" + k + "-base.png")
		var fd = File.new()
		fd.open("res://" + k + "-base.raster", File.WRITE)
		fd.store_var(raster)
		fd.close()
#	var male_base_raster = substract_raster(meshes.male.raster, meshes.base.raster)
#	var female_base_raster = substract_raster(meshes.female.raster, meshes.base.raster)
#	var male_base = raster2png(male_base_raster, Vector2(tex_width, tex_width))
#	var female_base = raster2png(female_base_raster, Vector2(tex_width, tex_width))
#	var fd_male_base = File.new()
#	fd_male_base.open("res://male-base.raster", File.WRITE)
#	fd_male_base.store_var(male_base_raster)
#	fd_male_base.close()
#	var fd_female_base = File.new()
#	fd_female_base.open("res://female-base.raster", File.WRITE)
#	fd_female_base.store_var(female_base_raster)
#	fd_female_base.close()
#	male_base.save_png("res://male-base.png")
#	female_base.save_png("res://female-base.png")

	print("all done")
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
