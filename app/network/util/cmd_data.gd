extends RefCounted
class_name CommandData

var callable : Callable
var permission_level : int
var max_args : int
var min_args : int
var where : int

func _init(c_data : Callable, perm_lvl : int, mx_args : int, mn_args : int, whr : int):
	callable = c_data
	permission_level = perm_lvl
	max_args = mx_args
	min_args = mn_args
	where = whr
