#define DATA_CRAFTING	"configs/textstore/crafting.cfg"

#define ITEMCRAFT	CraftList[item].Items[i]
#define MAXCRAFT		256

enum struct CraftEnum
{
	bool Category;
	int Admin;
	char Name[MAX_ITEM_LENGTH];

	bool Consume[MAXITEMS+1];
	int Items[MAXITEMS+1];
	int Result[MAXITEMS+1];
}

int CraftItems;
static CraftEnum CraftList[MAXCRAFT+1];

void Crafting_ConfigsExecuted()
{
	CraftItems = 0;

	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, PLATFORM_MAX_PATH, DATA_CRAFTING);
	if(!FileExists(buffer))
		return;

	KeyValues kv = new KeyValues("");
	if(kv.ImportFromFile(buffer))
	{
		ReadCraftCategory(kv, 0);

		RegConsoleCmd("sm_craft", Crafting_Command, "View list of items to craft");
		RegConsoleCmd("sm_crafting", Crafting_Command, "View list of items to craft");
	}
	delete kv;
}

static void ReadCraftCategory(KeyValues kv, int parent)
{
	CraftList[parent].Category = true;

	kv.GotoFirstSubKey();
	int i;
	do
	{
		if(!kv.GetSectionName(CraftList[CraftItems+1].Name, sizeof(CraftList[].Name)) || !CraftList[CraftItems+1].Name[0])
			break;

		if(kv.GetNum("hidden"))
			continue;

		CraftList[parent].Items[i] = ++CraftItems;
		CharToUpper(CraftList[CraftItems].Name[0]);
		int cost = kv.GetNum("cost", -999999);
		if(cost == -999999)
		{
			ReadCraftCategory(kv, CraftItems);
		}
		else
		{
			CraftList[CraftItems].Items[0] = cost;
			ReadCraftItem(kv, CraftItems);
		}
		i++;
	} while(CraftItems<MAXCRAFT && i<MAXITEMS && kv.GotoNextKey());
	kv.GoBack();
}

