void Native_PluginLoad()
{
	CreateNative("TextStore_GetInv", Native_GetInv);
	CreateNative("TextStore_SetInv", Native_SetInv);
	CreateNative("TextStore_Cash", Native_Cash);
	CreateNative("TextStore_ClientSave", Native_ClientSave);
	CreateNative("TextStore_ClientReload", Native_ClientReload);
	CreateNative("TextStore_GetItems", Native_GetItems);
	CreateNative("TextStore_GetItemKv", Native_GetItemKv);
	CreateNative("TextStore_GetItemName", Native_GetItemName);
}

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

public any Native_ClientSave(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %i", client);

	OnClientDisconnect(client);
}

public any Native_ClientReload(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %i", client);

	OnClientPostAdminCheck(client);
}

public any Native_GetItems(Handle plugin, int numParams)
{
	return MaxItems;
}

public any Native_GetItemKv(Handle plugin, int numParams)
{
	int item = GetNativeCell(1);
	if(item<0 || item>MAXITEMS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid item index %i", item);

	return Item[item].Kv;
}

public any Native_GetItemName(Handle plugin, int numParams)
{
	int item = GetNativeCell(1);
	if(item<0 || item>MAXITEMS)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid item index %i", item);

	int bytes;
	SetNativeString(2, Item[item].Name, GetNativeCell(3), _, bytes);
	return bytes;
}