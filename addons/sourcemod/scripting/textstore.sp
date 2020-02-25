#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN
#include <morecolors>
#include <textstore>

#pragma newdecls required

#define PLUGIN_VERSION "0.3.0"

#define FAR_FUTURE		100000000.0
#define MAX_SOUND_LENGTH	80
#define MAX_MODEL_LENGTH	128
#define MAX_MATERIAL_LENGTH	128
#define MAX_ENTITY_LENGTH	48
#define MAX_EFFECT_LENGTH	48
#define MAX_ATTACHMENT_LENGTH	48
#define MAX_ICON_LENGTH		48
#define MAX_INFO_LENGTH		128
#define HEX_OR_DEC_LENGTH	12
#define MAX_ATTRIBUTE_LENGTH	256
#define MAX_CONDITION_LENGTH	256
#define MAX_CLASSNAME_LENGTH	64
#define MAX_PLUGIN_LENGTH	64
#define MAX_ITEM_LENGTH		48
#define MAX_DESC_LENGTH		256
#define MAX_TITLE_LENGTH	192
#define MAX_NUM_LENGTH		5
#define VOID_ARG		-1

#define ITEM	Item[item].Items[i]

#define DATA_PLAYERS	"data/textstore/user/%s.txt"
#define DATA_STORE	"configs/textstore/store.cfg"

#define ADMINMENU_TEXTSTORE	"TextStoreCommands"

#define SELLRATIO	0.75
#define MAXITEMS	256
#define MAXONCE		64
#define MAXCATEGORIES	8

KeyValues StoreKv;
int MaxItems;
GlobalForward OnSellItem; 
TopMenu StoreTop;

enum StoreTypeEnum
{
	Type_Main = 0,
	Type_Store,
	Type_Inven,
	Type_Admin
}

enum struct InvEnum
{
	bool Equip;
	int Count;
}
InvEnum Inv[MAXPLAYERS+1][MAXITEMS+1];

enum struct ItemEnum
{
	bool Hidden;
	bool Stack;
	bool Trade;
	int Cost;
	int Sell;
	int Admin;
	int Slot;
	int Items[MAXONCE];
	char Name[MAX_ITEM_LENGTH];
	char Desc[MAX_DESC_LENGTH];
	char Plugin[MAX_PLUGIN_LENGTH];
}
ItemEnum Item[MAXITEMS+1];

enum struct ClientEnum
{
	int Cash;
	int Pos[MAXCATEGORIES];
	StoreTypeEnum StoreType;
	bool BackOutAdmin;

	void Setup(int client)
	{
		int i;
		for(; i<MAXCATEGORIES; i++)
		{
			this.Pos[i] = 0;
		}

		this.Cash = 0;
		for(i=0; i<=MAXITEMS; i++)
		{
			Inv[client][i].Count = 0;
			Inv[client][i].Equip = false;
		}

		if(IsFakeClient(client))
			return;

		char buffer[PLATFORM_MAX_PATH];
		if(!GetClientAuthId(client, AuthId_SteamID64, buffer, PLATFORM_MAX_PATH))
			return;

		BuildPath(Path_SM, buffer, PLATFORM_MAX_PATH, DATA_PLAYERS, buffer);
		if(!FileExists(buffer))
			return;

		File file = OpenFile(buffer, "r");
		if(file == null)
			return;

		int count;
		char buffers[3][MAX_ITEM_LENGTH];
		while(!file.EndOfFile() && file.ReadLine(buffer, PLATFORM_MAX_PATH))
		{
			count = ExplodeString(buffer, ";", buffers, 3, MAX_ITEM_LENGTH);

			if(count < 2)
				continue;

			if(StrEqual(buffers[0], "cash"))
				this.Cash = StringToInt(buffers[1]);

			for(i=1; i<=(MaxItems+1); i++)
			{
				if(i<=MaxItems && StrEqual(buffers[0], Item[i].Name))
					break;
			}

			if(i > MaxItems)
				continue;

			Inv[client][i].Count = StringToInt(buffers[1]);
			Inv[client][i].Equip = view_as<bool>(StringToInt(buffers[2]));
		}
		delete file;
	}

	void Save(int client)
	{
		char buffer[PLATFORM_MAX_PATH];
		if(!GetClientAuthId(client, AuthId_SteamID64, buffer, PLATFORM_MAX_PATH))
			return;

		BuildPath(Path_SM, buffer, PLATFORM_MAX_PATH, DATA_PLAYERS, buffer);
		File file = OpenFile(buffer, "w");
		if(file == null)
			return;

		file.WriteLine("cash;%i", this.Cash);
		for(int i=1; i<=MaxItems; i++)
		{
			if(Inv[client][i].Count > 0)
				file.WriteLine("%s;%i;%i", Item[i].Name, Inv[client][i].Count, Inv[client][i].Equip ? 1 : 0);
		}
		delete file;
	}

