class_name Piranha
extends PitCreature
## The robot piranha of the piranha tank (map character W): a PitCreature of the "piranha" kind, which snaps its big saw-toothed
## jaws while it is out of the water and bites for 10% of the player's health. Everything it does is in PitCreature; this class
## only names the kind (so `Piranha.new(...)` and `is Piranha` keep meaning the tank's fish).


func _init(surface: float = 0.0, spot_x: float = 0.0, left: float = 0.0, right: float = 0.0) -> void:
	super(surface, spot_x, left, right, "piranha")
