#define ITEM_BOXES	"boxes"

stock ItemResult Boxes_Use(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
{
	int maxItems = TextStore_GetItems();

	int keyUsed, amount;
	static char buffer[64], buffer2[64];
	item.GetString("locked", buffer, sizeof(buffer));
	if(buffer[0])
	{
		bool found;
		for(; keyUsed<maxItems; keyUsed++)
		{
			if(!TextStore_GetItemName(keyUsed, buffer2, sizeof(buffer2)) || !StrEqual(buffer, buffer2, false))
				continue;

			TextStore_GetInv(client, keyUsed, amount);
			found = amount>0;
			break;
		}

		if(!found)
		{
			SPrintToChat(client, "This item requires %s%s", STORE_COLOR2, buffer);
			return Item_None;
		}
	}

	char[][] names = new char[maxItems][sizeof(buffer)];
	for(int i; i<maxItems; i++)
	{
		TextStore_GetItemName(i, names[i], sizeof(buffer));
	}

	ArrayList list = new ArrayList(sizeof(buffer));
	if(item.GotoFirstSubKey())
	{
		item.GetSectionName(buffer, sizeof(buffer));
		do
		{
			int chance = StringToInt(buffer);
			if(chance < 1)
				continue;

			for(int i=1; ; i++)
			{
				IntToString(i, buffer2, sizeof(buffer2));
				item.GetString(buffer2, buffer, sizeof(buffer));
				if(!buffer[0])
					break;

				for(int a; a<maxItems; a++)
				{
					if(!StrEqual(buffer, names[a], false))
						continue;

					for(int b; b<chance; b++)
					{
						list.Push(a);
					}
					break;
				}
			}
		} while(item.GotoNextKey() && item.GetSectionName(buffer, sizeof(buffer)));
	}

	int length = list.Length;
	if(length)
	{
		maxItems = list.Get(GetRandomInt(0, length-1));
		SPrintToChat(client, "You unboxed %s%s", STORE_COLOR2, names[maxItems]);

		TextStore_GetInv(client, maxItems, amount);
		TextStore_SetInv(client, maxItems, amount+1);
		if(keyUsed)
		{
			TextStore_GetInv(client, keyUsed, amount);
			TextStore_SetInv(client, keyUsed, amount-1);
		}
	}
	delete list;
	return length ? Item_Used : Item_None;
}