	int GetPos()
	{
		int item;
		for(int i=(MAXCATEGORIES-1); i>=0; i--)
		{
			item = this.Pos[i];
			if(item)
				return item;
		}
		return 0;
	}

	void AddPos(int item)
	{
		for(int i; i<MAXCATEGORIES; i++)
		{
			if(!this.Pos[i])
			{
				this.Pos[i] = item;
				return;
			}
		}
	}

	int RemovePos()
	{
		int item;
		for(int i=(MAXCATEGORIES-1); i>=0; i--)
		{
			item = this.Pos[i];
			if(item)
			{
				this.Pos[i] = 0;
				return item;
			}
		}
		return 0;
	}

	void ClearPos()
	{
		for(int i; i<MAXCATEGORIES; i++)
		{
			this.Pos[i] = 0;
		}
	}
}
ClientEnum Client[MAXPLAYERS+1];

// SourceMod Events

public Plugin myinfo =
{
	name		=	"The Text Store",
	author		=	"Batfoxkid",
	description	=	"Buy and view an inventory of items",
	version		=	PLUGIN_VERSION
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TextStore_GetInv", Native_GetInv);
	CreateNative("TextStore_SetInv", Native_SetInv);
	CreateNative("TextStore_Cash", Native_Cash);
	OnSellItem = new GlobalForward("TextStore_OnSellItem", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);

	RegPluginLibrary("textstore");
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_store", CommandMain, "View the main menu");
	RegConsoleCmd("sm_shop", CommandMain, "View the main menu");

	RegConsoleCmd("sm_buy", CommandStore, "Browse items to buy");

	RegConsoleCmd("sm_inventory", CommandInven, "View your backpack of items");
	RegConsoleCmd("sm_inven", CommandInven, "View your backpack of items");
	RegConsoleCmd("sm_sell", CommandInven, "View your backpack of items");
	RegConsoleCmd("sm_inv", CommandInven, "View your backpack of items");

	RegAdminCmd("sm_store_admin", CommandAdmin, ADMFLAG_ROOT, "View the admin menu");

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	TopMenu topmenu;
	if(LibraryExists("adminmenu") && ((topmenu=GetAdminTopMenu())!=null))
		OnAdminMenuReady(topmenu);
}

public void OnPluginEnd()
{
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i))
			OnClientDisconnect(i);
	}
}

public void OnConfigsExecuted()
{
	MaxItems = 0;

	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, PLATFORM_MAX_PATH, DATA_STORE);
	StoreKv = new KeyValues("");
	StoreKv.ImportFromFile(buffer);

	ReadCategory(0);

	for(int i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i))
			Client[i].Setup(i);
	}
}

public void OnAdminMenuCreated(Handle topmenu)
{
	TopMenu menu = TopMenu.FromHandle(topmenu);
	if(menu.FindCategory(ADMINMENU_TEXTSTORE) == INVALID_TOPMENUOBJECT)
		menu.AddCategory(ADMINMENU_TEXTSTORE, TopMenuCategory);
}

public void OnAdminMenuReady(Handle topmenu)
{
	TopMenu menu = TopMenu.FromHandle(topmenu);
	if(menu == StoreTop)
		return;

	StoreTop = menu;
	TopMenuObject topobject = StoreTop.FindCategory(ADMINMENU_TEXTSTORE);
	if(topobject == INVALID_TOPMENUOBJECT)
	{
		topobject = StoreTop.AddCategory(ADMINMENU_TEXTSTORE, TopMenuCategory);
		if(topobject == INVALID_TOPMENUOBJECT)
			return;
	}

	StoreTop.AddItem("sm_buy", StoreT, topobject, "sm_buy", 0);
	StoreTop.AddItem("sm_sell", InventoryT, topobject, "sm_sell", 0);
	StoreTop.AddItem("sm_store_admin", AdminMenuT, topobject, "sm_store_admin", ADMFLAG_ROOT);
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "adminmenu"))
		StoreTop = null;
}

// Game Events

public void OnClientPostAdminCheck(int client)
{
	Client[client].Setup(client);
}

public void OnClientDisconnect(int client)
{
	Client[client].Save(client);
}

// Setup Events

