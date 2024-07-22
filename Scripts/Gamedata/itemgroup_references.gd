extends Node

# This script is intended to be used inside the GameData autoload singleton.
# It handles references between itemgroups and other entities.

# An itemgroup has been changed. Update items that were added or removed from the list.
# `olddata` and `newdata` are dictionaries that include "items" keys pointing to arrays of dictionaries.
func on_itemgroup_changed(newdata: Dictionary, olddata: Dictionary):
	var changes_made = false
	# Create lists of ids for each item in the itemgroup
	var oldlist = olddata.get("items", []).map(func(it): return it["id"])
	var newlist = newdata.get("items", []).map(func(it): return it["id"])
	var itemgroup = newdata["id"]

	# Remove itemgroup from items in the old list that are not in the new list
	for item_id in oldlist:
		if item_id not in newlist:
			changes_made = Gamedata.remove_reference(Gamedata.data.items, "core", "itemgroups", item_id, itemgroup) or changes_made

	# Add itemgroup to items in the new list that were not in the old list
	for item_id in newlist:
		if item_id not in oldlist:
			changes_made = Gamedata.add_reference(Gamedata.data.items, "core", "itemgroups", item_id, itemgroup) or changes_made

	# Save changes if any items were updated
	if changes_made:
		Gamedata.save_data_to_file(Gamedata.data.items)


# An itemgroup is being deleted from the data
# We have to loop over all the items in the itemgroup
# We can get the items by calling get_data_by_id(contentData, id) 
# and getting the items property, which will return an array of item id's
# For each item, we have to get the item's data, and delete the itemgroup from the item's itemgroups property if it is present
func on_itemgroup_deleted(itemgroup_id: String):
	var changes_made = false
	var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, itemgroup_id)

	if itemgroup_data.is_empty():
		print_debug("Itemgroup with ID", itemgroup_id, "not found.")
		return

	# Callable to remove the itemgroup from every furniture that references this itemgroup.
	var myfunc: Callable = func(furn_id):
		var furniture: DFurniture = Gamedata.furnitures.by_id(furn_id)
		furniture.remove_itemgroup(itemgroup_id)

	# Pass the callable to every furniture in the itemgroup's references
	# It will call myfunc on every furniture in itemgroup_data.references.core.furniture
	Gamedata.execute_callable_on_references_of_type(itemgroup_data, "core", "furniture", myfunc)

	# Remove references to this itemgroup from items listed in the itemgroup data.
	for item in itemgroup_data.get("items", []):
		changes_made = Gamedata.remove_reference(Gamedata.data.items, "core", "itemgroups", item["id"], itemgroup_id) or changes_made

	# Remove references to this itemgroup from maps.
	for mod in itemgroup_data.get("references", []):
		var maps = Helper.json_helper.get_nested_data(itemgroup_data, "references." + mod + ".maps")
		if maps:
			Gamedata.maps.remove_entity_from_selected_maps("itemgroup", itemgroup_id, maps)

	# Save changes to the data files if any changes were made.
	if changes_made:
		Gamedata.save_data_to_file(Gamedata.data.items)
		print_debug("Itemgroup", itemgroup_id, "has been successfully deleted from all items.")
	else:
		print_debug("No changes needed for itemgroup", itemgroup_id)
