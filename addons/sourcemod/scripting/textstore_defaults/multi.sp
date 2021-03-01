#define ITEM_MULTI	"multi"

stock ItemResult Multi_Use(int client, bool equipped, KeyValues kv, int index, const char[] name, int &count)
{
	int maxItems = TextStore_GetItems();
	int amount;
	static char buffer[MAX_ITEM_LENGTH], buffer2[MAX_DATA_LENGTH+MAX_ITEM_LENGTH+MAX_ITEM_LENGTH];
	kv.GetString("locked", buffer, sizeof(buffer));
	if(buffer[0])
	{
		bool found;
		for(int i; i<maxItems; i++)
		{
			TextStore_GetItemName(i, buffer2, sizeof(buffer2));
			if(!StrEqual(buffer, buffer2, false))
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
		IntToString(i, buffer, sizeof(buffer));
		kv.GetString(buffer, buffer2, sizeof(buffer2));
		if(!buffer2[0])
			break;

		static char buffers[3][MAX_DATA_LENGTH];
		amount = ExplodeString(buffer2, ";", buffers, sizeof(buffers), sizeof(buffers[]));

		for(int a; a<maxItems; a++)
		{
			TextStore_GetItemName(a, buffer, sizeof(buffer));
			if(!StrEqual(buffers[0], buffer, false))
				continue;

			if(amount > 1)
			{
				TextStore_CreateUniqueItem(client, a, buffers[1], amount>2 ? buffers[2] : NULL_STRING);
			}
			else
			{
				TextStore_GetInv(client, a, amount);
				TextStore_SetInv(client, a, amount+1);
			}

			SPrintToChat(client, "You unboxed %s%s", STORE_COLOR2, amount>2 ? buffers[2] : buffer2);
			break;
		}
	}
	return Item_Used;
}