void ReadCategory(int parent)
{
	StoreKv.GetSectionName(Item[parent].Name, MAX_ITEM_LENGTH);
	StoreKv.GotoFirstSubKey();
	int i;
	char buffer[MAX_ITEM_LENGTH];
	do
	{
		if(!StoreKv.GetSectionName(buffer, MAX_ITEM_LENGTH) || !buffer[0])
			break;

		Item[parent].Items[i] = ++MaxItems;
		if(StoreKv.GetNum("cost") < 1)
		{
			ReadCategory(MaxItems);
		}
		else
		{
			// Compiler wouldn't let me put this in the enum .w.
			StoreKv.GetSectionName(Item[MaxItems].Name, MAX_ITEM_LENGTH);

			StoreKv.GetString("admin", buffer, MAX_ITEM_LENGTH);
			Item[MaxItems].Admin = ReadFlagString(buffer);

			Item[MaxItems].Cost = StoreKv.GetNum("cost");
			Item[MaxItems].Hidden = view_as<bool>(StoreKv.GetNum("hidden", GetRandomInt(0, 5) ? 0 : 1));
			Item[MaxItems].Stack = view_as<bool>(StoreKv.GetNum("stack", 1));
			Item[MaxItems].Trade = view_as<bool>(StoreKv.GetNum("trade", 1));
			Item[MaxItems].Slot = StoreKv.GetNum("slot");
			StoreKv.GetString("plugin", Item[MaxItems].Plugin, MAX_PLUGIN_LENGTH);
			StoreKv.GetString("desc", Item[MaxItems].Desc, MAX_DESC_LENGTH, "No Description");
			Item[MaxItems].Sell = StoreKv.GetNum("sell", RoundFloat(Item[MaxItems].Cost*SELLRATIO));
		}
		i++;
	} while(MaxItems<MAXITEMS && i<MAXONCE && StoreKv.GotoNextKey());
	StoreKv.GoBack();
}

// Command Events

public Action CommandMain(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	Client[client].StoreType = Type_Main;
	Main(client);
	return Plugin_Handled;
}

public Action CommandStore(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	Client[client].BackOutAdmin = (args==-1);
	if(Client[client].StoreType != Type_Store)
	{
		Client[client].ClearPos();
		Client[client].StoreType = Type_Store;
	}

	Store(client);
	return Plugin_Handled;
}

public Action CommandInven(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	Client[client].BackOutAdmin = (args==-1);
	if(Client[client].StoreType != Type_Inven)
	{
		Client[client].ClearPos();
		Client[client].StoreType = Type_Inven;
	}

	Inventory(client);
	return Plugin_Handled;
}

public Action CommandAdmin(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	Client[client].BackOutAdmin = (args==-1);
	if(Client[client].StoreType != Type_Admin)
	{
		Client[client].ClearPos();
		Client[client].StoreType = Type_Admin;
	}

	AdminMenu(client);
	return Plugin_Handled;
}

// TopMenu Events

public void TopMenuCategory(TopMenu topmenu, TopMenuAction action, TopMenuObject topobject, int client, char[] buffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayTitle:
			strcopy(buffer, maxlength, "Text Store:");

		case TopMenuAction_DisplayOption:
			strcopy(buffer, maxlength, "Text Store");
	}
}

public void StoreT(TopMenu topmenu, TopMenuAction action, TopMenuObject topobject, int client, char[] buffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			strcopy(buffer, maxlength, "Store Menu");

		case TopMenuAction_SelectOption:
			CommandStore(client, -1);
	}
}

public void InventoryT(TopMenu topmenu, TopMenuAction action, TopMenuObject topobject, int client, char[] buffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			strcopy(buffer, maxlength, "Inventory Menu");

		case TopMenuAction_SelectOption:
			CommandInven(client, -1);
	}
}

public void AdminMenuT(TopMenu topmenu, TopMenuAction action, TopMenuObject topobject, int client, char[] buffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			strcopy(buffer, maxlength, "Admin Menu");

		case TopMenuAction_SelectOption:
			CommandAdmin(client, -1);
	}
}

// Menu Events

void Main(int client)
{
	if(IsVoteInProgress())
	{
		PrintToChat(client, "[SM] %t", "Vote in Progress");
		return;
	}

	Menu menu = new Menu(MainH);
	menu.SetTitle("Main Menu\n \nCredits: %i\n ", Client[client].Cash);

	menu.AddItem("", "Store");
	menu.AddItem("", "Inventory");
	if(CheckCommandAccess(client, "sm_store_admin", ADMFLAG_ROOT))
		menu.AddItem("", "Admin Menu");

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MainH(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			switch(choice)
			{
				case 0:
					CommandStore(client, 0);

				case 1:
					CommandInven(client, 0);

				case 2:
					CommandAdmin(client, 0);
			}
		}
	}
}

