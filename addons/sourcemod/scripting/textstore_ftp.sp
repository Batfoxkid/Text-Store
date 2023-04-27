#pragma semicolon 1

#include <sourcemod>
#include <textstore>
#include <system2>

#pragma newdecls required

#define DEBUG
#define PLUGIN_VERSION	"0.1"

#define DATA_PATH1	"data/textstore"
#define DATA_PATH2	"data/textstore/user"

ConVar CvarFTPUrl;
ConVar CvarFTPPort;
ConVar CvarFTPUser;
ConVar CvarFTPPass;
bool IgnoreLoad;

public Plugin myinfo =
{
	name		=	"The Text Store: FTP",
	author		=	"Batfoxkid",
	description	=	"Text Files from FTP",
	version		=	PLUGIN_VERSION
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("_textstore_saveaddon", _textstore_saveaddon);
	return APLRes_Success;
}

public any _textstore_saveaddon(Handle plugin, int numParams)
{
	return 0;
}

public void OnPluginStart()
{
	/*RegServerCmd("sm_textstore_convert", Command_Convert, "Trasnfer all existing TXT files to SQL");
	RegServerCmd("sm_textstore_import", Command_Import, "Import a TXT file to SQL");
	RegServerCmd("sm_textstore_check", Command_Check, "Checks data given a steamid");
	RegServerCmd("sm_textstore_modify", Command_Modify, "Change data given a steamid");
	*/
	
	CvarFTPUrl = CreateConVar("textstore_ftp_url", "", "FTP url to path (ftp://example.com/textstore)", FCVAR_PROTECTED);
	CvarFTPPort = CreateConVar("textstore_ftp_port", "21", "FTP port", FCVAR_PROTECTED);
	CvarFTPUser = CreateConVar("textstore_ftp_username", "", "FTP username", FCVAR_PROTECTED);
	CvarFTPPass = CreateConVar("textstore_ftp_password", "", "FTP password", FCVAR_PROTECTED);
	
	AutoExecConfig();
}

public Action TextStore_OnClientLoad(int client, char file[PLATFORM_MAX_PATH])
{
	if(IgnoreLoad)
	{
		IgnoreLoad = false;
		return Plugin_Continue;
	}
	
	char ftpurl[PLATFORM_MAX_PATH];
	CvarFTPUrl.GetString(ftpurl, sizeof(ftpurl));
	if(!ftpurl[0])
		return Plugin_Continue;
	
	char buffer1[PLATFORM_MAX_PATH], buffer2[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer2, sizeof(buffer2), NULL_STRING);	// addons/sourcemod/
	if(!StrContains(file, buffer2))
	{
		int size = strlen(buffer2);
		if(!StrContains(file[size], "data"))	// addons/sourcemod/data/
		{
			size += 5;
			if(!StrContains(file[size], "textstore"))	// addons/sourcemod/data/textstore/
				size += 10;
		}
		
		strcopy(buffer1, sizeof(buffer1), file[size]);
	}
	else
	{
		strcopy(buffer1, sizeof(buffer1), file);
	}
	
	ReplaceString(buffer1, sizeof(buffer1), "\\", "/");
	
	#if defined DEBUG
	PrintToServer("TextStore_OnClientLoad::%s/%s", ftpurl, buffer1);
	#endif
	
	int port = 21;
	int pos1 = FindCharInString(ftpurl, '@');
	if(pos1 != -1)
	{
		int pos2 = FindCharInString(ftpurl[pos1], ':');
		if(pos2 != -1)
			port = StringToInt(ftpurl[pos1 + pos2 + 1]);
	}
	
	#if defined DEBUG
	PrintToServer("TextStore_OnClientLoad::Port%d", port);
	#endif
	
	char username[64], password[64];
	CvarFTPUser.GetString(username, sizeof(username));
	CvarFTPPass.GetString(password, sizeof(password));
	
	System2FTPRequest request = new System2FTPRequest(FTPRetreived, "%s/%s", ftpurl, buffer1);
	request.Any = GetClientUserId(client);
	request.SetPort(CvarFTPPort.IntValue);
	request.SetAuthentication(username, password);
	request.SetOutputFile(file);
	request.StartRequest();
	return Plugin_Stop;
}

public void FTPRetreived(bool success, const char[] error, System2FTPRequest request, System2FTPResponse response)
{
	if(!success)
	{
		LogError(error);
	}
	
	int client = GetClientOfUserId(request.Any);
	if(client)
	{
		IgnoreLoad = true;
		TextStore_ClientReload(client);
		IgnoreLoad = false;
	}
}

public void TextStore_OnClientSaved(int client, const char[] file)
{
	char ftpurl[PLATFORM_MAX_PATH];
	CvarFTPUrl.GetString(ftpurl, sizeof(ftpurl));
	if(ftpurl[0])
	{
		char buffer1[PLATFORM_MAX_PATH], buffer2[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, buffer2, sizeof(buffer2), NULL_STRING);	// addons/sourcemod/
		if(!StrContains(file, buffer2))
		{
			int size = strlen(buffer2);
			if(!StrContains(file[size], "data"))	// addons/sourcemod/data/
			{
				size += 5;
				if(!StrContains(file[size], "textstore"))	// addons/sourcemod/data/textstore/
					size += 10;
			}
			
			strcopy(buffer1, sizeof(buffer1), file[size]);
		}
		else
		{
			strcopy(buffer1, sizeof(buffer1), file);
		}
		
		ReplaceString(buffer1, sizeof(buffer1), "\\", "/");
		
		#if defined DEBUG
		PrintToServer("TextStore_OnClientSaved::%s/%s", ftpurl, buffer1);
		#endif
		
		int port = 21;
		int pos1 = FindCharInString(ftpurl, '@');
		if(pos1 != -1)
		{
			int pos2 = FindCharInString(ftpurl[pos1], ':');
			if(pos2 != -1)
				port = StringToInt(ftpurl[pos1 + pos2 + 1]);
		}
		
		#if defined DEBUG
		PrintToServer("TextStore_OnClientSaved::Port%d", port);
		#endif
		
		char username[64], password[64];
		CvarFTPUser.GetString(username, sizeof(username));
		CvarFTPPass.GetString(password, sizeof(password));
		
		System2FTPRequest request = new System2FTPRequest(FTPRetreived, "%s/%s", ftpurl, buffer1);
		request.CreateMissingDirs = true;
		request.SetPort(CvarFTPPort.IntValue);
		request.SetAuthentication(username, password);
		request.SetInputFile(file);
		request.StartRequest();  
	}
}