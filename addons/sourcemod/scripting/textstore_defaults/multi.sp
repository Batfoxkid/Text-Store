#define ITEM_MULTI	"multi"

stock ItemResult Multi_Use(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
{
	int maxItems = TextStore_GetItems();

	char[][] names = new char[maxItems][MAX_ITEM_LENGTH];
	for(int i; i<maxItems; i++)
	{
		TextStore_GetItemName(i, names[i], MAX_ITEM_LENGTH);
	}

	int amount;
	static char buffer[MAX_ITEM_LENGTH];
	item.GetString("locked", buffer, sizeof(buffer));
	if(buffer[0])
	{
		bool found;
		for(int i; i<maxItems; i++)
		{
			if(!StrEqual(buffer, names[i], false))
				continue;

			TextStore_GetInv(client, i, amount);
			if(amount > 0)
			{
				TextStore_SetInv(client, i, amount-1);
				found = true;
			}
			break;
		}

		if(!found)
		{
			SPrintToChat(client, "This item requires %s%s", STORE_COLOR2, buffer);
			return Item_None;
		}
	}

	for(int i=1; ; i++)
	{
		static char buffer2[MAX_NUM_LENGTH];
		IntToString(i, buffer2, sizeof(buffer2));
		item.GetString(buffer2, buffer, sizeof(buffer));
		if(!buffer[0])
			break;

		for(int a; a<maxItems; a++)
		{
			if(!StrEqual(buffer, names[a], false))
				continue;

			SPrintToChat(client, "You unboxed %s%s", STORE_COLOR2, names[a]);
			TextStore_GetInv(client, a, amount);
			TextStore_SetInv(client, a, amount+1);
			break;
		}
	}
	return Item_Used;
}