void Store(int client)
{
	if(IsVoteInProgress())
	{
		PrintToChat(client, "[SM] %t", "Vote in Progress");
		return;
	}

	int item = Client[client].GetPos();
	if(!item || Item[item].Items[0]>0)
	{
		Menu menu = new Menu(StoreH);
		if(item)
		{
			menu.SetTitle("Store: %s\n ", Item[item].Name);
		}
		else
		{
			menu.SetTitle("Store\n \nCredits: %i\n ", Client[client].Cash);
		}
		for(int i; i<MAXONCE; i++)
		{
			if(ITEM < 1)
				break;

			if(Item[ITEM].Hidden)
				continue;

			static char buffer[MAX_NUM_LENGTH];
			IntToString(ITEM, buffer, MAX_NUM_LENGTH);
			menu.AddItem(buffer, Item[ITEM].Name, CheckCommandAccess(client, "textstore_all", Item[ITEM].Admin, true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	Panel panel = new Panel();
	char buffer[MAX_ITEM_LENGTH];
	FormatEx(buffer, MAX_ITEM_LENGTH, "%s\n ", Item[item].Name);
	panel.SetTitle(buffer);
	panel.DrawText(Item[item].Desc);

	if(Item[item].Stack)
	{
		FormatEx(buffer, MAX_ITEM_LENGTH, " \nYou have %i credits\nYou own %i\n ", Client[client].Cash, Inv[client][item].Count);
	}
	else
	{
		FormatEx(buffer, MAX_ITEM_LENGTH, " \nYou have %i credits\nYou %sown this item\n ", Client[client].Cash, Inv[client][item].Count<1 ? "don't " : "");
	}
	panel.DrawText(buffer);

	panel.DrawItem((Inv[client][item].Count>0 && Inv[client][item].Equip) ? "Disactivate Item" : "Activate Item", Inv[client][item].Count>0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	FormatEx(buffer, MAX_ITEM_LENGTH, "Buy (%i Credits)", Item[item].Cost);
	if((!Item[item].Stack && Inv[client][item].Count>0) || Client[client].Cash<Item[item].Cost)
	{
		panel.DrawItem(buffer, ITEMDRAW_DISABLED);
	}
	else
	{
		panel.DrawItem(buffer);
	}

	if(Item[item].Sell > 0)
	{
		FormatEx(buffer, MAX_ITEM_LENGTH, "Sell (%i Credits)", Item[item].Sell);
		panel.DrawItem(buffer, Inv[client][item].Count>0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	panel.DrawText(" ");
	panel.CurrentKey = 8;
	panel.DrawItem("Back");
	panel.DrawText(" ");
	panel.CurrentKey = 10;
	panel.DrawItem("Exit");
	panel.Send(client, StoreItemH, MENU_TIME_FOREVER);
}

public int StoreH(Menu menu, MenuAction action, int client, int choice)
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
				Store(client);
			}
			else if(Client[client].BackOutAdmin && StoreTop)
			{
				StoreTop.Display(client, TopMenuPosition_LastCategory);
			}
			else
			{
				Main(client);
			}
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, MAX_NUM_LENGTH);
			int item = StringToInt(buffer);
			if(item)
				Client[client].AddPos(item);

			Store(client);
		}
	}
}

public int StoreItemH(Menu panel, MenuAction action, int client, int choice)
{
	if(action != MenuAction_Select)
		return;

	int item = Client[client].GetPos();
	switch(choice)
	{
		case 1:
		{
			if(Inv[client][item].Count > 0)
				UseItem(client);
		}
		case 2:
		{
			if((Item[item].Stack || Inv[client][item].Count<1) && Client[client].Cash>=Item[item].Cost)
			{
				Inv[client][item].Count++;
				Client[client].Cash -= Item[item].Cost;
			}
		}
		case 3:
		{
			SellItem(client, item);
		}
		case 10:
		{
			Client[client].RemovePos();
			return;
		}
		default:
		{
			Client[client].RemovePos();
		}
	}
	Store(client);
}

void Inventory(int client)
{
	if(IsVoteInProgress())
	{
		PrintToChat(client, "[SM] %t", "Vote in Progress");
		return;
	}

	int item = Client[client].GetPos();
	if(!item || Item[item].Items[0]>0)
	{
		Menu menu = new Menu(InventoryH);
		if(item)
		{
			menu.SetTitle("Inventory: %s\n ", Item[item].Name);
		}
		else
		{
			menu.SetTitle("Inventory\n \nCredits: %i\n ", Client[client].Cash);
		}

		bool items;
		for(int i; i<MAXONCE; i++)
		{
			if(ITEM < 1)
				break;

			if(Item[ITEM].Items[0]<1 && Inv[client][ITEM].Count<1)
				continue;

			items = true;
			static char buffer[MAX_NUM_LENGTH];
			IntToString(ITEM, buffer, MAX_NUM_LENGTH);
			menu.AddItem(buffer, Item[ITEM].Name);
		}

		if(!items)
			menu.AddItem("0", "No Items", ITEMDRAW_DISABLED);

		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	Panel panel = new Panel();
	char buffer[MAX_ITEM_LENGTH];
	FormatEx(buffer, MAX_ITEM_LENGTH, "%s\n ", Item[item].Name);
	panel.SetTitle(buffer);
	panel.DrawText(Item[item].Desc);

	if(Item[item].Stack)
	{
		FormatEx(buffer, MAX_ITEM_LENGTH, " \nYou have %i credits\nYou own %i\n ", Client[client].Cash, Inv[client][item].Count);
	}
	else
	{
		FormatEx(buffer, MAX_ITEM_LENGTH, " \nYou have %i credits\nYou %sown this item\n ", Client[client].Cash, Inv[client][item].Count<1 ? "don't " : "");
	}
	panel.DrawText(buffer);

	panel.DrawItem(Inv[client][item].Equip ? "Disactivate Item" : "Activate Item");

	FormatEx(buffer, MAX_ITEM_LENGTH, "Buy (%i Credits)", Item[item].Cost);
	if((!Item[item].Stack && Inv[client][item].Count>0) || Client[client].Cash<Item[item].Cost)
	{
		panel.DrawItem(buffer, ITEMDRAW_DISABLED);
	}
	else
	{
		panel.DrawItem(buffer);
	}

	if(Item[item].Sell > 0)
	{
		FormatEx(buffer, MAX_ITEM_LENGTH, "Sell (%i Credits)", Item[item].Sell);
		panel.DrawItem(buffer, Inv[client][item].Count>0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	panel.DrawText(" ");
	panel.CurrentKey = 8;
	panel.DrawItem("Back");
	panel.DrawText(" ");
	panel.CurrentKey = 10;
	panel.DrawItem("Exit");
	panel.Send(client, InventoryItemH, MENU_TIME_FOREVER);
}

public int InventoryH(Menu menu, MenuAction action, int client, int choice)
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
				Inventory(client);
			}
			else if(Client[client].BackOutAdmin && StoreTop)
			{
				StoreTop.Display(client, TopMenuPosition_LastCategory);
			}
			else
			{
				Main(client);
			}
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, MAX_NUM_LENGTH);
			int item = StringToInt(buffer);
			if(item)
				Client[client].AddPos(item);

			Inventory(client);
		}
	}
}

