/*
    [ZP] Extra HEV Suit Mark IV - Half-Life Inspired
    Version 1.1 (Fixed - No Custom Natives)
    
    Description:
    - Extra Item purchasable by Humans only (once per round)
    - Grants armor protection with HEV-style damage absorption
    - Optional Long Jump support (velocity-based, CS compatible)
    - Plays authentic HEV Suit voice lines
    - Clean reset at round end
    - HEV-exclusive weapon viewmodels
    - Adrenaline Injector animation on low health

    - Plugin Name: HEV Suit Mark IV
    - Author: sp_half : SAAD~Rubio / LyesMC
    - Modified: 2026
    
    FIX: Removed custom fm_set_user_model/fm_reset_user_model natives
         Now uses standard cs_set_user_model/cs_reset_user_model from CStrike module
*/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <cstrike>
#include <zombieplague>

// --- Configuration ---
new const HEV_MODEL_SHORT[] = "player_hev"; 
new const HEV_ZOMBIE_FULL[]  = "models/player/hev_zombie/hev_zombie.mdl";
new const HEV_ZOMBIE_SHORT[] = "hev_zombie";
new const V_HEV_ZOMBIE_KNIFE[] = "models/v_hev_zombie.mdl";

new const V_HEV_MODEL[] = "models/v_hev.mdl"
#define HEV_ANIM_TIME 3.0
#define HEV_ANIM_SEQUENCE 0

new const V_HEV_ADRENALINE[] = "models/v_hev_adrenaline_injector.mdl";
#define ADRENALINE_TIME 3.0
#define ADRENALINE_ANIM_SEQ 0 

// HEV WEAPON VIEWMODELS
new const V_HEV_AK47[]      = "models/hev_weapons/v_ak47.mdl";
new const V_HEV_M4A1[]      = "models/hev_weapons/v_m4a1.mdl";
new const V_HEV_MP5NAVY[]   = "models/hev_weapons/v_mp5.mdl";
new const V_HEV_AWP[]       = "models/hev_weapons/v_awp.mdl";
new const V_HEV_DEAGLE[]    = "models/hev_weapons/v_deagle.mdl";
new const V_HEV_GLOCK18[]   = "models/hev_weapons/v_glock18.mdl";
new const V_HEV_AUG[]       = "models/hev_weapons/v_aug.mdl";
new const V_HEV_FAMAS[]     = "models/hev_weapons/v_famas.mdl";
new const V_HEV_M249[]      = "models/hev_weapons/v_m249.mdl";
new const V_HEV_M3[]        = "models/hev_weapons/v_m3.mdl";
new const V_HEV_XM1014[]    = "models/hev_weapons/v_xm1014.mdl";
new const V_HEV_USP[]       = "models/hev_weapons/v_usp.mdl";
new const V_HEV_P228[]      = "models/hev_weapons/v_p228.mdl";
new const V_HEV_P90[]       = "models/hev_weapons/v_p90.mdl";
new const V_HEV_GALIL[]     = "models/hev_weapons/v_galil.mdl";
new const V_HEV_UMP45[]     = "models/hev_weapons/v_ump45.mdl";
new const V_HEV_TMP[]       = "models/hev_weapons/v_tmp.mdl";
new const V_HEV_SG550[]     = "models/hev_weapons/v_sg550.mdl";
new const V_HEV_G3SG1[]     = "models/hev_weapons/v_g3sg1.mdl";

// --- WRENCH MODELS ---
new const V_HEV_WRENCH[]    = "models/hev_weapons/v_wrench.mdl";
new const P_HEV_WRENCH[]    = "models/hev_weapons/p_wrench.mdl"; 

// --- WRENCH SOUNDS ---
new const SND_WRENCH_DEPLOY[]    = "weapons/wrench_deploy.wav"
new const SND_WRENCH_HIT[]       = "weapons/wrench_hit.wav"
new const SND_WRENCH_HITWALL[]   = "weapons/wrench_hitwall.wav"
new const SND_WRENCH_SLASH[]     = "weapons/wrench_slash.wav"
new const SND_WRENCH_STAB[]      = "weapons/wrench_stab.wav"

new const ITEM_NAME[] = "HEV Suit Mark IV"
const ITEM_COST = 80

#define MAX_POWER 100
#define JUMP_COST 30
#define REGEN_TICK 2
#define BOOST_THRES 40
#define BOOST_VALUE 250

