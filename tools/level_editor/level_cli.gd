extends SceneTree
## Entry point of the level command-line tool: `tools/level_cli.sh <command> ...` runs this headless. It hands the words after `--` to
## LevelCli.run() and prints the result as JSON between two marker lines (the shell wrapper prints only what is between them).
## The exit code is 0 when the command worked and 1 when it did not.

# BEGIN_MARK / END_MARK: lines around the JSON so a wrapper can pick it out of Godot's own start-up chatter.
const BEGIN_MARK := "<<<LEVEL_CLI"
const END_MARK := "LEVEL_CLI>>>"


func _initialize() -> void:
	var result := LevelCli.run(Array(OS.get_cmdline_user_args()))
	print(BEGIN_MARK)
	if result.has("help"):
		print(str(result["help"]))
	else:
		print(JSON.stringify(result, "  ", false))
	print(END_MARK)
	quit(0 if bool(result.get("ok", false)) else 1)
