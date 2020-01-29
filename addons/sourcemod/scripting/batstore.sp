#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <batstore>

#pragma newdecls required

#define MAJOR_REVISION	"0"
#define MINOR_REVISION	"1"
#define STABLE_REVISION	"0"
#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

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
#define MAX_COOKIE_BYTE		6
#define MAX_COOKIE_BYTES	42
#define MAX_COOKIE_LENGTH	((MAX_COOKIE_BYTE+1)*MAX_COOKIE_BYTES)
#define MAX_ITEM_LENGTH		48
#define MAX_DESC_LENGTH		256
#define MAX_TITLE_LENGTH	192
#define MAX_NUM_LENGTH		5
#define VOID_ARG		-1

#define ITEM	Item[item].Items[i]

#define DATA_PLAYERS	"data/batstore/user/%i.txt"
#define DATA_STORE	"data/batstore/store.cfg"

#define SELLRATIO	0.75
#define MAXITEMS	256
#define MAXONCE		64
#define MAXCATEGORIES	8

KeyValues StoreKv;
int MaxItems;

enum struct InvEnum
{
	bool Equip;
	int Count;
};
InvEnum Inv[MAXPLAYERS+1][MAXITEMS+1];

enum struct ClientEnum
{
	int Cash;
	int Id;
	int Pos[MAXCATEGORIES];
	bool Store;

	void Setup(int client)
	{
		int i;
		for(; i<MAXCATEGORIES; i++)
		{
			Client[client].Pos[i] = 0;
		}

		this.Cash = 0;
		for(i=0; i<=MAXITEMS; i++)
		{
			Inv[client][i].Count = 0;
			Inv[client][i].Equip = false;
		}

		if(IsFakeClient(client))
		{
			this.Id = 0;
			return;
		}

		char buffer[PLATFORM_MAX_PATH];
		if(!GetClientAuthId(client, AuthId_SteamID64, buffer, PLATFORM_MAX_PATH))
		{
			this.Id = 0;
			return;
		}

		this.Id = StringToInt(buffer);
		if(!this.Id)
			return;

		BuildPath(Path_SM, buffer, PLATFORM_MAX_PATH, DATA_PLAYERS, this.Id);
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

			for(i=1; i<=MaxItems; i++)
			{
				if(!StrEqual(buffers[0], Item[i].Name))
					continue;
			}

			if(i > MaxItems)
				continue;

			Inv[client][i].Count = StringToInt(buffers[1]);
			Inv[client][i].Equip = view_as<bool>(StringToInt(buffers[2]));
		}
	}

	void Save(int client)
	{
		if(!this.Id)
			return;

		char buffer[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, buffer, PLATFORM_MAX_PATH, DATA_PLAYERS, this.Id);
		if(!FileExists(buffer))
			return;

		File file = OpenFile(buffer, "w+");
		if(file == null)
			return;

		file.WriteLine("cash;%i", this.Cash);
		for(int i=1; i<=MaxItems; i++)
		{
			if(Inv[client][i].Count > 0)
				file.WriteLine("%s;%i;%i", Item[i].Name, Inv[client][i].Count, Inv[client][i].Equip ? 1 : 0);
		}
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

	void RemovePos()
	{
		int item;
		for(int i=(MAXCATEGORIES-1); i>=0; i--)
		{
			item = this.Pos[i];
			if(item)
			{
				this.Pos[i] = 0;
				return;
			}
		}
	}

	void ClearPos()
	{
		for(int i; i<MAXCATEGORIES; i++)
		{
			this.Pos[i] = 0;
		}
	}
};
ClientEnum Client[MAXPLAYERS+1];

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

	void Read()
	{
		StoreKv.GetSectionName(this.Name, MAX_ITEM_LENGTH);
		ReplaceString(this.Name, MAX_ITEM_LENGTH, ";", "");

		char buffer[28];
		StoreKv.GetString("admin", buffer, 28);
		this.Admin = ReadFlagString(buffer);

		this.Cost = StoreKv.GetNum("cost");
		this.Hidden = (!GetRandomInt(0, 5) || StoreKv.GetNum("hidden"));
		this.Stack = view_as<bool>(StoreKv.GetNum("stack"));
		this.Trade = view_as<bool>(StoreKv.GetNum("trade"));
		StoreKv.GetString("plugin", this.Plugin, MAX_PLUGIN_LENGTH);
		StoreKv.GetString("desc", this.Desc, MAX_DESC_LENGTH, "No Description");
		this.Sell = StoreKv.GetNum("sell", RoundFloat(this.Cost*SELLRATIO));
	}

	void Use(int client, int item)
	{
		char buffer[256];
		Handle iter = GetPluginIterator();
		Handle plugin;
		while(MorePlugins(iter))
		{
			plugin = ReadPlugin(iter);
			GetPluginFilename(plugin, buffer, 256);
			if(StrContains(buffer, this.Plugin, false) == -1)
				continue;

			Function func = GetFunctionByName(plugin, "BatStore_Item");
			if(func == INVALID_FUNCTION)
			{
				if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
				{
					SPrintToClient(client, "%s is missing function BatStore_Item from %s!", this.Name, this.Plugin);
				}
				else
				{
					SPrintToClient(client, "%s can't be used right now!", this.Name);
				}
				delete iter;
				return;
			}

			StoreKv.Rewind();
			StoreKv.JumpToKey(this.Name);

			ItemResult result = Item_None;
			Call_StartFunction(plugin, func);
			Call_PushCell(client);
			Call_PushCell(Inv[client][item].Equip);
			Call_PushCell(StoreKv);
			Call_PushString(this.Name);
			Call_PushCellEx(Inv[client][i].Count);
			Call_Finish(result);

			// Somebody closed the damn kv
			if(StoreKv == INVALID_HANDLE)
				SetFailState("'%s' is not allowed to close KeyValues Handle for 'batstore.smx' in 'BatStore_Item'!", buffer);

			switch(result)
			{
				case Item_Used:
				{
					Inv[client][item].Count--;
				}
				case Item_On:
				{
					if(!Inv[client][item].Equip)
					{
						for(int i=1; i<=MaxItems; i++)
						{
							if(this.Slot == Item[i].Slot)
								Inv[client][item].Equip = false;
						}
						Inv[client][item].Equip = true;
					}
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
		if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
		{
			SPrintToClient(client, "%s is missing plugin %s!", this.Name, this.Plugin);
		}
		else
		{
			SPrintToClient(client, "%s can't be used right now!", this.Name);
		}
	}
};
ItemEnum Item[MAXITEMS+1];

// SourceMod Events

public Plugin myinfo =
{
	name		=	"The Text Store",
	author		=	"Batfoxkid",
	description	=	"Buy and view an inventory of items",
	version		=	PLUGIN_VERSION
};

/*public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
}*/

public void OnPluginStart()
{
	RegConsoleCmd("sm_inventory", CommandInven, "View your backpack of items");
	RegConsoleCmd("sm_inven", CommandInven, "View your backpack of items");
	RegConsoleCmd("sm_inv", CommandInven, "View your backpack of items");

	RegConsoleCmd("sm_store", CommandStore, "Browse items to buy");
	RegConsoleCmd("sm_shop", CommandStore, "Browse items to buy");
	RegConsoleCmd("sm_buy", CommandStore, "Browse items to buy");
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
		if(IsValidClient(i) && !IsFakeClient(i))
			Client[i].Setup(i);
	}
}

// Game Events

public void OnClientPostAdminCheck(int client)
{
	Client[i].Setup(i);
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
		if(StoreKv.GetNum("category"))
		{
			ReadCategory(MaxItems);
		}
		else
		{
			Item[MaxItems].ReadItem();
		}
		i++;
	} while(MaxItems<MAXITEMS && i<MAXONCES && StoreKv.GotoNextKey())
	StoreKv.GoBack();
}

