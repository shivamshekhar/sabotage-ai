class_name Groups
extends RefCounted
## The names of the node groups the game uses to find things (get_nodes_in_group). Use these instead of writing the name as a string.

const PLAYER := &"player"
const ENEMIES := &"enemies"            # everything a thrown object, a missile or a laser can hurt: it has hurtbox() and take_hit()
const PITS := &"pits"
const PROJECTILES := &"projectiles"    # thrown objects in flight
const LANDED_PROJECTILES := &"landed_projectiles"
const BOSS_BULLETS := &"boss_bullets"
const POWERUP_BOXES := &"powerup_boxes"
const SCORE_POPUPS := &"score_popups"    # the "+100" texts floating up
