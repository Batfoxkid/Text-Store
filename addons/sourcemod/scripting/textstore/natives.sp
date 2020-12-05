#define ERROR_NOTREADY		"Store not yet initialized"
#define ERROR_CLIENTINDEX		"Invalid client index %d"
#define ERROR_ITEMINDEX		"Invalid item index %d"

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
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	int length = Items.Length;
	int index = GetNativeCell(2);
	if(index<0 || index>=length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	ItemEnum item;
	Items.GetArray(index, item);
	SetNativeCellRef(3, item.Count[client]);
	return item.Equip[client];
}

public any Native_SetInv(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	int length = Items.Length;
	int index = GetNativeCell(2);
	if(index<0 || index>=length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	ItemEnum item;
	Items.GetArray(index, item);

	int count = GetNativeCell(3);
	if(count >= 0)
		item.Count[client] = count;

	switch(GetNativeCell(4))
	{
		case 0:
		{
			item.Equip[client] = false;
		}
		case 1:
		{
			item.Equip[client] = true;
		}
	}
	Items.SetArray(index, item);
}

public any Native_Cash(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	int cash = GetNativeCell(2);
	if(cash)
		Client[client].Cash += cash;

	return Client[client].Cash;
}

public any Native_ClientSave(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	OnClientDisconnect(client);
}

public any Native_ClientReload(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	OnClientPostAdminCheck(client);
}

public any Native_GetItems(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	return Items.Length;
}

public any Native_GetItemKv(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int length = Items.Length;
	int index = GetNativeCell(1);
	if(index<0 || index>=length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	ItemEnum item;
	Items.GetArray(index, item);
	if(item.Kv)
		item.Kv.Rewind();

	return item.Kv;
}

public any Native_GetItemName(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int length = Items.Length;
	int index = GetNativeCell(1);
	if(index<0 || index>=length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	ItemEnum item;
	Items.GetArray(index, item);

	int bytes;
	SetNativeString(2, item.Name, GetNativeCell(3), _, bytes);
	return bytes;
}