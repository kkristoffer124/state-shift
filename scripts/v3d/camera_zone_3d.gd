@tool
class_name CameraZone3D
extends Node3D
## Third-person camera hint: while the blob is inside this box (`size` metres, centred
## on the node, axis aligned) the CameraRig3D uses these overrides whenever the player
## isn't steering the camera by hand. Put them in a level's "CameraZones" node.

@export var size := Vector3(4, 4, 4)
## Arm length multiplier (1 = the rig's distance).
@export var distance_scale := 1.0
@export var use_pitch := false
## Resting pitch (deg, negative looks down).
@export var pitch_deg := -20.0
@export var use_yaw := false
## View direction (deg around Y; 0 looks along -Z, -90 along +X).
@export var yaw_deg := 0.0
## How fast the camera eases to the overrides.
@export var blend := 2.0


func contains(p: Vector3) -> bool:
	return AABB(global_position - size / 2.0, size).has_point(p)