new g_iItemId, g_maxPlayers, g_MsgSync;
new bool:g_bHasHEV[33], bool:g_bBoughtThisRound[33], bool:g_bMorphineUsed[33], bool:g_bArmorBoostUsed[33], bool:g_bIsHEVZombie[33]; 
new g_iSuitPower[33], g_ent_playermodel[33];
new g_cvArmor, g_cvHealthBonus, g_cvDamageReduction, g_cvLongJump;

new bool:g_bCriticalPlayed[33];

public plugin_precache()
{
    static model_path[128];
    formatex(model_path, charsmax(model_path), "models/player/%s/%s.mdl", HEV_MODEL_SHORT, HEV_MODEL_SHORT);
    precache_model(model_path);
    precache_model(HEV_ZOMBIE_FULL);
    
    precache_model(V_HEV_ZOMBIE_KNIFE);
    precache_model(V_HEV_MODEL);
    precache_model(V_HEV_ADRENALINE);
    precache_model(V_HEV_AK47);
    precache_model(V_HEV_M4A1);
    precache_model(V_HEV_MP5NAVY);
    precache_model(V_HEV_AWP);
    precache_model(V_HEV_DEAGLE);
    precache_model(V_HEV_GLOCK18);
    precache_model(V_HEV_AUG);
    precache_model(V_HEV_FAMAS);
    precache_model(V_HEV_M249);
    precache_model(V_HEV_M3);
    precache_model(V_HEV_XM1014);
    precache_model(V_HEV_USP);
    precache_model(V_HEV_P228);
    precache_model(V_HEV_P90);
    precache_model(V_HEV_GALIL);
    precache_model(V_HEV_UMP45);
    precache_model(V_HEV_TMP);
    precache_model(V_HEV_SG550);
    precache_model(V_HEV_G3SG1);

    precache_model(V_HEV_WRENCH);
    precache_model(P_HEV_WRENCH);

    precache_sound("fvox/morphine_shot.wav");
    precache_sound("fvox/health_critical.wav");
    precache_sound("fvox/hevSuit_get_infected_alert2.wav");
    precache_sound("fvox/power_restored.wav");
    precache_sound("fvox/hev_logon.wav");
    precache_sound("fvox/flatline.wav");
    precache_sound("player/pl_long_jump_1.wav");

    precache_sound(SND_WRENCH_DEPLOY);
    precache_sound(SND_WRENCH_HIT);
    precache_sound(SND_WRENCH_HITWALL);
    precache_sound(SND_WRENCH_SLASH);
    precache_sound(SND_WRENCH_STAB);
}

public plugin_init()
{
    register_plugin("[ZP] HEV Suit Mark IV", "1.1", "sp_half : SAAD~Rubio / LyesMC")

    g_iItemId = zp_register_extra_item(ITEM_NAME, ITEM_COST, ZP_TEAM_HUMAN);

    g_cvArmor = register_cvar("zp_hev_armor", "250");
    g_cvHealthBonus = register_cvar("zp_hev_health_bonus", "50");
    g_cvDamageReduction = register_cvar("zp_hev_damage_reduction", "20");
    g_cvLongJump = register_cvar("zp_hev_longjump", "1");

    RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage");
    RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1);
    RegisterHam(Ham_Killed, "player", "fw_PlayerKilled");
    
    register_forward(FM_PlayerPreThink, "fw_PlayerPreThink");
    register_event("CurWeapon", "Event_CurWeapon", "be", "1=1");
    register_forward(FM_EmitSound, "fw_EmitSound");

    new const weapon_list[][] = { 
        "weapon_ak47", "weapon_m4a1", "weapon_mp5navy", "weapon_awp",
        "weapon_deagle", "weapon_glock18", "weapon_aug", "weapon_famas",
        "weapon_m249", "weapon_m3", "weapon_xm1014", "weapon_usp", 
        "weapon_p228", "weapon_p90", "weapon_sg550", "weapon_g3sg1", 
        "weapon_galil", "weapon_ump45", "weapon_tmp", "weapon_knife"
    };

    for(new i = 0; i < sizeof weapon_list; i++)
        RegisterHam(Ham_Item_Deploy, weapon_list[i], "fw_Weapon_Deploy_Post", 1);

    register_event("HLTV", "event_NewRound", "a", "1=0", "2=0");
    g_maxPlayers = get_maxplayers();
    g_MsgSync = CreateHudSyncObj();
    set_task(1.0, "HEV_MainLoop", _, _, _, "b");
}

