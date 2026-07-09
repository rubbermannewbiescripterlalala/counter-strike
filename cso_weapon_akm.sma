#include <amxmodx>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombieplague>

#define PLUGIN "[CSO] Weapon: AKM "
#define VERSION "1.0"
#define AUTHOR "Base: Batcon & xUnicorn; ReEdit: kHRYSTAL"

#define CustomItem(%0) (pev(%0, pev_impulse) == WEAPON_SPECIAL_CODE)

// CWeaponBox
#define m_rgpPlayerItems_CWeaponBox 34

// CBasePlayerItem
#define m_pPlayer 41
#define m_pNext 42
#define m_iId 43

// CBasePlayerWeapon
#define m_flNextPrimaryAttack 46
#define m_flNextSecondaryAttack 47
#define m_flTimeWeaponIdle 48
#define m_iPrimaryAmmoType 49
#define m_iClip 51
#define m_fInReload 54

// CBaseMonster
#define m_flNextAttack 83

// CBasePlayer
#define m_rpgPlayerItems 367
#define m_pActiveItem 373
#define m_rgAmmo 376

#define ANIM_IDLE 0
#define ANIM_RELOAD 1
#define ANIM_DRAW 2
#define ANIM_ATTACK random_num(3, 5)

#define ANIM_IDLE_TIME 2/30.0
#define ANIM_SHOOT_TIME 17/20.0
#define ANIM_RELOAD_TIME 91/37.0
#define ANIM_DRAW_TIME 31/30.0

#define WEAPON_SPECIAL_CODE 19
#define WEAPON_CSW CSW_AK47
#define WEAPON_REFERENCE "weapon_ak47"
#define WEAPON_NEW_NAME "x-cso/weapon_akm"
#define WEAPON_HUD "sprites/x-cso/640hud31.spr"
#define WEAPON_HUD_AMMO "sprites/x-cso/640hud7.spr"

#define WEAPON_ITEM_NAME "AKM"
#define WEAPON_ITEM_COST 15

#define WEAPON_MODEL_VIEW "models/x-cso/v_akm.mdl"
#define WEAPON_MODEL_PLAYER "models/x-cso/p_akm.mdl"
#define WEAPON_MODEL_WORLD "models/x-cso/w_akm.mdl"
#define WEAPON_SOUND_SHOOT "weapons/akm-1.wav"
#define WEAPON_BODY 0

#define WEAPON_MAX_CLIP 30
#define WEAPON_DEFAULT_AMMO 90
#define WEAPON_RATE 0.1
#define WEAPON_PUNCHAGNLE 1.0
#define WEAPON_DAMAGE 1.50

