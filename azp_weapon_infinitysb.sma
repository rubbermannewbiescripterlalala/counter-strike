#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>
#include <cstrike>
#include <zombieplague>

#define ENG_NULLENT			-1
#define EV_INT_WEAPONKEY	EV_INT_impulse
#define infinib_WEAPONKEY 	823
#define MAX_PLAYERS  		32
#define IsValidUser(%1) (1 <= %1 <= g_MaxPlayers)

const USE_STOPPED = 0
const OFFSET_ACTIVE_ITEM = 373
const OFFSET_WEAPONOWNER = 41
const OFFSET_LINUX = 5
const OFFSET_LINUX_WEAPONS = 4

#define WEAP_LINUX_XTRA_OFF		4

#define m_pPlayer                			41
#define m_fKnown					44
#define m_flNextPrimaryAttack 		46
#define m_flNextSecondaryAttack 		47
#define m_flTimeWeaponIdle			48
#define m_iClip					51
#define m_fInReload				54
#define PLAYER_LINUX_XTRA_OFF	5
#define m_flNextAttack				83

#define infinib_RELOAD_TIME 	2.8

#define infinib_IDLE			0
#define infinib_SHOOT1			1
#define infinib_SHOOT2			2
#define infinib_SHOOT_EMPTY	3
#define infinib_RELOAD			4
#define infinib_DRAW			5

#define write_coord_f(%1)	engfunc(EngFunc_WriteCoord,%1)

new const Fire_Sounds[][] = { "weapons/infi.wav" }

new infinib_V_MODEL[64] = "models/zm/v_infinitysb.mdl"
new infinib_P_MODEL[64] = "models/zm/p_infinitysb.mdl"
new infinib_W_MODEL[64] = "models/zm/w_infinitysb.mdl"

new const GUNSHOT_DECALS[] = { 41, 42, 43, 44, 45 }

new cvar_dmg_infinib, cvar_recoil_infinib, g_itemid_infinib, cvar_clip_infinib, cvar_spd_infinib, cvar_infinib_ammo
new g_MaxPlayers, g_orig_event_infinib, g_IsInPrimaryAttack, g_iClip
new Float:cl_pushangle[MAX_PLAYERS + 1][3], m_iBlood[2]
new g_has_infinib[33], g_clip_ammo[33], g_infinib_TmpClip[33], oldweap[33]
new gmsgWeaponList

const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10", "weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550", "weapon_deagle", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
"weapon_ak47", "weapon_knife", "weapon_p90" }

public plugin_init()
{
	register_plugin("[ZP] Extra: Infinitys Black", "1.0", "Crock / =) (Poprogun4ik) / LARS-BLOODLIKER")
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	register_event("CurWeapon","CurrentWeapon","be","1=1")
	RegisterHam(Ham_Item_AddToPlayer, "weapon_usp", "fw_infinib_AddToPlayer")
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)
	for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
	if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_usp", "fw_infinib_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_usp", "fw_infinib_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_usp", "fw_infinib_SecondaryAttack")
	RegisterHam(Ham_Weapon_WeaponIdle, "weapon_usp", "fw_infinib_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_PostFrame, "weapon_usp", "infinib_ItemPostFrame")
	RegisterHam(Ham_Weapon_Reload, "weapon_usp", "infinib_Reload")
	RegisterHam(Ham_Weapon_Reload, "weapon_usp", "infinib_Reload_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fwPlaybackEvent")
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack", 1)

	cvar_dmg_infinib = register_cvar("zp_infinib_dmg", "1.26")
	cvar_recoil_infinib = register_cvar("zp_infinib_recoil", "1.0")
	cvar_clip_infinib = register_cvar("zp_infinib_clip", "8")
	cvar_spd_infinib = register_cvar("zp_infinib_spd", "0.98")
	cvar_infinib_ammo = register_cvar("zp_infinib_ammo", "200")

	g_itemid_infinib = zp_register_extra_item("[Pistol] Infinity Black", 5, ZP_TEAM_HUMAN)
	g_MaxPlayers = get_maxplayers()
	gmsgWeaponList = get_user_msgid("WeaponList")
}

