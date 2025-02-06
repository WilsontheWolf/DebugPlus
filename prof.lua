-- Modified from https://gist.github.com/cigumo/88d7f84ca364015eaf577590db7e6577

local logger = require "debugplus.logger"

local profSucc, profile = pcall(require, "jit.profile")
if not profSucc then
	logger.debug("jit.profile unavalible. Falling back to vanilla profiler.\n", profile)
	return require "engine/profile"
end
local vmdefSucc, vmdef = pcall(require, "jit.vmdef")
if not vmdefSucc then
	logger.debug("jit.vmdef unavailable. Profiler will not be able to resolve builtins.\n", vmdef)
	vmdef = nil
end

local format  = string.format
local sort    = table.sort
local math    = math
local floor   = math.floor
local vmstates = {
    N = "Native",
    I = "Interpreted",
    C = "C Code",
    G = "Garbage Collector",
    J = "JIT Compiler",
}

local prof = {}

prof.running = false
prof.flag_l2_shown = true
prof.flag_l2_levels = 3
prof.profiler_fmt = "Fi10"
prof.min_percent = 1
prof.l1_stack_fmt = "F"
prof.l2_stack_fmt = "l <"
prof.counts = {}  -- double index
prof.top_str = nil

local total_samples = 0

------------------------------------------------------------
local function prof_cb(thread,samples,vmmode)
    local c = prof.counts
    total_samples = total_samples + samples
    local l1_stack = profile.dumpstack(thread, prof.l1_stack_fmt, 1)
    local l2_stack = profile.dumpstack(thread, prof.l2_stack_fmt, 5)

	if vmdef then
		l1_stack = l1_stack:gsub("%[builtin#(%d+)%]", function(x) return vmdef.ffnames[tonumber(x)] end)
		l2_stack = l2_stack:gsub("%[builtin#(%d+)%]", function(x) return vmdef.ffnames[tonumber(x)] end)
	end

    if not c[l1_stack] then
        local vl1 = {key=l1_stack, count=0, callers={}, vmmodes = {}}  -- double index
        c[l1_stack] = vl1
        c[#c+1] = vl1
    end
    c[l1_stack].count = c[l1_stack].count + samples
    c[l1_stack].vmmodes[vmmode] = (c[l1_stack].vmmodes[vmmode] or 0) + 1

    if not c[l1_stack].callers[l2_stack] then
        local vl2 = {key=l2_stack, count=0, vmmodes = {}}
        local c2 = c[l1_stack].callers
        c2[l2_stack] = vl2
        c2[#c2+1] = vl2
    end
    c[l1_stack].callers[l2_stack].count = c[l1_stack].callers[l2_stack].count + samples
    c[l1_stack].callers[l2_stack].vmmodes[vmmode] = (c[l1_stack].callers[l2_stack].vmmodes[vmmode] or 0) + 1
end

local function format_vmmodes(vmmodes)
    local ret = ""
    for k,v in pairs(vmmodes) do
        if ret ~= "" then
            ret = ret .. ", "
        end
        ret = ret .. (vmstates[k] or k) .. ": " .. tostring(v)
    end
    return ret
end

function prof.format_result()
    local c = prof.counts
    local out = {}

    -- sort l1
    sort(c, function(a,b) return a.count > b.count end)

    -- sort l2
    for i,v in ipairs(c) do
        sort(v.callers, function(a,b) return a.count > b.count end)
    end

    -- format
    for i=1,#c do
        local vl1 = c[i]
        local pct = floor(vl1.count * 100 / total_samples + 0.5)
        if pct < prof.min_percent then break end
        table.insert(out, format("%2d%% %s (%s)", pct, vl1.key, format_vmmodes(vl1.vmmodes)))
        local c2 = vl1.callers

        if prof.flag_l2_shown then
            for j=1,#c2 do
                if j > prof.flag_l2_levels then break end
                local vl2 = c2[j]
                table.insert(out, format("    %4d %s (%s)", vl2.count, vl2.key, format_vmmodes(vl2.vmmodes)))
            end
        end
    end

    return table.concat(out,'\n')
end

prof.report = prof.format_result

function prof.start()
    if prof.running then
        logger.error("Profiler already running?")
        return
    end

    total_samples = 0
    prof.counts = {}
    profile.start(prof.profiler_fmt, prof_cb)
    prof.running = true
end

function prof.stop()
    if not prof.running then
        logger.error("Profiler not running?")
        return
    end
    profile.stop()
    prof.running = false
    prof.flag_dirty = true
end


------------------------------------------------------------
return prof

