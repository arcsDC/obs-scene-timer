local obs = require("obs")
local json = require("json")
local io = require("io")

local config_path = obs.script_path .. "/config.json"
local scene_list = {}
local interval_seconds = 30
local timer_id = nil
local index = 1

local function load_config()
    local file = io.open(config_path, "r")
    if not file then
        obs.log_warn("Config file not found. Using defaults.")
        scene_list = {"Scene 1", "Scene 2"}
        interval_seconds = 30
        return
    end
    local data = file:read("*a")
    file:close()
    local ok, decoded = pcall(json.decode, data)
    if ok and decoded then
        scene_list = decoded.scenes or scene_list
        interval_seconds = decoded.interval_seconds or interval_seconds
    else
        obs.log_error("Failed to parse config.json")
    end
end

local function switch_scene()
    if #scene_list == 0 then return end
    local scene_name = scene_list[index]
    local scene = obs.obs_data_getref("scene", scene_name)
    if scene then
        obs.obs_data_setref(obs.obs_frontend_get_current_scene(), "scene", scene)
        obs.obs_data_release(scene)
        obs.log_info("Switched to scene: " .. scene_name)
    else
        obs.log_warn("Scene not found: " .. scene_name)
    end
    index = index % #scene_list + 1
end

local function start_timer()
    if timer_id then return end
    load_config()
    if #scene_list == 0 then
        obs.log_error("No scenes configured.")
        return
    end
    timer_id = obs.timer_add(switch_scene, interval_seconds * 1000)
    obs.log_info("Scene timer started. Interval: " .. interval_seconds .. "s")
end

local function stop_timer()
    if timer_id then
        obs.timer_remove(timer_id)
        timer_id = nil
        obs.log_info("Scene timer stopped.")
    end
end

local function toggle_timer()
    if timer_id then
        stop_timer()
    else
        start_timer()
    end
end

obs.script_register_callback("on_load", function()
    obs.log_info("OBS Scene Timer loaded.")
end)

obs.script_register_callback("on_unload", function()
    stop_timer()
    obs.log_info("OBS Scene Timer unloaded.")
end)

obs.script_register_callback("on_hotkey", function(hotkey)
    if hotkey == "toggle_scene_timer" then
        toggle_timer()
    end
end)

obs.script_register_callback("on_hotkey_list", function(hotkeys)
    table.insert(hotkeys, {
        id = "toggle_scene_timer",
        name = "Toggle Scene Timer",
        description = "Start or stop the automatic scene switching timer"
    })
end)
