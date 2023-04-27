#pragma semicolon 1

#include <sourcemod>
#tryinclude <menus-controller>
#include <clientprefs>
#include <sdktools_voice>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN
#include <morecolors>
#include <textstore>

#pragma newdecls required

#define PLUGIN_VERSION	"1.2.13"

#define MAX_ITEM_LENGTH	48
#define MAX_DATA_LENGTH	256
#define MAX_DESC_LENGTH	256
#define MAX_TITLE_LENGTH	192
#define MAX_NUM_LENGTH	16

#define FPERM_DEFAULT	FPERM_O_EXEC|FPERM_O_READ|FPERM_G_EXEC|FPERM_G_READ|FPERM_U_EXEC|FPERM_U_WRITE|FPERM_U_READ

#define DATA_PATH1	"data/textstore"
#define DATA_PATH2	"data/textstore/user"
#define DATA_PLAYERS	"data/textstore/user/%s.txt"
#define DATA_STORE	"configs/textstore/store.cfg"

#define SELLRATIO	0.75
#define HIDECHANCE	0.175
#define MAXCATEGORIES	8

#define POS_NONE		-2147483645
#define POS_ALLITEM	-2147483644

enum StoreTypeEnum
{
	Type_Store = 0,
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
	ArrayList Pos;
	StoreTypeEnum StoreType;
	ChatTypeEnum ChatType;
	bool BackOutAdmin;
	bool CanTrade;

	int GetPos()
	{
		if(this.Pos)
		{
			int length = this.Pos.Length-1;
			if(length != -1)
				return this.Pos.Get(length);
		}
		return POS_NONE;
	}

	void AddPos(int item)
	{
		if(!this.Pos)
			this.Pos = new ArrayList();

		this.Pos.Push(item);
	}

	bool RemovePos()
	{
		if(this.Pos)
		{
			int length = this.Pos.Length-1;
			if(length != -1)
			{
				this.Pos.Erase(length);
				return true;
			}
		}
		return false;
	}

	void ClearPos()
	{
		if(this.Pos)
		{
			delete this.Pos;
			this.Pos = null;
		}
	}
}
ClientEnum Client[MAXPLAYERS+1];

#include "textstore/stocks.sp"
#include "textstore/forwards.sp"
#include "textstore/unique.sp"
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
	RegAdminCmd("sm_store_giveitem", CommandGiveItem, ADMFLAG_ROOT, "Gives a specific item with specific data");

	AddCommandListener(OnSayCommand, "say");
	AddCommandListener(OnSayCommand, "say_team");

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	Client[0].ClearPos();

	Unique_PluginStart();
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
	
	// SourceMod can't create two folders (atleast tested on Windows)
	BuildPath(Path_SM, buffer, sizeof(buffer), DATA_PATH1);
	if(!DirExists(buffer))
		CreateDirectory(buffer, FPERM_DEFAULT);
	
	BuildPath(Path_SM, buffer, sizeof(buffer), DATA_PATH2);
	if(!DirExists(buffer))
		CreateDirectory(buffer, FPERM_DEFAULT);
	
	BuildPath(Path_SM, buffer, sizeof(buffer), DATA_STORE);
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
	bool failed = ReadCategory(kv, POS_NONE);
	delete kv;

	Crafting_ConfigsExecuted();

	if(failed)
		SetFailState("Store Config File may be Invalid");

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
	Client[client].ClearPos();
	Client[client] = Client[0];

	SetupClient(client);

	if(AreClientCookiesCached(client))
		Trading_CookiesCached(client);
}

