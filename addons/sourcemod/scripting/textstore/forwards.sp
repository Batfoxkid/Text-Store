static GlobalForward OnSellItem;
static GlobalForward OnDescItem;
static GlobalForward OnClientLoad;
static GlobalForward OnClientLoaded;
static GlobalForward OnClientSave;
static GlobalForward OnClientSaved;
static GlobalForward OnMainMenu;
static GlobalForward OnCatalog;
static GlobalForward OnBuyItem;
static GlobalForward OnPriceItem;

void Forward_PluginLoad()
{
	OnSellItem = new GlobalForward("TextStore_OnSellItem", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);
	OnDescItem = new GlobalForward("TextStore_OnDescItem", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	OnClientLoad = new GlobalForward("TextStore_OnClientLoad", ET_Event, Param_Cell, Param_String);
	OnClientLoaded = new GlobalForward("TextStore_OnClientLoaded", ET_Ignore, Param_Cell, Param_String);
	OnClientSave = new GlobalForward("TextStore_OnClientSave", ET_Event, Param_Cell, Param_String);
	OnClientSaved = new GlobalForward("TextStore_OnClientSaved", ET_Ignore, Param_Cell, Param_String);
	OnMainMenu = new GlobalForward("TextStore_OnMainMenu", ET_Event, Param_Cell, Param_Cell);
	OnCatalog = new GlobalForward("TextStore_OnCatalog", ET_Ignore, Param_Cell);
	OnBuyItem = new GlobalForward("TextStore_OnBuyItem", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);
	OnPriceItem = new GlobalForward("TextStore_OnPriceItem", ET_Event, Param_Cell, Param_Cell, Param_CellByRef);
}

bool Forward_OnUseItem(ItemResult &result, const char[] pluginname, int client, bool equipped, KeyValues kv, int index, const char[] name, int &count, bool auto)
{
	Handle iter = GetPluginIterator();
	while(MorePlugins(iter))
	{
		Handle plugin = ReadPlugin(iter);
		static char buffer[256];
		GetPluginFilename(plugin, buffer, sizeof(buffer));
		if(StrContains(buffer, pluginname, false) == -1)
			continue;

		Function func = GetFunctionByName(plugin, "TextStore_Item");
		if(func == INVALID_FUNCTION)
		{
			if(CheckCommandAccess(client, "textstore_dev", ADMFLAG_RCON))
			{
				SPrintToChat(client, "'%s' is missing function 'TextStore_Item' from '%s'", name, buffer);
			}
			else
			{
				SPrintToChat(client, "%s can't be used right now!", name);
			}
			break;
		}
		
		Call_StartFunction(plugin, func);
		Call_PushCell(client);
		Call_PushCell(equipped);
		Call_PushCell(kv);
		Call_PushCell(index);
		Call_PushString(name);
		Call_PushCellRef(count);
		Call_PushCell(auto);
		Call_Finish(result);
		delete iter;
		return true;
	}
	delete iter;
	return false;
}

Action Forward_OnSellItem(int client, int item, int cash, int &count, int &sell)
{
	Action action = Plugin_Continue;
	Call_StartForward(OnSellItem);
	Call_PushCell(client);
	Call_PushCell(item);
	Call_PushCell(cash);
	Call_PushCellRef(count);
	Call_PushCellRef(sell);
	Call_Finish(action);
	return action;
}

void Forward_OnDescItem(int client, int item, char desc[MAX_DESC_LENGTH])
{
	Call_StartForward(OnDescItem);
	Call_PushCell(client);
	Call_PushCell(item);
	Call_PushStringEx(desc, MAX_DESC_LENGTH, SM_PARAM_STRING_COPY|SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
	Call_Finish();
}

Action Forward_OnClientLoad(int client, char file[512])
{
	Action action = Plugin_Continue;
	Call_StartForward(OnClientLoad);
	Call_PushCell(client);
	Call_PushStringEx(file, sizeof(file), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_Finish(action);
	return action;
}

void Forward_OnClientLoaded(int client, const char[] file)
{
	Call_StartForward(OnClientLoaded);
	Call_PushCell(client);
	Call_PushString(file);
	Call_Finish();
}

Action Forward_OnClientSave(int client, char file[PLATFORM_MAX_PATH])
{
	Action action = Plugin_Continue;
	Call_StartForward(OnClientSave);
	Call_PushCell(client);
	Call_PushStringEx(file, sizeof(file), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_Finish(action);
	return action;
}

void Forward_OnClientSaved(int client, const char[] file)
{
	Call_StartForward(OnClientSaved);
	Call_PushCell(client);
	Call_PushString(file);
	Call_Finish();
}

Action Forward_OnMainMenu(int client, Menu menu)
{
	Action action = Plugin_Continue;
	Call_StartForward(OnMainMenu);
	Call_PushCell(client);
	Call_PushCell(menu);
	Call_Finish(action);
	return action;
}

void Forward_OnCatalog(int client)
{
	Call_StartForward(OnCatalog);
	Call_PushCell(client);
	Call_Finish();
}

Action Forward_OnBuyItem(int client, int item, int cash, int &count, int &cost)
{
	Action action = Plugin_Continue;
	Call_StartForward(OnBuyItem);
	Call_PushCell(client);
	Call_PushCell(item);
	Call_PushCell(cash);
	Call_PushCellRef(count);
	Call_PushCellRef(cost);
	Call_Finish(action);
	return action;
}

Action Forward_OnPriceItem(int client, int item, int &price)
{
	Action action = Plugin_Continue;
	Call_StartForward(OnPriceItem);
	Call_PushCell(client);
	Call_PushCell(item);
	Call_PushCellRef(price);
	Call_Finish(action);
	return action;
}