static void ReadCraftItem(KeyValues kv, int item)
{
	CraftList[item].Category = false;

	char buffer[MAX_ITEM_LENGTH];
	kv.GetString("admin", buffer, sizeof(buffer));
	CraftList[item].Admin = ReadFlagString(buffer);

	kv.GotoFirstSubKey();
	do
	{
		if(!kv.GetSectionName(buffer, sizeof(buffer)) || !buffer[0])
			break;

		int i;
		for(i=1; i<=MaxItems; i++)
		{
			if(StrEqual(buffer, Item[i].Name, false))
				break;
		}

		if(i > MaxItems)
			continue;

		CraftList[item].Items[i] = kv.GetNum("cost");
		CraftList[item].Consume[i] = view_as<bool>(kv.GetNum("consume", 1));
		CraftList[item].Result[i] = kv.GetNum("gain");
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
	if(IsVoteInProgress())
	{
		PrintToChat(client, "[SM] %t", "Vote in Progress");
		return;
	}

	char buffer[MAX_TITLE_LENGTH];
	int item = Client[client].GetPos();
	if(item == -3)
	{
		Menu menu = new Menu(CraftingH);
		menu.SetTitle("Crafting: Available Recipes\n ");
		bool items, deny;
		for(int i=1; i<=MaxItems; i++)
		{
			if(CraftList[i].Category || !CheckCommandAccess(client, "textstore_all", CraftList[i].Admin, true))
				continue;

			for(int a=1; a<=MaxItems; a++)
			{
				if(CraftList[i].Items[a]<1 || Inv[client][a].Count>=CraftList[i].Items[a])
					continue;

				deny = true;
				break;
			}

			if(deny)
			{
				deny = false;
				continue;
			}

			items = true;
			IntToString(i, buffer, sizeof(buffer));
			menu.AddItem(buffer, CraftList[i].Name);
		}

		if(!items)
			menu.AddItem("0", "No Recipes", ITEMDRAW_DISABLED);

		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	if(!item || CraftList[item].Category)
	{
		Menu menu = new Menu(CraftingH);
		if(item)
		{
			menu.SetTitle("Crafting: %s\n ", CraftList[item].Name);
		}
		else
		{
			menu.SetTitle("Crafting\n \nCredits: %d\n ", Client[client].Cash);
			menu.AddItem("-3", "Available Recipes");
		}

		bool items;
		for(int i; i<=MaxItems; i++)
		{
			if(ITEMCRAFT < 1)
				break;

			items = true;
			IntToString(ITEMCRAFT, buffer, sizeof(buffer));
			menu.AddItem(buffer, CraftList[ITEMCRAFT].Name, CheckCommandAccess(client, "textstore_all", CraftList[ITEMCRAFT].Admin, true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		if(!items)
			menu.AddItem("0", "No Recipes", ITEMDRAW_DISABLED);

		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	Panel panel = new Panel();
	FormatEx(buffer, sizeof(buffer), "%s\n \nCost:", CraftList[item].Name);
	panel.SetTitle(buffer);

	bool deny;
	if(CraftList[item].Items[0] > 0)
	{
		if(Client[client].Cash < CraftList[item].Items[0])
			deny = true;

		FormatEx(buffer, sizeof(buffer), "Credits (%d/%d)", Client[client].Cash, CraftList[item].Items[0]);
		panel.DrawText(buffer);
	}

	for(int i=1; i<=MaxItems; i++)
	{
		if(CraftList[item].Items[i] < 1)
			continue;

		if(!deny && Inv[client][i].Count<CraftList[item].Items[i])
			deny = true;

		if(CraftList[item].Consume[i])
		{
			FormatEx(buffer, sizeof(buffer), "%s (%d/%d)", Item[i].Name, Inv[client][i].Count, CraftList[item].Items[i]);
		}
		else
		{
			FormatEx(buffer, sizeof(buffer), "%s (%d/%d) [Tool]", Item[i].Name, Inv[client][i].Count, CraftList[item].Items[i]);
		}
		panel.DrawText(buffer);
	}

	panel.DrawText(" \nResult:");
	for(int i=1; i<=MaxItems; i++)
	{
		if(CraftList[item].Result[i] > 1)
		{
			if(Inv[client][i].Count > 0)
			{
				FormatEx(buffer, sizeof(buffer), "%s x%d (Own %d)", Item[i].Name, CraftList[item].Result[i], Inv[client][i].Count);
			}
			else
			{
				FormatEx(buffer, sizeof(buffer), "%s x%d", Item[i].Name, CraftList[item].Result[i]);
			}
		}
		else if(CraftList[item].Result[i] > 0)
		{
			if(Inv[client][i].Count > 0)
			{
				FormatEx(buffer, sizeof(buffer), "%s (Own %d)", Item[i].Name, Inv[client][i].Count);
			}
			else
			{
				strcopy(buffer, sizeof(buffer), Item[i].Name);
			}
		}
		else
		{
			continue;
		}

		panel.DrawText(buffer);
	}

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

			if(Client[client].RemovePos())
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
			int item = StringToInt(buffer);
			if(item)
				Client[client].AddPos(item);

			Crafting(client);
		}
	}
}

public int CraftingItemH(Menu panel, MenuAction action, int client, int choice)
{
	if(action != MenuAction_Select)
		return;

	int item = Client[client].GetPos();
	switch(choice)
	{
		case 1:
		{
			if(CraftList[item].Items[0]<1 || Client[client].Cash>=CraftList[item].Items[0])
			{
				bool deny;
				for(int i=1; i<=MaxItems; i++)
				{
					if(CraftList[item].Items[i]<1 || Inv[client][i].Count>=CraftList[item].Items[i])
						continue;

					deny = true;
					break;
				}

				if(!deny)
				{
					for(int i=1; i<=MaxItems; i++)
					{
						if(CraftList[item].Items[i]>0 && CraftList[item].Consume[i])
							Inv[client][i].Count -= CraftList[item].Items[i];

						if(CraftList[item].Result[i] > 0)
							Inv[client][i].Count += CraftList[item].Result[i];
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