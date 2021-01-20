#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <sdktools_voice>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN
#include <morecolors>
#include <textstore>

#pragma newdecls required

#define PLUGIN_VERSION	"1.0.5"

#define MAX_ITEM_LENGTH	48
#define MAX_DESC_LENGTH	256
#define MAX_TITLE_LENGTH	192
#define MAX_NUM_LENGTH	5

#define FPERM_DEFAULT	FPERM_O_EXEC|FPERM_O_READ|FPERM_G_EXEC|FPERM_G_READ|FPERM_U_EXEC|FPERM_U_WRITE|FPERM_U_READ

#define DATA_PATH	"data/textstore/user"
#define DATA_PLAYERS	"data/textstore/user/%s.txt"
#define DATA_STORE	"configs/textstore/store.cfg"

#define SELLRATIO	0.75
#define HIDECHANCE	0.175
#define MAXCATEGORIES	8

enum StoreTypeEnum
{
	Type_Main = 0,
	Type_Store,
	Type_Inven,
	Type_Admin,
	Type_Craft,
	Type_Trade
}

enum ChatTypeEnum
{
	Type_None = 0,
	Type_TradeCash,
	Type_TradeItem
}

enum struct ItemEnum
{
	bool Hidden;
	int Parent;
	int Admin;
	char Name[MAX_ITEM_LENGTH];
	KeyValues Kv;

	int Count[MAXPLAYERS+1];
	bool Equip[MAXPLAYERS+1];
}
ArrayList Items;

enum struct ClientEnum
{
	int Cash;
	int Target;
	bool Ready;
	int Pos[MAXCATEGORIES];	// TODO: Make this ArrayList
	StoreTypeEnum StoreType;
	ChatTypeEnum ChatType;
	bool BackOutAdmin;
	bool CanTrade;

	void Setup(int client)
	{
		ItemEnum item;
		int length = Items.Length;
		for(int i; i<length; i++)
		{
			Items.GetArray(i, item);
			item.Count[client] = 0;
			Items.SetArray(i, item);
		}

		if(IsFakeClient(client))
			return;

		static char buffer[PLATFORM_MAX_PATH];
		if(!GetClientAuthId(client, AuthId_SteamID64, buffer, sizeof(buffer)))
			return;

		this.Ready = true;
		BuildPath(Path_SM, buffer, sizeof(buffer), DATA_PLAYERS, buffer);
		if(!FileExists(buffer))
			return;

		File file = OpenFile(buffer, "r");
		if(!file)
			return;

		static char buffers[3][MAX_ITEM_LENGTH+MAX_NUM_LENGTH+MAX_NUM_LENGTH];
		while(!file.EndOfFile() && file.ReadLine(buffer, sizeof(buffer)))
		{
			int count = ExplodeString(buffer, ";", buffers, sizeof(buffers), sizeof(buffers[]));
			if(count < 2)
				continue;

			if(StrEqual(buffers[0], "cash"))
			{
				this.Cash = StringToInt(buffers[1]);
				continue;
			}

			for(int i; i<length; i++)
			{
				Items.GetArray(i, item);
				if(!StrEqual(buffers[0], item.Name, false))
					continue;

				item.Count[client] += StringToInt(buffers[1]);
				if(!StringToInt(buffers[2]) || !UseThisItem(client, i, item))
					Items.SetArray(i, item);

				break;
			}
		}
		delete file;
	}

	void Save(int client)
	{
		static char buffer[PLATFORM_MAX_PATH];
		if(!GetClientAuthId(client, AuthId_SteamID64, buffer, sizeof(buffer)))
			return;

		BuildPath(Path_SM, buffer, sizeof(buffer), DATA_PLAYERS, buffer);
		File file = OpenFile(buffer, "w");
		if(!file)
			return;

		file.WriteLine("cash;%d", this.Cash);
		ItemEnum item;
		int length = Items.Length;
		for(int i; i<length; i++)
		{
			Items.GetArray(i, item);
			if(item.Count[client] > 0)
				file.WriteLine("%s;%d;%d", item.Name, item.Count[client], item.Equip[client] ? 1 : 0);
		}
		delete file;
	}

	int GetPos()
	{
		int item;
		for(int i=(MAXCATEGORIES-1); i>=0; i--)
		{
			item = this.Pos[i];
			if(item != -1)
				return item;
		}
		return -1;
	}