public plugin_precache()
{
	precache_model(infinib_V_MODEL)
	precache_model(infinib_P_MODEL)
	precache_model(infinib_W_MODEL)
	for(new i = 0; i < sizeof Fire_Sounds; i++)
	precache_sound(Fire_Sounds[i])	
	precache_sound("weapons/infis_foley1.wav")
	precache_sound("weapons/infis_foley1.wav")
	precache_sound("weapons/infis_clipin.wav")
	precache_sound("weapons/infis_clipout.wav")
	precache_sound("weapons/infis_draw.wav")
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")
	precache_generic("sprites/weapon_infinitysb.txt")
   	precache_generic("sprites/zm/640hud47.spr")
    	precache_generic("sprites/zm/640hud48.spr")
   	precache_generic("sprites/zm/640hud7.spr")
	
        register_clcmd("weapon_infinitysb", "weapon_hook")	

	register_forward(FM_PrecacheEvent, "fwPrecacheEvent_Post", 1)
}

public weapon_hook(id)
{
    engclient_cmd(id, "weapon_usp")
    return PLUGIN_HANDLED
}

public fw_TraceAttack(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_alive(iAttacker))
		return

	new g_currentweapon = get_user_weapon(iAttacker)

	if(g_currentweapon != CSW_USP) return
	
	if(!g_has_infinib[iAttacker]) return

	static Float:flEnd[3]
	get_tr2(ptr, TR_vecEndPos, flEnd)
	
	if(iEnt)
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_DECAL)
		write_coord_f(flEnd[0])
		write_coord_f(flEnd[1])
		write_coord_f(flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		write_short(iEnt)
		message_end()
	}
	else
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		write_coord_f(flEnd[0])
		write_coord_f(flEnd[1])
		write_coord_f(flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		message_end()
	}
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_GUNSHOTDECAL)
	write_coord_f(flEnd[0])
	write_coord_f(flEnd[1])
	write_coord_f(flEnd[2])
	write_short(iAttacker)
	write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
	message_end()
}

public zp_user_humanized_post(id)
{
	g_has_infinib[id] = false
}

public plugin_natives ()
{
	register_native("give_weapon_infinib", "native_give_weapon_add", 1)
}
public native_give_weapon_add(id)
{
	give_infinib(id)
}

