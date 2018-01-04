-- contains general functions/attributes applicable to any Terumetal/heat-based machine
terumet.machine = {}
local base_mach = terumet.machine
local opts = terumet.options.machine

function base_mach.heat_pct(machine)
    return 100.0 * machine.heat_level / machine.max_heat
end

--
-- GENERIC FORMSPECS
--

-- general preamble setting background, colors
base_mach.fs_start = 'background[0,0;8,9;terumet_gui_bg.png;true]listcolors[#3a101b;#905564;#190309;#114f51;#d2fdff]'

-- fuel slot formspec
function base_mach.fs_fuel_slot(machine, fsx, fsy)
    return 'list[context;fuel;'..fsx..','..fsy..';1,1;]label['..fsx..','..fsy+1 ..';Fuel Slot]'
end

-- heat display formspec
function base_mach.fs_heat_info(machine, fsx, fsy)
    return 'image['..fsx..','..fsy..';2,2;terumet_gui_heat_bg.png^[lowpart:'..
    base_mach.heat_pct(machine)..':terumet_gui_heat_fg.png]label['..fsx..','..fsy+2 ..';Heat Level]'
end

-- flux display formspec
function base_mach.fs_flux_info(machine, fsx, fsy, percent)
    return 'image['..fsx..','..fsy..';2,2;terumet_gui_flux_bg.png^[lowpart:'..
    percent..':terumet_gui_flux_fg.png]label['..fsx..','..fsy+2 ..';Molten Flux]'
end

-- player inventory formspec
function base_mach.fs_player_inv(fsx, fsy)
    return 'list[current_player;main;'..fsx..','..fsy..';8,1;]list[current_player;main;'..fsx..','..fsy+1.25 ..';8,3;8]'
end

--
-- GENERIC META
--

function base_mach.read_state(pos)
    local machine = {}
    local meta = minetest.get_meta(pos)
    machine.meta = meta
    machine.inv = meta:get_inventory()
    machine.heat_level = meta:get_int('heat_level') or 0
    machine.max_heat = meta:get_int('max_heat') or 0
    machine.state = meta:get_int('state')
    machine.state_time = meta:get_float('state_time') or 0
    machine.status_text = meta:get_string('status_text') or 'No Status'
    -- following attributes are not saved in meta, but reset every tick
    machine.need_heat = false
    return machine
end

function base_mach.write_state(pos, machine, formspec, infotext)
    local meta = minetest.get_meta(pos)
    meta:set_string('formspec', formspec)
    meta:set_string('infotext', infotext)
    meta:set_string('status_text', machine.status_text)
    meta:set_int('heat_level', machine.heat_level)
    meta:set_int('max_heat', machine.max_heat)
    meta:set_int('state', machine.state)
    meta:set_float('state_time', machine.state_time)
end

--
-- GENERIC MACHINE PROCESSES
--

function base_mach.set_low_heat_msg(machine, process)
    if process then
        machine.status_text = process .. ': Insufficient heat'
    else
        machine.status_text = 'Insufficient heat'
    end
end

-- handle basic fuel heating
function base_mach.process_fuel(machine)
    local fuel_item = machine.inv:get_stack('fuel',1)
    local heat_source = opts.basic_heat_sources[fuel_item:get_name()]
    if heat_source and (machine.max_heat - machine.heat_level) >= heat_source.hus then
        local return_item = heat_source.return_item
        if fuel_item:get_stack_max() > 1 then
            if (not return_item) or machine.inv:room_for_item('out', return_item) then
                machine.inv:add_item('out', return_item)
            else
                machine.status_text = 'Fuel: no space for ' .. minetest.registered_items[return_item].description
                return
            end
            machine.inv:remove_item('fuel', fuel_item:get_name())
        else
            machine.inv:set_stack('fuel', 1, return_item)
        end
        machine.heat_level = math.min(machine.max_heat, machine.heat_level + heat_source.hus)
        machine.need_heat = false
    end
end

-- handle expending heat
-- returns true if successful, false if not enough heat
-- automatically sets need_heat and "low heat message" if fails
function base_mach.expend_heat(machine, value, process)
    if machine.heat_level < value then
        base_mach.set_low_heat_msg(machine, process)
        machine.need_heat = true
        return false 
    end
    machine.heat_level = machine.heat_level - value
    return true
end

--
-- GENERIC CALLBACKS
--

function base_mach.allow_put(pos, listname, index, stack, player)
    if minetest.is_protected(pos, player:get_player_name()) then
        return 0 -- number of items allowed to move
    end
    if listname == "fuel" then
        if opts.basic_heat_sources[stack:get_name()] then
            return stack:get_count()
        else
            return 0
        end
    elseif listname == "inp" then
        return stack:get_count()
    else
        return 0
    end
end

function base_mach.allow_take(pos, listname, index, stack, player)
    if minetest.is_protected(pos, player:get_player_name()) then
        return 0
    end
    return stack:get_count()
end

function base_mach.allow_move(pos, from_list, from_index, to_list, to_index, count, player)
    --return count
    local stack = minetest.get_meta(pos):get_inventory():get_stack(from_list, from_index)
    return base_mach.allow_put(pos, to_list, to_index, stack, player)
end