@tool
extends RefCounted
class_name DPSelectionItem

var type : DPHelpers.SelectionType = DPHelpers.SelectionType.NONE;
var solid : DPMapSolid = null;
var solid_id : int = -1;
var face : DPMapFace = null;
var face_id : int = -1;
