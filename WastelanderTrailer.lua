-- WastelanderTrailer
-- by Hexarobi

local SCRIPT_VERSION = "0.4"

---
--- Auto-Updater Lib Install
---

-- Auto Updater from https://github.com/hexarobi/stand-lua-auto-updater
local status, auto_updater = pcall(require, "auto-updater")
if not status then
    local auto_update_complete = nil util.toast("Installing auto-updater...", TOAST_ALL)
    async_http.init("raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
            function(result, headers, status_code)
                local function parse_auto_update_result(result, headers, status_code)
                    local error_prefix = "Error downloading auto-updater: "
                    if status_code ~= 200 then util.toast(error_prefix..status_code, TOAST_ALL) return false end
                    if not result or result == "" then util.toast(error_prefix.."Found empty file.", TOAST_ALL) return false end
                    filesystem.mkdir(filesystem.scripts_dir() .. "lib")
                    local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
                    if file == nil then util.toast(error_prefix.."Could not open file for writing.", TOAST_ALL) return false end
                    file:write(result) file:close() util.toast("Successfully installed auto-updater lib", TOAST_ALL) return true
                end
                auto_update_complete = parse_auto_update_result(result, headers, status_code)
            end, function() util.toast("Error downloading auto-updater lib. Update failed to download.", TOAST_ALL) end)
    async_http.dispatch() local i = 1 while (auto_update_complete == nil and i < 40) do util.yield(250) i = i + 1 end
    if auto_update_complete == nil then error("Error downloading auto-updater lib. HTTP Request timeout") end
    auto_updater = require("auto-updater")
end
if auto_updater == true then error("Invalid auto-updater lib. Please delete your Stand/Lua Scripts/lib/auto-updater.lua and try again") end

---
--- Auto Update
---

local auto_update_config = {
    source_url = "https://raw.githubusercontent.com/hexarobi/stand-lua-wastelandertrailer/main/WastelanderTrailer.lua",
    script_relpath = SCRIPT_RELPATH,
}
auto_updater.run_auto_update(auto_update_config)

---
--- Dependencies
---

util.require_natives(1651208000)

---
--- State
---

local state = {}
local menus = {}

---
--- Attachments
---

local function update_attachment_position(attachment)
    if attachment.offset == nil then
        attachment.offset = {x=0,y=0,z=0}
    end
    if attachment.rotation == nil then
        attachment.rotation = {x=0,y=0,z=0}
    end
    if attachment.collision == nil then
        attachment.collision = true
    end
    ENTITY.ATTACH_ENTITY_TO_ENTITY(
        attachment.handle, attachment.root, attachment.bone_index or 0,
        attachment.offset.x or 0, attachment.offset.y or 0, attachment.offset.z or 0,
        attachment.rotation.x or 0, attachment.rotation.y or 0, attachment.rotation.z or 0,
        false, true, attachment.collision, false, 2, true
    )
end

local function get_vehicle_dimension(vehicle)
    local minimum = memory.alloc()
    local maximum = memory.alloc()
    MISC.GET_MODEL_DIMENSIONS(ENTITY.GET_ENTITY_MODEL(vehicle), minimum, maximum)
    local minimum_vec = v3.new(minimum)
    local maximum_vec = v3.new(maximum)
    return {min_vec=minimum_vec, max_vec=maximum_vec, x = maximum_vec.y - minimum_vec.y, y = maximum_vec.x - minimum_vec.x, z = maximum_vec.z - minimum_vec.z}
end

local function set_attachment_offset_for_root(attachment)
    local root_model = util.reverse_joaat(ENTITY.GET_ENTITY_MODEL(attachment.root))
    local dimensions = get_vehicle_dimension(attachment.handle)

    if root_model == "wastelander" then
        attachment.offset = {
            x=0,
            y=(dimensions.y / 2) - 2,
            z=(dimensions.min_vec.z) + 2.25
        }
    end

    if root_model == "slamtruck" then
        attachment.offset = {
            x=0,
            y=(dimensions.y / 2) - 3,
            z=(dimensions.min_vec.z) + 1.8
        }
        attachment.rotation = {
            x=7,
            y=0,
            z=0,
        }
    end

end

local function attach(attachment)
    attachment.position = ENTITY.GET_ENTITY_COORDS(attachment.root)
    ENTITY.SET_ENTITY_HAS_GRAVITY(attachment.handle, false)
    set_attachment_offset_for_root(attachment)
    update_attachment_position(attachment)

    ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(attachment.root, attachment.handle)

    return attachment
end

local function detach_attached_vehicle()
    if state.attached_vehicle ~= nil then
        util.toast("Detaching "..state.attached_vehicle.name)
        ENTITY.DETACH_ENTITY(state.attached_vehicle.handle, true, true)
        state.attached_vehicle = nil
    end
end

local function attach_nearest_vehicle()
    local player_vehicle = entities.get_user_vehicle_as_handle()
    if not player_vehicle then
        util.toast("You must be in a vehicle to attach")
        return
    end
    local pos = ENTITY.GET_ENTITY_COORDS(player_vehicle, 1)
    local range = 10
    local nearby_vehicles = entities.get_all_vehicles_as_handles()
    local count = 0
    for _, vehicle_handle in ipairs(nearby_vehicles) do
        if vehicle_handle ~= player_vehicle then
            local attachment = {handle=vehicle_handle, root=player_vehicle}
            attachment.position = ENTITY.GET_ENTITY_COORDS(attachment.handle, 1)
            attachment.distance = SYSTEM.VDIST(pos.x, pos.y, pos.z, attachment.position.x, attachment.position.y, attachment.position.z)
            if attachment.distance <= range then
                detach_attached_vehicle()
                attachment.name = VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(ENTITY.GET_ENTITY_MODEL(attachment.handle))
                util.toast("Attaching "..attachment.name)
                attach(attachment)
                state.attached_vehicle = attachment
                return
            end
        end
    end
end

---
--- Menus
---

menus.spawn_truck = menu.list(menu.my_root(), "Spawn Truck")
menu.action(menus.spawn_truck, "Wastelander", {}, "Spawn a Wastelander for towing", function()
    menu.trigger_commands("wastelander")
end)
menu.action(menus.spawn_truck, "Slamtruck", {}, "Spawn a Slamtruck for towing", function()
    menu.trigger_commands("slamtruck")
end)

menu.action(menu.my_root(), "Attach", {}, "Any close proximity vehicles will be attached to your current one", function()
    attach_nearest_vehicle()
end)

menu.action(menu.my_root(), "Detach", {}, "", function()
    detach_attached_vehicle()
end)