public fwPrecacheEvent_Post(type, const name[])
{
	if (equal("events/usp.sc", name))
	{
		g_orig_event_infinib = get_orig_retval()
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public client_connect(id)
{
	g_has_infinib[id] = false
}

public client_disconnect(id)
{
	g_has_infinib[id] = false
}

public zp_user_infected_post(id)
{
	if (zp_get_user_zombie(id))
	{
		g_has_infinib[id] = false
	}
}

public fw_SetModel(entity, model[])
{
	if(!is_valid_ent(entity))
		return FMRES_IGNORED
	
	static szClassName[33]
	entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
		
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	
	if(equal(model, "models/w_usp.mdl"))
	{
		static iStoredAugID
		
		iStoredAugID = find_ent_by_owner(ENG_NULLENT, "weapon_usp", entity)
	
		if(!is_valid_ent(iStoredAugID))
			return FMRES_IGNORED
	
		if(g_has_infinib[iOwner])
		{
			entity_set_int(iStoredAugID, EV_INT_WEAPONKEY, infinib_WEAPONKEY)
			
			g_has_infinib[iOwner] = false
			
			entity_set_model(entity, infinib_W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public give_infinib(id)
{
	drop_weapons(id, 2)
	new iWep2 = give_item(id,"weapon_usp")
	if( iWep2 > 0 )
	{
		cs_set_weapon_ammo(iWep2, get_pcvar_num(cvar_clip_infinib))
		cs_set_user_bpammo (id, CSW_USP, get_pcvar_num(cvar_infinib_ammo))	
		UTIL_PlayWeaponAnimation(id, infinib_DRAW)
		set_pdata_float(id, m_flNextAttack, 1.0, PLAYER_LINUX_XTRA_OFF)

		message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
		write_string("weapon_infinitysb")
		write_byte(6)
		write_byte(100)
		write_byte(-1)
		write_byte(-1)
		write_byte(1)
		write_byte(4)
		write_byte(CSW_USP)
		message_end()
	}
	g_has_infinib[id] = true
}

public zp_extra_item_selected(id, itemid)
{
	if(itemid != g_itemid_infinib)
		return

	give_infinib(id)
}

public fw_infinib_AddToPlayer(infinib, id)
{
	if(!is_valid_ent(infinib) || !is_user_connected(id))
		return HAM_IGNORED
	
	if(entity_get_int(infinib, EV_INT_WEAPONKEY) == infinib_WEAPONKEY)
	{
		g_has_infinib[id] = true
		
		entity_set_int(infinib, EV_INT_WEAPONKEY, 0)

		message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
		write_string("weapon_infinitysb")
		write_byte(6)
		write_byte(100)
		write_byte(-1)
		write_byte(-1)
		write_byte(1)
		write_byte(4)
		write_byte(CSW_USP)
		message_end()
		
		return HAM_HANDLED
	}
	else
	{
		message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
		write_string("weapon_usp")
		write_byte(6)
		write_byte(100)
		write_byte(-1)
		write_byte(-1)
		write_byte(1)
		write_byte(4)
		write_byte(CSW_USP)
		message_end()
	}
	return HAM_IGNORED
}

public fw_UseStationary_Post(entity, caller, activator, use_type)
{
	if (use_type == USE_STOPPED && is_user_connected(caller))
		replace_weapon_models(caller, get_user_weapon(caller))
}

public fw_Item_Deploy_Post(weapon_ent)
{
	static owner
	owner = fm_cs_get_weapon_ent_owner(weapon_ent)
	
	static weaponid
	weaponid = cs_get_weapon_id(weapon_ent)
	
	replace_weapon_models(owner, weaponid)
}

public CurrentWeapon(id)
{
     replace_weapon_models(id, read_data(2))

     if(read_data(2) != CSW_USP || !g_has_infinib[id])
          return
     
     static Float:iSpeed
     if(g_has_infinib[id])
          iSpeed = get_pcvar_float(cvar_spd_infinib)
     
     static weapon[32],Ent
     get_weaponname(read_data(2),weapon,31)
     Ent = find_ent_by_owner(-1,weapon,id)
     if(Ent)
     {
          static Float:Delay
          Delay = get_pdata_float( Ent, 46, 4) * iSpeed
          if (Delay > 0.0)
          {
               set_pdata_float(Ent, 46, Delay, 4)
          }
     }
}

replace_weapon_models(id, weaponid)
{
	switch (weaponid)
	{
		case CSW_USP:
		{
			if (zp_get_user_zombie(id) || zp_get_user_survivor(id))
				return
			
			if(g_has_infinib[id])
			{
				set_pev(id, pev_viewmodel2, infinib_V_MODEL)
				set_pev(id, pev_weaponmodel2, infinib_P_MODEL)
				if(oldweap[id] != CSW_USP) 
				{
					UTIL_PlayWeaponAnimation(id, infinib_DRAW)
					set_pdata_float(id, m_flNextAttack, 1.0, PLAYER_LINUX_XTRA_OFF)

					message_begin(MSG_ONE, gmsgWeaponList, {0,0,0}, id)
					write_string("weapon_infinitysb")
					write_byte(6)
					write_byte(100)
					write_byte(-1)
					write_byte(-1)
					write_byte(1)
					write_byte(4)
					write_byte(CSW_USP)
					message_end()
				}
			}
		}
	}
	oldweap[id] = weaponid
}

public fw_UpdateClientData_Post(Player, SendWeapons, CD_Handle)
{
	if(!is_user_alive(Player) || (get_user_weapon(Player) != CSW_USP || !g_has_infinib[Player]))
		return FMRES_IGNORED
	
	set_cd(CD_Handle, CD_flNextAttack, halflife_time () + 0.001)
	return FMRES_HANDLED
}

public fw_infinib_PrimaryAttack(Weapon)
{
	new Player = get_pdata_cbase(Weapon, 41, 4)
	
	if (!g_has_infinib[Player])
		return
	
	g_IsInPrimaryAttack = 1
	pev(Player,pev_punchangle,cl_pushangle[Player])
	
	g_clip_ammo[Player] = cs_get_weapon_ammo(Weapon)
	g_iClip = cs_get_weapon_ammo(Weapon)
}

public fwPlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if ((eventid != g_orig_event_infinib) || !g_IsInPrimaryAttack)
		return FMRES_IGNORED
	if (!(1 <= invoker <= g_MaxPlayers))
    return FMRES_IGNORED

	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_SUPERCEDE
}

public fw_infinib_PrimaryAttack_Post(Weapon)
{
	g_IsInPrimaryAttack = 0
	new Player = get_pdata_cbase(Weapon, 41, 4)
	
	new szClip, szAmmo
	get_user_weapon(Player, szClip, szAmmo)
	
	if(!is_user_alive(Player))
		return

	if (g_iClip <= cs_get_weapon_ammo(Weapon))
		return

	if(g_has_infinib[Player])
	{
		if (!g_clip_ammo[Player])
			return

		new Float:push[3]
		pev(Player,pev_punchangle,push)
		xs_vec_sub(push,cl_pushangle[Player],push)
		
		xs_vec_mul_scalar(push,get_pcvar_float(cvar_recoil_infinib),push)
		xs_vec_add(push,cl_pushangle[Player],push)
		set_pev(Player,pev_punchangle,push)
		
		emit_sound(Player, CHAN_WEAPON, Fire_Sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		if(szClip > 1)  UTIL_PlayWeaponAnimation(Player, random_num(infinib_SHOOT1,infinib_SHOOT2))
		if(szClip == 1) UTIL_PlayWeaponAnimation(Player, infinib_SHOOT_EMPTY)	
	}
}

public fw_infinib_SecondaryAttack(weapon)
{
   new id = get_pdata_cbase(weapon, 41, 4)

   if(g_has_infinib[id])
      return HAM_SUPERCEDE

   return HAM_IGNORED
}

public fw_infinib_WeaponIdle_Post(weapon)
{
	if(!pev_valid(weapon))
		return HAM_IGNORED

	new id = get_pdata_cbase(weapon, m_pPlayer, 4)

	if(!g_has_infinib[id])
		return HAM_SUPERCEDE

	new Float:get_idle = get_pdata_float(weapon, m_flTimeWeaponIdle)

	if(get_idle > 10.0)
	{
		UTIL_PlayWeaponAnimation(id, infinib_IDLE)
	}
	return HAM_IGNORED
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if (victim != attacker && is_user_connected(attacker))
	{
		if(get_user_weapon(attacker) == CSW_USP)
		{
			if(g_has_infinib[attacker])
				SetHamParamFloat(4, damage * get_pcvar_float(cvar_dmg_infinib))
		}
	}
}

public message_DeathMsg(msg_id, msg_dest, id)
{
	static szTruncatedWeapon[33], iAttacker, iVictim
	
	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))
	
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
	
	if(!is_user_connected(iAttacker) || iAttacker == iVictim)
		return PLUGIN_CONTINUE
	
	if(equal(szTruncatedWeapon, "usp") && get_user_weapon(iAttacker) == CSW_USP)
	{
		if(g_has_infinib[iAttacker])
			set_msg_arg_string(4, "usp")
	}
	return PLUGIN_CONTINUE
}

stock fm_cs_get_current_weapon_ent(id)
{
	return get_pdata_cbase(id, OFFSET_ACTIVE_ITEM, OFFSET_LINUX)
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS)
}

stock UTIL_PlayWeaponAnimation(const Player, const Sequence)
{
	set_pev(Player, pev_weaponanim, Sequence)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(pev(Player, pev_body))
	message_end()
}

public infinib_ItemPostFrame(weapon_entity) 
{
     new id = pev(weapon_entity, pev_owner)
     if (!is_user_connected(id))
          return HAM_IGNORED

     if (!g_has_infinib[id])
          return HAM_IGNORED

     static iClipExtra
     
     iClipExtra = get_pcvar_num(cvar_clip_infinib)
     new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, PLAYER_LINUX_XTRA_OFF)

     new iBpAmmo = cs_get_user_bpammo(id, CSW_USP)
     new iClip = get_pdata_int(weapon_entity, m_iClip, WEAP_LINUX_XTRA_OFF)

     new fInReload = get_pdata_int(weapon_entity, m_fInReload, WEAP_LINUX_XTRA_OFF) 

     if( fInReload && flNextAttack <= 0.0 )
     {
	     new j = min(iClipExtra - iClip, iBpAmmo)
	
	     set_pdata_int(weapon_entity, m_iClip, iClip + j, WEAP_LINUX_XTRA_OFF)
	     cs_set_user_bpammo(id, CSW_USP, iBpAmmo-j)
		
	     set_pdata_int(weapon_entity, m_fInReload, 0, WEAP_LINUX_XTRA_OFF)
	     fInReload = 0
     }
     return HAM_IGNORED
}

public infinib_Reload(weapon_entity) 
{
     new id = pev(weapon_entity, pev_owner)
     if (!is_user_connected(id))
          return HAM_IGNORED

     if (!g_has_infinib[id])
          return HAM_IGNORED

     static iClipExtra

     if(g_has_infinib[id])
          iClipExtra = get_pcvar_num(cvar_clip_infinib)

     g_infinib_TmpClip[id] = -1

     new iBpAmmo = cs_get_user_bpammo(id, CSW_USP)
     new iClip = get_pdata_int(weapon_entity, m_iClip, WEAP_LINUX_XTRA_OFF)

     if (iBpAmmo <= 0)
          return HAM_SUPERCEDE

     if (iClip >= iClipExtra)
          return HAM_SUPERCEDE

     g_infinib_TmpClip[id] = iClip

     return HAM_IGNORED
}

public infinib_Reload_Post(weapon_entity) 
{
	new id = pev(weapon_entity, pev_owner)
	if (!is_user_connected(id))
		return HAM_IGNORED

	if (!g_has_infinib[id])
		return HAM_IGNORED

	if (g_infinib_TmpClip[id] == -1)
		return HAM_IGNORED

	set_pdata_int(weapon_entity, m_iClip, g_infinib_TmpClip[id], WEAP_LINUX_XTRA_OFF)

	set_pdata_float(weapon_entity, m_flTimeWeaponIdle, infinib_RELOAD_TIME, WEAP_LINUX_XTRA_OFF)

	set_pdata_float(id, m_flNextAttack, infinib_RELOAD_TIME, PLAYER_LINUX_XTRA_OFF)

	set_pdata_int(weapon_entity, m_fInReload, 1, WEAP_LINUX_XTRA_OFF)

	UTIL_PlayWeaponAnimation(id, infinib_RELOAD)

	return HAM_IGNORED
}

stock drop_weapons(id, dropwhat)
{
     static weapons[32], num, i, weaponid
     num = 0
     get_user_weapons(id, weapons, num)
     
     for (i = 0; i < num; i++)
     {
          weaponid = weapons[i]
          
          if (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM))
          {
               static wname[32]
               get_weaponname(weaponid, wname, sizeof wname - 1)
               engclient_cmd(id, "drop", wname)
          }
     }
}