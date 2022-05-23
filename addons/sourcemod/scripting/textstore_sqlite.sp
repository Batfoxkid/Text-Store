#pragma semicolon 1

#include <sourcemod>
#include <textstore>

#pragma newdecls required

//#define DEBUG
#define PLUGIN_VERSION	"1.1"

ConVar CvarBackup;
Database DataBase;
bool IgnoreLoad;
ArrayList LastItems[MAXPLAYERS];
ArrayList LastUnique[MAXPLAYERS];

public Plugin myinfo =
{
	name		=	"The Text Store: SQLite",
	author		=	"Batfoxkid",
	description	=	"Text Files to SQLite",
	version		=	PLUGIN_VERSION
};

public void OnPluginStart()
{
	CvarBackup = CreateConVar("textstore_sql_hybrid", "0", "If to also save text files alongside SQL", _, true, 0.0, true, 1.0);
	
	char error[512];
	Database db = SQLite_UseDatabase("textstore", error, sizeof(error));
	if(!db)
		SetFailState(error);
	
	Transaction tr = new Transaction();
	
	tr.AddQuery("CREATE TABLE IF NOT EXISTS misc_data ("
	... "steamid INTEGER PRIMARY KEY, "
	... "cash INTEGER NOT NULL DEFAULT 0);");
	
	tr.AddQuery("CREATE TABLE IF NOT EXISTS common_items ("
	... "steamid INTEGER NOT NULL, "
	... "item TEXT NOT NULL, "
	... "count INTEGER NOT NULL, "
	... "equip INTEGER NOT NULL);");
	
	tr.AddQuery("CREATE TABLE IF NOT EXISTS unique_items ("
	... "steamid INTEGER NOT NULL, "
	... "item TEXT NOT NULL, "
	... "name TEXT NOT NULL, "
	... "equip INTEGER NOT NULL, "
	... "data TEXT NOT NULL);");
	
	db.Execute(tr, Database_SetupSuccess, Database_SetupFail, db);
}

public void Database_SetupSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	#if defined DEBUG
	PrintToServer("Database_SetupSuccess");
	#endif
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(TextStore_GetClientLoad(client))
				TextStore_ClientSave(client);
		}
	}
	
	DataBase = data;
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
			TextStore_ClientReload(client);
	}
}

public void Database_SetupFail(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	SetFailState(error);
}

public Action TextStore_OnClientLoad(int client, char file[PLATFORM_MAX_PATH])
{
	#if defined DEBUG
	PrintToServer("TextStore_OnClientLoad");
	#endif
	
	if(IgnoreLoad)
		return Plugin_Continue;
	
	if(LastItems[client])
	{
		delete LastItems[client];
		LastItems[client] = null;
	}
	
	if(LastUnique[client])
	{
		delete LastUnique[client];
		LastUnique[client] = null;
	}
	
	if(DataBase)
	{
		int id = GetSteamAccountID(client);
		if(!id)
			ThrowError("TextStore_OnClientLoad called but GetSteamAccountID is invalid?");
		
		Transaction tr = new Transaction();
		
		char buffer[256];
		FormatEx(buffer, sizeof(buffer), "SELECT * FROM misc_data WHERE steamid = %d;", id);
		tr.AddQuery(buffer);
		
		FormatEx(buffer, sizeof(buffer), "SELECT * FROM common_items WHERE steamid = %d;", id);
		tr.AddQuery(buffer);
		
		FormatEx(buffer, sizeof(buffer), "SELECT * FROM unique_items WHERE steamid = %d;", id);
		tr.AddQuery(buffer);
		
		DataBase.Execute(tr, Database_ClientSetup, Database_ClientRetry, GetClientUserId(client));
		
		#if defined DEBUG
		PrintToConsole(client, "Started");
		#endif
	}
	else if(CvarBackup.BoolValue)
	{
		return Plugin_Continue;
	}
	
	return Plugin_Stop;
}

public void Database_ClientRetry(Database db, any userid, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	#if defined DEBUG
	PrintToServer("Database_ClientRetry");
	#endif
	
	int client = GetClientOfUserId(userid);
	if(client)
	{
		int id = GetSteamAccountID(client);
		if(id)
		{
			Transaction tr = new Transaction();
			
			char buffer[256];
			FormatEx(buffer, sizeof(buffer), "SELECT * FROM misc_data WHERE steamid = %d;", id);
			tr.AddQuery(buffer);
			
			FormatEx(buffer, sizeof(buffer), "SELECT * FROM common_items WHERE steamid = %d;", id);
			tr.AddQuery(buffer);
			
			FormatEx(buffer, sizeof(buffer), "SELECT * FROM unique_items WHERE steamid = %d;", id);
			tr.AddQuery(buffer);
			
			DataBase.Execute(tr, Database_ClientSetup, Database_ClientRetry, userid);
			
			#if !defined DEBUG
			return;
			#endif
		}
	}
	
	LogError(error);
}

