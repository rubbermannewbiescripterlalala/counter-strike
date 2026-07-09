#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <fun>
#include <hamsandwich>
#include <zombieplague>

new const zombieclass1_name[] = "Light"
new const zombieclass1_info[] = "Invisibility"
new const zombieclass1_models[] = { "cj_light" }
new const zombieclass1_clawmodels[] = { "v_knife_light.mdl" }
const zombieclass1_health = 1500
const zombieclass1_speed = 260
const Float:zombieclass1_gravity = 0.7
const Float:zombieclass1_knockback = 1.0

#define MODEL "models/cso_zp/claws/v_knife_light_abil.mdl"

new const sound_zombie_invis[][] = { "csozp/zombi_pressure.wav" }

#define SKILL_TIME 10.0
#define COOLDOWN_TIME 20.0

new g_ZombieClassID, Float:g_fCooldown[33], g_Skill[33]

public plugin_init()
{
	register_clcmd("drop", "clcmd_drop")
	
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "ham_item_deploy_post",1)
}

public plugin_precache()
{
	g_ZombieClassID = zp_register_zombie_class(zombieclass1_name, zombieclass1_info, zombieclass1_models, zombieclass1_clawmodels, zombieclass1_health, zombieclass1_speed, zombieclass1_gravity, zombieclass1_knockback)
	
	precache_sound(sound_zombie_invis[0])
	precache_model(MODEL)
}

public ham_item_deploy_post(weapon_ent)
{
	static id;id=get_pdata_cbase(weapon_ent,41,4)
	
	if(g_Skill[id]&&zp_get_user_zombie(id)){
		set_pev(id, pev_viewmodel2, MODEL)
	}
}

public clcmd_drop(id)
{
	if (!zp_get_user_zombie(id) || zp_get_user_zombie_class(id) != g_ZombieClassID) return PLUGIN_CONTINUE
	if (zp_get_user_nemesis(id)) return PLUGIN_CONTINUE
	
	if(get_gametime()<g_fCooldown[id]) {
		client_print(id, print_center, "Способность перезаряжается! Осталось %d сек", floatround(g_fCooldown[id]-get_gametime()))
		return PLUGIN_HANDLED
	}
	
	g_fCooldown[id]=get_gametime()+COOLDOWN_TIME+SKILL_TIME

	emit_sound(id, CHAN_VOICE, sound_zombie_invis[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	fm_set_rendering(id,kRenderFxGlowShell,0,0,0,kRenderTransAlpha,0)
	g_Skill[id]=1
	set_pdata_int(id,363,110,5)
	set_user_footsteps(id, 1)
	static weapon_ent
	weapon_ent = get_pdata_cbase(id, 373, 5)
		
	if (pev_valid(weapon_ent))
		ExecuteHamB(Ham_Item_Deploy, weapon_ent)
	set_task(SKILL_TIME, "ability_end", id)
	return PLUGIN_HANDLED
}


public zp_user_infected_post(id){
	if (zp_get_user_zombie_class(id) == g_ZombieClassID)
	{
	
	}
}

public ability_end(id)
{
	if(!is_user_connected(id))return
	fm_set_rendering(id)
	set_user_footsteps(id, 0)
	g_Skill[id]=0
	if(!is_user_alive(id)||!zp_get_user_zombie(id))return
	static weapon_ent
	weapon_ent = get_pdata_cbase(id, 373, 5)
		
	if (pev_valid(weapon_ent))
		ExecuteHamB(Ham_Item_Deploy, weapon_ent)
	set_pdata_int(id,363,90,5)
}