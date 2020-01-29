#undef REQUIRE_PLUGIN
#tryinclude <freak_fortress_2>
#define REQUIRE_PLUGIN

#if defined _FF2_included
#define ITEM_TF2_FF2	"freak_fortress_2"

public ItemResult FF2_Use(int client, bool equipped, KeyValues item, const char[] name, int &count)
{
	if(GameType != Engine_TF2)
	{
		if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
		{
			SPrintToClient(client, "Incorrect game type for %s", name);
		}
		else
		{
			SPrintToClient(client, "This can't be used right now!");
		}
		return Item_None;
	}

	if(GetFeatureStatus(FeatureType_Native, "FF2_GetQueuePoints") != FeatureStatus_Available)
	{
		if(CheckCommandAccess(client, "batstore_dev", ADMFLAG_RCON))
		{
			item.GetString("plugin", buffer, MAX_MATERIAL_PATH);
			SPrintToClient(client, "%s can't find Freak Fortress 2 natives!", buffer);
		}
		else
		{
			SPrintToClient(client, "This can't be used right now!");
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

	// Unlock a boss
	static char buffer[64];
	item.GetString("unlock", buffer, sizeof(buffer));
	if(buffer[0])
	{
		for(int i; ; i++)
		{
			KeyValues kv = FF2_GetSpecialKV(i, 1);
			if(kv == INVALID_HANDLE)
				break;

			static char name[64];
			kv.GetString("name", name, sizeof(name));
			if(StrEqual(buffer, name))
			{
				kv.SetNum("donator", 0);
				kv.SetNum("admin", 0);
				kv.SetNum("owner", 0);
				kv.SetNum("theme", 0);
				kv.SetNum("hidden", 0);
				SPrintToChatAll("%s%s%s is now unlocked for the map duration!", STORE_COLOR2, buffer, STORE_COLOR);
				used = true;
				break;
			}
		}

		if(!used)
			SPrintToChat(client, "%s%s%s is not available right now!", STORE_COLOR2, buffer, STORE_COLOR);
	}

	return used ? Item_Used : Item_None;
}
#endif
