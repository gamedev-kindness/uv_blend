extends Node

var tex_width = 1024
var lopass_count = 2

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
func lopass(raster):
	for k in range(1, tex_width - 1):
		for l in range(1, tex_width - 1):
			var px = Vector3()
			for v in range(-1, 2):
				for u in range(-1, 2):
					px += raster[tex_width * k + tex_width * v + l + u]
			raster[tex_width * k + l] = px * (1.0 / 9.0)

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
	for i in range(lopass_count):
		lopass(result)
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

onready var mutex = Mutex.new()
func build_arrays(mesh: ArrayMesh, rect_size: Vector2) -> Array:
	var polygons = []
	var color_data = []
	print("build")
	var mdt: = MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	print("mdt")
	var aabb = AABB()
	var vertex_count = mdt.get_vertex_count()
	var face_count = mdt.get_face_count()
	print("rendering vertices: ", vertex_count)
	for k in range(vertex_count):
		aabb = aabb.expand(mdt.get_vertex(k))
	for k in range(face_count):
		var polygon = []
		var fcolors = []
		for h in range(3):
			var e = mdt.get_face_vertex(k, h)
			var v = (mdt.get_vertex(e) - aabb.position) / (aabb.size.length() * 2.0)
			var uv = mdt.get_vertex_uv(e) * rect_size
			polygon.push_back(uv)
			fcolors.push_back(mdt.get_vertex(e))
		polygons.push_back(polygon)
		color_data.push_back(fcolors)
#		if k % 100 == 0:
#			print("polygon: ", k, " ", mdt.get_face_count())
#		print("polygon: ", k, " ", mdt.get_face_count())
#		rasterize_triangle(raster, polygon, fcolors, rect_size)
	return [polygons, color_data]
func build_triangles(polygons, color_data, rect_size):
	var raster = []
	raster.resize(rect_size.x * rect_size.y)
	for k in range(raster.size()):
		raster[k] = Vector3()
	for r in range(polygons.size()):
		rasterize_triangle(raster, polygons[r], color_data[r], rect_size)
		if r % 100 == 0:
			print("polygon: ", r, " of ", polygons.size())
	return raster

func thread_runner(userdata):
	var raster = build_triangles(userdata.arrays[0], userdata.arrays[1], Vector2(tex_width, tex_width))
	for i in range(lopass_count):
		lopass(raster)
	call_deferred("finish_thread", userdata.id)
	return raster
onready	var meshes = {
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
var jobs = 0
func finish_thread(id):
	var raster = meshes[id].thread.wait_to_finish()
	meshes[id].raster = raster
	jobs -= 1
func _ready():
	print("creating threads")
	for k in meshes.keys():
		print(k)
		meshes[k].arrays = build_arrays(meshes[k].mesh, Vector2(tex_width, tex_width))
	print("arrays created")
	for k in meshes.keys():
		var thread = Thread.new()
		jobs += 1
		meshes[k].thread = thread
		thread.start(self, "thread_runner", {"arrays": meshes[k].arrays, "id": k})
	print("created threads")
	while jobs > 0:
		yield(get_tree(), "idle_frame")
	for k in meshes.keys():
		print("thread: ", k)
#		var thread = meshes[k].thread
#		var raster = thread.wait_to_finish()
		var raster = meshes[k].raster
		var img: Image = Image.new()
		img.create(tex_width, tex_width, false, Image.FORMAT_RGBF)
		img.lock()
		for k in range(tex_width):
			for l in range(tex_width):
				img.set_pixel(l, k, Color(raster[k * tex_width + l].x, raster[k * tex_width + l].y, raster[k * tex_width + l].z))
		img.unlock()
		img.save_png(meshes[k].path)
		meshes[k].img = img
#		meshes[k].raster = raster
	for k in meshes.keys():
		if k == "base":
			continue
		var raster = substract_raster(meshes[k].raster, meshes.base.raster)
		var img = raster2png(raster, Vector2(tex_width, tex_width))
		img.save_png("res://" + k + "-base.png")
		var fd = File.new()
		fd.open("res://" + k + "-base.raster", File.WRITE)
		var raster_data = {"name": k, "raster": raster, "size": Vector2(tex_width, tex_width)}
		fd.store_var(raster_data)
		fd.close()

	print("all done")
