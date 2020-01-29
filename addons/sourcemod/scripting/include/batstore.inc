#if defined _batstore_included
  #endinput
#endif

#define _batstore_included
#define STORE_PREFIX	"{green}[Store]{snow} "
#define STORE_COLOR	"{snow}"
#define STORE_COLOR2	"{green}"

enum ItemResult
{
	Item_None = 0,	// Do nothing to the item
	Item_Used,	// Delete one use of the item
	Item_On,	// Equip the item on the client
	Item_Off	// Unequip the item on the client
};

/**
 * Called when a Boss's music begins with name and artist
 *
 * @note		This is not actually a forward, this is called per plugin
 * @note		Do not close the KeyValues handle given
 *
 * @param client 	Client index of using item
 * @param equipped	If the item is already equipped on the client
 * @param item 		KeyValue of the item (already in place)
 * @param name 		Name of the item
 * @param count 	Amount of the item in the client's inventory
 *
 * @return		Item result
 */
forward ItemResult BatStore_Item(int client, bool equipped, KeyValues item, const char[] name, int &count);

/**
 * Prints a color message with the store's prefix
 *
 * Uses the same params and return values as CPrintToChat, CPrintToChatAll, and CReplyToCommand
 */
stock void SPrintToChat(int client, const char[] message, any ...)
{
	SetGlobalTransTarget(client);
	char buffer[192];
	VFormat(buffer, sizeof(buffer), message, 3);
	CPrintToChat(client, "%s%s", STORE_PREFIX, buffer);
}
stock void SPrintToChatAll(const char[] message, any ...)
{
	char buffer[192];
	VFormat(buffer, sizeof(buffer), message, 2);
	CPrintToChatAll("%s%s", STORE_PREFIX, buffer);
}
stock void SReplyToCommand(int client, const char[] message, any ...)
{
	SetGlobalTransTarget(client);
	char buffer[192];
	VFormat(buffer, sizeof(buffer), message, 3);
	if(!client)
	{
		CRemoveTags(buffer, sizeof(buffer));
		PrintToServer("[Store] %s", buffer);
	}
	else if(GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
	{
		CRemoveTags(buffer, sizeof(buffer));
		PrintToConsole(client, "[Store] %s", buffer);
	}
	else
	{
		CPrintToChat(client, "%s%s", STORE_PREFIX, buffer);
	}
}
