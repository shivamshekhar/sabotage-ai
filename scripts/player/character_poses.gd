class_name CharacterPoses
extends RefCounted
## Which pictures of a character show each state of its sprite (see PlayerSprite), and how fast they change. The hero has a breathing idle, blinks, a glance, a
## four-step walk and a shooting pose; the AI Bro (the "zombie") has the plain Kenney set. A state is shown by one picture or by a loop of several.

# BREATH_TIME: seconds each of the four breathing pictures of the hero's idle is shown (a whole breath is four times this). Smaller: faster breathing.
const BREATH_TIME := 0.32

# WALK_TIME: seconds each of the two walk pictures is shown (one step each: a cycle of two steps takes twice this). Smaller: legs move faster. Larger: a slow shuffle.
# Match it to Player.SPEED so the feet do not look like they slide.
const WALK_TIME := 0.12

# CLIMB_TIME: seconds each of the two climbing pictures is shown. Match it to Player.CLIMB_SPEED.
const CLIMB_TIME := 0.15

# The pictures of every state: "frames" are the pose names (the file is <character>_<pose>.png), "time" the seconds each is shown. The hero's &"blink" pictures
# match its &"idle" ones one to one (the same breath with the eyes shut), and &"look" is a glance; PlayerSprite shows them now and then while the hero stands.
# A walking sprite also bounces a little on every step (PlayerSprite.WALK_BOB).
const HERO := {
	&"idle": {"frames": ["idle1", "idle2", "idle3", "idle2"], "time": BREATH_TIME},
	&"blink": {"frames": ["blink1", "blink2", "blink3", "blink2"], "time": BREATH_TIME},
	&"look": {"frames": ["look"], "time": 1.0},
	&"walk": {"frames": ["walk1", "walk2"], "time": WALK_TIME},
	&"climb": {"frames": ["climb1", "climb2"], "time": CLIMB_TIME},
	&"climb_idle": {"frames": ["climb1"], "time": 1.0},
	&"jump": {"frames": ["jump"], "time": 1.0},
	&"fall": {"frames": ["fall"], "time": 1.0},
	&"hurt": {"frames": ["hurt"], "time": 1.0},
	&"throw_windup": {"frames": ["action1"], "time": 1.0},
	&"throw_release": {"frames": ["action2"], "time": 1.0},
	&"shoot": {"frames": ["shoot"], "time": 1.0},
}

const PLAIN := {
	&"idle": {"frames": ["idle"], "time": 1.0},
	&"walk": {"frames": ["walk1", "walk2"], "time": WALK_TIME},
	&"climb": {"frames": ["climb1", "climb2"], "time": CLIMB_TIME},
	&"climb_idle": {"frames": ["climb1"], "time": 1.0},
	&"jump": {"frames": ["jump"], "time": 1.0},
	&"fall": {"frames": ["fall"], "time": 1.0},
	&"hurt": {"frames": ["hurt"], "time": 1.0},
	&"throw_windup": {"frames": ["action1"], "time": 1.0},
	&"throw_release": {"frames": ["action2"], "time": 1.0},
	&"shoot": {"frames": ["action2"], "time": 1.0},
}

# HURT_POSE: the pose of a hit character (every character has it).
const HURT_POSE := "hurt"

# CHARACTER_HERO: the character that has the HERO set. Every other one has the PLAIN set.
const CHARACTER_HERO := "player"


## The state table of a character (see HERO and PLAIN).
static func table(character: String) -> Dictionary:
	return HERO if character == CHARACTER_HERO else PLAIN


## The pose shown when the character just stands (its first idle picture): used for its portrait in the mech and in the level editor.
static func standing(character: String) -> String:
	return table(character)[&"idle"]["frames"][0]


## Every pose (picture) a character has, without repeats.
static func all_poses(character: String) -> Array[String]:
	var out: Array[String] = []
	for entry in table(character).values():
		for pose in entry["frames"]:
			if not out.has(pose):
				out.append(pose)
	return out
