extends Node

## Globális mértékegység-kezelő. A junk-ok súlya a kódban MINDIG
## kilogrammban van tárolva (ez a "kanonikus" egység) - ez a singleton
## csak a MEGJELENÍTÉSHEZ konvertál, amikor a beállításokban lb-ra
## vált a felhasználó. Így semmi máshol (Junk.gd, eladási ár számítás,
## fizikai mass) nem kell tudnia arról, hogy épp melyik mértékegység
## van kiválasztva.

enum WeightUnit { KG, LB }

## Bárki feliratkozhat erre, ha automatikusan frissülnie kell, amikor a
## felhasználó menet közben vált kg és lb között (pl. a mérleg kijelzője).
signal unit_changed(new_unit: WeightUnit)

var weight_unit: WeightUnit = WeightUnit.KG:
	set(value):
		weight_unit = value
		unit_changed.emit(value)

const KG_TO_LB := 2.20462


## A tárolt kg érték átváltása a jelenleg kiválasztott mértékegységre.
func to_display_weight(weight_kg: float) -> float:
	match weight_unit:
		WeightUnit.LB:
			return weight_kg * KG_TO_LB
		_:
			return weight_kg


## Ugyanaz, csak formázott szöveggel, kiírható rögtön UI-ba.
func format_weight(weight_kg: float) -> String:
	match weight_unit:
		WeightUnit.LB:
			return "%.1f lb" % (weight_kg * KG_TO_LB)
		_:
			return "%.1f kg" % weight_kg


## Fordított irány, ha valaha felhasználói inputot (pl. egy szerkesztő
## mezőt) kellene visszaváltani kg-ra tároláshoz.
func display_to_kg(value: float) -> float:
	match weight_unit:
		WeightUnit.LB:
			return value / KG_TO_LB
		_:
			return value