	void AddPos(int item)
	{
		for(int i; i<MAXCATEGORIES; i++)
		{
			if(this.Pos[i] == -1)
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
			if(item != -1)
			{
				this.Pos[i] = -1;
				return item;
			}
		}
		return -1;
	}

	void ClearPos()
	{
		for(int i; i<MAXCATEGORIES; i++)
		{
			this.Pos[i] = -1;
		}
	}
}
ClientEnum Client[MAXPLAYERS+1];

#include "textstore/stocks.sp"
#include "textstore/forwards.sp"
#include "textstore/natives.sp"
#include "textstore/crafting.sp"
#include "textstore/adminmenu.sp"
#include "textstore/trading.sp"

public Plugin myinfo =
{
	name		=	"The Text Store",
	author		=	"Batfoxkid",
	description	=	"Buy and view an inventory of items",
	version		=	PLUGIN_VERSION
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	Native_PluginLoad();
	Forward_PluginLoad();
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

	AddCommandListener(OnSayCommand, "say");
	AddCommandListener(OnSayCommand, "say_team");

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	Client[0].ClearPos();

	Trading_PluginStart();
	AdminMenu_PluginStart();
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
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, PLATFORM_MAX_PATH, DATA_PATH);
	if(!DirExists(buffer))
		CreateDirectory(buffer, FPERM_DEFAULT);

	BuildPath(Path_SM, buffer, PLATFORM_MAX_PATH, DATA_STORE);
	KeyValues kv = new KeyValues("");
	kv.ImportFromFile(buffer);

	if(Items != INVALID_HANDLE)
	{
		ItemEnum item;
		int length = Items.Length;
		for(int i; i<length; i++)
		{
			Items.GetArray(i, item);
			if(item.Kv != INVALID_HANDLE)
				delete item.Kv;
		}
		delete Items;
	}

	Items = new ArrayList(sizeof(ItemEnum));
	ReadCategory(kv, -1);
	delete kv;

	Crafting_ConfigsExecuted();

	CreateTimer(60.0, Timer_AutoSave, 0, TIMER_FLAG_NO_MAPCHANGE);

	for(int i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i))
			OnClientPostAdminCheck(i);
	}
}

public void OnClientCookiesCached(int client)
{
	if(Client[client].Ready)
		Trading_CookiesCached(client);
}

public void OnClientPostAdminCheck(int client)
{
	Client[client] = Client[0];
	Client[client].Setup(client);
	if(AreClientCookiesCached(client))
		Trading_CookiesCached(client);
}

public void OnClientDisconnect(int client)
{
	if(!client)
		return;

	if(Client[client].Ready)
	{
		Client[client].Save(client);
		Client[client].Ready = false;
	}

	Client[client].Target = 0;

	for(int target=1; target<=MaxClients; target++)
	{
		if(!IsValidClient(target) || Client[target].Target!=client)
			continue;

		Client[target].Target = 0;
		PrintToChat(target, "[SM] %t", "Player no longer available");
	}

	Trading_Disconnect(client);
}

void ReadCategory(KeyValues kv, int parent)
{
	kv.GotoFirstSubKey();
	int i;
	char buffer[MAX_ITEM_LENGTH];
	do
	{
		ItemEnum item;
		if(!kv.GetSectionName(item.Name, sizeof(item.Name)) || !item.Name[0])
			break;

		item.Parent = parent;

		kv.GetString("admin", buffer, sizeof(buffer));
		item.Admin = ReadFlagString(buffer);

		if(kv.GetNum("cost", -9999) != -9999)
		{
			item.Kv = new KeyValues(item.Name);
			item.Kv.Import(kv);
			item.Hidden = kv.GetFloat("hidden", HIDECHANCE)>GetRandomFloat(0.0, 0.999999);

			Items.PushArray(item);
		}
		else
		{
			item.Kv = null;
			item.Hidden = kv.GetFloat("hidden", 0.0)>GetRandomFloat(0.0, 0.999999);

			ReadCategory(kv, Items.PushArray(item));
		}
		i++;
	} while(kv.GotoNextKey());
	kv.GoBack();
}