// Command Events

public Action CommandStore(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	if(!Client[client].Store)
		Client[client].ClearPos();

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

	if(Client[client].Store)
		Client[client].ClearPos();

	Inventory(client);
	return Plugin_Handled;
}

// Menu Events

public void Store(int client)
{
	int item = Client[client].GetPos();
	if(!item || Item[item].Items[0]>0)
	{
		Menu menu = new Menu(StoreH);
		menu.SetTitle("Store: %s", item ? Item[item].Name : "Main Menu");
		for(int i; i<MAXONCE; i++)
		{
			if(ITEM < 1)
				break;

			if(Item[ITEM].Hidden)
				continue;

			static char buffer[MAX_NUM_LENGTH];
			IntToString(ITEM, buffer, MAX_NUM_LENGTH);
			menu.AddItem(buffer, Item[ITEM].Name, CheckCommandAccess(client, "batstore_all", Item[ITEM].Admin, true) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}

		menu.ExitBackButton = item>0;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	Menu menu = new Menu(StoreItemH);
	menu.SetTitle("Store: %s", Item[item].Name);
	menu.AddItem("", " ", ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	menu.AddItem("", Item[item].Desc, ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	menu.AddItem("", " ", ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);

	char buffer[MAX_ITEM_LENGTH];
	if(Item[item].Stack)
	{
		FormatEx(buffer, MAX_ITEM_LENGTH, "You %sown this item", Inv[client][item].Count<1 ? "don't " : "");
	}
	else
	{
		FormatEx(buffer, MAX_ITEM_LENGTH, "You own %i", Inv[client][item].Count);
	}
	menu.AddItem("", buffer, ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	menu.AddItem("", " ", ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);

	FormatEx(buffer, MAX_ITEM_LENGTH, "Buy (%i Credit(s))", Item[item].Cost);
	if((Item[item].Stack && Inv[client][item].Count>0) || Client[client].Cash<Item[item].Cost)
	{
		menu.AddItem("0", buffer, ITEMDRAW_DISABLED);
	}
	else
	{
		menu.AddItem("2", buffer);
	}

	if(Item[item].Sell > 0)
	{
		FormatEx(buffer, MAX_ITEM_LENGTH, "Sell (%i Credit(s))", Item[item].Sell);
		if(Inv[client][item].Count > 0)
		{
			menu.AddItem("1", buffer);
		}
		else
		{
			menu.AddItem("0", buffer, ITEMDRAW_DISABLED);
		}
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
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

			Client[client].RemovePos();
			Store(client);
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, MAX_NUM_LENGTH);
			int item = StringToInt(buffer);
			if(item)
				AddClientPos(client, item);

			Store(client);
		}
	}
}

public int StoreItemH(Menu menu, MenuAction action, int client, int choice)
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

			Client[client].RemovePos();
			Store(client);
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, MAX_NUM_LENGTH);
			int num = StringToInt(buffer);
			int item = Client[client].GetPos();
			switch(num)
			{
				case 1:
				{
					if(Inv[client][item].Count>0 && Item[item].Sell>0)
					{
						Inv[client][item].Count--;
						Client[client].Cash += Item[item].Sell;
						if(Inv[client][item].Count < 1)
						{
							Client[client].RemovePos();
							Inv[client][item].Equip = false;
						}
					}
				}
				case 2:
				{
					if((!Item[item].Stack || Inv[client][item].Count<1) && Client[client].Cash>=Item[item].Cost)
					{
						Inv[client][item].Count++;
						Client[client].Cash -= Item[item].Cost;
					}
				}
			}
			Store(client);
		}
	}
}