new g_AllocString_V, g_AllocString_P, g_AllocString_E
new HamHook:g_fw_TraceAttack[4]
new g_iMsgID_Weaponlist
new g_iItemID
public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	RegisterHam(Ham_Item_Deploy, WEAPON_REFERENCE, "fw_Item_Deploy_Post", 1);
	RegisterHam(Ham_Item_PostFrame, WEAPON_REFERENCE, "fw_Item_PostFrame");
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Item_AddToPlayer_Post", 1);
	
	RegisterHam(Ham_Weapon_Reload, WEAPON_REFERENCE, "fw_Weapon_Reload");
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle");
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack");
	
	g_fw_TraceAttack[0] = RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack");
	g_fw_TraceAttack[1] = RegisterHam(Ham_TraceAttack, "info_target",    "fw_TraceAttack");
	g_fw_TraceAttack[2] = RegisterHam(Ham_TraceAttack, "player",         "fw_TraceAttack");
	g_fw_TraceAttack[3] = RegisterHam(Ham_TraceAttack, "hostage_entity", "fw_TraceAttack");
	fm_ham_hook(false);
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1);
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent");
	register_forward(FM_SetModel, "fw_SetModel");
	g_iMsgID_Weaponlist = get_user_msgid("WeaponList");
	register_clcmd(WEAPON_NEW_NAME, "HookSelect");
	g_iItemID = zp_register_extra_item(WEAPON_ITEM_NAME, 15 , ZP_TEAM_HUMAN);
}
public plugin_precache() {
	new szBuffer[64]; formatex(szBuffer, charsmax(szBuffer), "sprites/%s.txt", WEAPON_NEW_NAME);

	engfunc(EngFunc_PrecacheGeneric, szBuffer);
	engfunc(EngFunc_PrecacheGeneric, WEAPON_HUD);
	engfunc(EngFunc_PrecacheGeneric, WEAPON_HUD_AMMO);

	g_AllocString_V = engfunc(EngFunc_AllocString, WEAPON_MODEL_VIEW);
	g_AllocString_P = engfunc(EngFunc_AllocString, WEAPON_MODEL_PLAYER);
	g_AllocString_E = engfunc(EngFunc_AllocString, WEAPON_REFERENCE);

	engfunc(EngFunc_PrecacheModel, WEAPON_MODEL_VIEW);
	engfunc(EngFunc_PrecacheModel, WEAPON_MODEL_PLAYER);
	engfunc(EngFunc_PrecacheModel, WEAPON_MODEL_WORLD);

	new const WPN_SOUND[][] = {
		"weapons/akm_draw.wav",
		"weapons/akm_clipin.wav",
		"weapons/akm_clipout.wav"
	}
	for(new i = 0; i < sizeof WPN_SOUND;i++) engfunc(EngFunc_PrecacheSound, WPN_SOUND[i]);
	engfunc(EngFunc_PrecacheSound, WEAPON_SOUND_SHOOT);
}
public plugin_natives() {
	register_native("give_weapon_akm", "give_akm", 1);
}
public zp_extra_item_selected(iPlayer, iItemID) { 
	if(iItemID != g_iItemID) return;
	give_akm(iPlayer); 
}
public HookSelect(iPlayer) {
	engclient_cmd(iPlayer, WEAPON_REFERENCE);
	return PLUGIN_HANDLED;
}
public give_akm(iPlayer) {
	static iEnt; iEnt = engfunc(EngFunc_CreateNamedEntity, g_AllocString_E);
	if(iEnt <= 0) return 0;
	set_pev(iEnt, pev_spawnflags, SF_NORESPAWN);
	set_pev(iEnt, pev_impulse, WEAPON_SPECIAL_CODE);
	ExecuteHam(Ham_Spawn, iEnt);
	UTIL_DropWeapon(iPlayer, 1);
	if(!ExecuteHamB(Ham_AddPlayerItem, iPlayer, iEnt)) {
		engfunc(EngFunc_RemoveEntity, iEnt);
		return 0;
	}
	ExecuteHamB(Ham_Item_AttachToPlayer, iEnt, iPlayer);
	set_pdata_int(iEnt, m_iClip, WEAPON_MAX_CLIP, 4);
	new iAmmoType = m_rgAmmo +get_pdata_int(iEnt, m_iPrimaryAmmoType, 4);
	if(get_pdata_int(iPlayer, m_rgAmmo, 5) < WEAPON_DEFAULT_AMMO)
	set_pdata_int(iPlayer, iAmmoType, WEAPON_DEFAULT_AMMO, 5);
	emit_sound(iPlayer, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	return 1;
}
public fw_Item_Deploy_Post(iItem) {
	if(!CustomItem(iItem)) return;
	static iPlayer; iPlayer = get_pdata_cbase(iItem, m_pPlayer, 4);
	set_pev_string(iPlayer, pev_viewmodel2, g_AllocString_V);
	set_pev_string(iPlayer, pev_weaponmodel2, g_AllocString_P);
	UTIL_SendWeaponAnim(iPlayer, ANIM_DRAW);
	set_pdata_float(iPlayer, m_flNextAttack, ANIM_DRAW_TIME, 5);
	set_pdata_float(iItem, m_flTimeWeaponIdle, ANIM_DRAW_TIME, 4);
}
public fw_Item_PostFrame(iItem) {
	if(!CustomItem(iItem)) return HAM_IGNORED;
	static iPlayer; iPlayer = get_pdata_cbase(iItem, m_pPlayer, 4);
	if(get_pdata_int(iItem, m_fInReload, 4) == 1) {
		static iClip; iClip = get_pdata_int(iItem, m_iClip, 4);
		static iAmmoType; iAmmoType = m_rgAmmo + get_pdata_int(iItem, m_iPrimaryAmmoType, 4);
		static iAmmo; iAmmo = get_pdata_int(iPlayer, iAmmoType, 5);
		static j; j = min(WEAPON_MAX_CLIP - iClip, iAmmo);
		set_pdata_int(iItem, m_iClip, iClip+j, 4);
		set_pdata_int(iPlayer, iAmmoType, iAmmo-j, 5);
		set_pdata_int(iItem, m_fInReload, 0, 4);
	}
	return HAM_IGNORED;
}
public fw_Item_AddToPlayer_Post(iItem, iPlayer) {
	switch(pev(iItem, pev_impulse)) {
		case WEAPON_SPECIAL_CODE: s_weaponlist(iPlayer, true);
		case 0: s_weaponlist(iPlayer, false);
	}
}
public fw_Weapon_Reload(iItem) {
	if(!CustomItem(iItem)) return HAM_IGNORED;
	static iClip; iClip = get_pdata_int(iItem, m_iClip, 4);
	if(iClip >= WEAPON_MAX_CLIP) return HAM_SUPERCEDE;
	static iPlayer; iPlayer = get_pdata_cbase(iItem, m_pPlayer, 4);
	static iAmmoType; iAmmoType = m_rgAmmo + get_pdata_int(iItem, m_iPrimaryAmmoType, 4);
	if(get_pdata_int(iPlayer, iAmmoType, 5) <= 0) return HAM_SUPERCEDE

	set_pdata_int(iItem, m_iClip, 0, 4);
	ExecuteHam(Ham_Weapon_Reload, iItem);
	set_pdata_int(iItem, m_iClip, iClip, 4);
	set_pdata_float(iItem, m_flNextPrimaryAttack, ANIM_RELOAD_TIME, 4);
	set_pdata_float(iItem, m_flNextSecondaryAttack, ANIM_RELOAD_TIME, 4);
	set_pdata_float(iItem, m_flTimeWeaponIdle, ANIM_RELOAD_TIME, 4);
	set_pdata_float(iPlayer, m_flNextAttack, ANIM_RELOAD_TIME, 5);

	UTIL_SendWeaponAnim(iPlayer, ANIM_RELOAD);
	return HAM_SUPERCEDE;
}
public fw_Weapon_WeaponIdle(iItem) {
	if(!CustomItem(iItem) || get_pdata_float(iItem, m_flTimeWeaponIdle, 4) > 0.0) return HAM_IGNORED;
	UTIL_SendWeaponAnim(get_pdata_cbase(iItem, m_pPlayer, 4), ANIM_IDLE);
	set_pdata_float(iItem, m_flTimeWeaponIdle, ANIM_IDLE_TIME, 4);
	return HAM_SUPERCEDE;
}
public fw_Weapon_PrimaryAttack(iItem) {
	if(!CustomItem(iItem)) return HAM_IGNORED;
	static iPlayer; iPlayer = get_pdata_cbase(iItem, m_pPlayer, 4);
	if(get_pdata_int(iItem, m_iClip, 4) == 0) {
		ExecuteHam(Ham_Weapon_PlayEmptySound, iItem);
		set_pdata_float(iItem, m_flNextPrimaryAttack, 0.2, 4);
		return HAM_SUPERCEDE;
	}
	static fw_TraceLine; fw_TraceLine = register_forward(FM_TraceLine, "fw_TraceLine_Post", 1);
	fm_ham_hook(true);
	state FireBullets: Enabled;
	ExecuteHam(Ham_Weapon_PrimaryAttack, iItem);
	state FireBullets: Disabled;
	unregister_forward(FM_TraceLine, fw_TraceLine, 1);
	fm_ham_hook(false);
	static Float:vecPunchangle[3];
	static Float:vecOrigin[3]; fm_get_aim_origin(iPlayer, vecOrigin);

	pev(iPlayer, pev_punchangle, vecPunchangle);
	vecPunchangle[0] *= WEAPON_PUNCHAGNLE;
	vecPunchangle[1] *= WEAPON_PUNCHAGNLE;
	vecPunchangle[2] *= WEAPON_PUNCHAGNLE;
	set_pev(iPlayer, pev_punchangle, vecPunchangle);

	emit_sound(iPlayer, CHAN_WEAPON, WEAPON_SOUND_SHOOT, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	UTIL_SendWeaponAnim(iPlayer, ANIM_ATTACK);

	set_pdata_float(iItem, m_flNextPrimaryAttack, WEAPON_RATE, 4);
	set_pdata_float(iItem, m_flTimeWeaponIdle, ANIM_SHOOT_TIME, 4);

	return HAM_SUPERCEDE;
}
public fw_PlaybackEvent() <FireBullets: Enabled> { return FMRES_SUPERCEDE; }
public fw_PlaybackEvent() <FireBullets: Disabled> { return FMRES_IGNORED; }
public fw_PlaybackEvent() <> { return FMRES_IGNORED; }
public fw_TraceAttack(iVictim, iAttacker, Float:flDamage) {
	if(!is_user_connected(iAttacker)) return;
	static iItem; iItem = get_pdata_cbase(iAttacker, m_pActiveItem, 5);
	if(iItem <= 0 || !CustomItem(iItem)) return;
        SetHamParamFloat(3, flDamage * WEAPON_DAMAGE);
}
public fw_UpdateClientData_Post(iPlayer, SendWeapons, CD_Handle) {
	if(get_cd(CD_Handle, CD_DeadFlag) != DEAD_NO) return;
	static iItem; iItem = get_pdata_cbase(iPlayer, m_pActiveItem, 5);
	if(iItem <= 0 || !CustomItem(iItem)) return;
	set_cd(CD_Handle, CD_flNextAttack, 999999.0);
}
public fw_SetModel(iEnt) {
	static i, szClassname[32], iItem; 
	pev(iEnt, pev_classname, szClassname, 31);
	if(!equal(szClassname, "weaponbox")) return FMRES_IGNORED;
	for(i = 0; i < 6; i++) {
		iItem = get_pdata_cbase(iEnt, m_rgpPlayerItems_CWeaponBox + i, 4);
		if(iItem > 0 && CustomItem(iItem)) {
			engfunc(EngFunc_SetModel, iEnt, WEAPON_MODEL_WORLD);
			set_pev(iEnt, pev_body, WEAPON_BODY);
			return FMRES_SUPERCEDE;
		}
	}
	return FMRES_IGNORED;
}
public fw_TraceLine_Post(const Float:flOrigin1[3], const Float:flOrigin2[3], iFrag, iIgnore, tr) {
	if(iFrag & IGNORE_MONSTERS) return FMRES_IGNORED;
	static pHit; pHit = get_tr2(tr, TR_pHit);
	static Float:flvecEndPos[3]; get_tr2(tr, TR_vecEndPos, flvecEndPos);
	if(pHit > 0) {
		if(pev(pHit, pev_solid) != SOLID_BSP) return FMRES_IGNORED;
	}
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, flvecEndPos, 0);
	write_byte(TE_GUNSHOTDECAL);
	engfunc(EngFunc_WriteCoord, flvecEndPos[0]);
	engfunc(EngFunc_WriteCoord, flvecEndPos[1]);
	engfunc(EngFunc_WriteCoord, flvecEndPos[2]);
	write_short(pHit > 0 ? pHit : 0);
	write_byte(random_num(41, 45));
	message_end();

	return FMRES_IGNORED;
}
public fm_ham_hook(bool:on) {
	if(on) {
		EnableHamForward(g_fw_TraceAttack[0]);
		EnableHamForward(g_fw_TraceAttack[1]);
		EnableHamForward(g_fw_TraceAttack[2]);
		EnableHamForward(g_fw_TraceAttack[3]);
	}
	else {
		DisableHamForward(g_fw_TraceAttack[0]);
		DisableHamForward(g_fw_TraceAttack[1]);
		DisableHamForward(g_fw_TraceAttack[2]);
		DisableHamForward(g_fw_TraceAttack[3]);
	}
}
stock UTIL_SendWeaponAnim(iPlayer, iSequence) {
	set_pev(iPlayer, pev_weaponanim, iSequence);
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, iPlayer);
	write_byte(iSequence);
	write_byte(0);
	message_end();
}
stock UTIL_DropWeapon(iPlayer, iSlot) {
	static iEntity, iNext, szWeaponName[32]; 
	iEntity = get_pdata_cbase(iPlayer, m_rpgPlayerItems + iSlot, 5);
	if(iEntity > 0) {       
		do {
			iNext = get_pdata_cbase(iEntity, m_pNext, 4)
			if(get_weaponname(get_pdata_int(iEntity, m_iId, 4), szWeaponName, 31)) {  
				engclient_cmd(iPlayer, "drop", szWeaponName);
			}
		} while(( iEntity = iNext) > 0);
	}
}
stock s_weaponlist(iPlayer, bool:on) {
	message_begin(MSG_ONE, g_iMsgID_Weaponlist, _, iPlayer);
	write_string(on ? WEAPON_NEW_NAME : WEAPON_REFERENCE);
	write_byte(2);
	write_byte(on ? WEAPON_DEFAULT_AMMO : 90);
	write_byte(-1);
	write_byte(-1);
	write_byte(0);
	write_byte(1);
	write_byte(28);
	write_byte(0);
	message_end();
}