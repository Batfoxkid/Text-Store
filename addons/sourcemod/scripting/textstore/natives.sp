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
	CreateNative("TextStore_GetClientLoad", Native_GetClientLoad);
	CreateNative("TextStore_SetClientLoad", Native_SetClientLoad);
	CreateNative("TextStore_GetItems", Native_GetItems);
	CreateNative("TextStore_GetItemKv", Native_GetItemKv);
	CreateNative("TextStore_GetItemName", Native_GetItemName);
	CreateNative("TextStore_SetItemName", Native_SetItemName);
	CreateNative("TextStore_GetItemData", Native_GetItemData);
	CreateNative("TextStore_SetItemData", Native_SetItemData);
	CreateNative("TextStore_CreateUniqueItem", Native_NewUniqueItem);
	CreateNative("TextStore_UseItem", Native_UseItem);
	CreateNative("TextStore_GetItemHidden", Native_GetItemHidden);
	CreateNative("TextStore_SetItemHidden", Native_SetItemHidden);
	CreateNative("TextStore_GetItemParent", Native_GetItemParent);
	CreateNative("TextStore_SetItemParent", Native_SetItemParent);
}

public any Native_GetInv(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	int index = GetNativeCell(2);
	if(-UniqueList.Length>index || index>=Items.Length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	if(index < 0)
	{
		UniqueEnum unique;
		UniqueList.GetArray(-1-index, unique);
		SetNativeCellRef(3, unique.Owner==client ? 1 : 0);
		return unique.Owner==client ? unique.Equipped : false;
	}

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

	int index = GetNativeCell(2);
	if(-UniqueList.Length>index || index>=Items.Length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	int value = GetNativeCell(3);
	if(index < 0)
	{
		index = -1-index;
		UniqueEnum unique;
		UniqueList.GetArray(index, unique);

		if(value > 0)
		{
			unique.Owner = client;
		}
		else if(!value)
		{
			unique.Owner = 0;
		}

		value = GetNativeCell(4);
		if(value > 0)
		{
			unique.Equipped = true;
		}
		else if(!value)
		{
			unique.Equipped = false;
		}

		UniqueList.SetArray(index, unique);
	}
	else
	{
		ItemEnum item;
		Items.GetArray(index, item);

		if(value >= 0)
			item.Count[client] = value;

		value = GetNativeCell(4);
		if(value > 0)
		{
			item.Equip[client] = true;
		}
		else if(!value)
		{
			item.Equip[client] = false;
		}

		Items.SetArray(index, item);
	}
	return 0;
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
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int client = GetNativeCell(1);
	if(client<0 || client>MaxClients || !IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	SaveClient(client);
	return 0;
}

public any Native_ClientReload(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int client = GetNativeCell(1);
	if(client<0 || client>MaxClients || !IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	SetupClient(client);
	return 0;
}

public any Native_GetClientLoad(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	return Client[client].Ready;
}

public any Native_SetClientLoad(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	Client[client].Ready = GetNativeCell(2);
	return 0;
}

public any Native_GetItems(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	if(numParams)
		SetNativeCellRef(1, UniqueList.Length);

	return Items.Length;
}

public any Native_GetItemKv(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int index = GetNativeCell(1);
	if(-UniqueList.Length>index || index>=Items.Length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	if(index < 0)
	{
		UniqueEnum unique;
		UniqueList.GetArray(-1-index, unique);
		index = unique.BaseItem;
	}

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

	int index = GetNativeCell(1);
	if(-UniqueList.Length>index || index>=Items.Length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	bool add;
	if(index < 0)
	{
		UniqueEnum unique;
		UniqueList.GetArray(-1-index, unique);
		if(unique.Name[0])
		{
			SetNativeString(2, unique.Name, GetNativeCell(3), _, index);
			return index;
		}

		add = true;
		index = unique.BaseItem;
	}

	ItemEnum item;
	Items.GetArray(index, item);

	if(add)
	{
		index = strlen(item.Name);
		item.Name[index] = '*';
		item.Name[index+1] = '\0';
	}

	SetNativeString(2, item.Name, GetNativeCell(3), _, index);
	return index;
}

public any Native_SetItemName(Handle plugin, int numParams)
{
	if(UniqueList == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int index = -1-GetNativeCell(1);
	if(index>=UniqueList.Length || index<0)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, -1-index);

	UniqueEnum unique;
	UniqueList.GetArray(index, unique);
	GetNativeString(2, unique.Name, sizeof(unique.Name));
	UniqueList.SetArray(index, unique);
	return 0;
}

public any Native_GetItemData(Handle plugin, int numParams)
{
	if(UniqueList == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int index = -1-GetNativeCell(1);
	if(index>=UniqueList.Length || index<0)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, -1-index);

	UniqueEnum unique;
	UniqueList.GetArray(index, unique);
	SetNativeString(2, unique.Data, GetNativeCell(3), _, index);
	return index;
}

public any Native_SetItemData(Handle plugin, int numParams)
{
	if(UniqueList == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int index = -1-GetNativeCell(1);
	if(index>=UniqueList.Length || index<0)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, -1-index);

	UniqueEnum unique;
	UniqueList.GetArray(index, unique);
	GetNativeString(2, unique.Data, sizeof(unique.Data));
	UniqueList.SetArray(index, unique);
	return 0;
}

public any Native_NewUniqueItem(Handle plugin, int numParams)
{
	if(UniqueList == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int client = GetNativeCell(1);
	if(client<0 || client>MAXPLAYERS)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	int index = GetNativeCell(2);
	if(index<0 || index>=Items.Length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	char data[MAX_DATA_LENGTH];
	GetNativeString(3, data, sizeof(data));

	char name[MAX_ITEM_LENGTH];
	GetNativeString(4, name, sizeof(name));

	return -1-Unique_AddItem(index, client, GetNativeCell(5), name, data);
}

public any Native_UseItem(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int client = GetNativeCell(1);
	if(client<0 || client>MaxClients || !IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_CLIENTINDEX, client);

	int index = GetNativeCell(2);
	if(index >= Items.Length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);
	
	if(index < 0)
	{
		index = -1-index;
		if(index >= UniqueList.Length)
			ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, -1-index);
		
		return Unique_UseItem(client, index, GetNativeCell(3));
	}
	
	ItemEnum item;
	Items.GetArray(index, item);
	return UseThisItem(client, index, item, GetNativeCell(3));
}

public any Native_GetItemHidden(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int index = GetNativeCell(1);
	if(-UniqueList.Length>index || index>=Items.Length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	if(index < 0)
	{
		UniqueEnum unique;
		UniqueList.GetArray(-1-index, unique);
		index = unique.BaseItem;
	}

	ItemEnum item;
	Items.GetArray(index, item);
	return item.Hidden;
}

public any Native_SetItemHidden(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int index = GetNativeCell(1);
	if(-UniqueList.Length>index || index>=Items.Length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	if(index < 0)
	{
		UniqueEnum unique;
		UniqueList.GetArray(-1-index, unique);
		index = unique.BaseItem;
	}

	ItemEnum item;
	Items.GetArray(index, item);
	item.Hidden = GetNativeCell(2);
	Items.SetArray(index, item);
	return 0;
}

public any Native_GetItemParent(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int index = GetNativeCell(1);
	if(-UniqueList.Length>index || index>=Items.Length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	if(index < 0)
	{
		UniqueEnum unique;
		UniqueList.GetArray(-1-index, unique);
		index = unique.BaseItem;
	}

	ItemEnum item;
	Items.GetArray(index, item);
	return item.Parent;
}

public any Native_SetItemParent(Handle plugin, int numParams)
{
	if(Items == INVALID_HANDLE)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_NOTREADY);

	int index = GetNativeCell(1);
	if(-UniqueList.Length>index || index>=Items.Length)
		ThrowNativeError(SP_ERROR_NATIVE, ERROR_ITEMINDEX, index);

	if(index < 0)
	{
		UniqueEnum unique;
		UniqueList.GetArray(-1-index, unique);
		index = unique.BaseItem;
	}

	ItemEnum item;
	Items.GetArray(index, item);
	item.Parent = GetNativeCell(2);
	Items.SetArray(index, item);
	return 0;
}