extends RefCounted
## Minimal test framework. Counts test_* methods as individual tests.
## A test passes when it completes without any failed assertion.

var passed := 0
var failed := 0
var failures: Array[String] = []
var _suite := ""
var _test := ""


func run_suite(suite) -> void:
	_suite = suite.get_script().get_path().get_file()
	suite.fw = self
	var names: Array[String] = []
	for m in suite.get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not names.has(n):
			names.append(n)
	names.sort()
	print("Suite: " + _suite)
	for n in names:
		_test = n
		var before := failed
		suite.call(n)
		if failed == before:
			passed += 1
			print("  PASS  %s" % n)


func check(cond: bool, msg: String) -> void:
	if cond:
		return
	failed += 1
	var line := "%s :: %s — %s" % [_suite, _test, msg]
	failures.append(line)
	print("  FAIL  %s — %s" % [_test, msg])


func summary() -> void:
	print("")
	print("========================================")
	print("Passed: %d   Failed: %d" % [passed, failed])
	for f in failures:
		print("  FAILED: " + f)
	print("========================================")


func exit_code() -> int:
	return 1 if failed > 0 else 0
