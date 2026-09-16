class_name LevelGraph
extends RefCounted
## Four mandatory combats, a seeded support branch, and an accessible boss arena.

static func generate(seed_value: int, stage: int) -> Dictionary:
	var random = RandomNumberGenerator.new()
	random.seed = seed_value + stage * 104729
	# The first four authored route maps put their support room beside Combat 2.
	# SILENT CORE's source route attaches Support to Combat 4, so its graph must
	# follow the authored topology rather than a seeded legacy branch.
	var branch: int = 1 if stage <= 3 else 3
	var links: Array = [[1], [0, 2], [1, 3], [2, 5], [branch], [3]]
	links[branch].append(4)
	var templates: Array = []
	var order: Array = [0, 1, 2]
	for i in range(2, 0, -1):
		var j: int = random.randi_range(0, i)
		var saved = order[i]
		order[i] = order[j]
		order[j] = saved
	for i in range(4):
		templates.append(order[i % 3])
	return {"links": links, "templates": templates, "branch": branch,
		"support": ["chest", "shop", "heal"][random.randi_range(0, 2)]}

static func reachable(graph: Dictionary, start: int = 0) -> Array:
	var visited: Array = [start]
	var pending: Array = [start]
	while not pending.is_empty():
		var at: int = pending.pop_front()
		for destination in graph.links[at]:
			if not visited.has(destination):
				visited.append(destination)
				pending.append(destination)
	return visited

static func can_enter(room: int, destination: int, cleared: Array, graph: Dictionary) -> bool:
	if not graph.links[room].has(destination) or not cleared.has(room):
		return false
	if destination == 5:
		for mandatory in range(4):
			if not cleared.has(mandatory):
				return false
	return true
