#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

//#define DEBUG

ArrayList ArrayWeapon;

ConVar g_Cvar_Enable;

bool bLoaded = false;
bool bEnabled;

public Plugin myinfo =
{
	name = "[CSGO] Change Weapon Fire Rate",
	author = "Oylsister, Special Thanks to inklesspen",
	version = "1.0",
	url = "https://github.com/oylsister/CSGO-Weapon-Fire-Rate, https://forums.alliedmods.net/showthread.php?t=299481"
};

public void OnPluginStart()
{
    HookEvent("weapon_fire", WeaponFire);

    g_Cvar_Enable = CreateConVar("sm_custom_firerate_enable", "1.0", "Enable this plugin or not", _, true, 0.0, true , 1.0);

    HookConVarChange(g_Cvar_Enable, OnEnableChanged);
}

public void OnEnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    bEnabled = g_Cvar_Enable.BoolValue;
}

public void OnMapStart()
{
    LoadConfig();

    bEnabled = g_Cvar_Enable.BoolValue;
}

void LoadConfig()
{
    KeyValues kv = CreateKeyValues("weapons");

    char path[PLATFORM_MAX_PATH];

    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/rate_of_fire.txt");

    if(!FileExists(path))
    {
        SetFailState("Can't not find config \"%s\" file", path);
        bLoaded = false;
        return;
    }

    bLoaded = true;

    FileToKeyValues(kv, path);

    ArrayWeapon = new ArrayList();

    if(kv.GotoFirstSubKey())
    {
        do
        {
            StringMap g_WeaponData = new StringMap();

            char weaponentity[48];
            kv.GetSectionName(weaponentity, sizeof(weaponentity));
            g_WeaponData.SetString("sEntity", weaponentity);

            float fDefaultRate = kv.GetFloat("default_rate", -1.0);
            g_WeaponData.SetValue("fDefault", fDefaultRate);

            float fNewRate = kv.GetFloat("rate_of_fire", -1.0);
            g_WeaponData.SetValue("fRateOfFire", fNewRate);

            ArrayWeapon.Push(g_WeaponData);
        }
        while(kv.GotoNextKey());
    }
    delete kv;
}

public void WeaponFire(Event event, char[] name, bool dbc)
{
    if(bLoaded && bEnabled)
        RequestFrame(FirePostFrame, event.GetInt("userid"));
}

public void FirePostFrame(int userid)
{
    int client = GetClientOfUserId(userid);

    if(!client)
        return;

    int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
    float curtime = GetGameTime();
    float nexttime = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");

    char weaponname[32];

    int iItemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
    CS_WeaponIDToAlias(CS_ItemDefIndexToID(iItemDefIndex), weaponname, sizeof(weaponname)); 

    #if defined DEBUG
    float rate_of_fire;
    rate_of_fire = nexttime - curtime;
    #endif

    Format(weaponname, sizeof(weaponname), "weapon_%s", weaponname);
    float multiply = GetRateMultiply(weaponname);

    nexttime -= curtime;
    nexttime *= 1.0/multiply;

    #if defined DEBUG
    rate_of_fire = nexttime;
    #endif

    nexttime += curtime;

    SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", nexttime);
    SetEntPropFloat(client, Prop_Send, "m_flNextAttack", 0.0);

    #if defined DEBUG
    PrintToChat(client, "%s: %d and %0.4f", weaponname,  RoundToNearest(60.0 / rate_of_fire), rate_of_fire);
    #endif
} 

float GetRateMultiply(const char[] weaponentity)
{
    for(int i = 0; i < ArrayWeapon.Length; i++)
    {
        StringMap g_WeaponData = ArrayWeapon.Get(i);

        char sEntity[48];
        g_WeaponData.GetString("sEntity", sEntity, sizeof(sEntity));

        if(StrEqual(sEntity, weaponentity, false))
        {
            float fDefault;
            g_WeaponData.GetValue("fDefault", fDefault);

            float actualDefault = 60.0 / fDefault;

            float fNewRate;
            g_WeaponData.GetValue("fRateOfFire", fNewRate);

            float actualNewRate = 60.0 / fNewRate;

            return actualDefault / actualNewRate;
        }
    }

    return 1.0;
}