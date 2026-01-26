obs = obslua

-- Script properties
local source_name = ""
local vsource_name = "" -- New variable for Vertical Source
local hotkey_id = obs.OBS_INVALID_HOTKEY_ID
local toggle_hotkey_id = obs.OBS_INVALID_HOTKEY_ID -- New toggle hotkey

-- Upvalues to track hotkey and overlay state
local hotkey_active = false
local overlay_active = false
local toggle_locked = false -- New state for toggle mode
local timer_count = 0
local timer_delay_ms = 250
local timer_is_running = false

function debug_log(message)
    print(message)
end

-- Function to show/hide BOTH sources
function set_visibility(visible)
    local names = {source_name, vsource_name}
    
    for _, name in ipairs(names) do
        if name ~= "" then
            local source = obs.obs_get_source_by_name(name)
            if source ~= nil then
                obs.obs_source_set_enabled(source, visible)
                debug_log(string.format("Source '%s' visibility set to %s", name, tostring(visible)))
                obs.obs_source_release(source)
            else
                debug_log(string.format("ERROR: Could not find source '%s'", name))
            end
        end
    end
end

-- Timer callback for delayed overlay removal
function disable_overlay()
    if hotkey_active or toggle_locked then
        timer_count = 0
    elseif timer_count < 1 then
        timer_count = timer_count + 1
    else
        set_visibility(false)
        overlay_active = false
        timer_count = 0
        timer_is_running = false
        debug_log("Timer lapsed - hiding sources")
        obs.timer_remove(disable_overlay)
    end
end

-- Callback for key press/release (Hold mode)
function on_hotkey(pressed)
    if pressed then
        hotkey_active = true
        if not overlay_active then
            overlay_active = true
            toggle_locked = false -- Disable toggle when using hold
            set_visibility(true)
            if not timer_is_running then
                timer_is_running = true
                obs.timer_add(disable_overlay, timer_delay_ms)
            end
            debug_log("Hotkey pressed - showing sources")
        end
    else
        hotkey_active = false
        debug_log("Hotkey released")
    end
end

-- Callback for toggle hotkey
function on_toggle_hotkey(pressed)
    if pressed then
        toggle_locked = not toggle_locked
        overlay_active = toggle_locked
        
        if toggle_locked then
            set_visibility(true)
            if not timer_is_running then
                timer_is_running = true
                obs.timer_add(disable_overlay, timer_delay_ms)
            end
            debug_log("Toggle ON - sources visible")
        else
            set_visibility(false)
            debug_log("Toggle OFF - sources hidden")
        end
    end
end

function script_description()
    return [[Map Cover Script for Rust (Dual Source Support)
    Shows both primary and vertical images when hotkeys are held or toggled.
    - Hold hotkey: Shows while held, hides on release
    - Toggle hotkey: Press once to show, press again to hide]]
end

-- Updated to include the dropdown/list for both sources
function script_properties()
    local props = obs.obs_properties_create()
    
    -- Main Source Dropdown
    local p = obs.obs_properties_add_list(props, "source", "Main Image Source", 
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    
    -- Vertical Source Dropdown
    local vp = obs.obs_properties_add_list(props, "vsource", "Vertical Image Source", 
        obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)

    -- Populate both lists with current OBS sources
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(p, name, name)
            obs.obs_property_list_add_string(vp, name, name)
        end
    end
    obs.source_list_release(sources)

    return props
end

function script_update(settings)
    source_name = obs.obs_data_get_string(settings, "source")
    vsource_name = obs.obs_data_get_string(settings, "vsource")
    
    debug_log(string.format("Sources updated: Main='%s', Vertical='%s'", source_name, vsource_name))
    
    set_visibility(false) -- Ensure both start hidden
end

function script_load(settings)
    -- Register hold hotkey
    hotkey_id = obs.obs_hotkey_register_frontend("map_cover_g", "Show Map Cover (Hold G)", on_hotkey)
    
    -- Register toggle hotkey
    toggle_hotkey_id = obs.obs_hotkey_register_frontend("map_cover_toggle", "Toggle Map Cover", on_toggle_hotkey)
    
    -- Load saved hotkey data
    local htdata = obs.obs_data_get_array(settings, "htkey_g")
    obs.obs_hotkey_load(hotkey_id, htdata)
    obs.obs_data_array_release(htdata)
    
    local toggle_htdata = obs.obs_data_get_array(settings, "htkey_toggle")
    obs.obs_hotkey_load(toggle_hotkey_id, toggle_htdata)
    obs.obs_data_array_release(toggle_htdata)
    
    script_update(settings)
end

function script_save(settings)
    -- Save hold hotkey
    local htdata = obs.obs_hotkey_save(hotkey_id)
    obs.obs_data_set_array(settings, "htkey_g", htdata)
    obs.obs_data_array_release(htdata)
    
    -- Save toggle hotkey
    local toggle_htdata = obs.obs_hotkey_save(toggle_hotkey_id)
    obs.obs_data_set_array(settings, "htkey_toggle", toggle_htdata)
    obs.obs_data_array_release(toggle_htdata)
end