public void Database_ClientSetup(Database db, any userid, int numQueries, DBResultSet[] results, any[] queryData)
{
	#if defined DEBUG
	PrintToServer("Database_ClientSetup");
	#endif
	
	int client = GetClientOfUserId(userid);
	if(client)
	{
		if(LastItems[client])
			delete LastItems[client];
		
		LastItems[client] = new ArrayList();
		
		if(LastUnique[client])
			delete LastUnique[client];
		
		LastUnique[client] = new ArrayList(ByteCountToCells(48));
		
		static char item[48], name[48], data[256];
		if(results[0].FetchRow())
		{
			int cash = results[0].FetchInt(1) - TextStore_Cash(client);
			#if defined DEBUG
			PrintToConsole(client, "Cash = %d", cash);
			#endif
			TextStore_Cash(client, cash);
		}
		else if(!results[0].MoreRows)
		{
			Transaction tr = new Transaction();
			
			Format(data, sizeof(data), "INSERT INTO misc_data (steamid) VALUES (%d)", GetSteamAccountID(client));
			tr.AddQuery(data);
			
			DataBase.Execute(tr, Database_Success, Database_Fail);
			
			#if defined DEBUG
			PrintToConsole(client, "Inserting");
			#endif
			
			IgnoreLoad = true;
			TextStore_ClientReload(client);
			IgnoreLoad = false;
			
			if(TextStore_GetClientLoad(client))
				TextStore_OnClientSave(client, "");
			
			return;
		}
		else
		{
			ThrowError("Unable to fetch first row");
		}
		
		while(results[1].MoreRows)
		{
			if(results[1].FetchRow())
			{
				results[1].FetchString(1, item, sizeof(item));
				
				#if defined DEBUG
				PrintToConsole(client, item);
				#endif
				
				GiveNamedItem(client, item, results[1].FetchInt(2), view_as<bool>(results[1].FetchInt(3)));
			}
		}
		
		while(results[2].MoreRows)
		{
			if(results[2].FetchRow())
			{
				results[2].FetchString(1, item, sizeof(item));
				results[2].FetchString(2, name, sizeof(name));
				results[2].FetchString(4, data, sizeof(data));
				
				#if defined DEBUG
				PrintToConsole(client, "%s | %s | %s", item, name, data);
				#endif
				
				GiveNamedUnique(client, item, name, view_as<bool>(results[2].FetchInt(3)), data);
			}
		}
		
		#if defined DEBUG
		PrintToConsole(client, "Loaded");
		#endif
		
		TextStore_SetClientLoad(client, true);
	}
}

