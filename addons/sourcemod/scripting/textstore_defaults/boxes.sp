#define ITEM_BOXES	"boxes"

stock ItemResult Boxes_Use(int client, bool equipped, KeyValues kv, int index, const char[] name, int &count)
{
	int maxItems = TextStore_GetItems();
	int amount;
	static char buffer[MAX_ITEM_LENGTH], buffer2[MAX_ITEM_LENGTH+MAX_ITEM_LENGTH+MAX_DATA_LENGTH];
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

	static char buffers[3][MAX_DATA_LENGTH];
	ArrayList list = new ArrayList(sizeof(FullItemEnum));
	ArrayList bonus = new ArrayList(sizeof(FullItemEnum));
	if(kv.GotoFirstSubKey())
	{
		kv.GetSectionName(buffer, sizeof(buffer));
		do
		{
			if(StrContains(buffer, ".") != -1)
			{
				float chance = StringToFloat(buffer);
				if(chance >= GetRandomFloat())
				{
					for(amount=1; ; amount++)
					{
						IntToString(amount, buffer, sizeof(buffer));
						kv.GetString(buffer, buffer2, sizeof(buffer2));
						if(!buffer2[0])
							break;
					}

					if(amount != 1)
					{
						amount = GetRandomInt(1, amount-1);
						IntToString(amount, buffer, sizeof(buffer));
						kv.GetString(buffer, buffer2, sizeof(buffer2));

						amount = ExplodeString(buffer2, ";", buffers, sizeof(buffers), sizeof(buffers[]));
						for(int i; i<maxItems; i++)
						{
							TextStore_GetItemName(i, buffer, sizeof(buffer));
							if(!StrEqual(buffers[0], buffer, false))
								continue;

							FullItemEnum item;
							item.Index = i;

							if(amount > 1)
							{
								strcopy(item.Data, sizeof(item.Data), buffers[1]);
								if(amount > 2)
									strcopy(item.Name, sizeof(item.Name), buffers[2]);
							}

							bonus.PushArray(item);
							break;
						}
					}
				}
				continue;
			}

			int chance = StringToInt(buffer);
			if(chance < 1)
				continue;

			for(int i=1; ; i++)
			{
				IntToString(i, buffer, sizeof(buffer));
				kv.GetString(buffer, buffer2, sizeof(buffer2));
				if(!buffer2[0])
					break;

				amount = ExplodeString(buffer2, ";", buffers, sizeof(buffers), sizeof(buffers[]));
				for(int a; a<maxItems; a++)
				{
					TextStore_GetItemName(a, buffer, sizeof(buffer));
					if(!StrEqual(buffers[0], buffer, false))
						continue;

					FullItemEnum item;
					item.Index = a;

					if(amount > 1)
					{
						strcopy(item.Data, sizeof(item.Data), buffers[1]);
						if(amount > 2)
							strcopy(item.Name, sizeof(item.Name), buffers[2]);
					}

					for(amount=0; amount<chance; amount++)
					{
						list.PushArray(item);
					}
					break;
				}

			}
		} while(kv.GotoNextKey() && kv.GetSectionName(buffer, sizeof(buffer)));
	}

	FullItemEnum item;
	maxItems = list.Length;
	if(maxItems)
	{
		list.GetArray(GetRandomInt(0, maxItems-1), item);
		UnboxItem(client, item);
	}
	delete list;

	maxItems = bonus.Length;
	for(int i; i<maxItems; i++)
	{
		bonus.GetArray(i, item);
		UnboxItem(client, item);
	}
	delete bonus;
	return Item_Used;
}

static void UnboxItem(int client, FullItemEnum item)
{
	static char buffer[MAX_ITEM_LENGTH];
	if(item.Name[0])
	{
		strcopy(buffer, sizeof(buffer), item.Name);
	}
	else
	{
		TextStore_GetItemName(item.Index, buffer, sizeof(buffer));
	}

	SPrintToChat(client, "You unboxed %s%s", STORE_COLOR2, buffer);

	if(item.Data[0])
	{
		TextStore_CreateUniqueItem(client, item.Index, item.Data, item.Name);
	}
	else
	{
		int amount;
		TextStore_GetInv(client, item.Index, amount);
		TextStore_SetInv(client, item.Index, amount+1);
	}
}