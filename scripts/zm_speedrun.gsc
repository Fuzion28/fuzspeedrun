// FuzSpeedrun: timer and splits, nothing that changes a run
#using scripts\common\utility;
#using scripts\common\weapon;
#using scripts\common\callbacks;
#using scripts\common\status_effects\effect_charm;
#using scripts\mp\zm\systems\zm_armor;
#using scripts\mp\zm\systems\agent_manager;
// hashed game scripts, same list as ProjectNexus: perks, points, overrides, bgb, round flags
#using script_3b64eb40368c1450;
#using script_6995a3eb7d571a9f;
#using script_4e3b2b1d9542e66b;
#using script_4fca32f463c5e4fa;
#using script_25a8fa2ac8997425;
#using script_3a9d7a7cfee99885;
#using script_2301d27669c5a079;
#using script_aa3bac81ad4fc8e;
#using script_427ce33ec0c820cf;
#using script_4f24ca7a470a5fa8;
#using script_4ccf8f7e270f2426;
#using script_4b576523c81e6ee3;
#using script_27623f7ac600060c;
#using script_54198e0a02e4a0cd;
#using script_7bef99a2b184bfd5;
#using script_46fecad419c065b2;
// crafting_table, gobblegum machine (both loaded by the zm core script, like magicbox)
#using script_23131bd305bbd11b;
#using script_4478f81b31480314;
#using script_724b8f06df0c96b1;
#using script_734dce84c468439b;
// armor (namespace armor), public game script
#using script_1f6b7243f8d72fef;
#using script_53d9b43dfecd95ed;
// doorbuy (door purchase), public game script
#using script_681a06cc8e9fcb34;
// zone manager (spawn zones), public game script
#using script_7b92812967b04687;
// ai move speed stack (walk/run/sprint by priority), public game script
#using script_6c2f6a14fa53759e;
// equipment give (lethal/tactical slots), public game script
#using script_6b0663a111030b30;
// zm_quest: main quest steps, jump-to-step used by the boss fight option
#using script_c1369b1abe9a0d1;
// lastStand: self revive count, public game script
#using script_8c8e132af264960;
// loot (namespace_952965bfef60cff8): loot ID <-> ref, used by the saved builds
#using script_1ade2fa7cae9593d;

#namespace zm_speedrun;

// Kinds: 0 close, 1 back, 2 submenu, 4 toggle, 5 action, 6 round, 7 powerup, 8 give weapon, 9 action with a value.

