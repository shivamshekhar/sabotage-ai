class_name WrongOnlyGame
extends QuizGame
## "Wrong answers only": simple questions, but the goal is to pick a WRONG answer. Picking the right
## one loses.


func _init() -> void:
	instructions = "Wrong answers only. Seriously."
	header = "WRONG ANSWERS ONLY!"
	want_right = false
	lose_message = "CORRECT?! DISGUSTING."
	bank = [
		{"q": "What is 2 + 2?", "right": "4", "wrong": ["5", "22", "Fish", "3"]},
		{"q": "What colour is a clear sky?", "right": "Blue", "wrong": ["Plaid", "Beige", "Soup"]},
		{"q": "What is the capital of France?", "right": "Paris", "wrong": ["Pizza", "Mars", "Lyon"]},
		{"q": "How many legs does a spider have?", "right": "8", "wrong": ["12", "Yes", "6"]},
		{"q": "Which animal says MOO?", "right": "Cow", "wrong": ["Toaster", "Duck", "Printer"]},
		{"q": "What is 10 minus 3?", "right": "7", "wrong": ["Banana", "1000", "8"]},
	]
