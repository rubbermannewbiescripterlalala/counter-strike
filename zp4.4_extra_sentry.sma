/* =============================================================
    [ZP] Extra Item: Half-Life Combine Sentry 
    Version: 3.0 
    Ported by: LyesMC
    
    [CHANGELOG]:
    - Ported original HL Combine Sentry to CS 1.6 ZP compatible
    - Added "Sleep Cycle" (20s Active / 5s Recharge) to balance gameplay.
    - Added "Damage Reward System" (Every 750 DMG = 1 Ammo Pack).
    - Optimized "TraceAttack" to prevent HEV/Armor bugs.
    - Added Global Round Limit (Max 3 per round).
    - Added: Bot Compatibility (Bots can now place Sentry).
    - Added: CVAR "cvar_bot_sentry " to enable/disable bot placement.
    - Added: Aerial and ground sentry push zombies power.
    - Fixed model rotation to stand upright on any surface.
    - Sounds integrated
    - Anti-Block: Prevents planting inside walls or on top of other players.


    [CREDITS]:
    - Original Sentry Model: Valve / Half-Life
    ============================================================= */


#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <zombieplague>
#include <colorchat>


// Max players
#define MAXPLAYERS 32

new Float:g_BotStillTime[MAXPLAYERS + 1]; // Tracks how long a bot is stationary
const TASK_BOT_LOGIC = 9988;              // Unique Task ID

new g_total_sentry_sold = 0; // Global counter
new g_sentry_bot_sold = 0;    // How many bots bought sentry this round (max 2)
new g_round_sentry_limit = 5; // Only 5 sentries allowed per round globally
const BOT_SENTRY_LIMIT = 32;   // Max bots allowed to buy sentry per round

// --- NEW GLOBAL FOR REWARD SYSTEM ---
new Float:g_SentryDamageAccumulated[MAXPLAYERS + 1];
#define DAMAGE_FOR_AMMO 250.0 // +1 ammopack for 750 dmg sentry does  to zombies bonus
// ------------------------------------


// --- SEARCH STATE (when target lost) ---
#define SENTRY_STATE_SEARCHING 2
new Float:g_SentrySearchTimer[4096];
new const search_sound[] = "items/search.wav"


// --- NEW GLOBALS FOR SLEEP CYCLE ---
#define SENTRY_TIME_ACTIVE  30.0  // How long it shoots
#define SENTRY_TIME_SLEEP   6.0   // How long it sleeps

new g_SentryState[4096];      // 0 = Active, 1 = Sleeping
new Float:g_SentryTimer[4096]; // Timer for the cycle
// -----------------------------------

// per-entity acquired timestamp (0.0 = not waiting)
new Float:g_SentryAcquiredTime[4096];
new cvar_bot_sentry;

// sounds
new const fire[] = "weapons/sentry1.wav";
new const spot[] = "items/spot.wav";
new const sleep_sound[] = "items/sleep.wav";
new const building[] = "items/building.wav";
new const g_sound_menu[]      = "zombie_plague/game_ready"
new const g_accessdeny_menu[] = "zombie_plague/access_denied"


// [RED DOT SPRITE] Firing indicator sprite
new const REDDOT_SPRITE[] = "sprites/blueflare1.spr"

// glow declare
new cvar_sentry_glow;

new g_SmokeSprite; // Black smoke sprite index for death effect
new g_MuzzleSprite; // Muzzle flash sprite

// knockback power of sentry
#define AERIALPUSH 0.50
#define GROUNDPUSH 150.0


#define HITSD 0.95

#define SENTRY_DAMAGE_PER_SHOT 18.0 
#define THINK_INTERVAL        0.10

// ----- SENTY BRAIN: simple shooting + zombie-only targeting -----
#define SENTRY_FIREMODE_NO   0
#define SENTRY_FIREMODE_YES  1
#define THINKFIREFREQUENCY   0.10      // time between shots (seconds)
#define SENTRY_MAX_RANGE     1000.0     // detection range (tweak as needed)
#define SENTRY_PITCH_OFFSET   80.0 
#define SENTRY_SHOOT_DURATION 0.5

// per-entity storage keyed by entity edict
new g_SentryTarget[4096];    // stores player id 
new g_SentryFireMode[4096];  // SENTRY_FIREMODE_*
new g_SentryLevel[4096];     // unused now, reserved for scaling damage

// per-entity last fire time (float timestamps)
new Float:g_SentryLastFire[4096];

// [RED DOT] Storage for red dot sprite entity per sentry
new g_SentryRedDot[4096];

// sequence index for the shoot animation in the sentry model
const SENTRY_SEQ_SHOOT = 1; // Model sequences tweak
const SENTRY_SEQ_DIE   = 5; // 💀 Die sequence (21 frames @ 15fps = ~1.4s)
const TASK_SENTRY_DIE  = 5000; // Task offset for delayed death finish

// 💀 [DEATH ANIM] Store origin + owner so explosion fires after animation
new Float:g_SentryDeathOrigin[4096][3];
new g_SentryDeathOwner[4096];

// Globals
new bool:g_TripmineBought[MAXPLAYERS + 1];
new limit[MAXPLAYERS + 1];
new g_PlayerArmor[MAXPLAYERS + 1];

// Item Cost
new const g_item_name[] = { "Combine Sentry:" }; // Item name
const g_item_cost = 15; // Price 

// Constants
const m_pOwner = EV_INT_iuser1;
const m_rgpDmgTime = EV_INT_iuser3;
const m_flPowerUp = EV_FL_starttime;
const m_vecEnd = EV_VEC_endpos;
const m_flSparks = EV_FL_ltime;
const OFFSET_CSMENUCODE = 205;

new const glass[] = "debris/bustglass2.wav";

// Enums
enum _:tripmine_e
{
    TRIPMINE_IDLE1 = 0,
    TRIPMINE_IDLE2,
    TRIPMINE_ARM1,
    TRIPMINE_ARM2,
    TRIPMINE_FIDGET,
    TRIPMINE_HOLSTER,
    TRIPMINE_DRAW,
    TRIPMINE_WORLD,
    TRIPMINE_GROUND,
};

// Tasks
const TASK_SETLASER = 100;
const TASK_DELLASER = 200;
const TASK_IDLE = 300;

// Variables
new g_iMsgBarTime;
new g_iTripmine[MAXPLAYERS+1];
new g_iTripmineHealth[MAXPLAYERS+1][100];
new bool:g_bCantPlant[MAXPLAYERS+1];
new g_iSentryId, cvar_sentry_health, cvar_sentry_bonus;
new g_iMsgSayTxt;

public plugin_init()
{
    register_plugin("Extra-Sentry", "1.0", "LyesMC")

    // Register Message
    g_iMsgBarTime = get_user_msgid("BarTime");

    register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");

    cvar_sentry_glow = register_cvar("zp_sentry_glow", "1");
    cvar_bot_sentry = register_cvar("zp_bot_sentry", "1"); // 0=don't place, 1=bots place

    // Register Item
    g_iSentryId = zp_register_extra_item(g_item_name, g_item_cost, ZP_TEAM_HUMAN);


    // Register Forwards
    RegisterHam(Ham_Killed, "player", "CBasePlayer_Killed_Post", 1);
    RegisterHam(Ham_TakeDamage, "player", "CBasePlayer_TakeDamage_Pre");
    RegisterHam(Ham_TakeDamage, "info_target", "Tripmine_TakeDamage_Pre");
    RegisterHam(Ham_TakeDamage, "info_target", "Tripmine_TakeDamage_Post", 1);
    RegisterHam(Ham_Killed, "info_target", "Tripmine_Killed_Pre",  0); // PRE - fires BEFORE engine removes entity
    RegisterHam(Ham_Killed, "info_target", "Tripmine_Killed_Post", 1);

    register_forward(FM_OnFreeEntPrivateData, "OnFreeEntPrivateData");
    register_forward(FM_TraceLine, "Tripmine_ShowInfo_Post", 1);
    register_think("zp_sentry", "sentry_core_think");

     
    // Register Think
    register_think("zp_sentry", "Tripmine_Think");

    // Register Cvars
    cvar_sentry_health = register_cvar("zp_sentry_health", "375");
    cvar_sentry_bonus = register_cvar("zp_sentry_bonus", "10");

    g_iMsgSayTxt = get_user_msgid("SayText")

    // Register Binds
    register_concmd("+setsentry", "CmdSetLaser");
    register_concmd("-setsentry", "CmdUnsetLaser");
    register_concmd("+delsentry", "CmdDelLaser");
    register_concmd("-delsentry", "CmdUndelLaser");

    // Register Commands
    register_clcmd("say /sentry", "showMenuLasermine");
    register_clcmd("say_team /sentry", "showMenuLasermine");

    set_task(10.0, "task_bot_sentry_logic", TASK_BOT_LOGIC, _, _, "b");
}