public int InventoryItemH(Menu panel, MenuAction action, int client, int choice)
{
	if(action != MenuAction_Select)
		return;

	int item = Client[client].GetPos();
	switch(choice)
	{
		case 1:
		{
			if(Inv[client][item].Count > 0)
			{
				UseItem(client);
				if(Inv[client][item].Count < 1)
					Client[client].RemovePos();
			}
		}
		case 2:
		{
			if((Item[item].Stack || Inv[client][item].Count<1) && Client[client].Cash>=Item[item].Cost)
			{
				Inv[client][item].Count++;
				Client[client].Cash -= Item[item].Cost;
			}
		}
		case 3:
		{
			SellItem(client, item);
		}
		case 10:
		{
			Client[client].RemovePos();
			return;
		}
		default:
		{
			Client[client].RemovePos();
		}
	}
	Inventory(client);
}

void AdminMenu(int client)
{
	if(!CheckCommandAccess(client, "sm_store_admin", ADMFLAG_ROOT))
	{
		PrintToChat(client, "[SM] %t", "No Access");
		return;
	}

	if(IsVoteInProgress())
	{
		PrintToChat(client, "[SM] %t", "Vote in Progress");
		return;
	}

	switch(Client[client].Pos[0])
	{
		case 1:
		{
			if(!Client[client].Pos[1])
			{
				Menu menu = new Menu(AdminMenuH);
				menu.SetTitle("Store Admin Menu: Credits\nTarget:");
				GenerateClientList(menu, client);
				menu.ExitBackButton = true;
				menu.ExitButton = true;
				menu.Display(client, MENU_TIME_FOREVER);
				return;
			}

			int target = GetClientOfUserId(Client[client].Pos[1]);
			if(IsValidClient(target))
			{
				if(!Client[client].Pos[2])
				{
					Menu menu = new Menu(AdminMenuH);
					menu.SetTitle("Store Admin Menu: Credits\nTarget: %N\nMode:", target);
					menu.AddItem("1", "Add");
					menu.AddItem("2", "Remove");
					menu.AddItem("3", "Set");
					menu.ExitBackButton = true;
					menu.ExitButton = true;
					menu.Display(client, MENU_TIME_FOREVER);
					return;
				}

				if(!Client[client].Pos[3])
				{
					Menu menu = new Menu(AdminMenuH);
					menu.SetTitle("Store Admin Menu: Credits\nTarget: %N\nMode: %s\nAmount:", target, Client[client].Pos[2]==3 ? "Set" : Client[client].Pos[2]==2 ? "Remove" : "Add");
					if(Client[client].Pos[2] == 3)
						menu.AddItem("0", "0");

					menu.AddItem("100", "100");
					menu.AddItem("300", "300");
					menu.AddItem("500", "500");
					menu.AddItem("1000", "1,000");
					menu.AddItem("5000", "5,000");
					menu.AddItem("10000", "10,000");
					if(Client[client].Pos[2] != 3)
						menu.AddItem("50000", "50,000");

					menu.ExitBackButton = true;
					menu.ExitButton = true;
					menu.Display(client, MENU_TIME_FOREVER);
					return;
				}

				switch(Client[client].Pos[2])
				{
					case 1:
					{
						Client[target].Cash -= Client[client].Pos[3];
						CShowActivity2(client, STORE_PREFIX2, "%stoke %s%i%s credits from %s%N", STORE_COLOR, STORE_COLOR2, Client[client].Pos[3], STORE_COLOR, STORE_COLOR2, target);
					}
					case 2:
					{
						Client[target].Cash = Client[client].Pos[3];
						CShowActivity2(client, STORE_PREFIX2, "%sset %s%N's%s credits to %s%i", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR, STORE_COLOR2, Client[client].Pos[3]);
					}
					default:
					{
						Client[target].Cash += Client[client].Pos[3];
						CShowActivity2(client, STORE_PREFIX2, "%sgave %s%N %i%s credits", STORE_COLOR, STORE_COLOR2, target, Client[client].Pos[3], STORE_COLOR);
					}
				}
			}
			else
			{
				PrintToChat(client, "[SM] %t", "Player no longer available");
			}
			Client[client].ClearPos();
		}
		case 2:
		{
			if(!Client[client].Pos[1])
			{
				Menu menu = new Menu(AdminMenuH);
				menu.SetTitle("Store Admin Menu: Force Save\nTarget:");
				GenerateClientList(menu, client);
				menu.ExitBackButton = true;
				menu.ExitButton = true;
				menu.Display(client, MENU_TIME_FOREVER);
				return;
			}

			int target = GetClientOfUserId(Client[client].Pos[1]);
			if(IsValidClient(target))
			{
				OnClientDisconnect(client);
				CShowActivity2(client, STORE_PREFIX2, "%sforced %s%N%s to save data", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR);
			}
			else
			{
				PrintToChat(client, "[SM] %t", "Player no longer available");
			}

			Client[client].ClearPos();
		}
		case 3:
		{
			if(!Client[client].Pos[1])
			{
				Menu menu = new Menu(AdminMenuH);
				menu.SetTitle("Store Admin Menu: Force Reload\nTarget:");
				GenerateClientList(menu, client);
				menu.ExitBackButton = true;
				menu.ExitButton = true;
				menu.Display(client, MENU_TIME_FOREVER);
				return;
			}

			int target = GetClientOfUserId(Client[client].Pos[1]);
			if(IsValidClient(target))
			{
				OnClientPostAdminCheck(client);
				CShowActivity2(client, STORE_PREFIX2, "%sforced %s%N%s to reload data", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR);
			}
			else
			{
				PrintToChat(client, "[SM] %t", "Player no longer available");
			}

			Client[client].ClearPos();
		}
		case 4:
		{
			if(!Client[client].Pos[1])
			{
				Menu menu = new Menu(AdminMenuH);
				menu.SetTitle("Store Admin Menu: Give Item\nTarget:");
				GenerateClientList(menu, client);
				menu.ExitBackButton = true;
				menu.ExitButton = true;
				menu.Display(client, MENU_TIME_FOREVER);
				return;
			}

			int target = GetClientOfUserId(Client[client].Pos[1]);
			if(IsValidClient(target))
			{
				if(!Client[client].Pos[2])
				{
					Menu menu = new Menu(AdminMenuH);
					menu.SetTitle("Store Admin Menu: Credits\nTarget: %N\nMode:", target);
					menu.AddItem("1", "Give One");
					menu.AddItem("2", "Remove One");
					menu.AddItem("3", "Give & Equip");
					menu.AddItem("4", "Remove All");
					menu.ExitBackButton = true;
					menu.ExitButton = true;
					menu.Display(client, MENU_TIME_FOREVER);
					return;
				}

				if(!Client[client].Pos[3])
				{
					Menu menu = new Menu(AdminMenuH);
					menu.SetTitle("Store Admin Menu: Give Item\nTarget: %N\nMode: %s\nItem: %s", target, Client[client].Pos[2]==4 ? "Remove All" : Client[client].Pos[2]==3 ? "Give & Equip" : Client[client].Pos[2]==2 ? "Remove One" : "Give One");
					for(int i; i<MaxItems; i++)
					{
						if(Item[i].Items[0]>0 && Inv[client][i].Count>0)
							continue;

						static char buffer[MAX_NUM_LENGTH];
						IntToString(i, buffer, MAX_NUM_LENGTH);
						menu.AddItem(buffer, Item[i].Name);
					}
					menu.ExitBackButton = true;
					menu.ExitButton = true;
					menu.Display(client, MENU_TIME_FOREVER);
					return;
				}

				switch(Client[client].Pos[2])
				{
					case 1:
					{
						if(--Inv[client][Client[client].Pos[2]].Count < 1)
							Inv[client][Client[client].Pos[2]].Equip = false;

						CShowActivity2(client, STORE_PREFIX2, "%removed %s%N's %s", STORE_COLOR, STORE_COLOR2, target, Item[Client[client].Pos[2]].Name);
					}
					case 2:
					{
						Inv[client][Client[client].Pos[2]].Count++;
						Inv[client][Client[client].Pos[2]].Equip = true;
						CShowActivity2(client, STORE_PREFIX2, "%sgave and equipped %s%N %s", STORE_COLOR, STORE_COLOR2, target, Item[Client[client].Pos[2]].Name);
					}
					case 3:
					{
						Inv[client][Client[client].Pos[2]].Count = 0;
						Inv[client][Client[client].Pos[2]].Equip = false;
						CShowActivity2(client, STORE_PREFIX2, "%removed all of %s%N's %s", STORE_COLOR, STORE_COLOR2, target, Item[Client[client].Pos[2]].Name);
					}
					default:
					{
						Inv[client][Client[client].Pos[2]].Count++;
						CShowActivity2(client, STORE_PREFIX2, "%sgave %s%N %s", STORE_COLOR, STORE_COLOR2, target, Item[Client[client].Pos[2]].Name);
					}
				}
			}
			else
			{
				PrintToChat(client, "[SM] %t", "Player no longer available");
			}
			Client[client].ClearPos();
		}
	}

	Menu menu = new Menu(AdminMenuH);
	menu.SetTitle("Store Admin Menu\n ");
	menu.AddItem("1", "Credits");
	menu.AddItem("2", "Force Save");
	menu.AddItem("3", "Force Reload");
	menu.AddItem("4", "Give Item");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int AdminMenuH(Menu menu, MenuAction action, int client, int choice)
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
				AdminMenu(client);
			}
			else if(Client[client].BackOutAdmin && StoreTop)
			{
				StoreTop.Display(client, TopMenuPosition_LastCategory);
			}
			else
			{
				Main(client);
			}
		}
		case MenuAction_Select:
		{
			static char buffer[32];
			menu.GetItem(choice, buffer, 32);
			int item = StringToInt(buffer);
			if(item)
				Client[client].AddPos(item);

			Inventory(client);
		}
	}
}

