#define ITEM_CHAT	"chat"

enum struct ClientChatEnum
{
	char Tag[128];
	bool Name;
	bool Text;
}

enum ChatPlugin
{
	Plugin_Unknown = 0,
	Plugin_Drixevel
};

static ClientChatEnum ClientChat[MAXPLAYERS+1];

ItemResult Command_Use(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
{
	ChatPlugin plugin = ChatPlugin();

	static char buffer[128];
	if(plugin == Plugin_Unknown)
	{
		if(CheckCommandAccess(client, "textstore_dev", ADMFLAG_RCON))
		{
			item.GetString("plugin", buffer, sizeof(buffer));
			SPrintToChat(client, "%s can't find any chat processor plugin natives!", buffer);
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
		switch(plugin)
		{
			#if defined _chat_processor_included
			case Plugin_Drixevel:
			{
				bool success = !ClientChat[client].Tag[0];
				if(!success)
				{
					success = ChatProcessor_RemoveClientTag(client, ClientChat[client].Tag);
					if(success)
						ClientChat[client].Tag = 0;
				}

				if(success && buffer[0])
				{
					success = ChatProcessor_AddClientTag(client, buffer);
					if(success)
					{
						strcopy(ClientChat[client].Tag, 128, buffer);
						used = true;
					}
				}
			}
			#endif
		}
	}

	item.GetString("namecolor", buffer, sizeof(buffer), "X");
	if(!StrEqual(buffer, "X", false))
	{
		switch(plugin)
		{
			#if defined _chat_processor_included
			case Plugin_Drixevel:
			{
				bool success = ChatProcessor_SetNameColor(client, buffer);
				used = (success || used);
				Client[client].Name = used;
			}
			#endif
		}
	}

	item.GetString("chatcolor", buffer, sizeof(buffer), "X");
	if(!StrEqual(buffer, "X", false))
	{
		switch(plugin)
		{
			#if defined _chat_processor_included
			case Plugin_Drixevel:
			{
				bool success = ChatProcessor_SetChatColor(client, buffer);
				if(success)
				{
					used = true;
					Client[client].Text = view_as<bool>(buffer[0]);
				}
			}
			#endif
		}
	}
}

static ChatPlugin ChatPlugin()
{
	static ChatPlugin plugin;
	switch(plugin)
	{
		#if defined _chat_processor_included
		case Plugin_Drixevel:
		{
			if(GetFeatureStatus(FeatureType_Native, "ChatProcessor_AddClientTag") == FeatureStatus_Available)
				return plugin;

			plugin = Plugin_Unknown;
			return ChatPlugin();
		}
		#endif
		default:
		{
			#if defined _chat_processor_included
			if(GetFeatureStatus(FeatureType_Native, "ChatProcessor_AddClientTag") == FeatureStatus_Available)
			{
				plugin = Plugin_Drixevel;
				return plugin;
			}
			#endif
		}
	}
	return plugin;
}
