class_name JokeGame
extends QuizGame
## Pun quiz: pick the real punchline of each (terrible) AI joke.


func _init() -> void:
	instructions = "Pick the real punchline."
	header = "FINISH THE JOKE"
	want_right = true
	lose_message = "NOT FUNNY. (NEITHER IS THE AI.)"
	bank = [
		{"q": "Why did the AI cross the road?", "right": "To optimise the other side", "wrong": ["To get to the chicken", "It was prompted to"]},
		{"q": "What is a robot's favourite snack?", "right": "Microchips", "wrong": ["Oily crisps", "Bolts and gravy"]},
		{"q": "Why was the computer cold?", "right": "It left its Windows open", "wrong": ["It had no fans", "Low battery"]},
		{"q": "Why did the neural network see a therapist?", "right": "Too many hidden layers", "wrong": ["Low self-attention", "Overfitting on its ex"]},
		{"q": "Why did the chatbot get fired?", "right": "It kept making things up", "wrong": ["It was too honest", "It asked for a raise"]},
	]
