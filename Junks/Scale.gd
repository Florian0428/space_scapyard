extends Node3D
class_name Scale

## Kiadva minden alkalommal, amikor a mérlegen lévő tárgyak össztömege
## változik (rárakás/levétel után). A tömeg mindig kg-ban van - a
## kijelzőn a Units autoload konvertálja a megfelelő mértékegységre.
signal weight_changed(total_weight_kg: float)

@onready var detection_area: Area3D = $DetectionArea
@onready var display_label: Label3D = $DisplayLabel

# A mérlegen jelenleg nyugvó junk darabok.
var _items_on_scale: Array[Junk] = []


func _ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	# Ha valaki menet közben vált kg/lb között, a kijelző azonnal frissüljön,
	# akkor is, ha közben nem változik, ami a mérlegen van.
	Units.unit_changed.connect(_on_unit_changed)
	_update_display()


func _on_body_entered(body: Node3D) -> void:
	# Felszedéskor a junk collision_layer/mask 0-ra áll, szóval az nem is
	# triggereli ezt a jelet - csak akkor fut le, ha ténylegesen leteszik
	# a mérlegre.
	if body is Junk and not _items_on_scale.has(body):
		_items_on_scale.append(body)
		# Ha a tárgy törlődne, amíg a mérlegen van, essen ki a listából is.
		body.tree_exiting.connect(_on_item_freed.bind(body), CONNECT_ONE_SHOT)
		_update_display()


func _on_body_exited(body: Node3D) -> void:
	if _items_on_scale.has(body):
		_items_on_scale.erase(body)
		_update_display()


func _on_item_freed(body: Junk) -> void:
	if _items_on_scale.has(body):
		_items_on_scale.erase(body)
		_update_display()


func _on_unit_changed(_new_unit: Units.WeightUnit) -> void:
	_update_display()


## Az összes, jelenleg a mérlegen lévő junk súlyának összege, kg-ban.
func get_total_weight() -> float:
	var total := 0.0
	for item in _items_on_scale:
		if is_instance_valid(item):
			total += item.weight
	return total


func _update_display() -> void:
	var total := get_total_weight()
	weight_changed.emit(total)
	display_label.text = Units.format_weight(total)
