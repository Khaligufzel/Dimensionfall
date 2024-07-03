extends Node

# This script is intended to be used inside the GameData autoload singleton
# This script handles references between itemgroups and other entities.




# An itemgroup has been changed. Update items that were added or removed from the list.
# olddata and newdata are dictionaries that include "items" keys pointing to arrays of dictionaries.
func on_itemgroup_changed(newdata: Dictionary, olddata: Dictionary):
	var changes_made = false
	# Initialize empty arrays
	var oldlist = []
	var newlist = []

	# Fill oldlist with IDs from olddata
	for item in olddata.get("items", []):
		oldlist.append(item["id"])

	# Fill newlist with IDs from newdata
	for item in newdata.get("items", []):
		newlist.append(item["id"])

	var itemgroup: String = newdata.id
	# Remove itemgroup from items in the old list that are not in the new list
	if oldlist:
		for item_id in oldlist:
			if item_id not in newlist:
				# Call remove_reference to remove the itemgroup from this item
				changes_made = Gamedata.remove_reference(Gamedata.data.items, "core", "itemgroups", \
				item_id, itemgroup) or changes_made

	# Add itemgroup to items in the new list that were not in the old list
	if newlist:
		for item_id in newlist:
			if item_id not in oldlist:
				# Call add_reference to add the itemgroup to this item
				changes_made = Gamedata.add_reference(Gamedata.data.items, "core", "itemgroups", \
				item_id, itemgroup) or changes_made

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

	# This callable will remove this itemgroup from every furniture that references this itemgroup.
	var myfunc: Callable = func (furn_id):
		var furniture_data = Gamedata.get_data_by_id(Gamedata.data.furniture, furn_id)
		var container_group = furniture_data.get("Function", {}).get("container", {}).get("itemgroup", "")
		var disassembly_group = furniture_data.get("disassembly", {}).get("group", "")
		var destruction_group = furniture_data.get("destruction", {}).get("group", "")

		if container_group == itemgroup_id:
			changes_made = Helper.json_helper.delete_nested_property(furniture_data,\
							 "Function.container.itemgroup") or changes_made

		if disassembly_group == itemgroup_id:
			changes_made = Helper.json_helper.delete_nested_property(furniture_data,\
							 "disassembly.group") or changes_made

		if destruction_group == itemgroup_id:
			changes_made = Helper.json_helper.delete_nested_property(furniture_data,\
							 "destruction.group") or changes_made

	# Pass the callable to every furniture in the itemgroup's references
	# It will call myfunc on every furniture in itemgroup_data.references.core.furniture
	Gamedata.execute_callable_on_references_of_type(itemgroup_data, "core", "furniture", myfunc)

	# The itemgroup data contains a list of item IDs in an 'items' attribute
	# Loop over all the items in the list and remove the reference to this itemgroup
	if "items" in itemgroup_data:
		var items = itemgroup_data["items"]
		for item in items:
			# Use remove_reference to handle deletion of itemgroup references
			changes_made = Gamedata.remove_reference(Gamedata.data.items, "core", "itemgroups", \
			item.id, itemgroup_id) or changes_made
	
	# Check if the tile has references to maps and remove it from those maps
	var modules = itemgroup_data.get("references", [])
	for mod in modules:
		var maps = Helper.json_helper.get_nested_data(itemgroup_data, "references." + mod + ".maps")
		for map_id in maps:
			Gamedata.map_references.remove_entity_from_map(map_id, "itemgroup", itemgroup_id)

	# Save changes to the data file if any changes were made
	if changes_made:
		Gamedata.save_data_to_file(Gamedata.data.items)
		Gamedata.save_data_to_file(Gamedata.data.furniture)
		print_debug("Itemgroup", itemgroup_id, "has been successfully deleted from all items.")
	else:
		print_debug("No changes needed for itemgroup", itemgroup_id)
