#if defined _textstore_included
	#endinput
#endif
#define _textstore_included

#define STORE_PREFIX	"{green}[Store]{snow} "
#define STORE_PREFIX2	"{green}[Store] "
#define STORE_COLOR	"{snow}"
#define STORE_COLOR2	"{green}"

enum ItemResult
{
	Item_None = 0,	// Do nothing to the item
	Item_Used,	// Delete one use of the item
	Item_On,		// Equip the item on the client
	Item_Off		// Unequip the item on the client
};

/**
 * Change a client's inventory count/equippment
 *
 * @param client	Client index of using item
 * @param item		Index of the item
 * @param count		Amount of the item
 * @param item		If to force unequip or equip the item
 *
 * @noreturn
 */
native void TextStore_SetInv(int client, int item, int count=-1, int equip=-1);

/**
 * Get a client's inventory count/equippment
 *
 * @param client	Client index
 * @param item		Item index
 * @param count		Amount of the item in the client's inventory
 *
 * @return		If the item is equipped
 */
native bool TextStore_GetInv(int client, int item, int &count=0);

/**
 * Get, give, remove cash on a client
 *
 * @param client	Client index
 * @param cash		Cash to give/remove
 *
 * @return		New cash value
 */
native int TextStore_Cash(int client, int cash=0);

/**
 * Forces the client to save their current items into the database
 *
 * @param client	Client index
 *
 * @noreturn
 */
native void TextStore_ClientSave(int client);

/**
 * Forces the client to get their current items from previous save
 *
 * @param client	Client index
 *
 * @noreturn
 */
native void TextStore_ClientReload(int client);

/**
 * Gets the current amount of items and categories in the store
 *
 * @return		Amount of items and categories
 */
native int TextStore_GetItems();

/**
 * Gets the name of the item
 *
 * @note		Do not close the KeyValues handle given
 *
 * @param item		Item index
 *
 * @return		KeyValues handle
 */
native KeyValues TextStore_GetItemKv(int item);

/**
 * Gets the name of the item
 *
 * @param item		Item index
 * @param buffer	String to write to
 * @param count		Size of the string
 *
 * @return		Number of bytes written
 */
native int TextStore_GetItemName(int item, char[] buffer, int length);

/**
 * Gets data of a unique item
 *
 * @param item		Item index
 * @param buffer	String to write to
 * @param count		Size of the string
 *
 * @return		Number of bytes written
 */
native int TextStore_GetItemData(int item, char[] buffer, int length);

/**
 * Creates a unique variant of an item
 *
 * @param client	Client index
 * @param item		Base item index
 * @param data		Item data string
 * @param name		Custom item name
 * @param equipped	If given equipped
 *
 * @return		Given item index
 */
native int TextStore_CreateUniqueItem(int client, int item, const char[] data, const char[] name="", bool equipped=false);

/**
 * Called when a client is about to be sold
 *
 * @param client	Client index
 * @param item		Item index
 * @param cash		The current "cash" the client has
 * @param count		The current amount of the item the client has
 * @param sell		The amount the item is being sold for
 *
 * @return		Plugin_Changed to change values, Plugin_Handled/Plugin_Stop to prevent the sell
 */
forward Action TextStore_OnSellItem(int client, int item, int cash, int &count, int &sell);

/**
 * Called when a description of an item is about to be shown
 *
 * @param client	Client index
 * @param item		Item index
 * @param desc		Description of the item
 *
 * @noreturn
 */
forward void TextStore_OnDescItem(int client, int item, char[] desc);

/**
 * Called to a given plugin when a item is used
 *
 * @note		This is not actually a forward, this is called per plugin
 * @note		Do not close the KeyValues handle given
 *
 * @param client	Client index
 * @param equipped	If the item is already equipped on the client
 * @param item		KeyValue of the item (already in place)
 * @param index		Item Index
 * @param name		Name of the item
 * @param count		Amount of the item in the client's inventory
 *
 * @return		Item result
 */
forward ItemResult TextStore_Item(int client, bool equipped, KeyValues item, int index, const char[] name, int &count);

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

public SharedPlugin __pl_TextStore =
{
	name = "textstore",
	file = "textstore.smx",
	#if defined REQUIRE_PLUGIN
		required = 1,
	#else
		required = 0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_TextStore_SetNTVOptional()
{
	MarkNativeAsOptional("TextStore_GetInv");
	MarkNativeAsOptional("TextStore_SetInv");
	MarkNativeAsOptional("TextStore_Cash");
	MarkNativeAsOptional("TextStore_ClientSave");
	MarkNativeAsOptional("TextStore_ClientReload");
	MarkNativeAsOptional("TextStore_GetItems");
	MarkNativeAsOptional("TextStore_GetItemName");
	MarkNativeAsOptional("TextStore_GetItemData");
	MarkNativeAsOptional("TextStore_CreateUniqueItem");
}
#endif
