::nanas_lobber <- {
    spitter_spawn_count = 0,
    activeClouds = [],  // Track active clouds for cleanup

    // === EMS-style settings ===
    settings = {
        lobber_chance = 6,         // 1 in N chance
        lobber_health = 500,
        lobber_speed = 0.9,
        cloud_radius = 250,        // Bigger cloud radius
        cloud_damage = 3,
        cloud_duration = 12,        // Longer duration
        cloud_interval = 1,      // Damage tick rate
        spit_rate = 0.8,          // Faster fire rate (lower = faster)
    },

    function SaveSettings()
    {
        local path = "lobber/settings.cfg";
        local data = "{";
        foreach (k, v in settings)
            data += "\n\t" + k + " = " + v + ",";
        data += "\n}";
        StringToFile(path, data);
        printl("[lobber] Settings saved to: " + path);
    },

    function LoadSettings()
    {
        local path = "lobber/settings.cfg";
        local content = FileToString(path);

        if (!content)
        {
            printl("[lobber] Settings file not found, creating default...");
            SaveSettings();
            return;
        }

        try
        {
            local t = compilestring("return " + content)();
            foreach (k, v in t)
                if (k in settings) settings[k] = v;
            printl("[lobber] Settings loaded successfully");
        }
        catch (e)
        {
            printl("[lobber] Error loading settings: " + e);
            SaveSettings();
        }
    },

    function OnGameEvent_round_start(params)
    {
        try { this.LoadSettings(); } catch(e) { printl("[lobber] Settings load failed: " + e); }

        // Precache the Lobber model properly (no temp entity)
        if (!IsModelPrecached("models/infected/lobber.mdl"))
            PrecacheModel("models/infected/lobber.mdl");

        printl("[lobber] round_start initialised");
        
        // Clear active clouds on round start
        activeClouds.clear();
        
        // Reset CVars to default at round start
        try {
            Convars.SetValue("z_spitter_high_chance", 20);
            Convars.SetValue("z_spitter_max_wait_time", 20);
            Convars.SetValue("z_spit_interval", 20);
        } catch(e) { }
    },

    function OnGameEvent_player_spawn(params)
    {
        if (!("userid" in params)) return;
        local client = GetPlayerFromUserID(params.userid);
        if(client == null || !client.IsPlayer()) return;

        // Skip Ratman immediately
        client.ValidateScriptScope();
        local scope = client.GetScriptScope();
        if(scope && "IsRatman" in scope && scope["IsRatman"] == 1) return;
        
        // Skip Toad immediately
        if(scope && "IsToad" in scope && scope["IsToad"] == 1) return;

        // Skip deathbreath immediately
        if(scope && "Isdeathbreath" in scope && scope["Isdeathbreath"] == 1) return;

        // Skip bleeder immediately
        if(scope && "Isbleeder" in scope && scope["Isbleeder"] == 1) return;

        // Skip tumor immediately
        if(scope && "Istumor" in scope && scope["Istumor"] == 1) return;

        // Skip widow immediately
        if(scope && "Iswidow" in scope && scope["Iswidow"] == 1) return;

        // Skip catchucker immediately
        if(scope && "Iscatchucker" in scope && scope["Iscatchucker"] == 1) return;
        
        // Skip Slasher immediately
        if(scope && "IsSlasher" in scope && scope["IsSlasher"] == 1) return;

        if(NetProps.GetPropInt(client, "m_iTeamNum") == 3 && client.GetZombieType() == 4)
        {
            // Spawn chance logic (1 in N)
            local chance = ::nanas_lobber.settings.lobber_chance;
            if (RandomInt(1, chance) != 1) return; // Not lucky this time

            ::nanas_lobber.spitter_spawn_count += 1;

            // Delayed conversion using EntFire
            EntFire("worldspawn", "RunScriptCode",
                "DirectorScript.nanas_lobber.DelayedLobberConversion(" + client.GetEntityIndex() + ")",
                0.0, null);
        }
    },

    function DelayedLobberConversion(player_idx)
    {
        local client = EntIndexToHScript(player_idx);
        if(client == null || !client.IsValid() || client.IsDead()) return;

        // Skip if Ratman
        client.ValidateScriptScope();
        local scope = client.GetScriptScope();
        if(scope && "IsRatman" in scope && scope["IsRatman"] == 1) return;
        
        // Skip if Toad
        if(scope && "IsToad" in scope && scope["IsToad"] == 1) return;

        // Skip if deathbreath 
        if(scope && "Isdeathbreath" in scope && scope["Isdeathbreath"] == 1) return;

        // Skip if bleeder
        if(scope && "Isbleeder" in scope && scope["Isbleeder"] == 1) return;

        // Skip if tumor
        if(scope && "Istumor" in scope && scope["Istumor"] == 1) return;

        // Skip if widow
        if(scope && "Iswidow" in scope && scope["Iswidow"] == 1) return;

        // Skip if catchucker 
        if(scope && "Iscatchucker" in scope && scope["Iscatchucker"] == 1) return;
        
        // Skip if Slasher
        if(scope && "IsSlasher" in scope && scope["IsSlasher"] == 1) return;

        if (IsPlayerABot(client))
        {
            SetFakeClientConVarValue(client,"name","Lobber");
            NetProps.SetPropInt(client, "m_fFlags", NetProps.GetPropInt(client, "m_fFlags") & ~256);
        }

        // === APPLY LOBBER STATS ===
        client.SetMaxHealth(::nanas_lobber.settings.lobber_health);
        client.SetHealth(::nanas_lobber.settings.lobber_health);
        NetProps.SetPropFloat(client, "m_flLaggedMovementValue", ::nanas_lobber.settings.lobber_speed);

        // Set Lobber model
        client.SetModel("models/infected/lobber.mdl");
        
        // Set flags in script scope to identify this as a lobber
        if(scope) {
            scope["IsLobber"] <- 1;  // Set flag to 1 like other scripts
        }
        
        // Apply faster fire rate CVars
        try {
            Convars.SetValue("z_spitter_high_chance", ::nanas_lobber.settings.spit_rate);
            Convars.SetValue("z_spitter_max_wait_time", ::nanas_lobber.settings.spit_rate);
            Convars.SetValue("z_spit_interval", ::nanas_lobber.settings.spit_rate);
            printl("[lobber] Applied faster fire rate: " + ::nanas_lobber.settings.spit_rate);
        } catch(e) { printl("[lobber] Error setting CVars: " + e); }

        // Ability trigger remains unchanged
        local target = ::nanas_lobber.GetNearSurvivor(client);
        DoEntFire("!self", "RunScriptCode", format("self.TakeDamage(1, 2, activator);"), 0.5, target, client);
    },
    
    // Helper function to check if a player is a lobber
    function IsLobber(player)
    {
        if (!player || !player.IsValid()) return false;
        player.ValidateScriptScope();
        local scope = player.GetScriptScope();
        return (scope && "IsLobber" in scope && scope["IsLobber"] == 1);
    },

    function OnGameEvent_ability_use(params)
    {
        if(params.ability == "ability_spit"){
            local si = GetPlayerFromUserID(params.userid);
            // Only apply to lobbers
            if (si && ::nanas_lobber.IsLobber(si))
            {
                EntFire("worldspawn", "RunScriptCode",
                    "DirectorScript.nanas_lobber.Find_Spit(" + si.GetEntityIndex() + ")",
                    0.1, null);
                EntFire("worldspawn", "RunScriptCode",
                    "DirectorScript.nanas_lobber.AttackCall(" + si.GetEntityIndex() + ")",
                    ::nanas_lobber.settings.spit_rate + 0.1, null);
            }
        }
    },

    function Find_Spit(player_idx)
    {
        local si = EntIndexToHScript(player_idx);
        if(si == null || !si.IsValid()) return;
        if (!::nanas_lobber.IsLobber(si)) return;
        
        local spit = null;
        while (spit = Entities.FindByClassname(spit, "spitter_projectile")){
            if(spit.IsValid() && NetProps.GetPropEntity(spit, "m_hOwnerEntity") == si){
                return;
            }
        }
        EntFire("worldspawn", "RunScriptCode",
            "DirectorScript.nanas_lobber.Find_Spit(" + player_idx + ")",
            0.1, null);
    },

    function OnGameEvent_spit_burst(params)
    {
        local spit = EntIndexToHScript(params.subject);
        if (!spit || !spit.IsValid()) return;
        
        local spitter = NetProps.GetPropEntity(spit, "m_hOwnerEntity");
        
        // Only process lobber spits
        if (spitter && spitter.IsValid() && ::nanas_lobber.IsLobber(spitter))
        {
            // Get spit position
            local spitPos = spit.GetOrigin();
            
            // Spawn dense smoker cloud
            ::nanas_lobber.SpawnSmokeCloud(spitPos, spitter);
            
            // Kill the spit projectile (prevents acid pool)
            DoEntFire("!self", "Kill", "", 0.0, null, spit);
        }
    },
    
    function SpawnSmokeCloud(pos, owner)
    {
        // Spawn main smoke particles (denser by using multiple particles)
        local ptc1 = SpawnEntityFromTable("info_particle_system", {
            origin = pos - Vector(0,0,20),
            effect_name = "smoker_smokecloud",
            cpoint1 = "!self",
            start_active = 1
        });
        DoEntFire("!self", "Kill", "", settings.cloud_duration, null, ptc1);
        
        local ptc2 = SpawnEntityFromTable("info_particle_system", {
            origin = pos,
            effect_name = "smoker_smokecloud_camera",
            cpoint1 = "!self",
            start_active = 1
        });
        DoEntFire("!self", "Kill", "", settings.cloud_duration, null, ptc2);
        
        // Add extra smoke particles for denser effect
        local ptc3 = SpawnEntityFromTable("info_particle_system", {
            origin = pos + Vector(0,0,50),
            effect_name = "smoker_smokecloud",
            cpoint1 = "!self",
            start_active = 1
        });
        DoEntFire("!self", "Kill", "", settings.cloud_duration, null, ptc3);
        
        // Emit sound
        EmitAmbientSoundOn("SmokerZombie.Explode", 1.0, 350, 100, owner);
        
        // Track this cloud
        local cloudId = activeClouds.len();
        activeClouds.append({
            pos = pos,
            spawnTime = Time(),
            duration = settings.cloud_duration,
            owner = owner,
            cloudId = cloudId
        });
        
        // Start a recurring timer for damage with settings values passed in
        EntFire("worldspawn", "RunScriptCode",
            "DirectorScript.nanas_lobber.CloudDamageTimer(" + pos.x + "," + pos.y + "," + pos.z + "," + owner.GetEntityIndex() + "," + cloudId + "," + (Time() + settings.cloud_duration) + ")",
            settings.cloud_interval, null);
    },
    
    function CloudDamageTimer(x, y, z, owner_idx, cloudId, endTime)
    {
        local pos = Vector(x.tofloat(), y.tofloat(), z.tofloat());
        
        // Check if cloud has expired
        if (Time() >= endTime)
        {
            // Remove cloud from active list
            for (local i = activeClouds.len() - 1; i >= 0; i--)
            {
                if (activeClouds[i].cloudId == cloudId)
                {
                    activeClouds.remove(i);
                    break;
                }
            }
            return; // Stop the timer
        }
        
        local owner = EntIndexToHScript(owner_idx);
        
        // Check all survivors in the area
        local survivor = null;
        while (survivor = Entities.FindByClassnameWithin(survivor, "player", pos, settings.cloud_radius))
        {
            if (survivor && survivor.IsValid())
            {
                local zombieType = survivor.GetZombieType();
                if (zombieType == 9) // Survivor
                {
                    if (!survivor.IsDead() && !survivor.IsDying() && !survivor.IsIncapacitated())
                    {
                        // Apply damage
                        survivor.TakeDamage(settings.cloud_damage, 0, owner);
                        
                        // Play cough sound occasionally
                        if (RandomInt(1, 3) == 1) // 33% chance per tick
                        {
                            EmitSoundOn("Player.Cough", survivor);
                        }
                    }
                }
            }
        }
        
        // Keep timer running
        EntFire("worldspawn", "RunScriptCode",
            "DirectorScript.nanas_lobber.CloudDamageTimer(" + x + "," + y + "," + z + "," + owner_idx + "," + cloudId + "," + endTime + ")",
            settings.cloud_interval, null);
    },

    function AttackCall(player_idx)
    {
        local si = EntIndexToHScript(player_idx);
        if(si == null || !si.IsValid() || si.IsDead() || si.IsDying()) return;
        if (!::nanas_lobber.IsLobber(si)) return;
        
        local target = ::nanas_lobber.GetNearSurvivor(si);
        DoEntFire("!self", "RunScriptCode", format("self.TakeDamage(1, 2, activator);"), 0.0, target, si);
    },

    function GetNearSurvivor(self)
    {
        local new_target = null; local client = null;
        local dist; local min_dist = 100000.0;
        local fromOrigin = self.GetOrigin();
        while (client = Entities.FindByClassname(client, "player")) {
            if(self == client || !client.IsValid() || client.IsDead() || client.IsDying() || client.IsIncapacitated()
                || NetProps.GetPropInt(client, "m_iTeamNum" ) != 2) continue;

            dist = (client.GetOrigin() - fromOrigin).Length();
            if (dist < min_dist) {
                min_dist = dist;
                new_target = client;
            }
        }
        return new_target;
    },
    
    function OnGameEvent_player_death(params)
    {
        if (!("userid" in params)) return;
        local player = GetPlayerFromUserID(params.userid);
        if (!player) return;
        
        // Clean up lobber data if this was a lobber
        if (::nanas_lobber.IsLobber(player))
        {
            player.ValidateScriptScope();
            local scope = player.GetScriptScope();
            if (scope && "IsLobber" in scope)
            {
                delete scope["IsLobber"];
            }
            
            // Check if any lobbers still exist
            local anyLobbersLeft = false;
            local client = null;
            while (client = Entities.FindByClassname(client, "player"))
            {
                if (client != player && ::nanas_lobber.IsLobber(client) && !client.IsDead())
                {
                    anyLobbersLeft = true;
                    break;
                }
            }
            
            // If no lobbers left, reset CVars to default (20)
            if (!anyLobbersLeft)
            {
                try {
                    Convars.SetValue("z_spitter_high_chance", 20);
                    Convars.SetValue("z_spitter_max_wait_time", 20);
                    Convars.SetValue("z_spit_interval", 20);
                    printl("[lobber] Reset spitter CVars to default (20)");
                } catch(e) { printl("[lobber] Error resetting CVars: " + e); }
            }
        }
    },
    
    function OnGameEvent_round_end(params)
    {
        // Reset CVars to default (20) when round ends
        try {
            Convars.SetValue("z_spitter_high_chance", 20);
            Convars.SetValue("z_spitter_max_wait_time", 20);
            Convars.SetValue("z_spit_interval", 20);
            printl("[lobber] Reset spitter CVars to default (20) - round end");
        } catch(e) { }
        
        // Clear active clouds
        activeClouds.clear();
    }
}

__CollectEventCallbacks(::nanas_lobber, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);