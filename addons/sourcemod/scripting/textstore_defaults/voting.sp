#define ITEM_VOTE	"voting"

char VoteCommand[512];
ArrayList VoteDone;
int VoteCaster;
int VoteIndex;
float VoteMap;

public ItemResult Vote_Use(int client, bool equipped, KeyValues item, int index, const char[] name, int &count)
{
	if(VoteDone!=INVALID_HANDLE && VoteDone.FindValue(index)!=-1)
	{
		SPrintToChat(client, "This has already been casted before!");
		return Item_None;
	}

	if(IsVoteInProgress())
	{
		PrintToChat(client, "[SM] %t", "Vote in Progress");
		return Item_None;
	}

	if(!TestVoteDelay(client))
		return Item_None;

	VoteCaster = GetClientUserId(client);
	VoteIndex = index;

	if(item.GetNum("once"))
	{
		if(VoteDone == INVALID_HANDLE)
			VoteDone = new ArrayList();

		VoteDone.Push(index);
	}

	VoteMap = item.GetFloat("maptime");

	Menu menu = CreateMenu(Vote_UseH, view_as<MenuAction>(MENU_ACTIONS_ALL));
	item.GetString("title", VoteCommand, sizeof(VoteCommand));
	menu.SetTitle(VoteCommand);

	item.GetString("command", VoteCommand, sizeof(VoteCommand));

	menu.AddItem("", "Yes");
	menu.AddItem("", "No");

	menu.ExitButton = false;
	menu.DisplayVoteToAll(20);
	return Item_None;
}

public int Vote_UseH(Menu menu, MenuAction action, int choice, int param)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_VoteCancel:
		{
			int client = GetClientOfUserId(VoteCaster);
			if(IsValidClient(client))
				SPrintToChat(client, "Your item was not used up!");
		}
		case MenuAction_VoteEnd:
		{
			int client = GetClientOfUserId(VoteCaster);
			if(!IsValidClient(client))
				return 0;

			if(choice)
			{
				SPrintToChat(client, "Your item was not used up!");
				return 0;
			}

			int items;
			TextStore_GetInv(client, VoteIndex, items);
			if(items < 1)
				return 0;

			TextStore_SetInv(client, VoteIndex, items-1, items==1 ? 0 : -1);
			if(VoteMap)
			{
				ConVar timelimit = FindConVar("mp_timelimit");
				timelimit.FloatValue = timelimit.FloatValue + VoteMap;
			}
			ServerCommand(VoteCommand);
		}
	}
	return 0;
}

bool TestVoteDelay(int client)
{
 	int delay = CheckVoteDelay();
 	if(delay <= 0)
		return true;
 
	if(delay > 60)
 	{
 		PrintToChat(client, "[SM] %t", "Vote Delay Minutes", delay % 60);
 	}
 	else
 	{
 		PrintToChat(client, "[SM] %t", "Vote Delay Seconds", delay);
 	}
 	return false;
}