public plugin_precache()
{
    precache_sound(glass);

    precache_sound("items/sentry_die1.wav");
    precache_sound("items/sentry_die2.wav");
    g_SmokeSprite = precache_model("sprites/steam1.spr");
    g_MuzzleSprite = precache_model("sprites/muzzleflash7.spr");
    precache_model("models/sentry.mdl");
    precache_sound("weapons/sentry_deploy.wav");
    precache_sound("weapons/mine_charge.wav");
    precache_sound("weapons/mine_activate.wav");
    precache_sound("debris/beamstart9.wav");
    precache_sound("items/gunpickup2.wav");
    precache_sound(fire);
    precache_sound(building);
    precache_sound("items/spot.wav");
    precache_sound(sleep_sound);
    precache_sound("zombie_plague/game_ready.wav")
    precache_sound(search_sound);
    precache_model(REDDOT_SPRITE); // [RED DOT] Precache the red dot sprite
    precache_sound("zombie_plague/access_denied.wav")
}

public plugin_natives()
{
    set_module_filter("moduleFilter")
    set_native_filter("nativeFilter")
}

public moduleFilter(const szModule[])
{
    
    return PLUGIN_CONTINUE;
}

public nativeFilter(const szName[], iId, iTrap)
{
    if (!iTrap)
        return PLUGIN_HANDLED;
    
    return PLUGIN_CONTINUE;
}

public client_disconnected(this)
{
    g_iTripmine[this] = 0;

    Tripmine_Kill(this);
}

public EventNewRound()
{
    new pTripmine = -1;
    while ((pTripmine = find_ent_by_class(pTripmine, "zp_sentry")) != 0)
    {
        RemoveRedDot(pTripmine); // [FIX] Remove red dot sprite on new round
        remove_entity(pTripmine); 
    }

    g_total_sentry_sold = 0;
    g_sentry_bot_sold = 0;

    for (new id = 1; id <= get_maxplayers(); id++)
    {
        g_BotStillTime[id] = 0.0;
        g_TripmineBought[id] = false; // Allow buying again next round
        g_PlayerArmor[id] = false;
        limit[id] = 0;
        
        // Reset the Sentry Damage reward counter for the new round 
        g_SentryDamageAccumulated[id] = 0.0; 
        
        Tripmine_Kill(id);
    }

    arrayset(g_iTripmine, 0, sizeof g_iTripmine);
}

public CmdSetLaser(this)
{
    if (!is_user_alive(this))
        return PLUGIN_HANDLED;
    
    if (zp_get_user_zombie(this))
        return PLUGIN_HANDLED;

    if (task_exists(this+TASK_SETLASER))
        return PLUGIN_HANDLED;

    if (!g_iTripmine[this])
    {
        client_printcolor(this, "!y[!gZP!y]: You do not have !gSentry !yto plant.");
        return PLUGIN_HANDLED;
    }

    if (task_exists(this+TASK_DELLASER))
        return PLUGIN_HANDLED;
	
	
    new rgpData[1];

    new pTripmine = rgpData[0] = Tripmine_Spawn(this);
    Tripmine_RelinkTripmine(pTripmine);

    if (g_bCantPlant[this])
    {
        client_printcolor(this, "!y[!gZP!y]: You Can't plant !gSentry !yat this location!");

        Tripmine_Kill(this);
        return PLUGIN_HANDLED;
    }

    set_task(0.27, "TaskIdle", this+TASK_IDLE, rgpData, sizeof rgpData, "b");
    set_task(3.0, "TaskSetLaser", this+TASK_SETLASER, rgpData, sizeof rgpData);

    BarTime(this, 3);
    // emit_sound(this, CHAN_ITEM, "weapons/building.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    emit_sound(this, CHAN_ITEM, building, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_HANDLED;
}

public CmdUnsetLaser(this)
{
    if (!task_exists(this+TASK_SETLASER))
        return PLUGIN_HANDLED;

    Tripmine_Kill(this);
    return PLUGIN_HANDLED;
}

