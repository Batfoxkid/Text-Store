#if defined _chat_processor_included
#define ITEM_CHAT	"chat"

static char ClientTag[MAXPLAYERS+1][MAXLENGTH_NAME];

ItemResult Chat_Use(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
{
	static char buffer[MAXLENGTH_NAME];
	if(GetFeatureStatus(FeatureType_Native, "ChatProcessor_AddClientTag") != FeatureStatus_Available)
	{
		if(CheckCommandAccess(client, "textstore_dev", ADMFLAG_RCON))
		{
			item.GetString("plugin", buffer, sizeof(buffer));
			SPrintToChat(client, "%s can't find Chat-Processor natives!", buffer);
		}
		else
		{
			SPrintToChat(client, "This can't be used right now!");
		}
		return Item_None;
	}

	bool used;
	item.GetString("nametag", buffer, sizeof(buffer), "X");
	if(!StrEqual(buffer, "X", false))
	{
		used = !ClientChat[client].Tag[0];
		if(!used)
		{
			used = ChatProcessor_RemoveClientTag(client, ClientTag[client]);
			if(used)
				ClientTag[client][0] = 0;
		}

		if(used && buffer[0])
		{
			used = ChatProcessor_AddClientTag(client, buffer);
			if(used)
				strcopy(ClientTag[client], sizeof(ClientTag[]), buffer);
		}
	}

	item.GetString("namecolor", buffer, sizeof(buffer), "X");
	if(!StrEqual(buffer, "X", false))
		used = (ChatProcessor_SetNameColor(client, buffer) || used);

	item.GetString("chatcolor", buffer, sizeof(buffer), "X");
	if(!StrEqual(buffer, "X", false))
		used = (ChatProcessor_SetChatColor(client, buffer) || used);

	return used ? Item_Used : Item_None;
}
#endif
