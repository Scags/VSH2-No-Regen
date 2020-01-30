#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <vsh2>
#include <tf2_stocks>

public Plugin myinfo =  {
	name = "[VSH 2] No-Regen", 
	author = "Scag/Ragenewb", 
	description = "Prevent Medic hp regen for bosses", 
	version = "1.0.0", 
	url = ""
};

ConVar
	bEnabled,
	hNoHeals_Medic,
	hNoHeals_Dispenser
;

public void OnPluginStart()
{
	bEnabled = CreateConVar("sm_noregen_enable", "1.0", "Enable the VSH2 No-Regen plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hNoHeals_Medic = CreateConVar("sm_noregen_medics", "0", "Should Medics on a Boss' team be able to heal a boss?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hNoHeals_Dispenser = CreateConVar("sm_noregen_dispensers", "0", "Should Dispensers on a Boss' team be able to heal a boss?", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	GameData conf = new GameData("tf2.vsh2_noregen");
	if (!conf)
		SetFailState("Could not find Gamedata for plugin! Please verify its existence.");

	Handle hook = DHookCreateDetourEx(conf, "CTFPlayer::RegenThink", CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	if (!hook || !DHookEnableDetour(hook, false, CTFPlayer_RegenThink))
		SetFailState("Could not load detour for CTFPlayer::RegenThink.");

	hook = DHookCreateDetourEx(conf, "CWeaponMedigun::AllowedToHealTarget", CallConv_THISCALL, ReturnType_Bool, ThisPointer_CBaseEntity);
	if (!hook)
		SetFailState("Could not load detour for CWeaponMedigun::AllowedToHealTarget.");

	DHookAddParam(hook, HookParamType_CBaseEntity);
	if (!DHookEnableDetour(hook, false, CWeaponMedigun_AllowedToHealTarget))
		SetFailState("Could not load detour for CWeaponMedigun::AllowedToHealTarget.");

	hook = DHookCreateDetourEx(conf, "CObjectDispenser::CouldHealTarget", CallConv_THISCALL, ReturnType_Bool, ThisPointer_CBaseEntity);
	if (!hook)
		SetFailState("Could not load detour for CObjectDispenser::CouldHealTarget.");

	DHookAddParam(hook, HookParamType_CBaseEntity);
	if (!DHookEnableDetour(hook, false, CObjectDispenser_CouldHealTarget))
		SetFailState("Could not load detour for CObjectDispenser::CouldHealTarget.");

	delete conf;

	AutoExecConfig(true, "VSH2_NoRegen");
}

// The only other 'regens' are from attributes (metal, ammo, health)
// These are attributes that *probably* shouldn't be set onto bosses
public MRESReturn CTFPlayer_RegenThink(int pThis)
{
	if (!bEnabled.BoolValue)
		return MRES_Ignored;

	if (TF2_GetPlayerClass(pThis) != TFClass_Medic)		// Close enough assertion
		return MRES_Ignored;

	return VSH2Player(pThis).GetPropAny("bIsBoss") ? MRES_Supercede : MRES_Ignored;
}

public MRESReturn CObjectDispenser_CouldHealTarget(int pThis, Handle hReturn, Handle hParams)
{
	if (!hNoHeals_Dispenser.BoolValue)
		return _HealTarget(pThis, hReturn, hParams);
	return MRES_Ignored
}

public MRESReturn CWeaponMedigun_AllowedToHealTarget(int pThis, Handle hReturn, Handle hParams)
{
	if (!hNoHeals_Medic.BoolValue)
		return _HealTarget(pThis, hReturn, hParams);
	return MRES_Ignored
}

public MRESReturn _HealTarget(int pThis, Handle hReturn, Handle hParams)
{
	if (!bEnabled.BoolValue)
		return MRES_Ignored;

	int target = DHookGetParam(hParams, 1);
	if (!(0 < target <= MaxClients))
		return MRES_Ignored;

	if (GetEntProp(pThis, Prop_Send, "m_iTeamNum") == GetClientTeam(target) && VSH2Player(target).GetPropAny("bIsBoss"))	// Team check seems redundant but it doesn't hurt
	{
		DHookSetReturn(hReturn, false);
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

stock Handle DHookCreateDetourEx(GameData conf, const char[] name, CallingConvention callConv, ReturnType returntype, ThisPointerType thisType)
{
	Handle h = DHookCreateDetour(Address_Null, callConv, returntype, thisType);
	if (h)
		DHookSetFromConf(h, conf, SDKConf_Signature, name);
	return h;
}