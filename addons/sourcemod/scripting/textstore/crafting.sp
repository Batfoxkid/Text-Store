#define DATA_CRAFTING	"configs/textstore/crafting.cfg"

enum struct CraftEnum
{
	int Parent;
	int Admin;
	char Name[MAX_ITEM_LENGTH];
	KeyValues Kv;
}
ArrayList Crafts;

void Crafting_ConfigsExecuted()
{
	if(Crafts != INVALID_HANDLE)
	{
		CraftEnum craft;
		int length = Crafts.Length;
		for(int i; i<length; i++)
		{
			Crafts.GetArray(i, craft);
			if(craft.Kv != INVALID_HANDLE)
				delete craft.Kv;
		}
		delete Crafts;
	}

	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, PLATFORM_MAX_PATH, DATA_CRAFTING);
	if(!FileExists(buffer))
	{
		Crafts = null;
		return;
	}

	Crafts = new ArrayList(sizeof(CraftEnum));

	KeyValues kv = new KeyValues("");
	if(kv.ImportFromFile(buffer))
	{
		ReadCraftCategory(kv, -1);

		RegConsoleCmd("sm_craft", Crafting_Command, "View list of items to craft");
		RegConsoleCmd("sm_crafting", Crafting_Command, "View list of items to craft");
	}
	delete kv;
}

static void ReadCraftCategory(KeyValues kv, int parent)
{
	kv.GotoFirstSubKey();
	int i;
	char buffer[MAX_ITEM_LENGTH];
	do
	{
		CraftEnum craft;
		if(!kv.GetSectionName(craft.Name, sizeof(craft.Name)) || !craft.Name[0])
			break;

		craft.Parent = parent;

		kv.GetString("admin", buffer, sizeof(buffer));
		craft.Admin = ReadFlagString(buffer);

		if(kv.GetNum("cost", -9999) != -9999)
		{
			craft.Kv = new KeyValues(craft.Name);
			craft.Kv.Import(kv);

			Crafts.PushArray(craft);
		}
		else
		{
			craft.Kv = null;
			ReadCraftCategory(kv, Crafts.PushArray(craft));
		}
		i++;
	} while(kv.GotoNextKey());
	kv.GoBack();
}

public Action Crafting_Command(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	Client[client].BackOutAdmin = (args==-1);
	if(Client[client].StoreType != Type_Craft)
	{
		Client[client].ClearPos();
		Client[client].StoreType = Type_Craft;
	}

	Crafting(client);
	return Plugin_Handled;
}