public Action CommandMain(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	//Client[client].StoreType = Type_Main;
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

public Action OnSayCommand(int client, const char[] command, int args)
{
	if(Client[client].ChatType != Type_None)
	{
		static char buffer[16];
		GetCmdArgString(buffer, sizeof(buffer));
		ReplaceString(buffer, sizeof(buffer), "\"", "");
		return Trading_SayCommand(client, buffer);
	}
	return Plugin_Continue;
}

void Main(int client)
{
	Menu menu = new Menu(MainH);
	menu.SetTitle("Main Menu\n \nCredits: %d\n ", Client[client].Cash);

	menu.AddItem("0", "Store");
	menu.AddItem("1", "Inventory");

	if(Crafts)
		menu.AddItem("3", "Crafting");

	menu.AddItem("4", "Trading");

	if(CheckCommandAccess(client, "sm_store_admin", ADMFLAG_ROOT))
		menu.AddItem("2", "Admin Menu");

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
			static char buffer[MAX_NUM_LENGTH];
			menu.GetItem(choice, buffer, sizeof(buffer));
			switch(StringToInt(buffer))
			{
				case 1:
					CommandInven(client, 0);

				case 2:
					CommandAdmin(client, 0);

				case 3:
					Crafting_Command(client, 0);

				case 4:
					Trading_Command(client, 0);

				default:
					CommandStore(client, 0);
			}
		}
	}
}

