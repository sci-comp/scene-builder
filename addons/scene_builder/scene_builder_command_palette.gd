@tool
extends ConfirmationDialog
class_name SceneBuilderCommandPalette

signal command_selected(command_id: int)

var search_field: LineEdit
var command_list: ItemList
var all_commands: Array[Dictionary] = []
var filtered_commands: Array[Dictionary] = []

func _ready():
	# Setup dialog properties
	title = "Command Palette"
	size = Vector2(600, 400)
	popup_window = false

	# Hide OK/Cancel buttons - we don't need them
	get_cancel_button().hide()
	get_ok_button().hide()

	# Connect signals
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)

	# Create container for custom content
	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Create search field
	var search_container = MarginContainer.new()
	search_container.add_theme_constant_override("margin_left", 8)
	search_container.add_theme_constant_override("margin_right", 8)
	search_container.add_theme_constant_override("margin_top", 8)
	vbox.add_child(search_container)

	search_field = LineEdit.new()
	search_field.placeholder_text = "Type to search commands..."
	search_field.text_changed.connect(_on_search_text_changed)
	search_field.gui_input.connect(_on_search_field_input)
	search_container.add_child(search_field)

	# Create command list
	var list_container = MarginContainer.new()
	list_container.add_theme_constant_override("margin_left", 8)
	list_container.add_theme_constant_override("margin_right", 8)
	list_container.add_theme_constant_override("margin_bottom", 8)
	list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list_container)

	command_list = ItemList.new()
	command_list.item_activated.connect(_on_item_activated)
	command_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_container.add_child(command_list)

func setup_commands(commands: Array[Dictionary]):
	all_commands = commands.duplicate()
	all_commands.sort_custom(func(a, b): return a["name"] < b["name"])

func show_palette():
	if not visible:
		popup_centered()
		_refresh_command_list()
		search_field.text = ""
		search_field.grab_focus()

func _refresh_command_list(filter_text: String = ""):
	command_list.clear()
	filtered_commands.clear()

	var filter_lower = filter_text.to_lower()

	for cmd in all_commands:
		var name_lower = cmd["name"].to_lower()

		# Simple fuzzy matching: check if all characters appear in order
		if filter_text.is_empty() or _fuzzy_match(name_lower, filter_lower):
			filtered_commands.append(cmd)
			command_list.add_item(cmd["name"])

	# Auto-select first item
	if command_list.item_count > 0:
		command_list.select(0)

func _fuzzy_match(text: String, pattern: String) -> bool:
	if pattern.is_empty():
		return true

	var text_idx = 0
	var pattern_idx = 0

	while text_idx < text.length() and pattern_idx < pattern.length():
		if text[text_idx] == pattern[pattern_idx]:
			pattern_idx += 1
		text_idx += 1

	return pattern_idx == pattern.length()

func _on_search_text_changed(new_text: String):
	_refresh_command_list(new_text)

func _on_search_field_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_DOWN:
				_select_next_item()
			KEY_UP:
				_select_previous_item()
			KEY_ENTER, KEY_KP_ENTER:
				_execute_selected_command()
			KEY_ESCAPE:
				hide()

func _select_next_item():
	if command_list.item_count == 0:
		return

	var selected = command_list.get_selected_items()
	var current_idx = selected[0] if selected.size() > 0 else -1
	var next_idx = (current_idx + 1) % command_list.item_count

	command_list.select(next_idx)
	command_list.ensure_current_is_visible()

func _select_previous_item():
	if command_list.item_count == 0:
		return

	var selected = command_list.get_selected_items()
	var current_idx = selected[0] if selected.size() > 0 else 0
	var prev_idx = (current_idx - 1 + command_list.item_count) % command_list.item_count

	command_list.select(prev_idx)
	command_list.ensure_current_is_visible()

func _execute_selected_command():
	var selected = command_list.get_selected_items()
	if selected.size() > 0:
		var idx = selected[0]
		if idx < filtered_commands.size():
			var cmd = filtered_commands[idx]
			command_selected.emit(cmd["id"])
			hide()

func _on_item_activated(index: int):
	if index < filtered_commands.size():
		var cmd = filtered_commands[index]
		command_selected.emit(cmd["id"])
		hide()

func _on_confirmed():
	# Execute command when Enter is pressed
	_execute_selected_command()

func _on_canceled():
	# Just hide the dialog
	hide()
