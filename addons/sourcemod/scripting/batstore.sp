#pragma semicolon 1

#include <sourcemod>
#include <morecolors>
#include <sdkhooks>
#include <batstore>

#pragma newdecls required

#define MAJOR_REVISION	"0"
#define MINOR_REVISION	"2"
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
#define MAX_PLUGIN_LENGTH	64
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
GlobalForward OnSellItem; 

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
	int Id;
	int Pos[MAXCATEGORIES];
	bool Store;

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
		delete file;
	}

	void Save(int client)
	{
		if(!this.Id)
			return;

		char buffer[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, buffer, PLATFORM_MAX_PATH, DATA_PLAYERS, this.Id);
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
	CreateNative("BatStore_GetInv", Native_GetInv);
	CreateNative("BatStore_SetInv", Native_SetInv);
	CreateNative("BatStore_Cash", Native_Cash);
	OnSellItem = new GlobalForward("BatStore_OnSellItem", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);

	RegPluginLibrary("batstore");
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_store", CommandMain, "Browse items to buy");
	RegConsoleCmd("sm_shop", CommandMain, "Browse items to buy");

	RegConsoleCmd("sm_buy", CommandStore, "Browse items to buy");

	RegConsoleCmd("sm_inventory", CommandInven, "View your backpack of items");
	RegConsoleCmd("sm_inven", CommandInven, "View your backpack of items");
	RegConsoleCmd("sm_inv", CommandInven, "View your backpack of items");

	LoadTranslations("common.phrases");
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
			Item[MaxItems].Hidden = (!GetRandomInt(0, 5) || StoreKv.GetNum("hidden"));
			Item[MaxItems].Stack = view_as<bool>(StoreKv.GetNum("stack", 1));
			Item[MaxItems].Trade = view_as<bool>(StoreKv.GetNum("trade"));
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

	Client[client].ClearPos();
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

	if(!Client[client].Store)
		Client[client].ClearPos();

	Client[client].Store = true;
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

	Client[client].Store = false;
	Inventory(client);
	return Plugin_Handled;
}

// Menu Events

public void Main(int client)
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
			if(choice)
			{
				Client[client].Store = false;
				Inventory(client);
			}
			else
			{
				Client[client].Store = true;
				Store(client);
			}
		}
	}
}

public void Store(int client)
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
			menu.AddItem(buffer, Item[ITEM].Name, CheckCommandAccess(client, "batstore_all", Item[ITEM].Admin, true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
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
			if((Item[item].Stack || Inv[client][item].Count<1) && Client[client].Cash>=Item[item].Cost)
			{
				Inv[client][item].Count++;
				Client[client].Cash -= Item[item].Cost;
			}
		}
		case 2:
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

public Action Inventory(int client)
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

			if(Inv[client][ITEM].Count < 1)
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

/*public int InventoryItemH(Menu menu, MenuAction action, int client, int choice)
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
						UseItem(client, item);
				}
			}
			Inventory(client);
		}
	}
}*/

public int InventoryItemH(Menu panel, MenuAction action, int client, int choice)
{
	if(action != MenuAction_Select)
		return;

	int item = Client[client].GetPos();
	switch(choice)
	{
		case 1:
		{
			if(Inv[client][item].Count > 1)
			{
				UseItem(client);
				if(Inv[client][item].Count < 1)
					Client[client].RemovePos();
			}
		}
		case 2:
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
				if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
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

		Function func = GetFunctionByName(plugin, "BatStore_Item");
		if(func == INVALID_FUNCTION)
		{
			if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
			{
				SPrintToChat(client, "%s is missing function BatStore_Item from %s!", Item[item].Name, Item[item].Plugin);
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
			SetFailState("'%s' is not allowed to close KeyValues Handle for 'batstore.smx' in 'BatStore_Item'!", buffer);

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
				if(!Inv[client][item].Equip)
				{
					for(int i=1; i<=MaxItems; i++)
					{
						if(Inv[client][i].Count<1 || !Inv[client][i].Equip)
							continue;

						if(Item[item].Slot == Item[i].Slot)
							Inv[client][i].Equip = false;
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
		SPrintToChat(client, "%s is missing plugin %s!", Item[item].Name, Item[item].Plugin);
	}
	else
	{
		SPrintToChat(client, "%s can't be used right now!", Item[item].Name);
	}
}

void SellItem(int client, int item)
{
	if(Inv[client][item].Count<1 || Item[item].Sell<1)
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
	if(Inv[client][item].Count > 0)
		return;

	Client[client].RemovePos();
	Inv[client][item].Equip = false;
}

// Stocks

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
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

#file "Bat Store"