public Action Inventory(int client)
{
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
			menu.SetTitle("Inventory\nCredits: %i\n ", Client[client].Cash);
		}
		for(int i; i<MAXONCE; i++)
		{
			if(ITEM < 1)
				break;

			if(Inv[client][ITEM].Count < 1)
				continue;

			static char buffer[MAX_NUM_LENGTH];
			IntToString(ITEM, buffer, MAX_NUM_LENGTH);
			menu.AddItem(buffer, Item[ITEM].Name);
		}

		menu.ExitBackButton = item>0;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	Menu menu = new Menu(InventoryItemH);
	menu.SetTitle("Inventory: %s", Item[item].Name);
	menu.AddItem("", " ", ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	menu.AddItem("", Item[item].Desc, ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	menu.AddItem("", " ", ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);

	char buffer[MAX_ITEM_LENGTH];
	FormatEx(buffer, MAX_ITEM_LENGTH, "You own %i", Inv[client][item].Count);
	menu.AddItem("", buffer, ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);
	menu.AddItem("", " ", ITEMDRAW_DISABLED|ITEMDRAW_RAWLINE);

	menu.AddItem("2", Inv[client][item].Equip ? "Disactivate Item" : "Activate Item");
	if(Item[item].Sell > 0)
	{
		FormatEx(buffer, MAX_ITEM_LENGTH, "Sell (%i Credit(s))", Item[item].Sell);
		menu.AddItem("1", buffer);
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
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

			Client[client].RemovePos();
			Inventory(client);
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, MAX_NUM_LENGTH);
			int item = StringToInt(buffer);
			if(item)
				AddClientPos(client, item);

			Inventory(client);
		}
	}
}

public int InventoryItemH(Menu menu, MenuAction action, int client, int choice)
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

			Client[client].RemovePos();
			Inventory(client);
		}
		case MenuAction_Select:
		{
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, MAX_NUM_LENGTH);
			int num = StringToInt(buffer);
			int item = Client[client].GetPos();
			switch(num)
			{
				case 1:
				{
					if(Inv[client][item].Count>0 && Item[item].Sell>0)
					{
						Inv[client][item].Count--;
						Client[client].Cash += Item[item].Sell;
						if(Inv[client][item].Count < 1)
						{
							Client[client].RemovePos();
							Inv[client][item].Equip = false;
						}
					}
				}
				case 2:
				{
					if(Inv[client][item].Count > 1)
						Item[item].Use(client, item);
				}
			}
			Inventory(client);
		}
	}
}

// Stocks

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}

#file "Bat Store"