public Action TextStore_OnClientSave(int client, char file[PLATFORM_MAX_PATH])
{
	#if defined DEBUG
	PrintToServer("TextStore_OnClientSave");
	#endif
	
	if(DataBase && LastItems[client])
	{
		int id = GetSteamAccountID(client);
		if(!id)
			ThrowError("TextStore_OnClientSave called but GetSteamAccountID is invalid?");
		
		Transaction tr = new Transaction();
		
		static char buffer[1024];
		Format(buffer, sizeof(buffer), "UPDATE misc_data SET cash = %d WHERE steamid = %d;", TextStore_Cash(client), id);
		tr.AddQuery(buffer);
		
		DataBase.Execute(tr, Database_Success, Database_Fail);
		
		tr = new Transaction();
		
		ArrayList list = new ArrayList();
		
		int amount;
		int uniques;
		int items = TextStore_GetItems(uniques);
		for(int i; i<items; i++)
		{
			bool equipped = TextStore_GetInv(client, i, amount);
			if(LastItems[client].FindValue(i) == -1)
			{
				if(amount > 0)
				{
					TextStore_GetItemName(i, buffer, sizeof(buffer));
					DataBase.Format(buffer, sizeof(buffer), "INSERT INTO common_items (steamid, item, count, equip) VALUES ('%d', '%s', '%d', '%d')", id, buffer, amount, equipped);
					
					#if defined DEBUG
					PrintToConsole(client, buffer);
					#endif
					
					tr.AddQuery(buffer);
					list.Push(i);
				}
			}
			else if(amount > 0)
			{
				TextStore_GetItemName(i, buffer, sizeof(buffer));
				DataBase.Format(buffer, sizeof(buffer), "UPDATE common_items SET count = '%d', equip = '%d' WHERE steamid = %d AND item = '%s';", amount, equipped, id, buffer);
				
				#if defined DEBUG
				PrintToConsole(client, buffer);
				#endif
				
				tr.AddQuery(buffer);
				list.Push(i);
			}
			else
			{
				TextStore_GetItemName(i, buffer, sizeof(buffer));
				DataBase.Format(buffer, sizeof(buffer), "DELETE FROM common_items WHERE steamid = %d AND item = '%s';", id, buffer);
				
				#if defined DEBUG
				PrintToConsole(client, buffer);
				#endif
				
				tr.AddQuery(buffer);
			}
		}
		
		DataBase.Execute(tr, Database_Success, Database_Fail);
		
		delete LastItems[client];
		LastItems[client] = list;
		
		if(uniques)
		{
			tr = new Transaction();
			
			uniques = -uniques;
			
			if(LastUnique[client])
			{
				int length = LastUnique[client].Length;
				for(int i; i<length; i++)
				{
					LastUnique[client].GetString(i, buffer, sizeof(buffer));
					DataBase.Format(buffer, sizeof(buffer), "DELETE FROM unique_items WHERE steamid = %d AND item = '%s';", id, buffer);
					
					#if defined DEBUG
					PrintToConsole(client, buffer);
					#endif
					
					tr.AddQuery(buffer);
				}
				
				delete LastUnique[client];
			}
			else
			{
				FormatEx(buffer, sizeof(buffer), "DELETE FROM unique_items WHERE steamid = %d;", id);
				
				#if defined DEBUG
				PrintToConsole(client, buffer);
				#endif
				
				tr.AddQuery(buffer);
			}
			
			LastUnique[client] = new ArrayList(ByteCountToCells(48));
			
			char item[48], name[48];
			for(int i=-1; i>=uniques; i--)
			{
				bool equipped = TextStore_GetInv(client, i, amount);
				if(amount)
				{
					if(TextStore_GetItemKv(i).GetSectionName(item, sizeof(item)))
					{
						TextStore_GetItemName(i, name, sizeof(name));
						if(StrEqual(name, item, false))
							name[0] = 0;
						
						TextStore_GetItemData(i, buffer, sizeof(buffer));
						
						DataBase.Format(buffer, sizeof(buffer), "INSERT INTO unique_items (steamid, item, name, equip, data) VALUES ('%d', '%s', '%s', '%d', '%s')", id, item, name, equipped, buffer);
						
						#if defined DEBUG
						PrintToConsole(client, buffer);
						#endif
						
						tr.AddQuery(buffer);
						
						LastUnique[client].PushString(buffer);
					}
					else
					{
						LogError("KeyValues.GetSectionName failed with unique item");
					}
				}
			}
			
			DataBase.Execute(tr, Database_Success, Database_Fail);
		}
		
		if(!CvarBackup.BoolValue)
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void Database_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	#if defined DEBUG
	PrintToServer("Database_Success");
	#endif
}

public void Database_Fail(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	#if defined DEBUG
	PrintToServer("Database_Fail");
	#endif
	
	LogError(error);
}

void GiveNamedItem(int client, const char[] item, int amount, bool equipped)
{
	#if defined DEBUG
	PrintToServer("GiveNamedItem");
	#endif
	
	int items = TextStore_GetItems();
	for(int i; i<items; i++)
	{
		static char buffer[48];
		TextStore_GetItemName(i, buffer, sizeof(buffer));
		if(StrEqual(item, buffer, false))
		{
			TextStore_SetInv(client, i, amount, false);
			if(equipped)
				TextStore_UseItem(client, i, true);
			
			LastItems[client].Push(i);
			break;
		}
	}
}

void GiveNamedUnique(int client, const char[] item, const char[] name, bool equipped, const char[] data)
{
	#if defined DEBUG
	PrintToServer("GiveNamedUnique");
	#endif
	
	int items = TextStore_GetItems();
	for(int i; i<items; i++)
	{
		static char buffer[48];
		TextStore_GetItemName(i, buffer, sizeof(buffer));
		if(StrEqual(item, buffer, false))
		{
			int id = TextStore_CreateUniqueItem(client, i, data, name, false);
			if(equipped)
				TextStore_UseItem(client, id, true);
			
			if(LastUnique[client].FindString(buffer) == -1)
				LastUnique[client].PushString(buffer);
			
			break;
		}
	}
}

#file "Text Store: SQLite"