void Store(int client)
{
	ItemEnum item;
	int primary = Client[client].GetPos();
	if(primary != -1)
	{
		Items.GetArray(primary, item);
		if(item.Kv)
		{
			ViewItem(client, item);
			return;
		}
	}

	Menu menu = new Menu(GeneralMenuH);
	if(primary == -1)
	{
		menu.SetTitle("Store\n \nCredits: %d\n ", Client[client].Cash);
	}
	else
	{
		menu.SetTitle("Store: %s\n ", item.Name);
	}

	bool found;
	int length = Items.Length;
	for(int i; i<length; i++)
	{
		Items.GetArray(i, item);
		if(item.Hidden || item.Parent!=primary)
			continue;

		found = true;
		static char buffer[MAX_NUM_LENGTH];
		IntToString(i, buffer, sizeof(buffer));
		menu.AddItem(buffer, item.Name, CheckCommandAccess(client, "textstore_all", item.Admin, true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(!found)
		menu.AddItem("-1", "No Items", ITEMDRAW_DISABLED);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void Inventory(int client)
{
	bool found;
	Menu menu;
	ItemEnum item;
	static char buffer[MAX_NUM_LENGTH];
	int primary = Client[client].GetPos();
	if(primary == -3)
	{
		menu = new Menu(GeneralMenuH);
		menu.SetTitle("Inventory: All Items\n ");

		int length = Items.Length;
		for(int i; i<length; i++)
		{
			Items.GetArray(i, item);
			if(!item.Kv || item.Count[client]<1)
				continue;

			IntToString(i, buffer, sizeof(buffer));
			menu.AddItem(buffer, item.Name);
			found = true;
		}
	}
	else
	{
		if(primary != -1)
		{
			Items.GetArray(primary, item);
			if(item.Kv)
			{
				ViewItem(client, item);
				return;
			}
		}

		menu = new Menu(GeneralMenuH);
		if(primary == -1)
		{
			menu.SetTitle("Inventory\n \nCredits: %d\n ", Client[client].Cash);
		}
		else
		{
			menu.SetTitle("Inventory: %s\n ", item.Name);
		}

		int length = Items.Length;
		for(int i; i<length; i++)
		{
			Items.GetArray(i, item);
			if(item.Parent!=primary || (item.Kv && item.Count[client]<1))
				continue;

			IntToString(i, buffer, sizeof(buffer));
			menu.AddItem(buffer, item.Name);
			found = true;
		}
	}

	if(primary == -1)
	{
		menu.AddItem("-3", "All Items");
	}
	else if(!found)
	{
		menu.AddItem("-1", "No Items", ITEMDRAW_DISABLED);
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void AdminMenu(int client)
{
	if(!CheckCommandAccess(client, "sm_store_admin", ADMFLAG_ROOT))
	{
		PrintToChat(client, "[SM] %t", "No Access");
		return;
	}

	switch(Client[client].Pos[0])
	{
		case 1:
		{
			if(Client[client].Pos[1] == -1)
			{
				Menu menu = new Menu(GeneralMenuH);
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
				if(Client[client].Pos[2] == -1)
				{
					Menu menu = new Menu(GeneralMenuH);
					menu.SetTitle("Store Admin Menu: Credits\nTarget: %N\nMode:", target);
					menu.AddItem("1", "Add");
					menu.AddItem("2", "Remove");
					menu.AddItem("3", "Set");
					menu.ExitBackButton = true;
					menu.ExitButton = true;
					menu.Display(client, MENU_TIME_FOREVER);
					return;
				}

				if(Client[client].Pos[3] == -1)
				{
					Menu menu = new Menu(GeneralMenuH);
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
					case 2:
					{
						Client[target].Cash -= Client[client].Pos[3];
						CShowActivity2(client, STORE_PREFIX2, "%stoke %s%d%s credits from %s%N", STORE_COLOR, STORE_COLOR2, Client[client].Pos[3], STORE_COLOR, STORE_COLOR2, target);
					}
					case 3:
					{
						Client[target].Cash = Client[client].Pos[3];
						CShowActivity2(client, STORE_PREFIX2, "%sset %s%N's%s credits to %s%d", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR, STORE_COLOR2, Client[client].Pos[3]);
					}
					default:
					{
						Client[target].Cash += Client[client].Pos[3];
						CShowActivity2(client, STORE_PREFIX2, "%sgave %s%N %d%s credits", STORE_COLOR, STORE_COLOR2, target, Client[client].Pos[3], STORE_COLOR);
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
			if(Client[client].Pos[1] == -1)
			{
				Menu menu = new Menu(GeneralMenuH);
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
				Client[target].Save(target);
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
			if(Client[client].Pos[1] == -1)
			{
				Menu menu = new Menu(GeneralMenuH);
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
				OnClientPostAdminCheck(target);
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
			if(Client[client].Pos[1] == -1)
			{
				Menu menu = new Menu(GeneralMenuH);
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
				if(Client[client].Pos[2] == -1)
				{
					Menu menu = new Menu(GeneralMenuH);
					menu.SetTitle("Store Admin Menu: Give Item\nTarget: %N\nMode:", target);
					menu.AddItem("1", "Give One");
					menu.AddItem("3", "Remove One");
					menu.AddItem("2", "Give & Equip");
					menu.AddItem("4", "Remove All");
					menu.ExitBackButton = true;
					menu.ExitButton = true;
					menu.Display(client, MENU_TIME_FOREVER);
					return;
				}

				ItemEnum item;
				if(Client[client].Pos[3] == -1)
				{
					Menu menu = new Menu(GeneralMenuH);
					menu.SetTitle("Store Admin Menu: Give Item\nTarget: %N\nMode: %s\nItem:", target, Client[client].Pos[2]==4 ? "Remove All" : Client[client].Pos[2]==2 ? "Give & Equip" : Client[client].Pos[2]==3 ? "Remove One" : "Give One");

					bool need = Client[client].Pos[2]>2;
					int length = Items.Length;
					for(int i; i<length; i++)
					{
						Items.GetArray(i, item);
						if(!item.Kv || (need && item.Count[target]>0))
							continue;

						static char buffer[MAX_NUM_LENGTH];
						IntToString(i, buffer, MAX_NUM_LENGTH);
						menu.AddItem(buffer, item.Name);
					}

					menu.ExitBackButton = true;
					menu.ExitButton = true;
					menu.Display(client, MENU_TIME_FOREVER);
					return;
				}

				Items.GetArray(Client[client].Pos[3], item);
				switch(Client[client].Pos[3])
				{
					case 2:
					{
						if(--item.Count[target] < 1)
							item.Equip[target] = false;

						CShowActivity2(client, STORE_PREFIX2, "%removed %s%N's %s", STORE_COLOR, STORE_COLOR2, target, item.Name);
					}
					case 3:
					{
						item.Count[target]++;
						item.Equip[target] = true;
						CShowActivity2(client, STORE_PREFIX2, "%sgave and equipped %s%N %s", STORE_COLOR, STORE_COLOR2, target, item.Name);
					}
					case 4:
					{
						item.Count[target] = 0;
						item.Equip[target] = false;
						CShowActivity2(client, STORE_PREFIX2, "%removed all of %s%N's %s", STORE_COLOR, STORE_COLOR2, target, item.Name);
					}
					default:
					{
						item.Count[target]++;
						CShowActivity2(client, STORE_PREFIX2, "%sgave %s%N %s", STORE_COLOR, STORE_COLOR2, target, item.Name);
					}
				}
				Items.SetArray(Client[client].Pos[3], item);
			}
			else
			{
				PrintToChat(client, "[SM] %t", "Player no longer available");
			}
			Client[client].ClearPos();
		}
	}

	Menu menu = new Menu(GeneralMenuH);
	menu.SetTitle("Store Admin Menu\n ");
	menu.AddItem("1", "Credits");
	menu.AddItem("2", "Force Save");
	menu.AddItem("3", "Force Reload");
	menu.AddItem("4", "Give Item");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int GeneralMenuH(Menu menu, MenuAction action, int client, int choice)
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
				ReturnStoreType(client);
			}
			else if(!Client[client].BackOutAdmin || !AdminMenu_Return(client))
			{
				Main(client);
			}
		}
		case MenuAction_Select:
		{
			static char buffer[16];
			menu.GetItem(choice, buffer, sizeof(buffer));
			if(buffer[0])
				Client[client].AddPos(StringToInt(buffer));

			ReturnStoreType(client);
		}
	}
}

void ViewItem(int client, ItemEnum item)
{
	Panel panel = new Panel();

	char buffer[MAX_DESC_LENGTH];
	FormatEx(buffer, sizeof(buffer), "%s\n ", item.Name);
	panel.SetTitle(buffer);

	item.Kv.Rewind();
	item.Kv.GetString("desc", buffer, sizeof(buffer), "No Description");
	ReplaceString(buffer, sizeof(buffer), "\\n", "\n");
	panel.DrawText(buffer);

	bool stack = view_as<bool>(item.Kv.GetNum("stack", 1));
	if(stack || item.Count[client]>1)
	{
		FormatEx(buffer, sizeof(buffer), " \nYou have %d credits\nYou own %d\n ", Client[client].Cash, item.Count[client]);
	}
	else
	{
		FormatEx(buffer, sizeof(buffer), " \nYou have %d credits\nYou %sown this item\n ", Client[client].Cash, item.Count[client] ? "" : "don't ");
	}
	panel.DrawText(buffer);

	panel.DrawItem((item.Count[client]>0 && item.Equip[client]) ? "Disactivate Item" : "Activate Item", item.Count[client]>0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	int cost = item.Kv.GetNum("cost");
	int sell = item.Kv.GetNum("sell", RoundFloat(cost*SELLRATIO));
	if(cost>0 && !item.Hidden)
	{
		FormatEx(buffer, sizeof(buffer), "Buy (%d Credits)", cost);
		if((!stack && item.Count[client]) || Client[client].Cash<cost)
		{
			panel.DrawItem(buffer, ITEMDRAW_DISABLED);
		}
		else
		{
			panel.DrawItem(buffer);
		}
	}
	else if(sell > 0)
	{
		panel.DrawItem("Buy", ITEMDRAW_DISABLED);
	}

	if(sell > 0)
	{
		FormatEx(buffer, sizeof(buffer), "Sell (%d Credits)", sell);
		panel.DrawItem(buffer, item.Count[client]>0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	panel.DrawText(" ");
	panel.CurrentKey = 8;
	panel.DrawItem("Back");
	panel.DrawText(" ");
	panel.CurrentKey = 10;
	panel.DrawItem("Exit");
	panel.Send(client, ViewItemH, MENU_TIME_FOREVER);
	delete panel;
}

public int ViewItemH(Menu panel, MenuAction action, int client, int choice)
{
	if(action != MenuAction_Select)
		return;

	int index = Client[client].GetPos();
	ItemEnum item;
	Items.GetArray(index, item);
	item.Kv.Rewind();
	switch(choice)
	{
		case 1:
		{
			if(item.Count[client] > 0)
			{
				UseThisItem(client, index, item);
				if(item.Count[client] < 1)
					Client[client].RemovePos();
			}
		}
		case 2:
		{
			int cost = item.Kv.GetNum("cost");
			if(cost>0 && (item.Kv.GetNum("stack", 1) || item.Count[client]<1) && Client[client].Cash>=cost)
			{
				item.Count[client]++;
				Client[client].Cash -= cost;
				Items.SetArray(index, item);
				ClientCommand(client, "playgamesound buttons/buttons3.wav");
			}
		}
		case 3:
		{
			if(SellItem(client, index, item))
			{
				ClientCommand(client, "playgamesound buttons/buttons9.wav");
				if(item.Count[client] < 1)
					Client[client].RemovePos();
			}
		}
		case 10:
		{
			ClientCommand(client, "playgamesound buttons/combine_button7.wav");
			Client[client].RemovePos();
			return;
		}
		default:
		{
			ClientCommand(client, "playgamesound buttons/combine_button7.wav");
			Client[client].RemovePos();
		}
	}

	ReturnStoreType(client);
}

void ReturnStoreType(int client)
{
	switch(Client[client].StoreType)
	{
		case Type_Store:
			Store(client);

		case Type_Inven:
			Inventory(client);

		case Type_Admin:
			AdminMenu(client);
	}
}

bool UseThisItem(int client, int index, ItemEnum item)
{
	static char buffer[256];
	item.Kv.GetString("plugin", buffer, sizeof(buffer));

	Handle iter = GetPluginIterator();
	while(MorePlugins(iter))
	{
		Handle plugin = ReadPlugin(iter);
		static char buffer2[256];
		GetPluginFilename(plugin, buffer2, sizeof(buffer2));
		if(StrContains(buffer2, buffer, false) == -1)
			continue;

		Function func = GetFunctionByName(plugin, "TextStore_Item");
		if(func == INVALID_FUNCTION)
		{
			if(CheckCommandAccess(client, "textstore_dev", ADMFLAG_RCON))
			{
				SPrintToChat(client, "'%s' is missing function 'TextStore_Item' from '%s'", item.Name, buffer2);
			}
			else
			{
				SPrintToChat(client, "%s can't be used right now!", item.Name);
			}
			delete iter;
			return false;
		}

		ItemResult result = Item_None;
		Call_StartFunction(plugin, func);
		Call_PushCell(client);
		Call_PushCell(item.Equip[client]);
		Call_PushCell(item.Kv);
		Call_PushCell(index);
		Call_PushString(item.Name);
		Call_PushCellRef(item.Count[client]);
		Call_Finish(result);

		switch(result)
		{
			case Item_Used:
			{
				if(--item.Count[client] < 1)
				{
					item.Count[client] = 0;
					item.Equip[client] = false;
				}
			}
			case Item_On:
			{
				item.Equip[client] = true;
			}
			case Item_Off:
			{
				item.Equip[client] = false;
			}
		}

		Items.SetArray(index, item);
		delete iter;
		return true;
	}

	delete iter;
	if(CheckCommandAccess(client, "textstore_dev", ADMFLAG_RCON))
	{
		SPrintToChat(client, "'%s' could not find plugin '%s'", item.Name, buffer);
	}
	else
	{
		SPrintToChat(client, "%s can't be used right now!", item.Name);
	}
	return false;
}

bool SellItem(int client, int index, ItemEnum item)
{
	if(item.Count[client]<1 || (item.Count[client]<2 && item.Equip[client]))
		return false;

	int sell = item.Kv.GetNum("sell", RoundFloat(item.Kv.GetNum("cost")*SELLRATIO));
	if(sell < 1)
		return false;

	int count = item.Count[client];
	int sell2 = sell;
	switch(Forward_OnSellItem(client, index, Client[client].Cash, count, sell2))
	{
		case Plugin_Changed:
		{
			sell = sell2;
			item.Count[client] = count;
		}
		case Plugin_Handled:
		{
			item.Count[client] = count;
			return false;
		}
		case Plugin_Stop:
		{
			return false;
		}
	}

	item.Count[client]--;
	Client[client].Cash += sell;
	Items.SetArray(index, item);
	return true;
}

public Action Timer_AutoSave(Handle timer, int temp)
{
	int client = temp+1;
	if(client > MaxClients)
		client = 1;

	if(IsValidClient(client) && Client[client].Ready)
		Client[client].Save(client);

	CreateTimer(10.0, Timer_AutoSave, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

#file "Text Store"