public Event_CurWeapon(id)
{
    if (!is_user_alive(id)) return;

    if (g_bHasHEV[id] && !zp_get_user_zombie(id))
    {
        set_hev_weapon_model(id);
    }
    else if (zp_get_user_zombie(id) && g_bIsHEVZombie[id])
    {
        if (get_user_weapon(id) == CSW_KNIFE)
            set_pev(id, pev_viewmodel2, V_HEV_ZOMBIE_KNIFE);
    }
}

public fw_Weapon_Deploy_Post(ent)
{
    if (!pev_valid(ent)) return HAM_IGNORED;

    static id;
    id = get_pdata_cbase(ent, 41, 4);
    if (!is_user_alive(id)) return HAM_IGNORED;

    if (g_bHasHEV[id] && !zp_get_user_zombie(id))
    {
        set_hev_weapon_model(id);
    }
    return HAM_IGNORED;
}

stock set_hev_weapon_model(id)
{
    if (!is_user_alive(id) || !g_bHasHEV[id] || zp_get_user_zombie(id))
        return;

    static current_model[64];
    pev(id, pev_viewmodel2, current_model, charsmax(current_model));
    
    if (equal(current_model, V_HEV_ADRENALINE) || equal(current_model, V_HEV_MODEL))
        return; 

    new iWpn = get_user_weapon(id);

    switch(iWpn)
    {
        case CSW_AK47:      set_pev(id, pev_viewmodel2, V_HEV_AK47);
        case CSW_M4A1:      set_pev(id, pev_viewmodel2, V_HEV_M4A1);
        case CSW_MP5NAVY:   set_pev(id, pev_viewmodel2, V_HEV_MP5NAVY);
        case CSW_AWP:       set_pev(id, pev_viewmodel2, V_HEV_AWP);
        case CSW_DEAGLE:    set_pev(id, pev_viewmodel2, V_HEV_DEAGLE);
        case CSW_GLOCK18:   set_pev(id, pev_viewmodel2, V_HEV_GLOCK18);
        case CSW_AUG:       set_pev(id, pev_viewmodel2, V_HEV_AUG);
        case CSW_FAMAS:     set_pev(id, pev_viewmodel2, V_HEV_FAMAS);
        case CSW_M3:        set_pev(id, pev_viewmodel2, V_HEV_M3);
        case CSW_XM1014:    set_pev(id, pev_viewmodel2, V_HEV_XM1014);
        case CSW_USP:       set_pev(id, pev_viewmodel2, V_HEV_USP);
        case CSW_G3SG1:     set_pev(id, pev_viewmodel2, V_HEV_G3SG1);
        case CSW_P228:      set_pev(id, pev_viewmodel2, V_HEV_P228);
        case CSW_P90:       set_pev(id, pev_viewmodel2, V_HEV_P90);
        case CSW_GALIL:     set_pev(id, pev_viewmodel2, V_HEV_GALIL);
        case CSW_UMP45:     set_pev(id, pev_viewmodel2, V_HEV_UMP45);
        case CSW_TMP:       set_pev(id, pev_viewmodel2, V_HEV_TMP);
        case CSW_M249:      set_pev(id, pev_viewmodel2, V_HEV_M249);
        case CSW_SG550:     set_pev(id, pev_viewmodel2, V_HEV_SG550);

        case CSW_KNIFE:
        {
            set_pev(id, pev_viewmodel2, V_HEV_WRENCH);
            set_pev(id, pev_weaponmodel2, P_HEV_WRENCH);
        }
    }
}

public HEV_MainLoop()
{
    for(new i = 1; i <= g_maxPlayers; i++)
    {
        if(!is_user_alive(i) || !g_bHasHEV[i] || zp_get_user_zombie(i)) continue;
        
        new hp = get_user_health(i);
        if(hp <= 90 && !g_bCriticalPlayed[i])
        {
            client_cmd(i, "spk fvox/health_critical");
            g_bCriticalPlayed[i] = true;
        }
        else if(hp > 90 && g_bCriticalPlayed[i])
        {
            g_bCriticalPlayed[i] = false;
        }

        if(g_iSuitPower[i] < MAX_POWER) g_iSuitPower[i] = min(MAX_POWER, g_iSuitPower[i] + REGEN_TICK);

        set_hudmessage(255, 140, 0, 0.02, 0.88, 0, 0.1, 1.1, 0.1, 0.1, -1);
        ShowSyncHudMsg(i, g_MsgSync, "[ HEV Mark V ]^nPower: %d%% | HP: %d | Armor: %d",
            g_iSuitPower[i], hp, get_user_armor(i));
    }
}