public CmdDelLaser(this)
{
    if (!is_user_alive(this))
        return PLUGIN_HANDLED;

    if (zp_get_user_zombie(this))
        return PLUGIN_HANDLED;

    if (task_exists(this+TASK_SETLASER))
        return PLUGIN_HANDLED;

    new iBody, pEnt;

    get_user_aiming(this, pEnt, iBody, 128);

    if (!is_valid_ent(pEnt))
        return PLUGIN_HANDLED;

    new szClassName[32];

    entity_get_string(pEnt, EV_SZ_classname, szClassName, charsmax(szClassName));

    if (!equal(szClassName, "zp_sentry"))
        return PLUGIN_HANDLED;

    if (entity_get_int(pEnt, m_pOwner) != this)
        return PLUGIN_HANDLED;

    new rgpData[1];

    rgpData[0] = pEnt;

    set_task(3.0, "TaskDelLaser", this+TASK_DELLASER, rgpData, sizeof rgpData);
    set_task(0.27, "TaskIdle", this+TASK_IDLE, rgpData, sizeof rgpData, "b");
    
    BarTime(this, 3);
    emit_sound(this, CHAN_ITEM, building, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_HANDLED;
}

public CmdUndelLaser(this)
{
    if (!task_exists(this+TASK_DELLASER))
        return PLUGIN_HANDLED;

    Tripmine_Kill(this);
    return PLUGIN_HANDLED;
}

public TaskIdle(rgpData[], iTaskId)
{
    new Float:vecVelocity[3], pEnt, iBody;

    new pPlayer = iTaskId - TASK_IDLE;

    get_user_aiming(pPlayer, pEnt, iBody, 128);
    entity_get_vector(pPlayer, EV_VEC_velocity, vecVelocity);

    if (vector_length(vecVelocity) > 6.0 || task_exists(pPlayer+TASK_DELLASER) && rgpData[0] != pEnt)
        Tripmine_Kill(pPlayer);
}

public TaskSetLaser(rgpData[], iTaskId)
{
    new pPlayer = iTaskId - TASK_SETLASER;

    if (g_bCantPlant[pPlayer])
    {
        client_printcolor(pPlayer, "!y[!gZP!y]: Couldn't plant !gSentry!y.");
        Tripmine_Kill(pPlayer);
        return;
    }
    
    g_iTripmine[pPlayer] -= 1;

    if (!g_iTripmine[pPlayer])
        client_printcolor(pPlayer, "!y[!gZP!y]: Out Of Sentries!y!");
    else
        client_printcolor(pPlayer, "!y[!gZP!y]: You have !g%d !ymore Sentry to plant", g_iTripmine[pPlayer]);

    remove_task(pPlayer+TASK_IDLE);

    Tripmine_Render(rgpData[0]);

    entity_set_float(rgpData[0], EV_FL_nextthink, get_gametime() + 2.5);
    entity_set_float(rgpData[0], m_flPowerUp, 1.0);
    entity_set_int(rgpData[0], EV_INT_rendermode, kRenderNormal);

    emit_sound(rgpData[0], CHAN_VOICE, "weapons/sentry_deploy.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    // emit_sound(rgpData[0], CHAN_BODY, "weapons/mine_charge.wav", 0.2, ATTN_NORM, 0, PITCH_NORM);
    // set_rendering(rgpData[0], kRenderFxGlowShell, 15, 15, 225, kRenderNormal, 25)
}

public TaskDelLaser(rgpData[], iTaskId)
{
    if (!is_valid_ent(rgpData[0]))
        return;
    
    new pPlayer = iTaskId - TASK_DELLASER;

    g_iTripmineHealth[pPlayer][g_iTripmine[pPlayer]] = floatround(entity_get_float(rgpData[0], EV_FL_health));

    RemoveRedDot(rgpData[0]); // [FIX] Remove red dot sprite when reclaiming sentry
    remove_entity(rgpData[0]);
    remove_task(pPlayer+TASK_IDLE);

    // emit_sound(pPlayer, CHAN_ITEM, "weapons/building.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    // emit_sound(pPlayer, CHAN_ITEM, building, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    g_iTripmine[pPlayer]++;
}

public zp_user_humanized_post(this)
{
	g_iTripmine[this] = 0;

	Tripmine_Kill(this);
}

public zp_user_infected_post(this)
{
    g_iTripmine[this] = 0;

    Tripmine_Kill(this);
}

public remove_preview(id)
{
    g_iTripmine[id] = 0;

    Tripmine_Kill(id);
}

public zp_extra_item_selected(pPlayer, iItemId)
{
    if (iItemId != g_iSentryId)
        return PLUGIN_CONTINUE;
    
     // 1. Class check (Only block survivors)
     if (zp_get_user_survivor(pPlayer))
{
    client_printcolor(pPlayer, "!y[!gZP!y]: ^3Action Blocked^1! Survivor cannot buy Sentry.");
    client_cmd(pPlayer, "spk %s", g_accessdeny_menu);
    return ZP_PLUGIN_HANDLED;
}
    
    // 2. Personal "One per round" check
    if (g_TripmineBought[pPlayer])
    {
        client_printcolor(pPlayer, "!y[!gZP!y]: You can only buy one !gSentry !yper Round!"); 
        client_cmd(pPlayer, "spk %s", g_accessdeny_menu)
        return ZP_PLUGIN_HANDLED;
    }
    
    // 3. Global Round Limit check
    if (g_total_sentry_sold >= g_round_sentry_limit)
    {
        client_printcolor(pPlayer, "!y[!gZP!y]: Round limit reached! Only !g%d !yplayers can buy Sentry per round.", g_round_sentry_limit);
        client_cmd(pPlayer, "spk %s", g_accessdeny_menu)
        return ZP_PLUGIN_HANDLED;
    }
    
    // ===== VALID PURCHASE — APPLY EFFECTS =====
    g_TripmineBought[pPlayer] = true;
    // Bot limit: max 2 bots per round
    if (is_user_bot(pPlayer) && g_sentry_bot_sold >= BOT_SENTRY_LIMIT)
        return ZP_PLUGIN_HANDLED;

    g_total_sentry_sold++; // Increment global counter
    if (is_user_bot(pPlayer)) g_sentry_bot_sold++;
    
    new iHealth = get_pcvar_num(cvar_sentry_health);
    g_iTripmineHealth[pPlayer][g_iTripmine[pPlayer]] = iHealth;
    g_iTripmine[pPlayer] += 1;
    
    // emit_sound(pPlayer, CHAN_BODY, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    client_cmd(pPlayer, "spk %s", g_sound_menu)   
    
    // Broadcast who bought it and the current count
    new szName[32];
    get_user_name(pPlayer, szName, charsmax(szName));
    client_printcolor(0, "!y[!gZP!y]: !g%s !ypurchased a Sentry! !g[!y%d!g/!y%d!g]", szName, g_total_sentry_sold, g_round_sentry_limit);
    
    return PLUGIN_CONTINUE; // Allow ZP to take the ammo packs
}

public CBasePlayer_Killed_Post(this)
{
    g_iTripmine[this] = 0;

    Tripmine_Kill(this);
}

public CBasePlayer_TakeDamage_Pre(this, pInflictor, pAttacker, Float:flDamage)
{
    if (!is_valid_ent(pInflictor))
        return HAM_IGNORED;

    static szClassName[32];
    entity_get_string(pInflictor, EV_SZ_classname, szClassName, charsmax(szClassName));

    // Check if damage is from Sentry Bullets or Sentry Explosion
    if (equal(szClassName, "zp_sentry") || equal(szClassName, "zp_sentry_exp"))
    {
        if (!zp_get_user_zombie(this))
            return HAM_SUPERCEDE;

        // If it's the Sentry Gun firing (the bullets)
        if (equal(szClassName, "zp_sentry"))
        {
            // FORCE the damage to be your constant, ignoring knife multipliers
            SetHamParamFloat(4, SENTRY_DAMAGE_PER_SHOT);
            SetHamParamInteger(5, DMG_GENERIC);
        }
        else // It's the explosion
        {
            SetHamParamInteger(5, DMG_GENERIC);
            // Explosion scaling already handled in Tripmine_Explosion, but we enforce it here
            SetHamParamFloat(4, floatmax(flDamage, 25.0));
        }
        
        // Ensure the attacker is the correct player
        SetHamParamEntity(3, entity_get_int(pInflictor, m_pOwner));

        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

public OnFreeEntPrivateData(this)
{
    new szClassName[32];

    entity_get_string(this, EV_SZ_classname, szClassName, charsmax(szClassName));

    if (!equal(szClassName, "zp_sentry"))
        return FMRES_IGNORED;

    new Array:hDmgTime = Array:entity_get_int(this, m_rgpDmgTime);

    // beam removed: nothing to clean up here

    ArrayDestroy(hDmgTime);
    return FMRES_IGNORED;
}
public Tripmine_Spawn(pOwner)
{
    new pTripmine = create_entity("info_target");
    new Array:hDmgTime = ArrayCreate(1, 1);

    for (new i = 0; i < MAXPLAYERS+1; i++)
        ArrayPushCell(hDmgTime, 0.0);

    entity_set_int(pTripmine, EV_INT_movetype, MOVETYPE_FLY);
    entity_set_int(pTripmine, EV_INT_solid, SOLID_NOT);

    entity_set_model(pTripmine, "models/sentry.mdl");

    // entity_set_float(pTripmine, EV_FL_scale, 6.0);
    entity_set_size(
        pTripmine,
        Float:{-8.0, -8.0, -8.0},
        Float:{ 8.0,  8.0,  40.0}
    );

    new Float:ang[3];
    ang[0] = 270.0;
    ang[1] = 0.0;
    ang[2] = 0.0;
    entity_set_vector(pTripmine, EV_VEC_angles, ang);

    entity_set_int(pTripmine, EV_INT_body, 11);
    entity_set_int(pTripmine, EV_INT_sequence, TRIPMINE_WORLD);
    entity_set_string(pTripmine, EV_SZ_classname, "zp_sentry");
    entity_set_int(pTripmine, EV_INT_rendermode, kRenderTransAdd);
    entity_set_float(pTripmine, EV_FL_renderamt, 200.0);

    entity_set_int(pTripmine, m_pOwner, pOwner);
    entity_set_int(pTripmine, m_rgpDmgTime, _:hDmgTime);

    entity_set_float(
        pTripmine,
        EV_FL_health,
        float(g_iTripmineHealth[pOwner][g_iTripmine[pOwner] - 1])
    );
    entity_set_float(pTripmine, EV_FL_max_health, 455.0);

    entity_set_float(pTripmine, EV_FL_nextthink, get_gametime() + 0.02);

    // ===============================
    // PREVIEW STATE (CRITICAL FIX)
    // ===============================
    entity_set_int(pTripmine, EV_INT_iuser2, 0); // 0 = preview / NOT armed

    // init sentry state
    g_SentryFireMode[pTripmine] = SENTRY_FIREMODE_NO;
    g_SentryTarget[pTripmine]   = 0;
    g_SentryLevel[pTripmine]    = 0;
    g_SentryLastFire[pTripmine] = 0.0;

    // start brain (it will NOT shoot while preview)
    set_task(0.1, "sentry_core_think", pTripmine);

    return pTripmine;
}

public Tripmine_TakeDamage_Pre(this, pInflictor, pAttacker)
{
    if (!FClassnameIs(this, "zp_sentry"))
        return HAM_IGNORED;

    if (!is_user_alive(pAttacker))
        return HAM_SUPERCEDE;

    if (!zp_get_user_zombie(pAttacker))
        return HAM_SUPERCEDE;

    return HAM_IGNORED;
}

public Tripmine_TakeDamage_Post(this, pInflictor, pAttacker)
{
    if (!FClassnameIs(this, "zp_sentry"))
        return;

    if (GetHamReturnStatus() == HAM_SUPERCEDE)
        return;

    emit_sound(this, CHAN_ITEM, glass, 0.4, ATTN_NORM, 0, PITCH_NORM);

    Tripmine_Render(this);
}

// 💀 [PRE] Fires BEFORE engine removes entity - this is where we intercept
public Tripmine_Killed_Pre(this, pAttacker, shouldgib)
{
    if (!FClassnameIs(this, "zp_sentry"))
        return HAM_IGNORED;

    // Block the engine from killing/removing the entity
    // We take control and play the die animation ourselves
    Sentry_StartDeathAnim(this, pAttacker);
    return HAM_SUPERCEDE;
}

public Tripmine_Killed_Post(this, pAttacker)
{
    // This should rarely fire now - TakeDamage_Pre handles death animation
    // But keep as fallback for edge cases (e.g. kill via console)
    if (!FClassnameIs(this, "zp_sentry"))
        return;

    RemoveRedDot(this);
}

// 💀 [DEATH ANIM] Called from TakeDamage_Pre when sentry receives a lethal hit
Sentry_StartDeathAnim(this, pAttacker)
{
    RemoveRedDot(this);

    // Save origin + owner for the explosion that fires after animation
    new Float:vecOrigin[3];
    entity_get_vector(this, EV_VEC_origin, vecOrigin);
    g_SentryDeathOrigin[this][0] = vecOrigin[0];
    g_SentryDeathOrigin[this][1] = vecOrigin[1];
    g_SentryDeathOrigin[this][2] = vecOrigin[2];
    g_SentryDeathOwner[this]     = entity_get_int(this, m_pOwner);

    // Lock the entity - no more damage, no collision, stop all thinking
    set_pev(this, pev_takedamage, DAMAGE_NO);
    set_pev(this, pev_solid,      SOLID_NOT);
    set_pev(this, pev_movetype,   MOVETYPE_NONE);
    set_pev(this, pev_health,     1.0);
    set_pev(this, pev_deadflag,   DEAD_NO);

    // Stop all sentry tasks
    remove_task(this);
    remove_task(this + TASK_IDLE);

    // ✅ [SYNC FIX] Disarm brain so register_think returns immediately during death anim.
    // Without this, sentry_core_think() keeps firing every 0.2s (pev_nextthink can't be
    // stopped by remove_task), recreating the red dot + sending muzzle flash messages for
    // ~1s after death. Setting iuser2=0 makes the think guard exit instantly.
    entity_set_int(this, EV_INT_iuser2, 0);
    g_SentryFireMode[this] = SENTRY_FIREMODE_NO;
    g_SentryTarget[this]   = 0;

    // 💀 Play the die sequence
    set_pev(this, pev_sequence,  SENTRY_SEQ_DIE);
    set_pev(this, pev_framerate, 1.0);
    set_pev(this, pev_animtime,  get_gametime());

    // 🔊 Play random death sound
    new szDieSound[64];
    formatex(szDieSound, charsmax(szDieSound), "items/sentry_die%d.wav", random_num(1, 2));
    emit_sound(this, CHAN_VOICE, szDieSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    // 💨 Black smoke rising from sentry
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_SMOKE);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2] + 20.0);
    write_short(g_SmokeSprite);
    write_byte(15);   // scale (x10)
    write_byte(8);    // framerate
    message_end();

    // Schedule explosion + removal after die animation (~1.4s = 21 frames @ 15fps)
    set_task(1.4, "Sentry_DeathFinish", this + TASK_SENTRY_DIE);

    // Award bonus to attacker if zombie
    if (!is_user_alive(pAttacker) || !zp_get_user_zombie(pAttacker))
        return;

    new szName[32];
    get_user_name(pAttacker, szName, charsmax(szName));

    new iBonus = get_pcvar_num(cvar_sentry_bonus);
    zp_set_user_ammo_packs(pAttacker, zp_get_user_ammo_packs(pAttacker) + iBonus);

    client_printcolor(0, "!y[!gZP!y]: !g%s !yearned !g$%d !yfor destroying !gCombine Sentry!y!", szName, iBonus);
}

// 💀 [DEATH FINISH] Fires after die animation completes
public Sentry_DeathFinish(taskid)
{
    new ent = taskid - TASK_SENTRY_DIE;
    if (!is_valid_ent(ent))
        return;

    // Clean up and remove the sentry entity
    RemoveEntity(ent);
}

public Tripmine_Explosion(const Float:vecOrigin[3], pOwner)
{
    new pExplosion = create_entity("env_explosion");
    if (!pExplosion)
        return;

    entity_set_origin(pExplosion, vecOrigin);
    entity_set_string(pExplosion, EV_SZ_classname, "zp_sentry_exp");
    entity_set_int(pExplosion, EV_INT_iuser1, pOwner);

    // Visual explosion only (no engine damage)
    entity_set_int(pExplosion, EV_INT_spawnflags, SF_ENVEXPLOSION_NODAMAGE);
    DispatchKeyValue(pExplosion, "iMagnitude", "60");
    DispatchSpawn(pExplosion);
    force_use(pExplosion, pExplosion);

    // Explosion sound
    emit_sound(pExplosion, CHAN_WEAPON, "weapons/explode3.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);

    // Apply manual damage to nearby zombies only
    new iVictim = -1;
    const Float:radius = 60.0;
    new Float:vOrigin[3];
    new Float:dist;

    while ((iVictim = find_ent_in_sphere(iVictim, vecOrigin, radius)) != 0)
    {
        if (!is_user_alive(iVictim))
            continue;

        // Damage only zombies, not humans
        if (!zp_get_user_zombie(iVictim))
            continue;

        entity_get_vector(iVictim, EV_VEC_origin, vOrigin);
        dist = get_distance_f(vecOrigin, vOrigin);

        // Linear damage falloff (max near center)
        new Float:damage = 2.0 * (1.0 - (dist / radius));
        if (damage < 0.0) damage = 0.0;

        // FIXED LINE: 
        // iVictim = The Zombie
        // pExplosion = The "Weapon" (Inflictor)
        // pOwner = You (Attacker)
        ExecuteHamB(Ham_TakeDamage, iVictim, pExplosion, pOwner, damage, DMG_BLAST);
    }

    // Remove explosion entity after short delay
    set_task(0.5, "RemoveEntity", pExplosion);
}

public RemoveEntity(ent)
{
    if (!is_valid_ent(ent))
        return;

    // stop thinker task bound to this entity
    remove_task(ent);

    // clear sentry state
    g_SentryTarget[ent]       = 0;
    g_SentryFireMode[ent]     = SENTRY_FIREMODE_NO;
    g_SentryLevel[ent]        = 0;
    
    // --- NEW RESET ---
    g_SentryState[ent]        = 0; 
    g_SentryTimer[ent]        = 0.0;
    // -----------------
    RemoveRedDot(ent); // [FIX] Remove red dot sprite when removing entity

    remove_entity(ent);
}

public Tripmine_Think(this)
{
    // FIX: Check if the entity is valid. 
    // This prevents "Run time error 10: native error" if the entity was removed mid-frame.
    if (!is_valid_ent(this))
        return;

    static Float:flGameTime;
    flGameTime = get_gametime();

    // Check if the sentry is in its "Active/Glowing" state
    if (entity_get_int(this, EV_INT_renderfx) == kRenderFxGlowShell) 
    {
        static Float:vecEnd[3], Float:vecSrc[3];

        entity_get_vector(this, EV_VEC_origin, vecSrc);
        entity_get_vector(this, m_vecEnd, vecEnd);

        // If the Sentry is currently powering up (Arming)
        if (entity_get_float(this, m_flPowerUp) == 1.0)
        {
            static Float:vecAngles[3], Float:vecDir[3];

            entity_get_vector(this, EV_VEC_angles, vecAngles);
            entity_get_vector(this, EV_VEC_origin, vecSrc);

            // Calculate where the laser/view should point
            MakeAimVectors(vecAngles);
            global_get(glb_v_forward, vecDir);
            xs_vec_mul_scalar(vecDir, 2048.0, vecDir);
            xs_vec_add(vecSrc, vecDir, vecEnd);

            // Make the sentry physical so it can be shot/destroyed
            entity_set_int(this, EV_INT_solid, SOLID_BBOX);
            entity_set_float(this, EV_FL_takedamage, DAMAGE_YES);
            entity_set_int(this, EV_INT_flags, entity_get_int(this, EV_INT_flags) | FL_MONSTERCLIP);

            // Set iuser2 to 1 -> This tells the core logic the Sentry is now ALLOWED TO SHOOT
            entity_set_int(this, EV_INT_iuser2, 1);

            entity_set_vector(this, m_vecEnd, vecEnd);
            entity_set_float(this, m_flPowerUp, 0.0);
        }

        // Trace a line to see if anything is in front of the sentry
        engfunc(EngFunc_TraceLine, vecSrc, vecEnd, IGNORE_MONSTERS, this, 0);

        static Float:flFraction;
        get_tr2(0, TR_flFraction, flFraction);

        if (flFraction < 1.0)
            get_tr2(0, TR_vecEndPos, vecEnd);
    }
    else
    {
        // If not in glowing state, handle the relinking logic
        Tripmine_RelinkTripmine(this);
    }

    // Schedule the next think cycle (approx 43 times per second)
    entity_set_float(this, EV_FL_nextthink, flGameTime + 0.023);
}

public Tripmine_TraceAttack_Pre(this, pAttacker, Float:flDamage, Float:vecDir[3], ptr, bitsDamageType)
{
    if (!FClassnameIs(this, "zp_sentry"))
        return HAM_IGNORED;

    //  Allow bullets to pass through and continue hitting enemies
    if (bitsDamageType & DMG_BULLET)
    {
        // Ignore bullet collision but DO NOT block the trace itself
        set_tr2(ptr, TR_flFraction, 1.0);
        return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

Tripmine_RelinkTripmine(this)
{
    static hTr, pOwner, pHit, Float:vecPlaneNormal[3], Float:vecSrc[3], Float:vecEnd[3];

    pOwner = entity_get_int(this, m_pOwner);

    GetGunPosition(pOwner, vecSrc);
    GetAimPosition(pOwner, 128, vecEnd);

    hTr = create_tr2();
    engfunc(EngFunc_TraceLine, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, pOwner, hTr);

    static iBody, Float:flFraction, Float:vecAngles[3], Float:vecVelocity[3];

    get_tr2(hTr, TR_flFraction, flFraction);
    pHit = max(get_tr2(hTr, TR_pHit), 0);

    velocity_by_aim(pOwner, 128, vecVelocity);
    xs_vec_neg(vecVelocity, vecVelocity);
    vector_to_angle(vecVelocity, vecAngles);

    g_bCantPlant[pOwner] = true;
    iBody = 11;

    if (flFraction < 1.0)
    {
        get_tr2(hTr, TR_vecPlaneNormal, vecPlaneNormal);
        get_tr2(hTr, TR_vecEndPos, vecEnd);

        xs_vec_mul_scalar(vecPlaneNormal, 8.0, vecPlaneNormal);
        xs_vec_add(vecEnd, vecPlaneNormal, vecEnd);
        
        // [FIX BUG 2] Only allow placement on near-horizontal surfaces (floors).
        // vecPlaneNormal[2] > 0.7 means the surface normal points mostly upward,
        // i.e. it is a floor. Walls have normals close to 0 and ceilings are negative.
        if (!pHit && vecPlaneNormal[2] > 0.7)
        {
            vector_to_angle(vecPlaneNormal, vecAngles);
            g_bCantPlant[pOwner] = false;
            iBody = 15;
        }
    }

    // ----- apply model-correction so the sandbag stands vertically -----
    new Float:ang[3];
    ang[0] = vecAngles[0];
    ang[1] = vecAngles[1];
    ang[2] = vecAngles[2];

    // make the sentry stand upright
    ang[0] -= 90.0;

    entity_set_vector(this, EV_VEC_angles, ang);
    // ------------------------------------------------------------------

    entity_set_int(this, EV_INT_body, iBody);

    // Raise sandbag slightly above ground so platform isn't buried
    vecEnd[2] += -5.0; // adjust: 4.0 = small, 8.0 = normal, 12.0 = higher

    entity_set_origin(this, vecEnd);

    // [FIX BUG 1] Use kRenderTransColor so the rendercolor is actually applied.
    // kRenderTransAdd ignores rendercolor in GoldSrc, so the model always shows
    // as white. kRenderTransColor renders the model as a tinted silhouette and
    // correctly honors the green / red rendercolor.
    if (g_bCantPlant[pOwner])
    {
        // Red - invalid spot
        entity_set_int(this, EV_INT_rendermode, kRenderTransColor);
        entity_set_vector(this, EV_VEC_rendercolor, Float:{255.0, 0.0, 0.0});
        entity_set_float(this, EV_FL_renderamt, 180.0);
    }
    else
    {
        // Green - valid spot
        entity_set_int(this, EV_INT_rendermode, kRenderTransColor);
        entity_set_vector(this, EV_VEC_rendercolor, Float:{0.0, 255.0, 0.0});
        entity_set_float(this, EV_FL_renderamt, 180.0);
    }

    free_tr2(hTr);
}
Tripmine_Kill(pOwner)
{
    new pTripmine = -1;
    new bool:bIsConnected = bool:(is_user_connected(pOwner));

    while ((pTripmine = find_ent_by_class(pTripmine, "zp_sentry")))
    {
        if (entity_get_int(pTripmine, m_pOwner) != pOwner)
            continue;

        if (!bIsConnected) 
            entity_set_int(pTripmine, m_pOwner, pTripmine);

        // [FIX] Preview entities now use kRenderTransColor (green/red tint).
        // Accept both kRenderTransColor (preview ghost) and kRenderTransAdd (legacy)
        // so that ghost sentries are always cleaned up regardless of render mode.
        new iRenderMode = entity_get_int(pTripmine, EV_INT_rendermode);
        if (iRenderMode != kRenderTransColor && iRenderMode != kRenderTransAdd)
            continue;

        // ---------------------------------
        // clear sentry state then remove
        // ---------------------------------
        g_SentryTarget[pTripmine]   = 0;
        g_SentryFireMode[pTripmine] = SENTRY_FIREMODE_NO;
        g_SentryLevel[pTripmine]    = 0;
        // ---------------------------------
        RemoveRedDot(pTripmine); // [FIX] Remove red dot sprite when picking up sentry

        remove_entity(pTripmine);
        break;
    }

    remove_task(pOwner + TASK_SETLASER);
    remove_task(pOwner + TASK_DELLASER);
    remove_task(pOwner + TASK_IDLE);

    if (bIsConnected)
        BarTime(pOwner, 0);
}

public Tripmine_Render(this)
{
    new Float:vecColor[3];
    new Float:flHealth = entity_get_float(this, EV_FL_health);

    if (get_pcvar_num(cvar_sentry_glow))
    {
        // ORIGINAL COLOR LOGIC (unchanged)
        if (flHealth > 1065.0)
        {
            vecColor[0] = 0.0;
            vecColor[1] = 0.0;
            vecColor[2] = 255.0;
        }
        else
        {
            new Float:percent = flHealth / 1065.0;
            if (percent < 0.0) percent = 0.0;
            if (percent > 1.0) percent = 1.0;

            vecColor[0] = (1.0 - percent) * 255.0;
            vecColor[1] = percent * 255.0;
            vecColor[2] = 0.0;
        }

        entity_set_int(this, EV_INT_renderfx, kRenderFxGlowShell);
        entity_set_vector(this, EV_VEC_rendercolor, vecColor);
        entity_set_float(this, EV_FL_renderamt, 25.0);
    }
    else
    {
        // GLOW OFF (SAFE)
        entity_set_int(this, EV_INT_renderfx, kRenderFxGlowShell);
        entity_set_vector(this, EV_VEC_rendercolor, Float:{0.0, 0.0, 0.0});
        entity_set_float(this, EV_FL_renderamt, 0.0);
    }

    entity_set_int(this, EV_INT_body, 1);
}

GetAimPosition(this, iDistance, Float:vecDest[3])
{
    static Float:vecVelocity[3], Float:vecSrc[3];

    GetGunPosition(this, vecSrc);

    velocity_by_aim(this, iDistance, vecVelocity);
    xs_vec_add(vecSrc, vecVelocity, vecDest);
}

GetGunPosition(this, Float:vecDest[3])
{
    static Float:vecViewOfs[3], Float:vecSrc[3];

    entity_get_vector(this, EV_VEC_view_ofs, vecViewOfs);
    entity_get_vector(this, EV_VEC_origin, vecSrc);

    xs_vec_add(vecSrc, vecViewOfs, vecDest);
}

BarTime(this, iTime)
{
    message_begin(MSG_ONE, g_iMsgBarTime, .player = this)
    {
        write_short(iTime);
    }
    message_end();
}

MakeAimVectors(const Float:vecAngles[3])
{
    new Float:vecTmpAngles[3];

    xs_vec_set(vecTmpAngles, vecAngles[0], vecAngles[1], vecAngles[2]);
    vecTmpAngles[0] = -vecTmpAngles[0];

    engfunc(EngFunc_MakeVectors, vecTmpAngles);
}

// visual tracer (copied + adapted)
public sentry_tracer(const Float:start[3], const Float:end[3])
{
    // Use engine message begin and engine writecoord calls (matches Tripmine_Think style)
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, start, 0);
    {
        write_byte(TE_TRACER);
        engfunc(EngFunc_WriteCoord, start[0]);
        engfunc(EngFunc_WriteCoord, start[1]);
        engfunc(EngFunc_WriteCoord, start[2]);
        engfunc(EngFunc_WriteCoord, end[0]);
        engfunc(EngFunc_WriteCoord, end[1]);
        engfunc(EngFunc_WriteCoord, end[2]);
    }
    message_end();
}

public client_PostThink(id)
{
    if (!is_user_alive(id) || !is_user_bot(id) || zp_get_user_zombie(id))
    {
        g_BotStillTime[id] = 0.0;
        return;
    }

    static Float:velocity[3];
    entity_get_vector(id, EV_VEC_velocity, velocity);

    // If bot is barely moving (velocity < 15), increment their "still time"
    if (vector_length(velocity) < 15.0)
        g_BotStillTime[id] += 0.01; // Approximate increment per frame
    else
        g_BotStillTime[id] = 0.0;
}

public task_bot_sentry_logic()
{
    if (!get_pcvar_num(cvar_bot_sentry)) 
        return;

    if (g_total_sentry_sold >= g_round_sentry_limit)
        return;

    new iBots[32], iBotCount = 0;
    new iPlayers[32], iPCount;
    get_players(iPlayers, iPCount, "ad"); // a = alive, d = bots

    for (new i = 0; i < iPCount; i++)
    {
        new id = iPlayers[i];

        if (!zp_get_user_zombie(id) && !zp_get_user_survivor(id) && !zp_get_user_ammo_packs(id) 
            && !g_TripmineBought[id] && g_BotStillTime[id] > 3.0)
        {
            iBots[iBotCount++] = id;
        }
    }

    if (iBotCount > 0)
    {
        new selectedBot = iBots[random(iBotCount)];
        Bot_PlantSentry(selectedBot);
    }
}

Bot_PlantSentry(id)
{
    // Double check limits before proceeding
    if (g_total_sentry_sold >= g_round_sentry_limit)
        return;

    // Simulate purchase for the bot
    g_TripmineBought[id] = true;
    g_total_sentry_sold++;
    
    new iHealth = get_pcvar_num(cvar_sentry_health);
    g_iTripmineHealth[id][0] = iHealth;
    g_iTripmine[id] = 1;

    // --- FIND GROUND IN FRONT OF BOT ---
    new Float:vOrigin[3], Float:vForward[3], Float:vEnd[3], Float:vTraceEnd[3], Float:vAngles[3];
    entity_get_vector(id, EV_VEC_origin, vOrigin);
    entity_get_vector(id, EV_VEC_angles, vAngles);
    
    vAngles[0] = 0.0; // Force horizontal forward vector
    angle_vector(vAngles, ANGLEVECTOR_FORWARD, vForward);
    xs_vec_mul_scalar(vForward, 64.0, vForward); // 64 units in front
    xs_vec_add(vOrigin, vForward, vEnd);
    
    vTraceEnd = vEnd;
    vTraceEnd[2] -= 100.0; // Trace downward to find the floor
    
    new hTr = create_tr2();
    engfunc(EngFunc_TraceLine, vEnd, vTraceEnd, IGNORE_MONSTERS, id, hTr);
    
    new Float:flFraction;
    get_tr2(hTr, TR_flFraction, flFraction);
    
    if (flFraction < 1.0) // Floor found!
    {
        get_tr2(hTr, TR_vecEndPos, vEnd);
        new Float:vNormal[3];
        get_tr2(hTr, TR_vecPlaneNormal, vNormal);

        // Spawn the Sentry [cite: 332]
        new pEnt = Tripmine_Spawn(id);
        
        // Final position (lifted 5 units so it's not buried in the ground) [cite: 374]
        vEnd[2] += 5.0; 
        entity_set_origin(pEnt, vEnd);
        
        // --- PREVENT DISTORTION ---
        // Calculate angles from floor normal and subtract 90 degrees to stand upright 
        vector_to_angle(vNormal, vAngles);
        vAngles[0] -= 90.0; 
        entity_set_vector(pEnt, EV_VEC_angles, vAngles);

        // --- DIRECT ACTIVATION ---
        g_iTripmine[id] = 0;
        Tripmine_Render(pEnt); // [cite: 380]
        entity_set_float(pEnt, EV_FL_nextthink, get_gametime() + 2.0);
        entity_set_float(pEnt, m_flPowerUp, 1.0); // [cite: 362]
        entity_set_int(pEnt, EV_INT_rendermode, kRenderNormal);
        entity_set_int(pEnt, EV_INT_iuser2, 1); // Arm it immediately [cite: 361]

        emit_sound(pEnt, CHAN_VOICE, "weapons/sentry_deploy.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        
        // Broadcast the action
        new szName[32];
        get_user_name(id, szName, charsmax(szName));
        client_printcolor(0, "!y[!gZP!y]: !g%s (Bot) !ycamped and deployed a Sentry! !g[!y%d!g/!y%d!g]", szName, g_total_sentry_sold, g_round_sentry_limit);
    }
    else
    {
        // No floor found, cancel and refund the global slot
        g_total_sentry_sold--;
        g_TripmineBought[id] = false;
        g_iTripmine[id] = 0;
    }
    free_tr2(hTr);
}

// ----- turn only yaw toward target (preserve pitch for model animation) -----
public sentry_turntotarget(ent, Float:sentryOrigin[3], target, Float:targetOrigin[3])
{
    if (!is_valid_ent(ent)) return;

    static Float:dir[3], Float:angles[3], Float:curAng[3];

    xs_vec_sub(targetOrigin, sentryOrigin, dir);
    vector_to_angle(dir, angles);

    // Preserve current pitch (so model animation can control it)
    entity_get_vector(ent, EV_VEC_angles, curAng);

    // Only change yaw (and zero roll)
    curAng[1] = angles[1];
    curAng[2] = 0.0;


    // [RED DOT] Update position when sentry rotates
    if (g_SentryFireMode[ent] == SENTRY_FIREMODE_YES)
        UpdateRedDotPosition(ent);
    entity_set_vector(ent, EV_VEC_angles, curAng);
}

// Add/Uncomment these helper functions ABOVE sentry_core_think

public sentry_anim_shoot(ent)
{
    if (!is_valid_ent(ent)) return;

    // CRITICAL FIX: If we are already in firing mode, DO NOT reset the animation.
    // This prevents the "jerking" (resetting to frame 0 repeatedly).
    if (g_SentryFireMode[ent] == SENTRY_FIREMODE_YES) 
    {
        // Red dot may have been removed while sentry was lifted — recreate if missing
        if (!is_valid_ent(g_SentryRedDot[ent]))
            CreateRedDot(ent);
        return;
    }

    // Set sequence to shoot
    entity_set_int(ent, EV_INT_sequence, SENTRY_SEQ_SHOOT);
    entity_set_float(ent, EV_FL_animtime, get_gametime());
    entity_set_float(ent, EV_FL_framerate, 1.0); // Make sure it plays
    
    // Mark as firing
    g_SentryFireMode[ent] = SENTRY_FIREMODE_YES;
    CreateRedDot(ent); // [RED DOT] Show firing indicator
}

public sentry_anim_idle(ent)
{
    if (!is_valid_ent(ent)) return;

    // Only switch to idle if we are currently firing/aiming
    if (g_SentryFireMode[ent] == SENTRY_FIREMODE_NO)
        return;

    entity_set_int(ent, EV_INT_sequence, TRIPMINE_WORLD);
    entity_set_float(ent, EV_FL_animtime, get_gametime());
    entity_set_float(ent, EV_FL_framerate, 0.0); // Freeze idle if needed
    
    // Mark as not firing
    g_SentryFireMode[ent] = SENTRY_FIREMODE_NO;
    RemoveRedDot(ent); // [RED DOT] Hide firing indicator
}

public sentry_core_think(ent)
{
    if (!is_valid_ent(ent))
        return;

    static Float:now;
    now = get_gametime();

    entity_set_float(ent, EV_FL_nextthink, now + THINK_INTERVAL);

    if (entity_get_int(ent, EV_INT_iuser2) != 1)
        return;

    new id = entity_get_int(ent, m_pOwner);
    if (id <= 0 || !is_user_alive(id) || zp_get_user_zombie(id))
    {
        RemoveEntity(ent);
        return;
    }

    // --- SLEEP / ACTIVE CYCLE ---
    if (g_SentryState[ent] == 1) 
    {
        if (now >= g_SentryTimer[ent])
        {
            g_SentryState[ent] = 0; 
            g_SentryTimer[ent] = 0.0;
            // emit_sound(ent, CHAN_ITEM, "weapons/mine_activate.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        }
        else
        {
            sentry_anim_idle(ent);
            return; 
        }
    }

    static Float:sentryOrigin[3];
    entity_get_vector(ent, EV_VEC_origin, sentryOrigin);
    sentryOrigin[2] += 40.0; 

    new prevTarget = g_SentryTarget[ent]; 

    // --- TARGET VALIDATION (just clear, don't enter search yet) ---
    if (g_SentryTarget[ent] > 0)
    {
        if (!is_user_alive(g_SentryTarget[ent]) || !zp_get_user_zombie(g_SentryTarget[ent]))
        {
            g_SentryTarget[ent] = 0;
        }
        else
        {
            static Float:targetOrigin[3];
            entity_get_vector(g_SentryTarget[ent], EV_VEC_origin, targetOrigin);
            
            if (get_distance_f(sentryOrigin, targetOrigin) > SENTRY_MAX_RANGE)
            {
                g_SentryTarget[ent] = 0;
            }
            else
            {
                new trace = create_tr2();
                engfunc(EngFunc_TraceLine, sentryOrigin, targetOrigin, IGNORE_MONSTERS, ent, trace);
                new Float:fraction;
                get_tr2(trace, TR_flFraction, fraction);
                free_tr2(trace);
                if (fraction < 0.9)
                    g_SentryTarget[ent] = 0;
            }
        }
    }

    // --- TARGET ACQUISITION ---
    if (!g_SentryTarget[ent])
    {
        new Float:bestDist = SENTRY_MAX_RANGE;
        static Float:playerOrigin[3];
        new foundVictim = 0;

        for (new i = 1; i <= get_maxplayers(); i++)
        {
            if (!is_user_alive(i) || !zp_get_user_zombie(i)) continue;
            entity_get_vector(i, EV_VEC_origin, playerOrigin);
            new Float:dist = get_distance_f(sentryOrigin, playerOrigin);
            if (dist < bestDist)
            {
                new trace = create_tr2();
                engfunc(EngFunc_TraceLine, sentryOrigin, playerOrigin, IGNORE_MONSTERS, ent, trace);
                new Float:fraction;
                get_tr2(trace, TR_flFraction, fraction);
                free_tr2(trace);
                if (fraction >= 0.9) { bestDist = dist; foundVictim = i; }
            }
        }
        g_SentryTarget[ent] = foundVictim;
    }

    // --- ENTER SEARCH STATE only if a target was actively lost ---
    if (!g_SentryTarget[ent])
    {
        if (prevTarget > 0)
        {
            // Had a target, now lost it - start searching
            g_SentryState[ent] = SENTRY_STATE_SEARCHING;
            g_SentrySearchTimer[ent] = now + 4.0;
            StartSearchSound(ent);
        }
        else if (g_SentryState[ent] == SENTRY_STATE_SEARCHING)
        {
            if (now >= g_SentrySearchTimer[ent])
            {
                // 4 seconds passed with no target - go to sleep
                g_SentryState[ent] = 1;
                g_SentryTimer[ent] = now + SENTRY_TIME_SLEEP;
                g_SentryTarget[ent] = 0; // clear so wake-up doesn't trigger search
                StopSearchSound(ent);
                emit_sound(ent, CHAN_ITEM, sleep_sound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
                sentry_anim_idle(ent);
            }
            else
            {
                // Still in the 4-second search window
                sentry_anim_shoot(ent);
            }
        }
        else
        {
            // Completely idle - no target, not searching
            sentry_anim_idle(ent);
        }
        return; // no target, nothing more to do
    }

    // --- We have a target - cancel search state if active ---
    if (g_SentryState[ent] == SENTRY_STATE_SEARCHING)
    {
        g_SentryState[ent] = 0;
        g_SentrySearchTimer[ent] = 0.0;
        StopSearchSound(ent);
    }

    // --- SPOT SOUND & REACTION DELAY ---
    if (g_SentryTarget[ent] != prevTarget && g_SentryTarget[ent] > 0)
    {
        g_SentryAcquiredTime[ent] = now + 0.5; 
        emit_sound(ent, CHAN_ITEM, spot, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    }

    // --- SHOOTING LOGIC ---
    if (g_SentryTarget[ent] > 0 && now >= g_SentryAcquiredTime[ent])
    {
        if (g_SentryTimer[ent] == 0.0) g_SentryTimer[ent] = now + SENTRY_TIME_ACTIVE;

        if (now >= g_SentryTimer[ent])
        {
            g_SentryState[ent] = 1; 
            g_SentryTimer[ent] = now + SENTRY_TIME_SLEEP;
            g_SentryTarget[ent] = 0; // clear so wake-up doesn't trigger search
            emit_sound(ent, CHAN_ITEM, sleep_sound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
            sentry_anim_idle(ent);
            return;
        }

        static Float:targetOrigin[3];
        entity_get_vector(g_SentryTarget[ent], EV_VEC_origin, targetOrigin);
        sentry_turntotarget(ent, sentryOrigin, g_SentryTarget[ent], targetOrigin);
        sentry_anim_shoot(ent);

        if (now - g_SentryLastFire[ent] > THINKFIREFREQUENCY)
        {
            g_SentryLastFire[ent] = now;
            emit_sound(ent, CHAN_WEAPON, fire, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
            sentry_tracer(sentryOrigin, targetOrigin);

            // [FIX BUG 3] Muzzle flash at actual barrel tip.
            // sentryOrigin already has +40 on Z (eye-level offset added above).
            // We use the raw entity origin and compute the barrel tip by offsetting
            // forward along the sentry's yaw direction and up to the gun height.
            // Tune BARREL_FORWARD (units ahead) and BARREL_UP (units above base)
            // to match your sentry.mdl barrel tip exactly.
            new Float:vMuzzleBase[3], Float:vMuzzleAng[3], Float:vMuzzleFwd[3], Float:vMuzzleTip[3];
            entity_get_vector(ent, EV_VEC_origin, vMuzzleBase);
            entity_get_vector(ent, EV_VEC_angles, vMuzzleAng);
            engfunc(EngFunc_MakeVectors, vMuzzleAng);
            global_get(glb_v_forward, vMuzzleFwd);
            // Forward offset along barrel + height offset to gun
            new Float:BARREL_FORWARD = 15.0; // units in front of sentry origin
            new Float:BARREL_UP      = 42.0; // units above sentry base origin
            new Float:vMuzzleRight[3];
            global_get(glb_v_right, vMuzzleRight);

            new Float:BARREL_RIGHT = -3.0; // positive = right, negative = left

            vMuzzleTip[0] = vMuzzleBase[0] + vMuzzleFwd[0] * BARREL_FORWARD + vMuzzleRight[0] * BARREL_RIGHT;
            vMuzzleTip[1] = vMuzzleBase[1] + vMuzzleFwd[1] * BARREL_FORWARD + vMuzzleRight[1] * BARREL_RIGHT;
            vMuzzleTip[2] = vMuzzleBase[2] + BARREL_UP;

            engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vMuzzleTip, 0);
            write_byte(TE_SPRITE);
            engfunc(EngFunc_WriteCoord, vMuzzleTip[0]);
            engfunc(EngFunc_WriteCoord, vMuzzleTip[1]);
            engfunc(EngFunc_WriteCoord, vMuzzleTip[2]);
            write_short(g_MuzzleSprite);
            write_byte(2);   // scale (x10, so 4 = 0.4)
            write_byte(200); // brightness
            message_end();
            ExecuteHamB(Ham_TakeDamage, g_SentryTarget[ent], ent, id, SENTRY_DAMAGE_PER_SHOT, DMG_GENERIC);
            g_SentryDamageAccumulated[id] += SENTRY_DAMAGE_PER_SHOT;

            if (g_SentryDamageAccumulated[id] >= DAMAGE_FOR_AMMO)
            {
                zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + 1);
                g_SentryDamageAccumulated[id] -= DAMAGE_FOR_AMMO;
            }

            static Float:vPush[3], Float:vCurrent[3];
            xs_vec_sub(targetOrigin, sentryOrigin, vPush);
            xs_vec_normalize(vPush, vPush);

            if (entity_get_int(g_SentryTarget[ent], EV_INT_flags) & FL_ONGROUND)
                xs_vec_mul_scalar(vPush, HITSD * GROUNDPUSH, vPush); 
            else
                xs_vec_mul_scalar(vPush, AERIALPUSH, vPush); 

            entity_get_vector(g_SentryTarget[ent], EV_VEC_velocity, vCurrent);
            vCurrent[0] += vPush[0];
            vCurrent[1] += vPush[1];
            vCurrent[2] += vPush[2];
            entity_set_vector(g_SentryTarget[ent], EV_VEC_velocity, vCurrent);
        }
    }
    else
    {
        sentry_anim_idle(ent);
    }
}

public sentry_reset_anim(ent)
{
    if (!is_valid_ent(ent))
        return;

    // restore world/idle sequence; use pev_animtime so animation timing is correct
    set_pev(ent, pev_sequence, TRIPMINE_WORLD);
    set_pev(ent, pev_frame, 0.0);
    set_pev(ent, pev_framerate, 0.0);
    set_pev(ent, pev_animtime, get_gametime());

    // clear firing state
    g_SentryFireMode[ent] = SENTRY_FIREMODE_NO;
    RemoveRedDot(ent); // [RED DOT] Clear firing indicator on reset
}

public sentry_simple_damagetoplayer(ent, targetPlayer, Float:damage)
{
    if (!is_user_connected(targetPlayer)) return;
    if (!is_user_alive(targetPlayer)) return;
    if (!is_valid_ent(ent)) return;

    new owner = entity_get_int(ent, m_pOwner);
    if (owner <= 0 || !is_user_connected(owner))
        return;

    // --- APPLY KNOCKBACK (Direct Math) ---
    new Float:vecOrigin[3], Float:vecTarget[3], Float:vecDir[3];
    entity_get_vector(ent, EV_VEC_origin, vecOrigin);
    entity_get_vector(targetPlayer, EV_VEC_origin, vecTarget);
    
    // Get direction from Sentry to Player
    xs_vec_sub(vecTarget, vecOrigin, vecDir);
    xs_vec_normalize(vecDir, vecDir);
    
    // Scale by damage and your constant HITSD
    xs_vec_mul_scalar(vecDir, damage * HITSD, vecDir);
    
    // Add to player velocity
    new Float:vecVel[3];
    entity_get_vector(targetPlayer, EV_VEC_velocity, vecVel);
    xs_vec_add(vecVel, vecDir, vecVel);
    entity_set_vector(targetPlayer, EV_VEC_velocity, vecVel);

    // --- APPLY DAMAGE ---
    // We use the sentry (ent) as the inflictor/attacker so it tracks correctly
    ExecuteHamB(
        Ham_TakeDamage,
        targetPlayer,   // Victim
        ent,            // Inflictor
        ent,            // Attacker
        damage,
        DMG_GENERIC
    );
}

FClassnameIs(this, szClassName[])
{
    new _szClassName[32];

    if (!is_valid_ent(this))
        return 0;

    entity_get_string(this, EV_SZ_classname, _szClassName, charsmax(_szClassName));

    if (equali(szClassName, _szClassName))
        return 1;

    return 0;
}

public showMenuLasermine(id)
{
    new menuid = menu_create("\ySentry Menu\d 1/1", "menuLasermine");
    menu_setprop(menuid, MPROP_NUMBER_COLOR, "\y");
    menu_additem(menuid, "Plant Sentry");
    menu_additem(menuid, "Remove Sentry");
    menu_display(id, menuid, 0);
}

public menuLasermine(id, menuid, item)
{
    if (!is_user_alive(id))
        return PLUGIN_HANDLED;

    if (zp_get_user_zombie(id))
        return PLUGIN_HANDLED;

    switch(item)
    {
        case MENU_EXIT:
        {
            menu_destroy(menuid);
            return PLUGIN_HANDLED;
        }
        case 0:
        {
            if (!g_iTripmine[id])
            {
                // client_printcolor(id, "!y[!gZP!y]: Unable to buy !gSentry!y!");
                showMenuLasermine(id);
                return PLUGIN_HANDLED;
            }

            if (g_iTripmine[id])
            {
                CmdSetLaser(id);
            }

            showMenuLasermine(id);
        }
        case 1:
        {
            CmdDelLaser(id);
            showMenuLasermine(id);
        }
    }

    return PLUGIN_HANDLED;
}

stock print_colored(const index, const input [ ], const any:...) 
{  
    new message[191] 
    vformat(message, 190, input, 3) 
    replace_all(message, 190, "!y", "^1") 
    replace_all(message, 190, "!t", "^3") 
    replace_all(message, 190, "!g", "^4") 

    if(index) 
    { 
        //print to single person 
        message_begin(MSG_ONE, g_iMsgSayTxt, _, index) 
        write_byte(index) 
        write_string(message) 
        message_end() 
    } 
    else 
    { 
        //print to all players 
        new players[32], count, i, id 
        get_players(players, count, "ch") 
        for( i = 0; i < count; i ++ ) 
        { 
            id = players[i] 
            if(!is_user_connected(id)) continue; 

            message_begin(MSG_ONE_UNRELIABLE, g_iMsgSayTxt, _, id) 
            write_byte(id) 
            write_string(message) 
            message_end() 
        } 
    } 
} 

public Tripmine_ShowInfo_Post(Float:flVecStart[3], Float:flVecEnd[3], Conditions, this, Trace)
{
    if (!is_user_connected(this) || !is_user_alive(this))
        return FMRES_IGNORED;

    static iHit;
    iHit = get_tr2(Trace, TR_pHit);

    if (pev_valid(iHit))
    {
        if (pev(iHit, pev_deadflag) == DEAD_NO)
        {
            new szClassName[32], szName[32];
            pev(iHit, pev_classname, szClassName, charsmax(szClassName))

            if (equali(szClassName, "zp_sentry"))
            {
                static iOwner, iHealth;
                iOwner = pev(iHit, pev_iuser1);
                iHealth = pev(iHit, pev_health);
                get_user_name(iOwner, szName, charsmax(szName));

                set_hudmessage(200, 0, 0, -1.0, 0.60, 0, 6.0, 0.4, 0.0, 0.0, -1);
                show_hudmessage(this, "Owner: %s^nSentry HP: %d", szName, iHealth);
            }
        }
    }

    return FMRES_IGNORED;
}

stock client_printcolor(const id,const input[], any:...)
{
	new msg[191], players[32], count = 1; vformat(msg,190,input,3);
	replace_all(msg,190,"!g","^4");    // green
	replace_all(msg,190,"!y","^1");    // normal
	replace_all(msg,190,"!t","^3");    // team
	    
	if (id) players[0] = id; else get_players(players,count,"ch");
	    
	for (new i=0;i<count;i++)
	{
		if (is_user_connected(players[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE,get_user_msgid("SayText"),_,players[i]);
			write_byte(players[i]);
			write_string(msg);
			message_end();
		}
	}
}

// Apply knockback
stock tripmine_apply_plasma_knockback(ent, target)
{
    if (!is_user_alive(target))
        return;

    if (!zp_get_user_zombie(target))
        return;

    static Float:flStart[3], Float:flTarget[3];
    static Float:flDir[3], Float:flVel[3];

    new owner = entity_get_int(ent, m_pOwner);
    if (owner > 0 && is_user_connected(owner))
        pev(owner, pev_origin, flStart);
    else
        pev(ent, pev_origin, flStart);

    pev(target, pev_origin, flTarget);

    xs_vec_sub(flTarget, flStart, flDir);

    // IMPORTANT: lift from ground friction
    flDir[2] = 0.4;

    new Float:len = xs_vec_len(flDir);
    if (len <= 0.0)
        return;

    xs_vec_div_scalar(flDir, len, flDir);
    xs_vec_mul_scalar(flDir, 60.0, flDir); // actual impulse strength

    pev(target, pev_velocity, flVel);
    xs_vec_add(flVel, flDir, flVel);

    set_pev(target, pev_velocity, flVel);
}

// ==========================================
// [RED DOT SPRITE] Helper Functions
// ==========================================
CreateRedDot(iSentry)
{
    if (!is_valid_ent(iSentry)) return;
    
    // Check if red dot already exists - don't create duplicate
    if (is_valid_ent(g_SentryRedDot[iSentry])) return;
    
    // Create sprite entity
    new iRedDot = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"));
    if (!is_valid_ent(iRedDot)) return;
    
    // Set sprite model
    engfunc(EngFunc_SetModel, iRedDot, REDDOT_SPRITE);
    
    // Link to sentry
    set_pev(iRedDot, pev_owner, iSentry);
    set_pev(iRedDot, pev_movetype, MOVETYPE_NOCLIP);
    set_pev(iRedDot, pev_solid, SOLID_NOT);
    
    // Make it bright RED and visible
    set_rendering(iRedDot, kRenderFxNoDissipation, 255, 0, 0, kRenderTransAdd, 255);
    set_pev(iRedDot, pev_scale, 0.07); // Small dot size
    
    // Store the red dot ID
    g_SentryRedDot[iSentry] = iRedDot;
    
    // Position it on the sentry gun
    UpdateRedDotPosition(iSentry);
}

UpdateRedDotPosition(iSentry)
{
    new iRedDot = g_SentryRedDot[iSentry];
    if (!is_valid_ent(iRedDot)) return;
    
    new Float:vOrigin[3], Float:vAngles[3];
    entity_get_vector(iSentry, EV_VEC_origin, vOrigin);
    entity_get_vector(iSentry, EV_VEC_angles, vAngles);
    
    // Calculate directions from sentry angles
    new Float:vForward[3], Float:vUp[3], Float:vRight[3]; // <--- Added vRight
    engfunc(EngFunc_MakeVectors, vAngles);
    
    global_get(glb_v_forward, vForward);
    global_get(glb_v_up, vUp);
    global_get(glb_v_right, vRight); // <--- Get the Right vector
    
    // 1. Position Forward
    xs_vec_mul_scalar(vForward, 5.13, vForward); 
    xs_vec_add(vOrigin, vForward, vOrigin);
    
    // 2. Position Up
    xs_vec_mul_scalar(vUp, 46.09, vUp); 
    xs_vec_add(vOrigin, vUp, vOrigin);

    // 3. NEW: Position Left/Right
    // Change 3.0 to move it more/less. 
    // Use positive (3.0) for Right, negative (-3.0) for Left.
    xs_vec_mul_scalar(vRight, 1.99, vRight); 
    xs_vec_add(vOrigin, vRight, vOrigin);
    
    // Set the final red dot position
    engfunc(EngFunc_SetOrigin, iRedDot, vOrigin);
}

/*
UpdateRedDotPosition(iSentry)
{
    new iRedDot = g_SentryRedDot[iSentry];
    if (!is_valid_ent(iRedDot)) return;
    
    new Float:vOrigin[3], Float:vAngles[3];
    entity_get_vector(iSentry, EV_VEC_origin, vOrigin);
    entity_get_vector(iSentry, EV_VEC_angles, vAngles);
    
    // Calculate forward/up directions from sentry angles
    new Float:vForward[3], Float:vUp[3];
    engfunc(EngFunc_MakeVectors, vAngles);
    global_get(glb_v_forward, vForward);
    global_get(glb_v_up, vUp);
    
    // Position the dot forward and up from sentry base (gun barrel area)
    xs_vec_mul_scalar(vForward, 5.0, vForward); // Move forward to gun
    xs_vec_add(vOrigin, vForward, vOrigin);
    
    xs_vec_mul_scalar(vUp, 46.0, vUp); // Move up to eye/gun level
    xs_vec_add(vOrigin, vUp, vOrigin);
    
    // Set the red dot position
    engfunc(EngFunc_SetOrigin, iRedDot, vOrigin);
}
*/
RemoveRedDot(iSentry)
{
    new iRedDot = g_SentryRedDot[iSentry];
    if (is_valid_ent(iRedDot))
    {
        engfunc(EngFunc_RemoveEntity, iRedDot);
        g_SentryRedDot[iSentry] = 0;
    }
}


// ==========================================
// [SEARCH SOUND] Looping search sound helpers
// ==========================================
StartSearchSound(ent)
{
    if (!is_valid_ent(ent)) return;
    emit_sound(ent, CHAN_VOICE, search_sound, 0.4, ATTN_NORM, 0, PITCH_NORM);
}

StopSearchSound(ent)
{
    if (!is_valid_ent(ent)) return;
    emit_sound(ent, CHAN_VOICE, search_sound, VOL_NORM, ATTN_NORM, SND_STOP, PITCH_NORM);
}
