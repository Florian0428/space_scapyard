extends RigidBody3D
class_name Junk

## Milyen fajta roncs ez. Ezt majd a szortírozó konténereknél fogjuk
## felhasználni, hogy csak a megfelelő konténerbe lehessen berakni.
@export_enum("Metal", "Electronics", "Glass") var junk_type: String = "Metal"

@export_category("Value")
## Alap eladási ár, mielőtt a súly és a ritkaság módosítaná.
@export var base_value: float = 10.0
## A tárgy súlya kilogrammban. Ez szorozza az eladási árat -
## egy nehezebb fémdarab többet ér, mint egy kicsi.
@export var weight: float = 1.0
## Milyen ritka ez a darab. Minden szint egy beépített szorzót ad
## az eladási árhoz (lásd RARITY_MULTIPLIERS lent).
@export_enum("Common", "Uncommon", "Rare", "Epic") var rarity: String = "Common"
## Extra, kézzel finomhangolható szorzó a rarity tetejére - pl. ha egy
## adott darabot valamiért még ritkábbá/értékesebbé akarsz tenni anélkül,
## hogy a rarity szintjét feljebb vinnéd.
@export var extra_rarity_multiplier: float = 1.0

## Ha be van kapcsolva, a fizikai tömeg (mass) is a weight értékét veszi fel,
## így egy nehezebb darab a fizikában is nehezebbnek fog érződni.
@export var affect_physics_mass: bool = true




const RARITY_MULTIPLIERS := {
	"Common": 1.0,
	"Uncommon": 1.5,
	"Rare": 2.5,
	"Epic": 5.0,
}


func _ready() -> void:
	add_to_group("Junk")
	if affect_physics_mass:
		mass = weight


## A tárgy tényleges eladási értéke: alapár * súly * ritkaság-szorzók.
func get_sell_value() -> float:
	var rarity_multiplier: float = RARITY_MULTIPLIERS.get(rarity, 1.0)
	return base_value * weight * rarity_multiplier * extra_rarity_multiplier


## A súly szövegként, a beállításokban kiválasztott mértékegységben
## (pl. "2.3 kg" vagy "5.1 lb"). A weight mező mindig kg-ban van tárolva -
## ez csak a megjelenítéshez konvertál a Units autoload segítségével.
func get_display_weight_string() -> String:
	return Units.format_weight(weight)