public zp_extra_item_selected(id, itemid)
{
    if(itemid != g_iItemId) return;
    if(g_bHasHEV[id] || g_bBoughtThisRound[id]) {
        client_print(id, print_chat, "[HEV] Suit already active.");
        return;
    }
    ActivateHEV(id);
}

ActivateHEV(id)
{
    g_bHasHEV[id] = true;
    g_bBoughtThisRound[id] = true;
    g_bMorphineUsed[id] = false;
    g_bArmorBoostUsed[id] = false;
    g_bIsHEVZombie[id] = false;
    g_iSuitPower[id] = MAX_POWER;

    fm_remove_model_ent(id);
    if (is_user_connected(id))
    {
        cs_set_user_model(id, HEV_MODEL_SHORT);
        set_pev(id, pev_viewmodel2, V_HEV_MODEL)
        util_play_weapon_animation(id, HEV_ANIM_SEQUENCE); 
        remove_task(id)
        set_task(HEV_ANIM_TIME, "restore_weapon_model", id)
    }
    set_user_health(id, get_user_health(id) + get_pcvar_num(g_cvHealthBonus));
    cs_set_user_armor(id, get_pcvar_num(g_cvArmor), CS_ARMOR_VESTHELM);
    client_cmd(id, "spk fvox/hev_logon");
    ScreenFade(id, {255, 150, 0}, 1.0, 0.5);
}

public restore_weapon_model(id)
{
    if (!is_user_alive(id) || zp_get_user_zombie(id)) return;
    set_hev_weapon_model(id);
}

public zp_user_infected_post(id)
{
    if(g_bHasHEV[id]) 
    {
        client_cmd(id, "spk fvox/hevSuit_get_infected_alert2");
        zp_remove_hev(id);
        g_bIsHEVZombie[id] = true;
        if (is_user_connected(id))
        {
            cs_set_user_model(id, HEV_ZOMBIE_SHORT);
            if(get_user_weapon(id) == CSW_KNIFE) set_pev(id, pev_viewmodel2, V_HEV_ZOMBIE_KNIFE);
        }
    }
    else zp_remove_hev(id);
}

public zp_user_humanized_post(id)
{
    if (g_bIsHEVZombie[id])
    {
        cs_reset_user_model(id);
        g_bIsHEVZombie[id] = false;
    }
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damageBits)
{
    if(!is_user_alive(victim) || !g_bHasHEV[victim] || zp_get_user_zombie(victim))
        return HAM_IGNORED;

    new Float:reduction = float(get_pcvar_num(g_cvDamageReduction)) / 100.0;
    damage = damage * (1.0 - reduction);

    new Float:armor = float(get_user_armor(victim));
    if (armor > 0.0)
    {
        new Float:armor_damage = damage * 0.5;
        new Float:health_damage = damage - armor_damage;

        if (armor_damage > armor)
        {
            health_damage = damage - armor;
            armor_damage = armor;
        }

        set_user_armor(victim, floatround(armor - armor_damage));
        damage = health_damage;
    }

    SetHamParamFloat(4, damage);

    if(!g_bMorphineUsed[victim] && (float(get_user_health(victim)) - damage <= float(BOOST_THRES)))
    {
        g_bMorphineUsed[victim] = true;
        set_user_health(victim, BOOST_VALUE);
        client_cmd(victim, "spk fvox/morphine_shot");
        ScreenFade(victim, {0, 0, 255}, 0.5, 0.3);
        return HAM_SUPERCEDE;
    }

    if(!g_bArmorBoostUsed[victim] && (get_user_armor(victim) <= BOOST_THRES))
    {
        g_bArmorBoostUsed[victim] = true;
        cs_set_user_armor(victim, BOOST_VALUE, CS_ARMOR_VESTHELM);
        client_cmd(victim, "spk fvox/power_restored");
        ScreenFade(victim, {255, 255, 0}, 0.5, 0.3);
    }

    return HAM_HANDLED;
}

