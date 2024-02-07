-- WastelanderTrailer
-- by Hexarobi

local SCRIPT_VERSION = "0.5"

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
    draw_bounding_box = false,
}
auto_updater.run_auto_update(auto_update_config)

---
--- Dependencies
---

util.require_natives(1651208000)
local quaternionLib = require("quaternionLib")

---
--- State
---

local config = {
    edit_offset_step = 1,
    preview_bounding_box_color = {r=255,g=0,b=255,a=255}
}

local state = {
    attached_vehicle = {
        is_attached = false,
        offset = { x = 0, y = 0, z = 0 }
    }
}
local menus = {}


---
--- Bounding Box
---

local gizmo_minimum = memory.alloc()
local gizmo_maximum = memory.alloc()
local function get_entity_bounds(entity)
    MISC.GET_MODEL_DIMENSIONS(ENTITY.GET_ENTITY_MODEL(entity), gizmo_minimum, gizmo_maximum)
    local minimum_vec = v3.new(gizmo_minimum)
    local maximum_vec = v3.new(gizmo_maximum)
    local max_copy = v3.new(maximum_vec)
    max_copy:sub(minimum_vec)
    return {min = minimum_vec, max = maximum_vec, dimensions = max_copy}
end

local indices <const> = {{1, 2},{1, 4},{1, 8},{3, 4},{3, 2},{3, 5},{6, 5},{6, 8},{6, 2},{7, 4},{7, 5},{7, 8}}
local function draw_bounding_box(entity, colour)

    local rot = quaternionLib.from_entity(entity)
    local pos = ENTITY.GET_ENTITY_COORDS(entity)

    local bounds = get_entity_bounds(entity)

    local minimum_vec = bounds.min
    local maximum_vec = bounds.max

    local vertices = {
        v3.new(minimum_vec.x, maximum_vec.y, maximum_vec.z),    --local top_left
        v3.new(minimum_vec.x, minimum_vec.y, maximum_vec.z),    --local bottom_left
        v3.new(maximum_vec.x, minimum_vec.y, maximum_vec.z),    --local bottom_right
        v3.new(maximum_vec),                                    --local top_right
        v3.new(maximum_vec.x, minimum_vec.y, minimum_vec.z),    --local bottom_right_back
        v3.new(minimum_vec),                                    --local bottom_left_back
        v3.new(maximum_vec.x, maximum_vec.y, minimum_vec.z),    --local top_right_back
        v3.new(minimum_vec.x, maximum_vec.y, minimum_vec.z)     --local top_left_back
    }

    for i = 1, #vertices, 1 do
        local vert = vertices[i]
        vert = rot:mul_v3(vert)
        vert:add(pos)
        vertices[i] = vert
    end

    for i = 1, #indices, 1 do
        local vert_a = vertices[indices[i][1]]
        local vert_b = vertices[indices[i][2]]

        GRAPHICS.DRAW_LINE(
                vert_a.x, vert_a.y, vert_a.z,
                vert_b.x, vert_b.y, vert_b.z,
                colour.r, colour.g, colour.b, colour.a
        )
    end
end

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

    if root_model == "flatbed" then
        attachment.offset = {
            x=0,
            y=(dimensions.y / 2) - 2.73,
            z=(dimensions.z / 2)
        }
        attachment.rotation = {x=0,y=0,z=0}
    end

    if root_model == "wastelander" then
        attachment.offset = {
            x=0,
            y=(dimensions.y / 2) - 2,
            z=(dimensions.z / 2) + 0.8
        }
        attachment.rotation = {x=0,y=0,z=0}
    end

    if root_model == "slamtruck" then
        attachment.offset = {
            x=0,
            y=(dimensions.y / 2) - 3,
            z=(dimensions.z / 2) + 0.2
        }
        attachment.rotation = {
            x=7,
            y=0,
            z=0,
        }
    end

end

local function attach(attachment)
    attachment.is_attached = true
    attachment.position = ENTITY.GET_ENTITY_COORDS(attachment.root)
    ENTITY.SET_ENTITY_HAS_GRAVITY(attachment.handle, false)
    set_attachment_offset_for_root(attachment)
    update_attachment_position(attachment)

    ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(attachment.root, attachment.handle)

    menus.position_x.value = math.floor(attachment.offset.x * 100)
    menus.position_y.value = math.floor(attachment.offset.y * -100)
    menus.position_z.value = math.floor(attachment.offset.z * -100)

    return attachment
end

local function detach_attached_vehicle()
    if state.attached_vehicle ~= nil and state.attached_vehicle.is_attached then
        util.toast("Detaching "..state.attached_vehicle.name)
        state.attached_vehicle.is_attached = false
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
--- Tick Handler
---

local function draw_bounding_box_tick()
    if config.draw_bounding_box and state.attached_vehicle ~= nil then
        draw_bounding_box(state.attached_vehicle.handle, config.preview_bounding_box_color)
    end
end

util.create_tick_handler(draw_bounding_box_tick)

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
menu.action(menus.spawn_truck, "Flatbed", {}, "Spawn a Slamtruck for towing", function()
    menu.trigger_commands("flatbed")
end)

menu.action(menu.my_root(), "Attach", {}, "Any close proximity vehicles will be attached to your current one", function()
    attach_nearest_vehicle()
end)

menu.action(menu.my_root(), "Detach", {}, "", function()
    detach_attached_vehicle()
end)


menus.adjust_position = menu.list(menu.my_root(), "Adjust Position")

menus.position_x = menu.slider_float(menus.adjust_position, "X: Left / Right", { "wastetrailerposx"}, "", -10000000, 10000000, math.floor(state.attached_vehicle.offset.x * 100), config.edit_offset_step, function(value)
    state.attached_vehicle.offset.x = value / 100
    update_attachment_position(state.attached_vehicle)
end)
menus.position_y = menu.slider_float(menus.adjust_position, "Y: Forward / Back", {"wastetrailerposy"}, "", -10000000, 10000000, math.floor(state.attached_vehicle.offset.y * -100), config.edit_offset_step, function(value)
    state.attached_vehicle.offset.y = value / -100
    update_attachment_position(state.attached_vehicle)
end)
menus.position_z = menu.slider_float(menus.adjust_position, "Z: Up / Down", {"wastetrailerposz"}, "", -10000000, 10000000, math.floor(state.attached_vehicle.offset.z * -100), config.edit_offset_step, function(value)
    state.attached_vehicle.offset.z = value / -100
    update_attachment_position(state.attached_vehicle)
end)