static void Crafting(int client)
{
	CraftEnum craft;
	char buffer[MAX_TITLE_LENGTH];
	int primary = Client[client].GetPos();
	if(primary == -3)
	{
		Menu menu = new Menu(CraftingH);
		menu.SetTitle("Crafting: Available Recipes\n ");

		ItemEnum item;
		bool found, deny;
		int length = Items.Length;
		int length2 = Crafts.Length;
		for(int i; i<length2; i++)
		{
			Crafts.GetArray(i, craft);
			if(!craft.Kv || !CheckCommandAccess(client, "textstore_all", craft.Admin, true))
				continue;

			craft.Kv.Rewind();
			if(craft.Kv.GetNum("cost") > Client[client].Cash)
				continue;

			craft.Kv.GotoFirstSubKey();
			do
			{
				if(!craft.Kv.GetSectionName(buffer, sizeof(buffer)) || !buffer[0])
					break;

				for(int id; id<length; id++)
				{
					Items.GetArray(id, item);
					if(StrEqual(buffer, item.Name, false))
					{
						if(craft.Kv.GetNum("cost")>item.Count[client] || (craft.Kv.GetNum("gain")>0 && !item.Kv.GetNum("stack", 1) && item.Count[client]))
							deny = true;

						break;
					}
				}
			} while(!deny && craft.Kv.GotoNextKey());

			if(deny)
			{
				deny = false;
				continue;
			}

			found = true;
			IntToString(i, buffer, sizeof(buffer));
			menu.AddItem(buffer, craft.Name);
		}

		if(!found)
			menu.AddItem("", "No Recipes", ITEMDRAW_DISABLED);

		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	if(primary != -1)
		Crafts.GetArray(primary, craft);

	if(!craft.Kv)
	{
		Menu menu = new Menu(CraftingH);
		if(primary == -1)
		{
			menu.SetTitle("Crafting\n \nCredits: %d\n ", Client[client].Cash);
			menu.AddItem("-3", "Available Recipes");
		}
		else
		{
			menu.SetTitle("Crafting: %s\n ", craft.Name);
		}

		int length = Crafts.Length;
		for(int i; i<length; i++)
		{
			Crafts.GetArray(i, craft);
			if(craft.Parent != primary)
				continue;

			IntToString(i, buffer, sizeof(buffer));
			menu.AddItem(buffer, craft.Name, CheckCommandAccess(client, "textstore_all", craft.Admin, true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	Panel panel = new Panel();
	FormatEx(buffer, sizeof(buffer), "%s\n \nCost:", craft.Name);
	panel.SetTitle(buffer);

	craft.Kv.Rewind();
	bool deny;
	int value = craft.Kv.GetNum("cost");	
	if(value > 0)
	{
		if(Client[client].Cash < value)
			deny = true;

		FormatEx(buffer, sizeof(buffer), "Credits (%d/%d)", Client[client].Cash, value);
		panel.DrawText(buffer);
	}

	ItemEnum item;
	int length = Items.Length;
	craft.Kv.GotoFirstSubKey();
	do
	{
		if(!craft.Kv.GetSectionName(buffer, sizeof(buffer)) || !buffer[0])
			break;

		for(int i; i<length; i++)
		{
			Items.GetArray(i, item);
			if(StrEqual(buffer, item.Name, false))
			{
				value = craft.Kv.GetNum("cost");
				if(value > 0)
				{
					if(value > item.Count[client])
						deny = true;

					if(craft.Kv.GetNum("consume", 1))
					{
						FormatEx(buffer, sizeof(buffer), "%s (%d/%d)", item.Name, item.Count[client], value);
					}
					else
					{
						FormatEx(buffer, sizeof(buffer), "%s (%d/%d) [Tool]", item.Name, item.Count[client], value);
					}
					panel.DrawText(buffer);
				}
				break;
			}
		}
	} while(craft.Kv.GotoNextKey());

	panel.DrawText(" \nResult:");

	craft.Kv.GoBack();
	craft.Kv.GotoFirstSubKey();
	do
	{
		if(!craft.Kv.GetSectionName(buffer, sizeof(buffer)) || !buffer[0])
			break;

		for(int i; i<length; i++)
		{
			Items.GetArray(i, item);
			if(StrEqual(buffer, item.Name, false))
			{
				value = craft.Kv.GetNum("gain");
				if(value > 1)
				{
					if(item.Count[client] > 0)
					{
						FormatEx(buffer, sizeof(buffer), "%s x%d (Own %d)", item.Name, value, item.Count[client]);
					}
					else
					{
						FormatEx(buffer, sizeof(buffer), "%s x%d", item.Name, value);
					}
					panel.DrawText(buffer);
				}
				else if(value == 1)
				{
					if(item.Count[client] < 1)
					{
						panel.DrawText(item.Name);
					}
					else if(item.Kv.GetNum("stack", 1))
					{
						FormatEx(buffer, sizeof(buffer), "%s (Own %d)", item.Name, item.Count[client]);
						panel.DrawText(buffer);
					}
					else
					{
						deny = true;
						FormatEx(buffer, sizeof(buffer), "%s (Already Own)", item.Name);
						panel.DrawText(buffer);
					}
				}
				break;
			}
		}
	} while(craft.Kv.GotoNextKey());

	panel.DrawText(" ");
	panel.DrawItem("Craft", deny ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 8;
	panel.DrawItem("Back");
	panel.DrawText(" ");
	panel.CurrentKey = 10;
	panel.DrawItem("Exit");
	panel.Send(client, CraftingItemH, MENU_TIME_FOREVER);
	delete panel;
}

public int CraftingH(Menu menu, MenuAction action, int client, int choice)
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

			if(Client[client].RemovePos() != -1)
			{
				Crafting(client);
			}
			else if(!Client[client].BackOutAdmin || !AdminMenu_Return(client))
			{
				Main(client);
			}
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, sizeof(buffer));
			if(buffer[0])
				Client[client].AddPos(StringToInt(buffer));

			Crafting(client);
		}
	}
}

public int CraftingItemH(Menu panel, MenuAction action, int client, int choice)
{
	if(action != MenuAction_Select)
		return;

	switch(choice)
	{
		case 1:
		{
			CraftEnum craft;
			Crafts.GetArray(Client[client].GetPos(), craft);

			craft.Kv.Rewind();
			if(craft.Kv.GetNum("cost") <= Client[client].Cash)
			{
				static char buffer[MAX_ITEM_LENGTH];

				ItemEnum item;
				bool deny;
				int length = Items.Length;
				craft.Kv.GotoFirstSubKey();
				int[] amount = new int[length];
				do
				{
					if(!craft.Kv.GetSectionName(buffer, sizeof(buffer)) || !buffer[0])
						break;

					for(int i; i<length; i++)
					{
						Items.GetArray(i, item);
						if(StrEqual(buffer, item.Name, false))
						{
							int cost = craft.Kv.GetNum("cost");
							if(cost < 0)
								cost = 0;

							int gain = craft.Kv.GetNum("gain");
							if(gain < 0)
								gain = 0;

							if(cost>item.Count[client] || (gain && !item.Kv.GetNum("stack", 1) && item.Count[client]))
							{
								deny = true;
							}
							else
							{
								amount[i] = gain-cost;
							}
							break;
						}
					}
				} while(!deny && craft.Kv.GotoNextKey());

				if(!deny)
				{
					for(int i; i<length; i++)
					{
						if(!amount[i])
							continue;

						Items.GetArray(i, item);
						item.Count[client] += amount[i];
						Items.SetArray(i, item);
					}
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
	Crafting(client);
}