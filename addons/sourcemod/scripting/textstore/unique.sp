enum struct UniqueEnum
{
	int BaseItem;
	int Owner;
	bool Equipped;
	char Name[MAX_ITEM_LENGTH];
	char Data[MAX_DATA_LENGTH];
}
ArrayList UniqueList;

void Unique_PluginStart()
{
	if(UniqueList != INVALID_HANDLE)
		delete UniqueList;

	UniqueList = new ArrayList(sizeof(UniqueEnum));
}

void Unique_Disconnect(int client)
{
	UniqueEnum unique;
	int length = UniqueList.Length;
	for(int i; i<length; i++)
	{
		UniqueList.GetArray(i, unique);
		if(unique.Owner == client)
		{
			unique.Owner = 0;
			UniqueList.SetArray(i, unique);
		}
	}
}

int Unique_AddItem(int base, int client, bool equipped, const char[] name, const char[] data)
{
	UniqueEnum unique;

	unique.BaseItem = base;
	unique.Owner = client;
	unique.Equipped = equipped;
	strcopy(unique.Name, sizeof(unique.Name), name);
	strcopy(unique.Data, sizeof(unique.Data), data);

	return UniqueList.PushArray(unique);
}

bool Unique_HasUniqueOf(int client, int index)
{
	UniqueEnum unique;
	int length = UniqueList.Length;
	for(int i; i<length; i++)
	{
		UniqueList.GetArray(i, unique);
		if(unique.Owner==client && unique.BaseItem==index)
			return true;
	}
	return false;
}

static void Unique(int client)
{
	UniqueItem(client, Client[client].GetPos());
}

void UniqueItem(int client, int primary)
{
	ItemEnum item;
	UniqueEnum unique;
	if(primary >= 0)
	{
		Items.GetArray(primary, item);

		Menu menu = new Menu(UniqueH);
		menu.SetTitle("%s\n ", item.Name);

		int length = strlen(item.Name);
		item.Name[length] = '*';
		item.Name[length+1] = '\0';

		length = UniqueList.Length;
		bool found;
		for(int i; i<length; i++)
		{
			UniqueList.GetArray(i, unique);
			if(unique.BaseItem!=primary || unique.Owner!=client)
				continue;

			found = true;
			static char buffer[MAX_NUM_LENGTH];
			IntToString(-1-i, buffer, sizeof(buffer));
			menu.AddItem(buffer, unique.Name[0] ? unique.Name : item.Name);
		}

		if(!found)
			menu.AddItem("", "No Unique Items", ITEMDRAW_DISABLED);

		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	char buffer[MAX_DESC_LENGTH];
	UniqueList.GetArray(-1-primary, unique);
	Items.GetArray(unique.BaseItem, item);

	Panel panel = new Panel();
	if(unique.Name[0])
	{
		FormatEx(buffer, sizeof(buffer), "%s\n ", unique.Name);
	}
	else
	{
		FormatEx(buffer, sizeof(buffer), "%s*\n ", item.Name);
	}
	panel.SetTitle(buffer);

	item.Kv.Rewind();
	item.Kv.GetString("desc", buffer, sizeof(buffer), "No Description");
	ReplaceString(buffer, sizeof(buffer), "\\n", "\n");
	Forward_OnDescItem(client, primary, buffer);
	panel.DrawText(buffer);

	FormatEx(buffer, sizeof(buffer), " \nYou have %d credits\n ", Client[client].Cash);
	panel.DrawText(buffer);

	if(unique.Owner == client)
	{
		panel.DrawItem(unique.Equipped ? "Disactivate Item" : "Activate Item");

		int sell = GetSellPrice(unique.Data, item.Kv);
		if(sell > 0)
		{
			panel.CurrentKey = 3;
			FormatEx(buffer, sizeof(buffer), "Sell (%d Credits)", sell);
			panel.DrawItem(buffer, unique.Equipped ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.DrawText(" ");
		}
	}

	panel.CurrentKey = 8;
	panel.DrawItem("Back");
	panel.DrawText(" ");
	panel.CurrentKey = 10;
	panel.DrawItem("Exit");
	panel.Send(client, UniqueItemH, MENU_TIME_FOREVER);
	delete panel;
}

public int UniqueH(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if(choice != MenuCancel_ExitBack)
				return;

			ReturnStoreType(client);
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, sizeof(buffer));
			if(buffer[0])
				Client[client].AddPos(StringToInt(buffer));

			Unique(client);
		}
	}
}

public int UniqueItemH(Menu panel, MenuAction action, int client, int choice)
{
	if(action != MenuAction_Select)
		return;

	switch(choice)
	{
		case 1:
		{
			if(Unique_UseItem(client, -1-Client[client].GetPos()))
				Client[client].RemovePos();
		}
		case 3:
		{
			int id = Client[client].GetPos();
			int index = -1-id;

			UniqueEnum unique;
			UniqueList.GetArray(index, unique);
			if(unique.Owner==client && !unique.Equipped)
			{
				ItemEnum item;
				Items.GetArray(unique.BaseItem, item);
				int sell = GetSellPrice(unique.Data, item.Kv);
				if(sell > 0)
				{
					int temp = 1;
					int sell2 = sell;
					switch(Forward_OnSellItem(client, id, Client[client].Cash, temp, sell2))
					{
						case Plugin_Changed:
						{
							sell = sell2;
						}
						case Plugin_Handled, Plugin_Stop:
						{
							Unique(client);
							return;
						}
					}

					Client[client].Cash += sell;
					unique.Owner = 0;
					UniqueList.SetArray(index, unique);
					Client[client].RemovePos();
				}
			}
		}
		case 8:
		{
			Client[client].RemovePos();
		}
		case 10:
		{
			Client[client].RemovePos();
			return;
		}
	}
	Unique(client);
}

bool Unique_UseItem(int client, int index)
{
	UniqueEnum unique;
	UniqueList.GetArray(index, unique);

	if(unique.Owner == client)
	{
		ItemEnum item;
		Items.GetArray(unique.BaseItem, item);

		static char buffer[256];
		item.Kv.GetString("plugin", buffer, sizeof(buffer));

		int temp = 1;
		ItemResult result = Item_None;
		if(Forward_OnUseItem(result, buffer, client, unique.Equipped, item.Kv, -1-index, unique.Name, temp))
		{
			switch(result)
			{
				case Item_Used:
				{
					unique.Owner = 0;
				}
				case Item_On:
				{
					unique.Equipped = true;
				}
				case Item_Off:
				{
					unique.Equipped = false;
				}
			}

			UniqueList.SetArray(index, unique);
		}
		else if(CheckCommandAccess(client, "textstore_dev", ADMFLAG_RCON))
		{
			SPrintToChat(client, "'%s' could not find plugin '%s'", item.Name, buffer);
		}
		else
		{
			SPrintToChat(client, "%s can't be used right now!", item.Name);
		}
	}
	return !unique.Owner;
}

static int GetSellPrice(const char[] data, KeyValues kv)
{
	int sell = StrContains(data, "sell");
	if(sell == -1)
	{
		sell = kv.GetNum("sell", RoundFloat(kv.GetNum("cost")*SELLRATIO));
	}
	else
	{
		sell += 4;
		char buffer[16];
		int size = strlen(data);
		for(int i; ; i++)
		{
			if(sell>=size || !IsCharNumeric(data[sell]))
			{
				buffer[i] = '\0';
				break;
			}

			buffer[i] = data[sell];
			sell++;
		}
		sell = StringToInt(buffer);
	}
	return sell;
}