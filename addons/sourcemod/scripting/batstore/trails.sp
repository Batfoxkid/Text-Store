#define ITEM_TRAIL	"trail"
enum struct TrailEnum
{
	char Path[MAX_MATERIAL_LENGTH];
	int Color[4];
	float Width;
	int Precache;
	int Entity;

	int Setup(const char[] material, float width, int color[4])
	{
		this.Width = width;
		this.Color[0] = color[0];
		this.Color[1] = color[1];
		this.Color[2] = color[2];
		this.Color[3] = color[3];
		strcopy(this.Path, MAX_MATERIAL_LENGTH, material);
		this.Precache = PrecacheModel(material);
		if(!this.Precache)
			this.Path[0] = 0;

		return this.Precache;
	}

	void Clear()
	{
		this.Path[0] = 0;
	}
}
TrailEnum Trail[MAXPLAYERS+1];
int TrailOwner[2048];

public void Trail_Create(int userid)
{
	int client = GetClientOfUserId(userid);
	if(!IsValidClient(client))
		return;

	if(!Trail[client].Path[0])
		return;

	if(GameType == Engine_CSGO)
	{
		if(!Trail[client].Entity || !IsValidEdict(Trail[client].Entity))
		{
			Trail[client].Entity = CreateEntityByName("env_sprite");
			DispatchKeyValue(Trail[client].Entity, "classname", "env_sprite");
			DispatchKeyValue(Trail[client].Entity, "spawnflags", "1");
			DispatchKeyValue(Trail[client].Entity, "scale", "0.0");
			DispatchKeyValue(Trail[client].Entity, "rendermode", "10");
			DispatchKeyValue(Trail[client].Entity, "rendercolor", "255 255 255 0");
			DispatchKeyValue(Trail[client].Entity, "model", Trail[client].Precache);
			DispatchSpawn(Trail[client].Entity);
			Trail_Attach(Trail[client].Entity, client);
			SDKHook(entity, SDKHook_SetTransmit, Trail_Transmit);
		}

		int color[4];
		color[0] = Trail[client].Color[0];
		color[1] = Trail[client].Color[1];
		color[2] = Trail[client].Color[2];
		color[3] = Trail[client].Color[3];
		TE_SetupBeamFollow(Trail[client].Entity, Trail[client].Precache, 0, 0.8, Trail[client].Width, Trail[client].Width, 10, color);
		TE_SendToAll();
		return;
	}

	Trail[client].Entity  = CreateEntityByName("env_spritetrail");
	SetEntPropFloat(Trail[client].Entity, Prop_Send, "m_flTextureRes", 0.05);

	char temp[17];
	FormatEx(temp, sizeof(temp), "%i %i %i %i", Trail[client].Color[0], Trail[client].Color[1], Trail[client].Color[2], Trail[client].Color[3]);
	DispatchKeyValue(Trail[client].Entity, "renderamt", "255");
	DispatchKeyValue(Trail[client].Entity, "rendercolor", temp);
	DispatchKeyValue(Trail[client].Entity, "lifetime", "0.8");
	DispatchKeyValue(Trail[client].Entity, "rendermode", "5");
	DispatchKeyValue(Trail[client].Entity, "spritename", Trail[client].Path);

	FloatToString(Trail[client].Width, temp, sizeof(temp));
	DispatchKeyValue(Trail[client].Entity, "startwidth", temp);
	DispatchKeyValue(Trail[client].Entity, "endwidth", temp);

	DispatchSpawn(Trail[client].Entity);
	Trail_Attach(Trail[client].Entity, client);

	SDKHook(entity, SDKHook_SetTransmit, Trail_Transmit);
	TrailOwner[entity] = client;
}

public void Trail_Remove(int client)
{
	if(Trail[client].Entity && IsValidEdict(Trail[client].Entity))
	{
		TrailOwner[Trail[client].Entity] = 0;
		static char classname[64];
		GetEdictClassname(Trail[client].Entity, classname);
		if(StrEqual("env_spritetrail", classname))
		{
			SDKUnhook(Trail[client].Entity, SDKHook_SetTransmit, Trail_Transmit);
			AcceptEntityInput(Trail[client].Entity, "Kill");
		}
	}
	Trail[client].Entity = 0;
}

public void Trail_Attach(int entity, int client)
{
	static float org[3], ang[3];
	static float temp[3] = {0.0, 90.0, 0.0};
	static float pos[3] = {0.0, 0.0, 5.0};
	GetEntPropVector(client, Prop_Data, "m_angAbsRotation", ang);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", tmp);
	GetClientAbsOrigin(client, org);
	AddVectors(org, pos, org);
	TeleportEntity(entity, org, temp, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client, entity);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", ang);
}

public Action Trail_Transmit(int entity, int client)
{
	if(!IsValidClient(TrailOwner[entity]))
		return Plugin_Handled;

	if(!IsPlayerAlive(TrailOwner[entity]))
		return Plugin_Handled;

	if(GameType != Engine_TF2)
		return Plugin_Continue;

	return (TF2_GetClientTeam(TrailOwner[entity])!=TF2_GetClientTeam(client) && (TF2_IsPlayerInCondition(TrailOwner[entity], TFCond_Cloaked) || TF2_IsPlayerInCondition(TrailOwner[entity], TFCond_Stealthed))) ? Plugin_Handled : Plugin_Continue;
}
