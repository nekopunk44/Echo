extends RefCounted
## Набор оружия и плёнок: уровни и итоговые множители. Один у игрока, по одному у каждой копии.

const Upgrades := preload("res://upgrades.gd")

var levels := {}          # id -> уровень
var trait_bonus := {}     # постоянные бонусы героя


func set_hero(hero: String) -> void:
    var hero_info: Dictionary = Upgrades.HERO_INFO.get(hero, {})
    trait_bonus = hero_info.get("bonuses", {}).duplicate()


func level(id: String) -> int:
    return int(levels.get(id, 0))


func add(id: String) -> void:
    var def: Dictionary = Upgrades.CATALOG[id]
    if def.has("parts") and level(id) == 0:   # Монтаж: исходные предметы исчезают, слоты освобождаются
        for p in def["parts"]:
            levels.erase(p)
    levels[id] = level(id) + 1


func count_kind(kind: String) -> int:
    var n := 0
    for id in levels:
        if Upgrades.CATALOG[id]["kind"] == kind:
            n += 1
    return n


## Сумма приростов для характеристики (плёнки + черта героя).
func bonus(stat: String) -> float:
    var total := float(trait_bonus.get(stat, 0.0))
    for id in levels:
        var def: Dictionary = Upgrades.CATALOG[id]
        if def["kind"] != "film" and not def.get("endless", false):
            continue
        if def.has("stats"):   # плёнка с несколькими характеристиками
            total += float(def["stats"].get(stat, 0.0)) * float(levels[id])
        elif def["stat"] == stat:
            total += float(def["per_level"]) * float(levels[id])
    return total


func mult(stat: String) -> float:
    return 1.0 + bonus(stat)
