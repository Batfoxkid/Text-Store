#if defined _FF2_included
#define ITEM_TF2_FF2	"freak_fortress_2"
char FF2Selection[MAXPLAYERS+1];
int FF2StoreIndex[MAXPLAYERS+1];

public ItemResult FF2_Use(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
{
	if(GameType != Engine_TF2)
	{
		if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
		{
			SPrintToChat(client, "Incorrect game type for %s", name);
		}
		else
		{
			SPrintToChat(client, "This can't be used right now!");
		}
		return Item_None;
	}

	static char buffer[64];
	if(GetFeatureStatus(FeatureType_Native, "FF2_GetQueuePoints") != FeatureStatus_Available)
	{
		if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
		{
			item.GetString("plugin", buffer, sizeof(buffer));
			SPrintToChat(client, "%s can't find Freak Fortress 2 natives!", buffer);
		}
		else
		{
			SPrintToChat(client, "This can't be used right now!");
		}
		return Item_None;
	}

	bool used;
	// Give queue points
	{
		int points = item.GetNum("points");
		if(points)
		{
			FF2_SetQueuePoints(client, FF2_GetQueuePoints(client)+points);
			SPrintToChat(client, "You have %s %i queue point(s)", points<0 ? "lost" : "gained", points);
			used = true;
		}
	}

	static char boss[64];
	// Unlock a boss
	item.GetString("unlock", buffer, sizeof(buffer));
	if(buffer[0])
	{
		for(int i; ; i++)
		{
			KeyValues kv = view_as<KeyValues>(FF2_GetSpecialKV(i, 1));
			if(kv == INVALID_HANDLE)
				break;

			kv.GetString("filename", boss, sizeof(boss));
			if(StrEqual(buffer, boss, false))
			{
				kv.SetNum("blocked", 0);
				kv.SetNum("donator", 0);
				kv.SetNum("admin", 0);
				kv.SetNum("owner", 0);
				kv.SetNum("theme", 0);
				kv.SetNum("hidden", 0);
				kv.GetString("name", boss, sizeof(boss));
				for(int target=1; target<=MaxClients; target++)
				{
					if(!IsValidClient(target))
						continue;

					FF2_GetName(i, boss, sizeof(boss), 1, target);
					SPrintToChat(target, "%s%s%s is now unlocked for the map duration!", STORE_COLOR2, buffer, STORE_COLOR);
				}
				used = true;
				break;
			}
		}

		if(!used)
			SPrintToChat(client, "%s%s%s is not available right now!", STORE_COLOR2, buffer, STORE_COLOR);
	}

	// Select a boss (Unofficial FF2)
	item.GetString("select", buffer, sizeof(buffer));
	if(buffer[0] && GetFeatureStatus(FeatureType_Native, "FF2_SelectBoss")==FeatureStatus_Available)
	{
		for(int i; ; i++)
		{
			KeyValues kv = view_as<KeyValues>(FF2_GetSpecialKV(i, 1));
			if(kv == INVALID_HANDLE)
				break;

			kv.GetString("filename", boss, sizeof(boss));
			if(StrEqual(buffer, boss, false))
			{
				kv.GetString("name", boss, sizeof(boss));
				if(!FF2_SelectBoss(client, boss, true))
				{
					strcopy(FF2Selection[client], sizeof(FF2Selection[]), boss);
					FF2StoreIndex[client] = index;
				}
				FF2_GetName(i, boss, sizeof(boss), 1, client);
				SPrintToChat(client, "%s%s%s is now selected!", STORE_COLOR2, boss, STORE_COLOR);
				used = true;
				break;
			}
		}

		if(!used)
			SPrintToChat(client, "%s%s%s is not available right now!", STORE_COLOR2, buffer, STORE_COLOR);

		return Item_None;
	}

	return used ? Item_Used : Item_None;
}

public void FF2_OnArenaRoundStart()
{
	if(GetFeatureStatus(FeatureType_Native, "FF2_GetBossSpecial") != FeatureStatus_Available)
		return;

	for(int client=1; client<=MaxClients; client++)
	{
		if(!FF2StoreIndex[client] || !IsValidClient(client))
			continue;

		int boss = FF2_GetBossIndex(client);
		if(boss == -1)
			continue;

		static char buffer[64];
		FF2_GetBossSpecial(boss, buffer, sizeof(buffer), 0);
		if(!StrEqual(buffer, FF2Selection[client]))
		{
			FF2StoreIndex[client] = 0;
			continue;
		}

		FF2_SelectBoss(client, "", false);

		int items;
		BatStore_GetInv(client, FF2StoreIndex[client], items);
		if(items < 1)
		{
			LogError("Exploit detected with Select FF2 Item! Client: %N Index: %i Count: %i Boss: %s", client, FF2StoreIndex[client], items, FF2Selection[client]);
			FF2StoreIndex[client] = 0;
			return;
		}

		FF2StoreIndex[client] = 0;
		BatStore_SetInv(client, FF2StoreIndex[client], items-1, items==1 ? 0 : -1);
	}
}

public Action BatStore_OnSellItem(int client, int item, int cash, int &count, int &sell)
{
	if(count>1 || FF2StoreIndex[client]!=item)
		return Plugin_Continue;

	SPrintToChat(client, "You can not sell this item right now!");
	return Plugin_Handled;
}

stock void FF2_GetName(int boss, char[] buffer, int length, int mode, int client)
{
	if(GetFeatureStatus(FeatureType_Native, "FF2_GetBossName") == FeatureStatus_Available)
	{
		FF2_GetBossName(boss, buffer, length, mode, client);
	}
	else
	{
		FF2_GetBossSpecial(boss, buffer, length, mode);
	}
}
#endif
