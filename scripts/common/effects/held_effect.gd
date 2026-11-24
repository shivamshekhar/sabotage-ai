class_name HeldEffect
extends Node2D
## What a stream of light that something holds on has in common (ElectricArc, EnergyBeam), so whatever fires one can fire any: it runs from one world position to another, is aimed
## again every step while it is on, and fades out when it is let go.

## Move the ends (world positions) and say whether it ends on something. Call it every step while it is on.
func aim(_from: Vector2, _to: Vector2, _hit: bool) -> void:
	pass


## Let it go: it fades out and removes itself.
func release() -> void:
	pass
