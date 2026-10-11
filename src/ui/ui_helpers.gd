class_name UI
extends RefCounted
## Small helpers for building code-driven UI. The game constructs its menus in
## code to keep scenes small, testable, and easy to localize.

static func bg(parent: Control, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)
	return r


static func vbox(parent: Control, separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	parent.add_child(v)
	return v


static func hbox(parent: Control, separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	parent.add_child(h)
	return h


static func center(parent: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	return c


static func label(text: String, size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	return b


static func panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	return p


static func spacer(parent: Control, height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)
	return s


static func title(parent: Control, text: String, size: int = 40) -> Label:
	var l := label(text, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l