public fw_PlayerPreThink(id)
{
    if(!is_user_alive(id) || !g_bHasHEV[id] || !get_pcvar_num(g_cvLongJump) || zp_get_user_zombie(id))
        return FMRES_IGNORED;

    static button, oldbutton, flags;
    button = pev(id, pev_button);
    oldbutton = pev(id, pev_oldbuttons);
    flags = pev(id, pev_flags);

    if((button & IN_JUMP) && !(oldbutton & IN_JUMP) && (button & IN_DUCK) && (flags & FL_ONGROUND))
    {
        if(g_iSuitPower[id] >= JUMP_COST)
        {
            g_iSuitPower[id] -= JUMP_COST;
            static Float:vel[3];
            velocity_by_aim(id, 500, vel);
            vel[2] = 250.0;
            set_pev(id, pev_velocity, vel);
            client_cmd(id, "spk player/pl_long_jump_1");
        }
    }
    return FMRES_IGNORED;
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
    if (!is_user_connected(id) || !g_bHasHEV[id] || zp_get_user_zombie(id))
        return FMRES_IGNORED;

    if (sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i') 
    {
        if (equal(sample, "weapons/knife_deploy1.wav"))
        {
            emit_sound(id, channel, SND_WRENCH_DEPLOY, volume, attn, flags, pitch);
            return FMRES_SUPERCEDE;
        }
        if (containi(sample, "hit") != -1 && containi(sample, "wall") == -1)
        {
            emit_sound(id, channel, SND_WRENCH_HIT, volume, attn, flags, pitch);
            return FMRES_SUPERCEDE;
        }
        if (containi(sample, "hitwall") != -1)
        {
            emit_sound(id, channel, SND_WRENCH_HITWALL, volume, attn, flags, pitch);
            return FMRES_SUPERCEDE;
        }
        if (containi(sample, "slash") != -1)
        {
            emit_sound(id, channel, SND_WRENCH_SLASH, volume, attn, flags, pitch);
            return FMRES_SUPERCEDE;
        }
        if (equal(sample, "weapons/knife_stab.wav"))
        {
            emit_sound(id, channel, SND_WRENCH_STAB, volume, attn, flags, pitch);
            return FMRES_SUPERCEDE;
        }
    }

    return FMRES_IGNORED;
}

public event_NewRound() { for (new i = 1; i <= g_maxPlayers; i++) zp_remove_hev(i); }
public fw_PlayerSpawn_Post(id) { zp_remove_hev(id); }
public fw_PlayerKilled(victim) { if(g_bHasHEV[victim]) client_cmd(victim, "spk fvox/flatline"); zp_remove_hev(victim); }
public client_disconnect(id) { zp_remove_hev(id); }

stock zp_remove_hev(id)
{
    if(!g_bHasHEV[id]) return;
    g_bHasHEV[id] = false;
    g_bCriticalPlayed[id] = false;
    g_bBoughtThisRound[id] = false;
    if (is_user_connected(id)) { cs_reset_user_model(id); restore_default_weapon_model(id); }
    fm_remove_model_ent(id);
    remove_task(id);
}

stock restore_default_weapon_model(id)
{
    if (!is_user_alive(id)) return;
    new iWpn = get_user_weapon(id);
    new szModel[64];
    switch(iWpn)
    {
        case CSW_AK47: formatex(szModel, charsmax(szModel), "models/v_ak47.mdl");
        case CSW_KNIFE: formatex(szModel, charsmax(szModel), "models/v_knife.mdl");
        default: return;
    }
    set_pev(id, pev_viewmodel2, szModel);
}

stock fm_remove_model_ent(id) { if (pev_valid(g_ent_playermodel[id])) { engfunc(EngFunc_RemoveEntity, g_ent_playermodel[id]); g_ent_playermodel[id] = 0; } }

stock ScreenFade(id, color[3], Float:duration, Float:hold)
{
    message_begin(MSG_ONE, get_user_msgid("ScreenFade"), _, id);
    write_short(floatround(duration * (1<<12)));
    write_short(floatround(hold * (1<<12)));
    write_short(0x0000);
    write_byte(color[0]); write_byte(color[1]); write_byte(color[2]); write_byte(100);
    message_end();
}

stock util_play_weapon_animation(const Player, const Sequence)
{
    set_pev(Player, pev_weaponanim, Sequence)
    message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
    write_byte(Sequence); write_byte(pev(Player, pev_body));
    message_end()
}