void UseItem(int client)
{
	int item;
	char buffer[256];
	StoreKv.Rewind();
	for(int i; i<MAXCATEGORIES; i++)
	{
		if(!Client[client].Pos[i])
			break;

		StoreKv.GotoFirstSubKey();
		item = Client[client].Pos[i];
		for(int a=0; a<MAXONCE; a++)
		{
			StoreKv.GetSectionName(buffer, sizeof(buffer));
			if(StrEqual(buffer, Item[item].Name, false))
				break;

			if(!StoreKv.GotoNextKey())
			{
				if(CheckCommandAccess(client, "textstore_dev", ADMFLAG_RCON))
				{
					SPrintToChat(client, "%s doesn't exist anymore?", Item[item].Name);
				}
				else
				{
					SPrintToChat(client, "%s can't be used right now!", Item[item].Name);
				}
				return;
			}
		}
	}

	Handle iter = GetPluginIterator();
	Handle plugin;
	while(MorePlugins(iter))
	{
		plugin = ReadPlugin(iter);
		GetPluginFilename(plugin, buffer, 256);
		if(StrContains(buffer, Item[item].Plugin, false) == -1)
			continue;

		Function func = GetFunctionByName(plugin, "TextStore_Item");
		if(func == INVALID_FUNCTION)
		{
			if(CheckCommandAccess(client, "textstore_dev", ADMFLAG_RCON))
			{
				SPrintToChat(client, "%s is missing function TextStore_Item from %s!", Item[item].Name, Item[item].Plugin);
			}
			else
			{
				SPrintToChat(client, "%s can't be used right now!", Item[item].Name);
			}
			delete iter;
			return;
		}

		ItemResult result = Item_None;
		Call_StartFunction(plugin, func);
		Call_PushCell(client);
		Call_PushCell(Inv[client][item].Equip);
		Call_PushCell(StoreKv);
		Call_PushCell(item);
		Call_PushString(Item[item].Name);
		Call_PushCellRef(Inv[client][item].Count);
		Call_Finish(result);

		// Somebody closed the damn kv
		if(StoreKv == INVALID_HANDLE)
			SetFailState("'%s' is not allowed to close KeyValues Handle for 'textstore.smx' in 'TexTStore_Item'!", buffer);

		switch(result)
		{
			case Item_Used:
			{
				if(--Inv[client][item].Count < 1)
				{
					Inv[client][item].Count = 0;
					Inv[client][item].Equip = false;
				}
			}
			case Item_On:
			{
				if(!Inv[client][item].Equip && Item[item].Slot)
				{
					for(int i=1; i<=MaxItems; i++)
					{
						if(Inv[client][i].Count<1 || !Inv[client][i].Equip)
							continue;

						if(Item[item].Slot == Item[i].Slot)
							Inv[client][i].Equip = false;
					}
				}
				Inv[client][item].Equip = true;
			}
			case Item_Off:
			{
				Inv[client][item].Equip = false;
			}
		}
		delete iter;
		return;
	}

	delete iter;
	if(CheckCommandAccess(client, "textstore_dev", ADMFLAG_RCON))
	{
		SPrintToChat(client, "%s is missing plugin %s!", Item[item].Name, Item[item].Plugin);
	}
	else
	{
		SPrintToChat(client, "%s can't be used right now!", Item[item].Name);
	}
}

