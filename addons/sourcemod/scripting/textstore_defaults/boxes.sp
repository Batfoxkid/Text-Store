#define ITEM_BOXES	"boxes"

stock ItemResult Boxes_Use(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
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

	ArrayList list = new ArrayList();
	ArrayList bonus = new ArrayList();
	if(item.GotoFirstSubKey())
	{
		item.GetSectionName(buffer, sizeof(buffer));
		do
		{
			static char buffer2[MAX_NUM_LENGTH];
			if(StrContains(buffer, ".") != -1)
			{
				float chance = StringToFloat(buffer);
				if(chance >= GetRandomFloat())
				{
					ArrayList current = new ArrayList();
					for(int i=1; ; i++)
					{
						IntToString(i, buffer2, sizeof(buffer2));
						item.GetString(buffer2, buffer, sizeof(buffer));
						if(!buffer[0])
							break;

						for(amount=0; amount<maxItems; amount++)
						{
							if(!StrEqual(buffer, names[amount], false))
								continue;

							current.Push(amount);
							break;
						}
					}

					amount = current.Length;
					if(amount)
						bonus.Push(current.Get(GetRandomInt(0, amount-1)));

					delete current;
				}
				continue;
			}

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

					for(amount=0; amount<chance; amount++)
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
	}

	length = bonus.Length;
	if(length)
	{
		for(int i; i<length; i++)
		{
			maxItems = bonus.Get(i);
			SPrintToChat(client, "You unboxed %s%s", STORE_COLOR2, names[maxItems]);

			TextStore_GetInv(client, maxItems, amount);
			TextStore_SetInv(client, maxItems, amount+1);
		}
	}

	delete list;
	delete bonus;
	return Item_Used;
}
