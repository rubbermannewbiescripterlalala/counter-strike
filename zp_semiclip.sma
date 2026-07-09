#include <amxmodx>
#include <fakemeta>
#include <xs>
#include <zombieplague>

#define PLUGIN "[ZP] Anti-Stuck Advanced Semiclip"
#define VERSION "2.0"
#define AUTHOR "Community"

#define distance_to_push 56.0 // Distance threshold to trigger auto-pushing

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    register_forward(FM_PlayerPreThink, "fw_PlayerPreThink");
    register_forward(FM_PlayerPostThink, "fw_PlayerPostThink");
}

public fw_PlayerPreThink(id) {
    if (!is_user_alive(id))
        return FMRES_IGNORED;
        
    // Loop through other players to see if we are colliding
    static i, Float:origin1[3], Float:origin2[3], Float:distance
    pev(id, pev_origin, origin1);
    
    for (i = 1; i <= 32; i++) {
        if (!is_user_alive(i) || i == id)
            continue;
            
        pev(i, pev_origin, origin2);
        distance = get_distance_f(origin1, origin2);
        
        // If we are overlapping, remove solid collision AND apply a gentle push away
        if (distance < distance_to_push) {
            set_pev(id, pev_solid, SOLID_NOT);
            
            // Push vector logic to slide players apart smoothly
            static Float:velocity[3];
            xs_vec_sub(origin1, origin2, velocity);
            xs_vec_normalize(velocity, velocity);
            xs_vec_mul_scalar(velocity, 120.0, velocity); // Push force speed
            velocity[2] = 0.0; // Don't lift players into the air
            
            set_pev(id, pev_velocity, velocity);
            return FMRES_IGNORED;
        }
    }
    return FMRES_IGNORED;
}

public fw_PlayerPostThink(id) {
    if (is_user_alive(id)) {
        set_pev(id, pev_solid, SOLID_SLIDEBOX); // Restore collision so bullets/zombies still hit
    }
    return FMRES_IGNORED;
}
