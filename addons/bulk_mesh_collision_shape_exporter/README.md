
# Godot Bulk Mesh Collisionshape Exporter

## Description

Quickly export collision shapes for all Meshes that are children of a Node3D. Very useful if you are working with asset packs. Export unlimited amounts of collision shapes with a single click.

## System Requirements

Tested versions:
- Godot 4.4
- Godot 4.7

There is a decent chance the plugin will work on other versions as well.

## Installation

The easiest way to install the plugin will be using Godot's integrated Asset Store. Refer to the [Godot Docs](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html)
for details.

You must also enable the plugin under Project/Project\ Settings/Plugins as explained in [the previously linked doc page](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html#enabling-a-plugin).

## Usage
- Go to the [3D workspace](https://docs.godotengine.org/en/stable/tutorials/3d/introduction_to_3d.html#d-workspace)
- Select any node that inherits from `Node3D`
- In the [viewport toolbar](https://docs.godotengine.org/en/stable/tutorials/3d/introduction_to_3d.html#main-toolbar) there will be a button called `Bulk Mesh2Collision`
- Upon selecting this button you will be presented with 4 options
	* `Export Collision Shapes`  
		Export the collision shapes with the  configured settings. If you don't care about the settings you can just use this without reading the rest of the docs.
	* `General Search Depth`  
		Specifies how far away a children can be until it will no longer be included in the export.  
__Example__: If this is `1` the base node and its direct Children will be included in the export. Children of Children will not be included.
If this is `0` only the selected Nodes will be used for the export and not their children
	* `Search Depth After Fist Mesh`  
		Specifies how far away a children can be until it will no longer be included in the export only counting Nodes of type `MeshInstance3D`.  
__Example__: If this is `0` the first meshes found after the selected Node will be included in the export but not their children. If your selected Node has 3 children which are all Meshes all these 3 children would be included. But if the children are nested (children of 1 another) only the highest level child would be included.
If his is `1` and your selected Node is a Mesh and has any Node which doesn't inherit from `MeshInstance3D` which itself has a Meshinstance3D as a child. Both the selected Node and the nested `MeshInstance3D` would be included in the export despite the `Meshinstance3D` not being a direct child of the selected Node.
	* `Simplify Shapes`  
		Toggles the `simplify` parameter of [create_convex_collision](https://docs.godotengine.org/en/stable/classes/class_meshinstance3d.html#class-meshinstance3d-method-create-convex-collision) 
(Simplifies the generated Collision Shapes for better performance)

## Known Bugs
If you installed Godot via Flatpak and did not change the default permission you will be unable to change any settings since Godot is not allowed to create new windows by Flatpak.
Since this is a Godot / Flatpak related bug I cannot fix it for this plugin.
Honestly I would not recommend installing Godot via Flatpak anyways.
