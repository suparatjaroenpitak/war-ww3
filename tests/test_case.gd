class_name TestCase
extends RefCounted
## Base class for test suites. Provides assertion helpers that report to the
## framework instance injected by the runner.

var fw = null


func assert_true(cond: bool, msg: String = "") -> void:
	fw.check(cond, msg if msg != "" else "expected true, got false")


func assert_false(cond: bool, msg: String = "") -> void:
	fw.check(not cond, msg if msg != "" else "expected false, got true")


func assert_eq(a, b, msg: String = "") -> void:
	fw.check(a == b, ("%s — " % msg if msg != "" else "") + "got=%s expected=%s" % [str(a), str(b)])


func assert_ne(a, b, msg: String = "") -> void:
	fw.check(a != b, ("%s — " % msg if msg != "" else "") + "both are %s" % [str(a)])


func assert_gt(a, b, msg: String = "") -> void:
	fw.check(a > b, ("%s — " % msg if msg != "" else "") + "got=%s expected > %s" % [str(a), str(b)])


func assert_gte(a, b, msg: String = "") -> void:
	fw.check(a >= b, ("%s — " % msg if msg != "" else "") + "got=%s expected >= %s" % [str(a), str(b)])


func assert_lt(a, b, msg: String = "") -> void:
	fw.check(a < b, ("%s — " % msg if msg != "" else "") + "got=%s expected < %s" % [str(a), str(b)])


func assert_lte(a, b, msg: String = "") -> void:
	fw.check(a <= b, ("%s — " % msg if msg != "" else "") + "got=%s expected <= %s" % [str(a), str(b)])