autoexec init()
{
    if ( !utility::iszm() )
    {
        return;
    }
    // FuzMenu shares this guard: the first script loaded wins, so never let both run
    if ( isdefined( level.zmm_initialized ) )
    {
        level thread menu_both_warn();
        return;
    }
    level.zmm_initialized = 1;
    level.zmm_name = "FuzSpeedrun";
    level.zmm_footer = "[{+speed_throw}] Up   [{+attack}] Down   [{+activate}] OK   [{+melee}] Back";
    level.zmm_hint = "Speedrun options are in the pause menu";
    level.zmm_visible = 12;
    level.zmm_themes = [ ( 0, 0.6, 1 ), ( 1, 0.2, 0.2 ), ( 0.2, 1, 0.35 ), ( 0.7, 0.3, 1 ), ( 1, 0.6, 0 ), ( 1, 0.85, 0.2 ) ];
    level.zmm_theme_names = [ "blue", "red", "green", "purple", "orange", "gold" ];
    // zm_mod_menu_post.lua draws the menu from zmm_view and sets zmm_lua to "1"
    setdvar( @"zmm_view", "" );
    setdvar( @"zmm_lua", "" );
    setdvar( @"zmm_exec", "" ); setdvar( @"zmm_ptimer", "" ); setdvar( @"zmm_pgums", "" ); setdvar( @"zmm_paction", "" ); setdvar( @"zmm_pshow", "" ); setdvar( @"zmm_pmode", "" ); setdvar( @"zmm_splice", "" );
    setdvar( @"zmm_hud", "" );
    setdvar( @"zmm_big", "" );
    setdvar( @"hash_3c05d1d16d772c9e", -1 );
    setdvar( @"hash_8054c9327575fd95", 0 );
    // the Lua can only write dvars that already exist
    setdvar( @"zmm_up", "0" );
    setdvar( @"zmm_down", "0" );
    setdvar( @"zmm_enter", "0" );
    setdvar( @"zmm_back", "0" );
    setdvar( @"zmm_open", "0" );
    setdvar( @"zmm_pad", "0" );
    // Old School parts that are on, read by the game-wide hooks
    level.zmm_cl = [];
    menu_build_pages();
    level callback::add( #"player_spawned", &menu_on_spawned );
    level callback::add( #"player_death", &menu_on_death );
    level callback::add( #"player_disconnect", &menu_on_disconnect );
    level thread menu_scan_players();
    level thread menu_sr_loop();
    // splitter layout (zm_splitter_post.lua) reads the speedrun data through dvars
    level thread zmsplit_bridge();
}

function menu_build_pages()
{
    level.zmm_pages = [];
    level.zmm_labels = [];
    level.zmm_toggle_keys = [];

    menu_add_page( "Main", "SPEEDRUN", [
        [ "Start speedrun", 9, "restart", 0 ],
        [ "Timer", 4, "speedrun" ],
        [ "Infinite gums", 4, "gums" ],
        [ "Close", 0, "" ]
    ] );
}

function menu_add_page( id, title, items )
{
    page = spawnstruct();
    page.title = title;
    page.items = items;
    level.zmm_pages[ id ] = page;
    foreach ( entry in items )
    {
        if ( entry[ 1 ] == 4 || entry[ 1 ] == 5 )
        {
            // literal strings: the profiles cannot rely on getarraykeys, which hashes some keys
            if ( entry[ 1 ] == 4 && !isdefined( level.zmm_labels[ entry[ 2 ] ] ) )
            {
                level.zmm_toggle_keys[ level.zmm_toggle_keys.size ] = entry[ 2 ];
            }
            level.zmm_labels[ entry[ 2 ] ] = entry[ 0 ];
        }
    }
}

function menu_scan_players()
{
    for ( i = 0; i < 480; i++ )
    {
        found = false;
        if ( isdefined( level.players ) )
        {
            foreach ( player in level.players )
            {
                if ( isdefined( player ) && isplayer( player ) && isalive( player ) && player.sessionstate == "playing" )
                {
                    found = true;
                    player thread menu_on_spawned( undefined );
                }
            }
        }
        if ( found )
        {
            return;
        }
        wait 0.25;
    }
}

function menu_on_spawned( params )
{
    if ( !isdefined( self ) || !isplayer( self ) )
    {
        return;
    }
    if ( isdefined( self.zmm ) && self.zmm.running )
    {
        return;
    }

    state = spawnstruct();
    state.running = true;
    state.is_open = false;
    state.page = "Main";
    state.cursor = 0;
    state.top = 0;
    state.stack = [];
    state.depth = 0;
    state.toggles = [];
    state.toggles[ "menu_right" ] = 1;
    state.equip_loop = 0;
    state.upgrade_loop = 0;
    state.god_loop = 0;
    state.hornet_loop = 0;
    state.points_loop = 0;
    state.has_save = 0;
    state.theme = 0;
    state.lua = 0;
    state.nav_open = getdvar( @"zmm_open" );
    state.spawn_origin = self.origin;
    state.spawn_angles = self getplayerangles();
    self.zmm = state;
    
    self thread menu_welcome();
}

function menu_on_death( params )
{
    if ( isdefined( self ) && isdefined( self.zmm ) )
    {
        menu_close();
    }
}

function menu_on_disconnect( params )
{
    if ( isdefined( self ) && isdefined( self.zmm ) )
    {
        self.zmm.running = false;
        menu_close();
    }
}

function menu_close()
{
    state = self.zmm;
    state.is_open = false;
    state.nav_open = getdvar( @"zmm_open" );
    state.stack = [];
    state.depth = 0;
    if ( istrue( state.lua ) )
    {
        setdvar( @"zmm_view", "" );
    }
    menu_hud_destroy();
}

function menu_notify( label, ok )
{
    if ( !isdefined( self ) || !isdefined( self.zmm ) )
    {
        return;
    }
    if ( ok )
    {
        text = label + " ^2OK";
    }
    else
    {
        text = label + " ^1failed";
    }
    if ( self.zmm.is_open )
    {
        menu_render();
    }
    // hud mode shows results in the kill feed: one hud string per result would fill the 256 text slots
    if ( !self.zmm.is_open || isdefined( self.zmm.hud ) )
    {
        self iprintln( text );
    }
}

function menu_is_host()
{
    // a guest can sit at level.players[ 0 ], so index 0 only counts when no player reports being host
    foreach ( player in level.players )
    {
        if ( istrue( player function_b36623eefe0028c8() ) )
        {
            return self == player;
        }
    }
    return isdefined( level.players[ 0 ] ) && self == level.players[ 0 ];
}

function menu_line_text( entry, on )
{
    if ( entry[ 1 ] == 2 )
    {
        return entry[ 0 ] + "  ^3>";
    }
    if ( entry[ 1 ] == 4 )
    {
        return entry[ 0 ] + ( on ? "  ^2ON" : "  OFF" );
    }
    return entry[ 0 ];
}

function menu_text_rows( page, cursor )
{
    count = page.items.size;
    line = "^3> " + menu_item_label( page.items[ cursor ] ) + " ^3<";
    if ( cursor > 0 )
    {
        line = "^7" + menu_item_label( page.items[ cursor - 1 ] ) + "   " + line;
    }
    if ( cursor + 1 < count )
    {
        line = line + "   ^7" + menu_item_label( page.items[ cursor + 1 ] );
    }
    return line;
}

function menu_page_list( page, top )
{
    list = "";
    for ( i = 0; i < level.zmm_visible && top + i < page.items.size; i++ )
    {
        entry = page.items[ top + i ];
        if ( i > 0 )
        {
            list += "
";
        }
        list += menu_line_text( entry, entry[ 1 ] == 4 && menu_toggle_state( entry[ 2 ] ) );
    }
    return list;
}

function menu_welcome()
{
    // spawn happens during the intro, and the intro teleports the player: wait for real walking
    // (small steps several ticks in a row) or a button press
    prev = self.origin;
    steps = 0;
    for ( i = 0; i < 600 && steps < 5; i++ )
    {
        wait 0.05;
        if ( !isdefined( self ) )
        {
            return;
        }
        if ( self adsbuttonpressed() || self attackbuttonpressed() || self usebuttonpressed() || self meleebuttonpressed() )
        {
            break;
        }
        // no distance builtin: an unknown builtin would stop the whole script from linking
        d = self.origin - prev;
        prev = self.origin;
        moved = d[ 0 ] * d[ 0 ] + d[ 1 ] * d[ 1 ];
        if ( moved > 2 && moved < 2500 )
        {
            steps++;
        }
        else
        {
            steps = 0;
        }
    }
    wait 0.5;
    if ( !isdefined( self ) || !isdefined( self.zmm ) )
    {
        return;
    }
    // what is loaded, shown on every load
    if ( isdefined( level.zmm_sr ) && level.zmm_sr.gums === "1" )
    {
        self iprintlnbold( "^5FuzSpeedrun v1.1 ^7- ^3Infinite gums ON" );
    }
    else
    {
        self iprintlnbold( "^5FuzSpeedrun v1.1 ^7- no cheats - ^2Normal game" );
    }
    self iprintln( level.zmm_hint );
}

function menu_hud_destroy()
{
    state = self.zmm;
    if ( isdefined( state.hud ) && isdefined( level.zmm_hud_destroy ) )
    {
        self [[ level.zmm_hud_destroy ]]();
    }
    state.hud = undefined;
}

function menu_hud_set( key, elem, text )
{
    hud = self.zmm.hud;
    if ( isdefined( hud.cache[ key ] ) && hud.cache[ key ] == text )
    {
        return 0;
    }
    self [[ level.zmm_hud_set ]]( key, elem, text );
    return 1;
}

function menu_item_label( entry )
{
    if ( entry[ 1 ] == 2 )
    {
        return entry[ 0 ] + "  ^3>";
    }
    if ( entry[ 1 ] == 4 )
    {
        if ( menu_toggle_state( entry[ 2 ] ) )
        {
            return entry[ 0 ] + "  ^2[ON]";
        }
        return entry[ 0 ] + "  ^1[OFF]";
    }
    return entry[ 0 ];
}

function menu_render()
{
    state = self.zmm;
    if ( !state.is_open )
    {
        return;
    }
    page = level.zmm_pages[ state.page ];
    count = page.items.size;
    position = "(" + ( state.cursor + 1 ) + "/" + count + ")";

    vis = level.zmm_visible;
    if ( state.cursor < state.top )
    {
        state.top = state.cursor;
    }
    else if ( state.cursor >= state.top + vis )
    {
        state.top = state.cursor - vis + 1;
    }

    if ( state.lua )
    {
        rows = "";
        n = 0;
        for ( ; n < vis && state.top + n < count; n++ )
        {
            rows += menu_view_row( page.items[ state.top + n ] ) + "|";
        }
        right = menu_toggle_state( "menu_right" ) ? "1" : "0";
        setdvar( @"zmm_view", "ZMM|" + state.theme + "|" + right + "|" + page.title + "|" + ( state.cursor - state.top ) + "|" + n + "|" + ( state.cursor + 1 ) + "/" + count + "|" + rows + "END" );
        return;
    }

    if ( !isdefined( state.hud ) )
    {
        // BO7 shows one centre line at a time and drops line breaks: previous / current / next on one line
        self iprintlnbold( "^5" + page.title + " ^7" + position + "   " + menu_text_rows( page, state.cursor ) );
        return;
    }

    hud = state.hud;
    menu_hud_set( "name", hud.name, level.zmm_name );
    menu_hud_set( "subtitle", hud.subtitle, page.title );
    // the whole list is one text element: 12 line elements only showed new text when it was
    // sent again ~0.3 s later, a single element (like the subtitle) shows it at once
    menu_hud_set( "list", hud.list, menu_page_list( page, state.top ) );
    bar_y = hud.line_y + ( state.cursor - state.top ) * hud.spacing;
    hud.bar.y = bar_y;
    hud.accent.y = bar_y;
    menu_hud_set( "footer", hud.footer, level.zmm_footer );
}

function menu_view_row( entry )
{
    if ( entry[ 1 ] == 2 )
    {
        return ">" + entry[ 0 ];
    }
    if ( entry[ 1 ] == 4 )
    {
        return ( menu_toggle_state( entry[ 2 ] ) ? "+" : "-" ) + entry[ 0 ];
    }
    return " " + entry[ 0 ];
}

function menu_toggle( key )
{
    state = self.zmm;
    now_on = !menu_toggle_state( key );
    state.toggles[ key ] = now_on ? 1 : 0;
    menu_apply_toggle( key );
    // "Start speedrun" restarts the map, which would forget both rows
    if ( menu_is_host() )
    {
        nengine_store_load( "fuzspeedrun", "speedrun" );
        nengine_store_set( "fuzspeedrun", key == "gums" ? "gums" : "timer", now_on ? "1" : "0" );
        nengine_store_save( "fuzspeedrun", "speedrun" );
    }
    menu_render();
}

function menu_toggle_state( key )
{
    state = self.zmm;
    if ( !isdefined( state.toggles[ key ] ) )
    {
        return false;
    }
    return istrue( state.toggles[ key ] );
}

function menu_apply_toggle( key )
{
    state = self.zmm;
    if ( key == "speedrun" && menu_toggle_state( key ) && !istrue( state.hud_loop ) )
    {
        state.hud_loop = 1;
        self thread menu_hud_loop();
    }
    if ( key == "gums" && menu_toggle_state( key ) && !istrue( state.gum_loop ) )
    {
        state.gum_loop = 1;
        self thread menu_gum_refill();
    }
    return true;
}

function menu_hud_loop()
{
    state = self.zmm;
    while ( isdefined( self ) && menu_loop_active( "speedrun" ) )
    {
        if ( menu_is_host() )
        {
            // the splitter layout (zm_splitter_post.lua) draws the timer and splits now: no text line
            setdvar( @"zmm_hud", "" );
        }
        wait 0.1;
    }
    state.hud_loop = 0;
    if ( menu_is_host() )
    {
        setdvar( @"zmm_hud", "" );
    }
}

function menu_sr_setup()
{
    map = "";
    if ( isdefined( level.mapname ) )
    {
        map = level.mapname;
    }
    sr = spawnstruct();
    if ( map == "zm_sat_ruby" )
    {
        sr.names = [ "LGM-1", "Brain", "Mars", "Ritual", "Caltheris" ];
        sr.flags = [ "ruby_wwq_complete", "ruby_mq_s2_defend_success", "ruby_mq_s3_orrery_defend_success", "ruby_mq_all_5_melody_pillars_on", "ruby_boss_fight_complete" ];
    }
    else if ( map == "zm_sat_firefly" )
    {
        // fixed splits: Gauntlet, lab lockdown (serum trial) end, keys cinematic start, challenges, boss arena
        sr.quest = zm_quest::function_bf48db63228e7ef( #"firefly_ww_quest" );
        if ( !isdefined( sr.quest ) )
        {
            return false;
        }
        sr.names = [ "Gauntlet", "Lockdown end", "Keys", "Challenges", "Veytarion" ];
        sr.flags = [ sr.quest, "serum_t_finished", "mid_igc_started", "MQ_STEP_18_COMPLETE", "firefly_boss_fight_complete" ];
    }
    else if ( map == "zm_sat_hornet" )
    {
        // fixed splits, in quest order; step 29 is the banners placed on the right spots
        sr.names = [ "Cat", "Mask", "Noble", "Poisons", "Locations", "Boss", "End" ];
        sr.flags = [ "nekomata_acquired", "mq_step_5_complete", "mq_acc_n_killed", "mq_step_21_complete", "mq_step_29_complete", "hornet_boss_fight_start", "hornet_boss_fight_complete" ];
    }
    else if ( map == "zm_sat_locust" )
    {
        // fixed splits, in quest order
        sr.names = [ "JOTUNN Star", "Atomkraft core", "Boss enter", "End" ];
        sr.flags = [ "ww_step_08", "mq_rp_step_03", "boss_fight_start", "boss_fight_end" ];
    }
    else if ( map == "zm_sat_mantis" )
    {
        // fixed splits, in quest order
        sr.names = [ "Chalk", "Sundergat", "Symbols", "Soulbox", "Boss enter", "End" ];
        sr.flags = [ "chalk_picked_up", "wwu_weapon_retrieved", "music_notes_puzzle_completed", "sheet_music_delivered", "start_boss_fight", "boss_fight_done" ];
    }
    else if ( map == "zm_sat_scarab" )
    {
        // fixed splits, in quest order; the PaP quest has no end flag, so split 1 reads the quest itself
        sr.quest = zm_quest::function_bf48db63228e7ef( #"hash_fbb52a4fe83b2f5c" );
        if ( !isdefined( sr.quest ) )
        {
            return false;
        }
        sr.names = [ "Pap", "House", "Vey Finish", "Boss Enter", "End" ];
        sr.flags = [ sr.quest, "wanna_wingo_eh", "vey_temples", "enter_boss_fight_done", "scarab_boss_fight_complete" ];
    }
    else
    {
        return false;
    }
    sr.map = map;
    sr.host = level.players[ 0 ];
    foreach ( player in level.players )
    {
        if ( player menu_is_host() )
        {
            sr.host = player;
        }
    }
    sr.index = 0;
    sr.times = [];
    sr.pb = [];
    // PB = split times of the fastest finished run, "ms,ms,..." in kronos/fuzmenu/speedrun.json
    nengine_store_load( "fuzspeedrun", "speedrun" );
    sr.pb_str = nengine_store_get( "fuzspeedrun", map );
    if ( isdefined( sr.pb_str ) && sr.pb_str != "" )
    {
        foreach ( part in strtok( sr.pb_str, "," ) )
        {
            sr.pb[ sr.pb.size ] = int( part );
        }
    }
    if ( sr.flags.size == 0 )
    {
        return false;
    }
    if ( sr.pb.size != sr.flags.size )
    {
        sr.pb = [];
    }
    sr.gums = nengine_store_get( "fuzspeedrun", "gums" );
    sr.timer = nengine_store_get( "fuzspeedrun", "timer" );
    sr.show = nengine_store_get( "fuzspeedrun", "show" );
    if ( !( sr.show === "0" ) )
    {
        sr.show = "1";
    }
    sr.mode = nengine_store_get( "fuzspeedrun", "mode" );
    if ( !( sr.mode === "pap" ) )
    {
        sr.mode = "ee";
    }
    // "Start speedrun" asked before the restart, cleared so the next restart is a normal run
    sr.restart = nengine_store_get( "fuzspeedrun", "restart" );
    if ( sr.restart === "1" )
    {
        nengine_store_set( "fuzspeedrun", "restart", "0" );
        nengine_store_save( "fuzspeedrun", "speedrun" );
    }
    menu_sr_mode( sr );
    level.zmm_sr = sr;
    return true;
}

function menu_sr_done( index )
{
    sr = level.zmm_sr;
    if ( sr.flags[ index ] === "pap" )
    {
        return istrue( sr.pap_done );
    }
    if ( sr.flags[ index ] === "vey_temples" )
    {
        return namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "sst_made_nice1" ) && namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "sst_made_nice2" ) && namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "sst_made_nice3" ) && namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( "sst_made_nice4" );
    }
    if ( isstring( sr.flags[ index ] ) )
    {
        return namespace_60b3bdcc70f79fc6::function_f0bb112fe637e41c( sr.flags[ index ] );
    }
    return sr.flags[ index ].var_cb2962eb3d2eb963 == 1;
}

function menu_sr_restart()
{
    if ( !isdefined( level.zmm_sr ) || !menu_is_host() || getdvar( @"zmm_lua" ) != "1" )
    {
        return 0;
    }
    nengine_store_load( "fuzspeedrun", "speedrun" );
    nengine_store_set( "fuzspeedrun", "restart", "1" );
    nengine_store_save( "fuzspeedrun", "speedrun" );
    setdvar( @"zmm_exec", "map_restart " + gettime() );
    return 1;
}

function menu_sr_loop()
{
    level endon( #"game_ended" );
    while ( !menu_sr_someone_playing() )
    {
        wait 0.05;
    }
    // level.mapname is read once the map is up
    if ( !menu_sr_setup() )
    {
        return;
    }
    sr = level.zmm_sr;
    level thread menu_sr_restore_gums();
    level thread menu_pause_cmds();
    menu_sr_live( "idle" );
    // "Start speedrun" restarted the map: show the splits
    if ( sr.restart === "1" )
    {
        menu_sr_show();
    }
    menu_sr_wait_move();
    menu_sr_count_attempt();
    sr.start = gettime();
    menu_sr_live( "running" );
    while ( sr.index < sr.flags.size )
    {
        if ( menu_sr_done( sr.index ) )
        {
            sr.times[ sr.index ] = gettime() - sr.start;
            iprintlnbold( "^2Split " + ( sr.index + 1 ) + "/" + sr.flags.size + " ^7" + sr.names[ sr.index ] + "  ^3" + menu_sr_time( sr.times[ sr.index ] ) + menu_sr_delta( sr.index ) );
            sr.index++;
            menu_sr_live( "running" );
        }
        else
        {
            waitframe();
        }
    }
    menu_sr_live( "done" );
    if ( sr.pb.size == 0 || sr.times[ sr.times.size - 1 ] < sr.pb[ sr.pb.size - 1 ] )
    {
        sr.pb = sr.times;
        sr.pb_str = "" + sr.times[ 0 ];
        for ( i = 1; i < sr.times.size; i++ )
        {
            sr.pb_str = sr.pb_str + "," + sr.times[ i ];
        }
        nengine_store_load( "fuzspeedrun", "speedrun" );
        nengine_store_set( "fuzspeedrun", sr.pb_key, sr.pb_str );
        nengine_store_save( "fuzspeedrun", "speedrun" );
        iprintlnbold( "^2New PB: " + menu_sr_time( sr.times[ sr.times.size - 1 ] ) );
    }
}

function menu_sr_someone_playing()
{
    if ( !isdefined( level.players ) )
    {
        return false;
    }
    foreach ( player in level.players )
    {
        if ( isdefined( player ) && isalive( player ) && player.sessionstate == "playing" )
        {
            return true;
        }
    }
    return false;
}

function menu_sr_time( ms )
{
    sr = level.zmm_sr;
    sr.f_ms = ms;
    sr.f_min = 0;
    sr.f_sec = 0;
    sr.f_tenth = 0;
    while ( sr.f_ms >= 60000 )
    {
        sr.f_min++;
        sr.f_ms -= 60000;
    }
    while ( sr.f_ms >= 1000 )
    {
        sr.f_sec++;
        sr.f_ms -= 1000;
    }
    while ( sr.f_ms >= 100 )
    {
        sr.f_tenth++;
        sr.f_ms -= 100;
    }
    return sr.f_min + ":" + ( sr.f_sec < 10 ? "0" : "" ) + sr.f_sec + "." + sr.f_tenth;
}

function menu_sr_delta( index )
{
    sr = level.zmm_sr;
    if ( sr.pb.size == 0 )
    {
        return "";
    }
    if ( sr.times[ index ] <= sr.pb[ index ] )
    {
        return "  ^2-" + menu_sr_time( sr.pb[ index ] - sr.times[ index ] );
    }
    return "  ^1+" + menu_sr_time( sr.times[ index ] - sr.pb[ index ] );
}

function menu_sr_text()
{
    sr = level.zmm_sr;
    if ( !isdefined( sr ) )
    {
        return "Splits: map not supported yet";
    }
    if ( !isdefined( sr.start ) )
    {
        return "0:00.0";
    }
    if ( sr.index >= sr.flags.size )
    {
        return "^2DONE " + menu_sr_time( sr.times[ sr.times.size - 1 ] ) + menu_sr_delta( sr.times.size - 1 );
    }
    sr.text = "^7#" + sr.att + " ^3" + menu_sr_time( gettime() - sr.start ) + "  ^7" + ( sr.index + 1 ) + "/" + sr.flags.size + " " + sr.names[ sr.index ];
    if ( sr.index > 0 )
    {
        sr.text = sr.text + "   ^7" + sr.names[ sr.index - 1 ] + " " + menu_sr_time( sr.times[ sr.index - 1 ] ) + menu_sr_delta( sr.index - 1 );
    }
    if ( sr.show == "0" )
    {
        return "^7#" + sr.att + " ^3" + menu_sr_time( gettime() - sr.start );
    }
    return sr.text;
}

function menu_sr_show()
{
    sr = level.zmm_sr;
    while ( isdefined( sr.host ) && !isdefined( sr.host.zmm ) )
    {
        waitframe();
    }
    if ( isdefined( sr.host ) && !( sr.timer === "0" ) && !sr.host menu_toggle_state( "speedrun" ) )
    {
        sr.host.zmm.toggles[ "speedrun" ] = 1;
        sr.host menu_apply_toggle( "speedrun" );
    }
}

function menu_sr_wait_move()
{
    sr = level.zmm_sr;
    sr.from = sr.host.origin;
    sr.steps = 0;
    // shortcut: the 5 steps make every timer start 0.25 s late, same for all runs; subtract it if runs must match real time
    while ( isdefined( sr.host ) && sr.steps < 5 )
    {
        wait 0.05;
        sr.delta = sr.host.origin - sr.from;
        sr.from = sr.host.origin;
        sr.moved = sr.delta[ 0 ] * sr.delta[ 0 ] + sr.delta[ 1 ] * sr.delta[ 1 ];
        if ( sr.moved > 2 && sr.moved < 2500 )
        {
            sr.steps++;
        }
        else
        {
            sr.steps = 0;
        }
    }
}

function menu_loop_active( key )
{
    if ( !isdefined( self ) || !isplayer( self ) || !isdefined( self.zmm ) || !self.zmm.running )
    {
        return false;
    }
    return istrue( self.zmm.toggles[ key ] );
}

function menu_gum_ok( name )
{
    if ( !isdefined( name ) || name == "" || name == "none" || name == "empty" || name == "weapon_null" || name == "mr_peeks" )
    {
        return 0;
    }
    if ( !isdefined( level.bgb[ name ] ) || !isdefined( level.bgb[ name ].name ) || istrue( level.bgb[ name ].banned ) )
    {
        return 0;
    }
    gum_hash = getxhash( name );
    if ( !isdefined( level.gobblegums[ gum_hash ] ) || !isdefined( level.gobblegums[ gum_hash ].index ) )
    {
        return 0;
    }
    return 1;
}

function menu_gum_slot_busy( slot )
{
    if ( isdefined( self.var_f1dccd054c74a27e ) && istrue( self.var_f1dccd054c74a27e[ slot ] ) )
    {
        return 1;
    }
    if ( isdefined( self.bgb_activation_in_progress ) && istrue( self.bgb_activation_in_progress[ slot ] ) )
    {
        return 1;
    }
    return 0;
}

function menu_gum_in_other_slot( name, slot )
{
    for ( other = 1; other <= 3; other++ )
    {
        if ( other != slot && self.var_b02f6e7abbbc8a84[ other ] === name )
        {
            return 1;
        }
    }
    return 0;
}

function menu_write_gum_slot( slot, name )
{
    if ( !menu_gum_ok( name ) )
    {
        return 0;
    }
    index = level.gobblegums[ getxhash( name ) ].index;
    self.var_b02f6e7abbbc8a84[ slot ] = name;
    if ( slot == 2 )
    {
        self setclientomnvar( "ui_gobblegum_slot_2", index );
    }
    else if ( slot == 3 )
    {
        self setclientomnvar( "ui_gobblegum_slot_3", index );
    }
    else
    {
        self setclientomnvar( "ui_gobblegum_slot_1", index );
    }
    self setclientomnvar( "ui_focused_gobblegum_slot_index", slot );
    self setclientomnvar( "ui_gobblegum_slot_acquired_notify", slot );
    return 1;
}

function menu_param( label, action, value )
{
    ok = 0;
    if ( action == "restart" )
    {
        ok = menu_sr_restart();
    }
    menu_notify( label, ok );
}

function menu_both_warn()
{
    wait 20;
    iprintlnbold( "^1FuzSpeedrun: another menu is enabled. Keep only one in the Workshop." );
}

function menu_pause_cmds()
{
    sr = level.zmm_sr;
    while ( isdefined( sr.host ) && !isdefined( sr.host.zmm ) )
    {
        waitframe();
    }
    setdvar( @"zmm_pgums", "0" );
    if ( sr.gums === "1" )
    {
        setdvar( @"zmm_pgums", "1" );
    }
    setdvar( @"zmm_pshow", sr.show );
    setdvar( @"zmm_pmode", sr.mode );
    // set last: Lua waits for this dvar before adding the rows
    setdvar( @"zmm_ptimer", "1" );
    if ( sr.timer === "0" )
    {
        setdvar( @"zmm_ptimer", "0" );
    }
    while ( isdefined( sr.host ) )
    {
        menu_pause_sync( "speedrun", getdvar( @"zmm_ptimer" ) );
        menu_pause_sync( "gums", getdvar( @"zmm_pgums" ) );
        if ( !( getdvar( @"zmm_pshow" ) === sr.show ) )
        {
            sr.show = getdvar( @"zmm_pshow" );
            menu_pause_save( "show", sr.show );
        }
        if ( !( getdvar( @"zmm_pmode" ) === sr.mode ) )
        {
            sr.mode = getdvar( @"zmm_pmode" );
            menu_pause_save( "mode", sr.mode );
        }
        sr.p_cmd = getdvar( @"zmm_paction" );
        if ( sr.p_cmd != "" && !( sr.p_cmd === sr.p_last ) )
        {
            sr.p_last = sr.p_cmd;
            if ( issubstr( sr.p_cmd, "start" ) )
            {
                sr.host thread menu_param( "Start speedrun", "restart", 0 );
            }
        }
        wait 0.1;
    }
}

function menu_pause_save( key, value )
{
    nengine_store_load( "fuzspeedrun", "speedrun" );
    nengine_store_set( "fuzspeedrun", key, value );
    nengine_store_save( "fuzspeedrun", "speedrun" );
}

function menu_sr_mode( sr )
{
    sr.pb_key = sr.map;
    if ( sr.mode != "pap" )
    {
        return;
    }
    sr.names = [ "PaP Taken" ];
    sr.flags = [ "pap" ];
    sr.pb_key = sr.map + "_pap";
    sr.pb = [];
    sr.pb_str = nengine_store_get( "fuzspeedrun", sr.pb_key );
    if ( isdefined( sr.pb_str ) && sr.pb_str != "" )
    {
        sr.pb[ 0 ] = int( sr.pb_str );
    }
    // fired by the Pack-a-Punch machine when it upgrades a weapon
    level callback::add( #"hash_eee96f780807d870", &menu_sr_on_pap );
}

function menu_sr_on_pap( params )
{
    level.zmm_sr.pap_done = 1;
}

function menu_sr_splice()
{
    sr = level.zmm_sr;
    // the dvar outlives map restarts: one id per game session, like the BO3 mod
    sr.sid = getdvar( @"zmm_session" );
    if ( !isdefined( sr.sid ) || sr.sid == "" )
    {
        sr.sid = "";
        sr.sid_chars = strtok( "A,B,C,D,E,F,G,H,J,K,L,M,N,P,Q,R,S,T,U,V,W,X,Y,Z,2,3,4,5,6,7,8,9", "," );
        for ( sr.sid_i = 0; sr.sid_i < 10; sr.sid_i++ )
        {
            sr.sid += sr.sid_chars[ randomint( sr.sid_chars.size ) ];
        }
        setdvar( @"zmm_session", sr.sid );
    }
    setdvar( @"zmm_splice", sr.sid + " ^5#" + sr.att + " ^7FuzSpeedrun v1.1" );
}

function menu_pause_sync( key, value )
{
    sr = level.zmm_sr;
    sr.p_on = sr.host menu_toggle_state( key );
    if ( ( value == "1" && !sr.p_on ) || ( value == "0" && sr.p_on ) )
    {
        sr.host menu_toggle( key );
    }
}

function menu_sr_restore_gums()
{
    sr = level.zmm_sr;
    while ( isdefined( sr.host ) && !isdefined( sr.host.zmm ) )
    {
        waitframe();
    }
    if ( isdefined( sr.host ) && sr.gums === "1" )
    {
        sr.host.zmm.toggles[ "gums" ] = 1;
        sr.host menu_apply_toggle( "gums" );
    }
}

function menu_gum_refill()
{
    state = self.zmm;
    state.gum_keep = [];
    while ( isdefined( self ) && menu_loop_active( "gums" ) )
    {
        if ( isdefined( level.bgb ) && isdefined( level.gobblegums ) && isdefined( self.var_b02f6e7abbbc8a84 ) )
        {
            for ( slot = 1; slot <= 3; slot++ )
            {
                if ( menu_gum_ok( self.var_b02f6e7abbbc8a84[ slot ] ) )
                {
                    state.gum_keep[ slot ] = self.var_b02f6e7abbbc8a84[ slot ];
                }
                else if ( isdefined( state.gum_keep[ slot ] ) && !menu_gum_slot_busy( slot ) && !menu_gum_in_other_slot( state.gum_keep[ slot ], slot ) )
                {
                    menu_write_gum_slot( slot, state.gum_keep[ slot ] );
                }
            }
        }
        wait 0.5;
    }
    state.gum_loop = 0;
}

function menu_sr_count_attempt()
{
    sr = level.zmm_sr;
    nengine_store_load( "fuzspeedrun", "speedrun" );
    sr.att_str = nengine_store_get( "fuzspeedrun", "att_" + sr.map );
    sr.att = 1;
    if ( isdefined( sr.att_str ) && sr.att_str != "" )
    {
        sr.att = int( sr.att_str ) + 1;
    }
    nengine_store_set( "fuzspeedrun", "att_" + sr.map, "" + sr.att );
    nengine_store_save( "fuzspeedrun", "speedrun" );
    menu_sr_splice();
}

function menu_sr_live( status )
{
    sr = level.zmm_sr;
    nengine_store_load( "fuzspeedrun", "live" );
    nengine_store_set( "fuzspeedrun", "status", status );
    nengine_store_set( "fuzspeedrun", "split", "" + sr.index );
    nengine_store_save( "fuzspeedrun", "live" );
}


// ---------------------------------------------------------------- splitter layout bridge
// Hands the speedrun data to zm_splitter_post.lua through dvars:
//   zm_sr 1 = splits from this mod, 2 = still waiting, 0 = no splits for this map (own clock, F6 splits)
//   zm_srmap map name, zm_srnames split names (|), zm_srpb PB times in ms (,), zm_srt finished split times in ms (,)
//   zm_tms time in ms (0 until you move, stays at the last split when done)
function zmsplit_join( arr, sep )
{
    out = "";
    if ( !isdefined( arr ) )
    {
        return out;
    }
    for ( i = 0; i < arr.size; i++ )
    {
        if ( i > 0 )
        {
            out = out + sep;
        }
        out = out + arr[ i ];
    }
    return out;
}

// best segments: kept per key in the store ("<map>_best", or "<map>_pap_best" in PaP mode) as "ms,ms,..."
// and updated each time a split ends faster than ever before
function zmsplit_best_key( sr )
{
    key = sr.map;
    if ( isdefined( sr.pb_key ) )
    {
        key = sr.pb_key;
    }
    return key + "_best";
}

function zmsplit_best_load( sr, st )
{
    st.bkey = zmsplit_best_key( sr );
    st.best = [];
    nengine_store_load( "fuzspeedrun", "speedrun" );
    st.bstr = nengine_store_get( "fuzspeedrun", st.bkey );
    if ( isdefined( st.bstr ) && st.bstr != "" )
    {
        foreach ( part in strtok( st.bstr, "," ) )
        {
            st.best[ st.best.size ] = int( part );
        }
    }
    if ( st.best.size != sr.flags.size )
    {
        st.best = [];
    }
    st.nd = sr.times.size;
}

function zmsplit_best_text( sr, st )
{
    out = "";
    for ( i = 0; i < sr.flags.size; i++ )
    {
        if ( i > 0 )
        {
            out = out + ",";
        }
        if ( isdefined( st.best[ i ] ) )
        {
            out = out + st.best[ i ];
        }
        else
        {
            out = out + "0";
        }
    }
    return out;
}

function zmsplit_best_update( sr, st )
{
    st.dirty = 0;
    while ( st.nd < sr.times.size )
    {
        st.seg = sr.times[ st.nd ];
        if ( st.nd > 0 )
        {
            st.seg = st.seg - sr.times[ st.nd - 1 ];
        }
        if ( !isdefined( st.best[ st.nd ] ) || st.best[ st.nd ] <= 0 || st.seg < st.best[ st.nd ] )
        {
            st.best[ st.nd ] = st.seg;
            st.dirty = 1;
        }
        st.nd++;
    }
    if ( st.dirty )
    {
        nengine_store_load( "fuzspeedrun", "speedrun" );
        nengine_store_set( "fuzspeedrun", st.bkey, zmsplit_best_text( sr, st ) );
        nengine_store_save( "fuzspeedrun", "speedrun" );
    }
}

function zmsplit_bridge()
{
    level endon( #"game_ended" );
    st = spawnstruct();
    st.active = 0;
    st.manual = 0;
    st.sent = "";
    st.nm_sent = "";
    st.pb_sent = "";
    st.bt_sent = "";

    setdvar( "zm_tms", 0 );
    setdvar( "zm_sr", 2 );
    setdvar( "zm_srmap", "" );
    setdvar( "zm_srnames", "" );
    setdvar( "zm_srpb", "" );
    setdvar( "zm_srbest", "" );
    setdvar( "zm_srt", "" );
    setdvar( "zm_split", 0 );

    while ( !isdefined( level.players ) || level.players.size == 0 )
    {
        waitframe();
    }
    st.t0 = gettime();

    while ( true )
    {
        sr = level.zmm_sr;
        if ( isdefined( sr ) && isdefined( sr.names ) && isdefined( sr.flags ) )
        {
            if ( !st.active )
            {
                st.active = 1;
                setdvar( "zm_srmap", sr.map );
                setdvar( "zm_sr", 1 );
            }
            // names and PB are re-sent when they change (PaP mode swaps the split list, a new PB replaces the old)
            st.nm = zmsplit_join( sr.names, "|" );
            if ( st.nm != st.nm_sent )
            {
                st.nm_sent = st.nm;
                setdvar( "zm_srnames", st.nm );
            }
            st.pbs = zmsplit_join( sr.pb, "," );
            if ( st.pbs != st.pb_sent )
            {
                st.pb_sent = st.pbs;
                setdvar( "zm_srpb", st.pbs );
            }
            st.key = "" + sr.index;
            st.times = zmsplit_join( sr.times, "," );
            if ( !isdefined( st.bkey ) || st.bkey != zmsplit_best_key( sr ) )
            {
                zmsplit_best_load( sr, st );
            }
            zmsplit_best_update( sr, st );
            st.bt = zmsplit_best_text( sr, st );
            if ( st.bt != st.bt_sent )
            {
                st.bt_sent = st.bt;
                setdvar( "zm_srbest", st.bt );
            }
            if ( st.key != st.sent )
            {
                st.sent = st.key;
                setdvar( "zm_srt", st.times );
            }
            if ( !isdefined( sr.start ) )
            {
                setdvar( "zm_tms", 0 );
            }
            else if ( sr.index >= sr.flags.size )
            {
                setdvar( "zm_tms", sr.times[ sr.times.size - 1 ] );
            }
            else
            {
                setdvar( "zm_tms", gettime() - sr.start );
            }
        }
        else if ( gettime() - st.t0 > 15000 )
        {
            // no splits for this map: own clock from the spawn, split by hand with F6
            if ( !st.manual )
            {
                st.manual = 1;
                setdvar( "zm_sr", 0 );
            }
            setdvar( "zm_tms", gettime() - st.t0 );
        }
        waitframe();
    }
}