void SetupClient(int client)
{
	ItemEnum item;
	int length;
	if(Items)
	{
		length = Items.Length;
		for(int i; i<length; i++)
		{
			Items.GetArray(i, item);
			item.Count[client] = 0;
			Items.SetArray(i, item);
		}
	}

	if(!Items || IsFakeClient(client))
		return;

	Action action;
	static char buffer[512];
	if(GetClientAuthId(client, AuthId_SteamID64, buffer, sizeof(buffer)))
	{
		BuildPath(Path_SM, buffer, sizeof(buffer), DATA_PLAYERS, buffer);
		action = Forward_OnClientLoad(client, buffer);
	}
	else
	{
		buffer[0] = 0;
		action = Forward_OnClientLoad(client, buffer);
		if(action == Plugin_Continue)
			return;
	}
	
	if(action == Plugin_Stop)
		return;

	Client[client].Ready = true;
	if(action != Plugin_Handled && FileExists(buffer))
	{
		File file = OpenFile(buffer, "r");
		if(file)
		{
			static char buffers[4][MAX_DATA_LENGTH];
			while(!file.EndOfFile() && file.ReadLine(buffer, sizeof(buffer)))
			{
				ReplaceString(buffer, sizeof(buffer), "\n", "");
				int count = ExplodeString(buffer, ";", buffers, sizeof(buffers), sizeof(buffers[]));
				if(count < 2)
					continue;

				if(StrEqual(buffers[0], "cash"))
				{
					Client[client].Cash = StringToInt(buffers[1]);
					continue;
				}

				for(int i; i<length; i++)
				{
					Items.GetArray(i, item);
					if(!StrEqual(buffers[0], item.Name, false))
						continue;

					if(count > 3)
					{
						int index = Unique_AddItem(i, client, false, buffers[1], buffers[3]);
						if(StringToInt(buffers[2]))
							Unique_UseItem(client, index, true);
					}
					else
					{
						item.Count[client] += StringToInt(buffers[1]);
						if(StringToInt(buffers[2]))
							UseThisItem(client, i, item, true);

						Items.SetArray(i, item);
					}
					break;
				}
			}
			delete file;
		}
	}
	
	Forward_OnClientLoaded(client, buffer);
}

public void OnClientDisconnect(int client)
{
	if(!client || IsFakeClient(client))
		return;

	if(Client[client].Ready)
	{
		SaveClient(client);
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
	Unique_Disconnect(client);
}

void SaveClient(int client)
{
	static char buffer[PLATFORM_MAX_PATH];
	if(GetClientAuthId(client, AuthId_SteamID64, buffer, sizeof(buffer)))
	{
		BuildPath(Path_SM, buffer, sizeof(buffer), DATA_PLAYERS, buffer);
		Action action = Forward_OnClientSave(client, buffer);
		if(action >= Plugin_Handled)
			return;
	}
	else
	{
		Action action = Forward_OnClientSave(client, buffer);
		if(action != Plugin_Changed)
			return;
	}

	File file = OpenFile(buffer, "w");
	if(!file)
		return;

	file.WriteLine("cash;%d", Client[client].Cash);
	ItemEnum item;
	int length = Items.Length;
	for(int i; i<length; i++)
	{
		Items.GetArray(i, item);
		if(item.Count[client] > 0)
			file.WriteLine("%s;%d;%d", item.Name, item.Count[client], item.Equip[client] ? 1 : 0);
	}

	UniqueEnum unique;
	length = UniqueList.Length;
	for(int i; i<length; i++)
	{
		UniqueList.GetArray(i, unique);
		if(unique.Owner == client)
		{
			Items.GetArray(unique.BaseItem, item);
			file.WriteLine("%s;%s;%d;%s", item.Name, unique.Name, unique.Equipped ? 1 : 0, unique.Data);
		}
	}
	delete file;
	
	Forward_OnClientSaved(client, buffer);
}

bool ReadCategory(KeyValues kv, int parent)
{
	bool errored;
	
	char buffer[MAX_ITEM_LENGTH];
	if(kv.GotoFirstSubKey())
	{
		int i;
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

				if(ReadCategory(kv, Items.PushArray(item)))
					errored = true;
			}
			i++;
		} while(kv.GotoNextKey());
		kv.GoBack();
	}
	else
	{
		kv.GetSectionName(buffer, sizeof(buffer));
		LogError("Section '%s' is invalid in store.cfg", buffer);
		return true;
	}
	
	return errored;
}

