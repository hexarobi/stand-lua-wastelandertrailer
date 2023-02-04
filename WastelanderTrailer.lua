-- WastelanderTrailer
-- by Hexarobi

local SCRIPT_VERSION = "0.2"

---
--- Dependencies
---

util.require_natives(1651208000)

---
--- State
---

local attachments = {}
local menus = {}

---
--- Utils
---

-- From https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating
local function array_remove(t, fnKeep)
    local j, n = 1, #t;

    for i=1,n do
        if (fnKeep(t, i, j)) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end

    return t;
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
    return {x = maximum_vec.y - minimum_vec.y, y = maximum_vec.x - minimum_vec.x, z = maximum_vec.z - minimum_vec.z}
end

local function set_attachment_offset_for_root(attachment)
    local root_model = util.reverse_joaat(ENTITY.GET_ENTITY_MODEL(attachment.root))
    local dimensions = get_vehicle_dimension(attachment.handle)

    if root_model == "wastelander" then
        attachment.offset = {
            x=0,
            y=(dimensions.y / 2) - 2,
            z=(dimensions.z / 2) + 0.8
        }
    end

    if root_model == "slamtruck" then
        attachment.offset = {
            x=0,
            y=(dimensions.y / 2) - 3,
            z=(dimensions.z / 2) + 0.3
        }
        attachment.rotation = {
            x=8,
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
    for _, existing_attachment in pairs(attachments) do
        ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(existing_attachment.handle, attachment.handle)
    end

    return attachment
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
                attachment.name = VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(ENTITY.GET_ENTITY_MODEL(attachment.handle))
                util.toast("Attaching "..attachment.name)
                attach(attachment)
                table.insert(attachments, attachment)
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
    array_remove(attachments, function(t, i, j)
        local attachment = t[i]
        util.toast("Detaching "..attachment.name)
        ENTITY.DETACH_ENTITY(attachment.handle, true, true)
        return true
    end)
end)
