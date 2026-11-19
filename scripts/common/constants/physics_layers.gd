class_name PhysicsLayers
extends RefCounted
## The game's physics layers. Godot collision layers are bit flags, so each one needs its own bit. Use these names everywhere (collision_layer,
## collision_mask, ray and shape queries) instead of the numbers.

# WORLD: ground, walls, crates and ledges. Level colliders use it as their layer; the player, enemies and thrown things collide with it.
const WORLD := 1

# LADDER_DECK: the one-way deck on top of each ladder. It has its own layer so the player can drop their collision with it while climbing
# (to pass through the deck both ways) and still be stopped by the world.
const LADDER_DECK := 2

# ENEMY: enemies. The player does not collide with it (you can walk through an enemy; it hurts through its attack, not by touching).
const ENEMY := 4

# BARRIER: invisible walls (the "invisible_wall" tile). Only the player collides with this layer; enemies, thrown things and the level
# solver ignore it.
const BARRIER := 8

# What the player's body is stopped by while walking, and while climbing a ladder (it lets go of the deck then).
const PLAYER_MASK := WORLD | LADDER_DECK | BARRIER
const PLAYER_CLIMBING_MASK := WORLD | BARRIER

# What a vehicle's feet, a missile or a flying piece stand on: the floor and the one-way decks.
const FLOOR := WORLD | LADDER_DECK
