extends Object

class ImgLoadRequest:
	extends RefCounted
	
	var path: String
	var file: String
	var callback_func: Callable
	var is_main_cover: bool
	var index: int
	## Longest side the texture is shrunk to (0: full size).
	var max_size: int
	var thread := Thread.new()

var _img_load_request_queue: Array[ImgLoadRequest] = []
## The list rows in view (first, last): their covers load before the others' (owner, 2026-10-30: covers on screen
## first). Read by the loading threads, so set under the mutex (set_view).
var _view := Vector2i(0, -1)

# variable used to keep track of how many threads are currently loading images
var _img_load_mutex := Mutex.new()
var _running_img_load_threads := 0

var _max_img_load_threads: int

func _init(num_threads: int = 10) -> void:
	_max_img_load_threads = num_threads

## Loads path + file into a texture on a thread and calls callback_func(texture, is_main_cover, index); with
## max_size above 0 a bigger image is shrunk to that longest side first (a list's cover needs a fraction of the
## pixels, and uploads and draws faster).
func load_texture(path: String, file: String, callback_func: Callable, is_main_cover: bool, index: int, max_size := 0) -> void:
	var new_req := ImgLoadRequest.new()
	new_req.max_size = max_size
	new_req.path = path
	new_req.file = file
	new_req.callback_func = callback_func
	new_req.is_main_cover = is_main_cover
	new_req.index = index
	# the loading threads take requests off this queue under the mutex, so adding goes under it too
	_img_load_mutex.lock()
	_img_load_request_queue.push_back(new_req)
	_img_load_mutex.unlock()
	
	_start_next_img_load()

## Loads the covers of list rows first..last (in view) before the others still waiting.
func set_view(first: int, last: int) -> void:
	_img_load_mutex.lock()
	_view = Vector2i(first, last)
	_img_load_mutex.unlock()

## Drops the list covers still waiting (not the big cover): the list was rebuilt, and its rows ask again.
func drop_list_requests() -> void:
	_img_load_mutex.lock()
	for i in range(_img_load_request_queue.size() - 1, -1, -1):
		if not _img_load_request_queue[i].is_main_cover:
			_img_load_request_queue.remove_at(i)
	_img_load_mutex.unlock()

func _start_next_img_load() -> void:
	_img_load_mutex.lock()
	# looked for only when a thread is free: a list rebuild queues every row while the threads are busy
	if _img_load_request_queue.size() > 0 and _running_img_load_threads < _max_img_load_threads:
		var next_req := _img_load_request_queue.pop_at(_next_request()) as ImgLoadRequest
		
		if next_req and Utils.custom_thread_call(next_req.thread, _load_img_threaded, [next_req]) == OK:
			_running_img_load_threads += 1
	_img_load_mutex.unlock()

## Which waiting request loads next: the big cover, else the first row in view, else the oldest. Under the mutex,
## with requests waiting.
func _next_request() -> int:
	var in_view := -1
	for i in _img_load_request_queue.size():
		var req := _img_load_request_queue[i]
		if req.is_main_cover:
			return i
		if in_view < 0 and req.index >= _view.x and req.index <= _view.y:
			in_view = i
	return maxi(in_view, 0)

func _load_img_threaded(req: ImgLoadRequest) -> void:
	# read cover image data from file into a buffer
	var data := Utils.read_binary_file(req.path,req.file)
	var tex: ImageTexture = null
	if len(data) > 0:
		var img : Image
		if req.file.to_lower().ends_with(".png"):
			img = Image.new()
			img.load_png_from_buffer(data)
		elif req.file.to_lower().ends_with(".jpg") or req.file.to_lower().ends_with(".jpeg"):
			img = Image.new()
			img.load_jpg_from_buffer(data)
		else:
			img = Image.load_from_file(req.path + req.file)
		if img != null and not img.is_empty():
			if req.max_size > 0 and maxi(img.get_width(), img.get_height()) > req.max_size:
				var scale := float(req.max_size) / maxi(img.get_width(), img.get_height())
				img.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
			ImageUtils.round_corners(img, roundi(mini(img.get_width(), img.get_height()) * ImageUtils.COVER_CORNER))
			tex = ImageTexture.create_from_image(img)
	
	# perform callback in the form of my_callback(texture, filepath, ...);
	# texture is null if the file was missing or couldn't be decoded
	req.callback_func.bind(tex, req.is_main_cover, req.index).call()
	
	# decrement count to show that this thread is done and another can start;
	# this must happen for failed loads too, or each missing cover would
	# use up a thread for good and covers would stop loading
	_img_load_mutex.lock()
	_running_img_load_threads -= 1
	_img_load_mutex.unlock()
	
	# start next load if there are any waiting
	_start_next_img_load()
