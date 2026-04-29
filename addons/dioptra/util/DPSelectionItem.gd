@tool
extends RefCounted
class_name DPSelectionItem

var type : DPHelpers.SelectionType = DPHelpers.SelectionType.NONE;
var solid : DPMapSolid = null;
var solid_id : int = -1;
var face : DPMapFace = null;
var face_id : int = -1;
var edge_id : int = -1; ## First vertex ID of the corner. If for vertex, refers to face corner index
var vertex_id : int = -1; ## Index of the associated point, not face corner

var decal : DPMapDecal = null;
var decal_id : int = -1;
