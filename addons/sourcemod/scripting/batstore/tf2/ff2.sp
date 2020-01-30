#pragma newdecls optional
#undef REQUIRE_PLUGIN
#tryinclude <freak_fortress_2>
#define REQUIRE_PLUGIN
#pragma newdecls required

#if defined _FF2_included
#define ITEM_TF2_FF2	"freak_fortress_2"

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

	// Unlock a boss
	item.GetString("unlock", buffer, sizeof(buffer));
	if(buffer[0])
	{
		for(int i; ; i++)
		{
			KeyValues kv = view_as<KeyValues>(FF2_GetSpecialKV(i, 1));
			if(kv == INVALID_HANDLE)
				break;

			static char boss[64];
			kv.GetString("name", boss, sizeof(boss));
			if(StrEqual(buffer, boss))
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