void SellItem(int client, int item)
{
	if(Inv[client][item].Count<1 || Item[item].Sell<1 || (Inv[client][item].Count<2 && Inv[client][item].Equip))
		return;

	int count = Inv[client][item].Count;
	int sell = Item[item].Sell;
	Action action = Plugin_Continue;
	Call_StartForward(OnSellItem);
	Call_PushCell(client);
	Call_PushCell(item);
	Call_PushCell(Client[client].Cash);
	Call_PushCellRef(count);
	Call_PushCellRef(sell);
	switch(action)
	{
		case Plugin_Changed:
		{
			Inv[client][item].Count = count;
		}
		case Plugin_Handled:
		{
			Inv[client][item].Count = count;
			return;
		}
		case Plugin_Stop:
		{
			return;
		}
		default:
		{
			sell = Item[item].Sell;
		}
	}

	Inv[client][item].Count--;
	Client[client].Cash += sell;
	if(Inv[client][item].Count < 1)
		Client[client].RemovePos();
}

// Stocks

stock void GenerateClientList(Menu menu, int client=0)
{
	for(int target=1; target<=MaxClients; target++)
	{
		if(!IsValidClient(target))
			continue;

		static char name[64];
		GetClientName(target, name, sizeof(name));
		if(client && CanUserTarget(client, target))
		{
			menu.AddItem("0", name, ITEMDRAW_DISABLED);
			continue;
		}

		static char userid[32];
		IntToString(GetClientUserId(target), userid, sizeof(userid));
		menu.AddItem(userid, name);
	}
}

stock bool IsValidClient(int client)
{
	if(client<1 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
		return false;

	return true;
}

// Natives

public any Native_GetInv(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %i", client);

	int item = GetNativeCell(2);
	if(item<0 || item>MAXITEMS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid item index %i", item);

	SetNativeCellRef(3, Inv[client][item].Count);
	return Inv[client][item].Equip;
}

public any Native_SetInv(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %i", client);

	int item = GetNativeCell(2);
	if(item<0 || item>MAXITEMS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid item index %i", item);

	int count = GetNativeCell(3);
	if(count >= 0)
		Inv[client][item].Count = count;

	switch(GetNativeCell(4))
	{
		case 0:
		{
			Inv[client][item].Equip = false;
		}
		case 1:
		{
			Inv[client][item].Equip = true;
		}
	}
}

public any Native_Cash(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %i", client);

	int cash = GetNativeCell(2);
	if(cash)
		Client[client].Cash += cash;

	return Client[client].Cash;
}

#file "Text Store"