public Action CommandMain(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	if(!Client[client].Ready)
	{
		ReplyToCommand(client, "[SM] Your inventory isn't loaded yet");
		return Plugin_Handled;
	}

	if(args)
	{
		LookupItemMenu(client, 0);
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

	if(!Client[client].Ready)
	{
		ReplyToCommand(client, "[SM] Your inventory isn't loaded yet");
		return Plugin_Handled;
	}

	Client[client].BackOutAdmin = (args==-1);
	if(Client[client].StoreType != Type_Store)
	{
		Client[client].ClearPos();
		Client[client].StoreType = Type_Store;
	}

	if(args)
	{
		LookupItemMenu(client, 1);
		return Plugin_Handled;
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

	if(!Client[client].Ready)
	{
		ReplyToCommand(client, "[SM] Your inventory isn't loaded yet");
		return Plugin_Handled;
	}

	Client[client].BackOutAdmin = (args==-1);
	if(Client[client].StoreType != Type_Inven)
	{
		Client[client].ClearPos();
		Client[client].StoreType = Type_Inven;
	}

	if(args)
	{
		LookupItemMenu(client, 2);
		return Plugin_Handled;
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

public Action CommandGiveItem(int client, int args)
{
	if(args > 1)
	{
		char targetName[MAX_TARGET_LENGTH];
		GetCmdArg(2, targetName, sizeof(targetName));

		int index;
		ItemEnum item;
		int length = Items.Length;
		for(; index<length; index++)
		{
			Items.GetArray(index, item);
			if(StrEqual(targetName, item.Name, false))
				break;
		}

		if(index != length)
		{
			char pattern[PLATFORM_MAX_PATH];
			GetCmdArg(1, pattern, sizeof(pattern));

			int targets[MAXPLAYERS];
			bool targetNounIsMultiLanguage;
			if((length=ProcessTargetString(pattern, client, targets, sizeof(targets), COMMAND_FILTER_NO_IMMUNITY|COMMAND_FILTER_NO_BOTS, targetName, sizeof(targetName), targetNounIsMultiLanguage)) > 0)
			{
				bool equip;
				int amount = 1;
				if(args > 2)
				{
					GetCmdArg(3, pattern, sizeof(pattern));
					amount = StringToInt(pattern);

					if(args > 3)
					{
						GetCmdArg(4, pattern, sizeof(pattern));
						equip = view_as<bool>(StringToInt(pattern));
					}

					if(!amount && !equip)
					{
						SReplyToCommand(client, "Nothing is given or equipped");
						return Plugin_Handled;
					}
				}

				char buffer[64];
				if(args > 4)
				{
					if(amount < 1)
					{
						SReplyToCommand(client, "Can not remove unique items");
						return Plugin_Handled;
					}

					GetCmdArg(5, pattern, sizeof(pattern));
					GetCmdArg(6, buffer, sizeof(buffer));

					for(int target; target<length; target++)
					{
						for(int i; i<amount; i++)
						{
							int id = Unique_AddItem(index, targets[target], false, buffer, pattern);
							if(equip)
								Unique_UseItem(targets[target], id);
						}
					}

					Format(item.Name, sizeof(item.Name), "\"%s\"", buffer[0] ? buffer : item.Name);
				}
				else
				{
					for(int target; target<length; target++)
					{
						item.Count[targets[target]] += amount;
						if(item.Count[targets[target]] < 1)
						{
							item.Count[targets[target]] = 0;
						}
						else if(equip && !item.Equip[targets[target]])
						{
							UseThisItem(targets[target], index, item);
						}
					}

					Items.SetArray(index, item);
				}

				// {color1}Gave and equipped
				FormatEx(buffer, sizeof(buffer), "%s%s", STORE_COLOR, amount>0 ? "Gave" : amount<0 ? "Removed" : "Equipped");
				if(equip && amount)
					Format(buffer, sizeof(buffer), "%s and equipped", buffer);

				// {color1}Item A x3
				FormatEx(pattern, sizeof(pattern), "%s%s", STORE_COLOR, item.Name);
				if(amount>1 || amount<-1)
					Format(pattern, sizeof(pattern), "%s x%d", pattern, amount);

				// {color1}Gave and equipped {color2}Player {color1}Item A x3
				if(targetNounIsMultiLanguage)
				{
					CShowActivity2(client, STORE_PREFIX2, "%s %s%t %s", buffer, STORE_COLOR2, targetName, pattern);
				}
				else
				{
					CShowActivity2(client, STORE_PREFIX2, "%s %s%s %s", buffer, STORE_COLOR2, targetName, pattern);
				}
			}
			else
			{
				ReplyToTargetError(client, length);
			}
		}
		else
		{
			SReplyToCommand(client, "Could not find item %s%s", STORE_COLOR2, targetName);
		}
	}
	else
	{
		ReplyToCommand(client, "[SM] Usage: sm_store_giveitem <client> <item name> [amount] [equip] [unique data] [nick name]");
	}
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

	menu.AddItem("1", "Store");
	menu.AddItem("2", "Inventory");

	if(Crafts)
		menu.AddItem("4", "Crafting");

	menu.AddItem("5", "Trading");

	if(Forward_OnMainMenu(client, menu) >= Plugin_Handled)
	{
		delete menu;
		return;
	}

	if(CheckCommandAccess(client, "sm_store_admin", ADMFLAG_ROOT))
		menu.AddItem("3", "Admin Menu");

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
			static char buffer[64];
			menu.GetItem(choice, buffer, sizeof(buffer));
			switch(StringToInt(buffer))
			{
				case 1:
					CommandStore(client, 0);
				
				case 2:
					CommandInven(client, 0);

				case 3:
					CommandAdmin(client, 0);

				case 4:
					Crafting_Command(client, 0);

				case 5:
					Trading_Command(client, 0);

				default:
					FakeClientCommand(client, buffer);
			}
		}
	}
	return 0;
}

void Store(int client)
{
	ItemEnum item;
	int primary = Client[client].GetPos();
	if(primary != POS_NONE)
	{
		if(primary < 0)
		{
			UniqueItem(client, primary);
		}
		else
		{
			Items.GetArray(primary, item);
			if(item.Kv)
			{
				ViewItem(client, primary, item);
				return;
			}
		}
	}
	
	Forward_OnCatalog(client);
	
	Menu menu = new Menu(GeneralMenuH);
	if(primary == POS_NONE)
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
		menu.AddItem(buffer, item.Name, (item.Count[client] || CheckCommandAccess(client, "textstore_all", item.Admin, true)) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(!found)
		menu.AddItem("", "No Items", ITEMDRAW_DISABLED);

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
	if(primary == POS_ALLITEM)
	{
		menu = new Menu(GeneralMenuH);
		menu.SetTitle("Inventory: All Items\n ");

		int length = Items.Length;
		for(int i; i<length; i++)
		{
			Items.GetArray(i, item);
			if(!item.Kv || (item.Count[client]<1 && !Unique_HasUniqueOf(client, i)))
				continue;

			IntToString(i, buffer, sizeof(buffer));
			menu.AddItem(buffer, item.Name);
			found = true;
		}
	}
	else
	{
		if(primary != POS_NONE)
		{
			if(primary < 0)
			{
				UniqueItem(client, primary);
				return;
			}
			else
			{
				Items.GetArray(primary, item);
				if(item.Kv)
				{
					ViewItem(client, primary, item);
					return;
				}
			}
		}

		menu = new Menu(GeneralMenuH);
		if(primary == POS_NONE)
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
			if(item.Parent!=primary || (item.Kv && item.Count[client]<1 && !Unique_HasUniqueOf(client, i)))
				continue;

			IntToString(i, buffer, sizeof(buffer));
			menu.AddItem(buffer, item.Name);
			found = true;
		}
	}

	if(primary == POS_NONE)
	{
		IntToString(POS_ALLITEM, buffer, sizeof(buffer));
		menu.AddItem(buffer, "All Items");
	}
	else if(!found)
	{
		menu.AddItem("", "No Items", ITEMDRAW_DISABLED);
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

	int length = Client[client].Pos ? Client[client].Pos.Length : 0;
	if(!length)
	{
		Menu menu = new Menu(GeneralMenuH);
		menu.SetTitle("Store Admin Menu\n ");
		menu.AddItem("1", "Credits");
		menu.AddItem("2", "Force Save");
		menu.AddItem("3", "Force Reload");
		menu.AddItem("4", "Give Item");
		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	if(length == 1)
	{
		static const char items[][] = { "Credits", "Force Save", "Force Reload", "Give Item" };
		Menu menu = new Menu(GeneralMenuH);
		menu.SetTitle("Store Admin Menu: %s\nTarget:", items[Client[client].Pos.Get(0)-1]);
		GenerateClientList(menu, client);
		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	int target = GetClientOfUserId(Client[client].Pos.Get(1));
	if(!IsValidClient(target))
	{
		PrintToChat(client, "[SM] %t", "Player no longer available");
		Client[client].ClearPos();
		AdminMenu(client);
		return;
	}

	switch(Client[client].Pos.Get(0))
	{
		case 1:
		{
			switch(length)
			{
				case 2:
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
				case 3:
				{
					int type = Client[client].Pos.Get(2);
					bool set = type==3;

					Menu menu = new Menu(GeneralMenuH);
					menu.SetTitle("Store Admin Menu: Credits\nTarget: %N\nMode: %s\nAmount:", target, set ? "Set" : type==2 ? "Remove" : "Add");

					if(set)
						menu.AddItem("0", "0");

					menu.AddItem("100", "100");
					menu.AddItem("300", "300");
					menu.AddItem("500", "500");
					menu.AddItem("1000", "1,000");
					menu.AddItem("5000", "5,000");
					menu.AddItem("10000", "10,000");

					if(!set)
						menu.AddItem("50000", "50,000");

					menu.ExitBackButton = true;
					menu.ExitButton = true;
					menu.Display(client, MENU_TIME_FOREVER);
					return;
				}
				default:
				{
					int value = Client[client].Pos.Get(3);
					switch(Client[client].Pos.Get(2))
					{
						case 2:
						{
							Client[target].Cash -= value;
							CShowActivity2(client, STORE_PREFIX2, "%sToke %d credits from %s%N", STORE_COLOR, value, STORE_COLOR2, target);
						}
						case 3:
						{
							Client[target].Cash = value;
							CShowActivity2(client, STORE_PREFIX2, "%sSet %s%N's%s credits to %d", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR, value);
						}
						default:
						{
							Client[target].Cash += value;
							CShowActivity2(client, STORE_PREFIX2, "%sGave %s%N %s%d credits", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR, value);
						}
					}
				}
			}
		}
		case 2:
		{
			SaveClient(target);
			CShowActivity2(client, STORE_PREFIX2, "%sForced %s%N%s to save data", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR);
		}
		case 3:
		{
			SetupClient(target);
			CShowActivity2(client, STORE_PREFIX2, "%sForced %s%N%s to reload data", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR);
		}
		case 4:
		{
			switch(length)
			{
				case 2:
				{
					Menu menu = new Menu(GeneralMenuH);
					menu.SetTitle("Store Admin Menu: Give Item\nTarget: %N\nMode:", target);
					menu.AddItem("1", "Give One");
					menu.AddItem("2", "Remove One");
					menu.AddItem("3", "Give & Equip");
					menu.AddItem("4", "Remove All");
					menu.ExitBackButton = true;
					menu.ExitButton = true;
					menu.Display(client, MENU_TIME_FOREVER);
					return;
				}
				case 3:
				{
					int value = Client[client].Pos.Get(2);
					ItemEnum item;
					Menu menu = new Menu(GeneralMenuH);
					menu.SetTitle("Store Admin Menu: Give Item\nTarget: %N\nMode: %s\nItem:", target, value==4 ? "Remove All" : value==2 ? "Give & Equip" : value==3 ? "Remove One" : "Give One");

					bool need = value>2;
					value = Items.Length;
					for(int i; i<value; i++)
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
				default:
				{
					int index = Client[client].Pos.Get(3);
					ItemEnum item;
					Items.GetArray(index, item);
					switch(Client[client].Pos.Get(2))
					{
						case 2:
						{
							if(--item.Count[target] < 1)
								item.Equip[target] = false;

							CShowActivity2(client, STORE_PREFIX2, "%sRemoved %s%N's %s%s", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR, item.Name);
						}
						case 3:
						{
							item.Count[target]++;
							UseThisItem(client, index, item);
							CShowActivity2(client, STORE_PREFIX2, "%sGave and equipped %s%N %s%s", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR, item.Name);
						}
						case 4:
						{
							item.Count[target] = 0;
							item.Equip[target] = false;
							CShowActivity2(client, STORE_PREFIX2, "%sRemoved all of %s%N's %s%s", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR, item.Name);
						}
						default:
						{
							item.Count[target]++;
							CShowActivity2(client, STORE_PREFIX2, "%sGave %s%N %s%s", STORE_COLOR, STORE_COLOR2, target, STORE_COLOR, item.Name);
						}
					}
					Items.SetArray(index, item);
				}
			}
		}
	}

	Client[client].ClearPos();
	AdminMenu(client);
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
				return 0;

			if(Client[client].RemovePos())
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
	return 0;
}

void ViewItem(int client, int index, ItemEnum item)
{
	Forward_OnCatalog(client);
	
	Panel panel = new Panel();

	char buffer[MAX_DESC_LENGTH];
	FormatEx(buffer, sizeof(buffer), "%s\n ", item.Name);
	panel.SetTitle(buffer);

	item.Kv.Rewind();
	item.Kv.GetString("desc", buffer, sizeof(buffer), "No Description");
	ReplaceString(buffer, sizeof(buffer), "\\n", "\n");
	Forward_OnDescItem(client, index, buffer);
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
	
	int cost2 = cost;
	switch(Forward_OnPriceItem(client, index, cost2))
	{
		case Plugin_Changed:
		{
			cost = cost2;
		}
		case Plugin_Handled, Plugin_Stop:
		{
			cost = 0;
		}
	}
	
	if(cost > 0)
	{
		FormatEx(buffer, sizeof(buffer), "Buy (%d Credits)", cost);
		if(item.Hidden || (!stack && item.Count[client]) || Client[client].Cash<cost)
		{
			panel.DrawItem(buffer, ITEMDRAW_DISABLED);
		}
		else
		{
			panel.DrawItem(buffer);
		}
	}

	if(sell > 0)
	{
		panel.CurrentKey = 3;
		FormatEx(buffer, sizeof(buffer), "Sell (%d Credits)", sell);
		panel.DrawItem(buffer, item.Count[client]>0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(Unique_HasUniqueOf(client, index))
	{
		panel.CurrentKey = 4;
		panel.DrawItem("View Variants");
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
		return 0;
	
	Forward_OnCatalog(client);
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
			
			int count = item.Count[client];
			int cost2 = cost;
			switch(Forward_OnBuyItem(client, index, Client[client].Cash, count, cost2))
			{
				case Plugin_Changed:
				{
					cost = cost2;
					item.Count[client] = count;
				}
				case Plugin_Handled:
				{
					item.Count[client] = count;
					cost = 0;
				}
				case Plugin_Stop:
				{
					cost = 0;
				}
			}
			
			if(cost>0 && !item.Hidden && (item.Kv.GetNum("stack", 1) || item.Count[client]<1) && Client[client].Cash>=cost)
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
		case 4:
		{
			ClientCommand(client, "playgamesound buttons/combine_button7.wav");
			UniqueItem(client, index);
			return 0;
		}
		case 10:
		{
			ClientCommand(client, "playgamesound buttons/combine_button7.wav");
			Client[client].RemovePos();
			return 0;
		}
		default:
		{
			ClientCommand(client, "playgamesound buttons/combine_button7.wav");
			Client[client].RemovePos();
		}
	}

	ReturnStoreType(client);
	return 0;
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

bool UseThisItem(int client, int index, ItemEnum item, bool auto=false)
{
	static char buffer[256];
	item.Kv.GetString("plugin", buffer, sizeof(buffer));

	ItemResult result = Item_None;
	if(Forward_OnUseItem(result, buffer, client, item.Equip[client], item.Kv, index, item.Name, item.Count[client], auto))
	{
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
		return true;
	}

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
		SaveClient(client);

	CreateTimer(20.0, Timer_AutoSave, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

void LookupItemMenu(int client, int type)
{
	static char key[256];
	GetCmdArgString(key, sizeof(key));

	Forward_OnCatalog(client);

	Menu menu = new Menu(GeneralMenuH);
	menu.SetTitle("%s\n ", key);

	ReplaceString(key, sizeof(key), "\"", "");

	bool found;
	ItemEnum item;
	int length = Items.Length;
	for(int i; i<length; i++)
	{
		static char buffer[MAX_DESC_LENGTH];
		Items.GetArray(i, item);
		if(StrContains(item.Name, key, false) == -1)
		{
			if(!item.Kv)
				continue;

			item.Kv.Rewind();
			item.Kv.GetString("desc", buffer, sizeof(buffer));
			if(!buffer[0] || StrContains(buffer, key, false) == -1)
				continue;
		}

		bool owned = view_as<bool>(item.Count[client]);
		switch(type)
		{
			case 1:
			{
				if(item.Hidden)
					continue;
			}
			case 2:
			{
				if(!owned)
					continue;
			}
			default:
			{
				if(!owned && item.Hidden)
					continue;
			}
		}

		found = true;
		IntToString(i, buffer, sizeof(buffer));
		menu.AddItem(buffer, item.Name, (owned || CheckCommandAccess(client, "textstore_all", item.Admin, true)) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	if(!found)
		menu.AddItem("", "No Items", ITEMDRAW_DISABLED);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}