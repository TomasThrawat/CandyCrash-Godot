class_name LevelData
extends RefCounted

enum ObjectiveType { SCORE, BLOCKERS, COLLECT, JELLY }

static func all_levels() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	var targets = [1800, 2400, 3000, 3600, 4500, 5200]
	for i in range(36):
		var idx := i + 1
		var objective := ObjectiveType.SCORE
		var target: int = targets[i % targets.size()]
		var moves: int = 24 + min(i / 6, 7)
		var blockers: int = 0
		var collect := 0
		var jelly := 0
		if idx >= 5 and idx % 5 == 0:
			objective = ObjectiveType.BLOCKERS
			blockers = min(4 + idx / 4, 12)
			target = blockers
		elif idx >= 8 and idx % 4 == 0:
			objective = ObjectiveType.COLLECT
			collect = 10 + (idx % 6) * 2
			target = collect
		elif idx >= 12 and idx % 6 == 0:
			objective = ObjectiveType.JELLY
			jelly = min(12 + idx / 2, 26)
			target = jelly
		levels.append({
			"id": idx,
			"name": "Level %02d" % idx,
			"moves": moves,
			"objective": objective,
			"target": target,
			"blockers": blockers,
			"collect": collect,
			"jelly": jelly,
			"min_score": 800 + idx * 120,
			"spawn_special": idx >= 3,
			"locked": idx > 1
		})
	return levels

static func get_level(id: int) -> Dictionary:
	var list := all_levels()
	id = clamp(id, 1, list.size())
	return list[id - 1]
