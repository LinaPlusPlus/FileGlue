--! stage {name="stager", after={}}
local Stager = {};
Stager.__index = Stager;

function Stager:new(t)
    t=t or {};
    setmetatable(t,self);
end

function Stager:get(name)
    local got = stages[name];
    if got then return got end

    local start_enabled = false
    if glue["disabled-"..name] then
        --start_enabled = false; --override default enabled status
        --FIXME work on this form of disabled handling
    end
    if glue["enabled-"..name] then
        start_enabled = true; --override default enabled status
    end
    if glue.target == name then
        start_enabled = true;
    end

    got = {
        name = name,
        after = {},
        write = nil,
        enabled = nil,
        resolved = false,
        enabled_resolved = false,
        default_enabled = start_enabled, -- implicit stages are default disabled

        enablers_trip = false,
        disablers_trip = false,
        -- for k,v of (en/dis)ablers if enabled_resolved and k.enabled == v then set (en/dis)abler_trip flag
        -- resolving means having (en/dis)abler children settled and enabled = not disabler_trip and (enabler_trip or default_enabled)
        enablers = {},
        disablers = {},
        wants = {}, -- when stage enabled_resoves to enabled, (k guerinteed resolved) assert(k.enabled == v)
    };
    stages[name] = got;
    return got;
end

function Stager.applyInsideToStagedef(stagedef,inside,seen)
    seen=seen or {};
    if inside then
        for _,name in pairs(inside) do
            local bound = glue.bounds[name];
            if not bound then
                print("WARN: unknown bound: "..name);
                bound = {};
            end
            for boundK,boundV in pairs(bound) do
                if type(boundV) == "table" then
                    local hostV = stagedef[boundK];
                    if hostV == nil then --enshure is a table
                        hostV = {};
                        stagedef[boundK] = hostV;
                    end
                    for ck,cv in pairs(boundV) do --assign to that table as array and dict
                        if ck == "inside" then --special recursion case
                            if not seen[cv] then
                                seen[cv] = true;
                                apply_inside(stagedef,cv);
                            end
                        elseif type(ck) == "number" then
                            table.insert(hostV,cv);
                        else
                            hostV[ck] = cv;
                        end
                    end
                else --not a table
                    local hostV = stagedef[boundK];
                    local allowed = hostV == nil
                    if allowed then
                        stagedef[boundK] = boundV;
                    end
                end
            end
        end
    end
end



local function locational_apply()
    --why cant write? what was the logic?
    glue.cantWrite = "cannot write during setup,try adding after={\"header\"} or inside={'body'} to your stage";
    local unresolvedStages = {};
    for k,v in pairs(stages) do
        if v.enabled then
            unresolvedStages[v] = true;
        end
    end
    local hasWork = true;
    while hasWork do
        hasWork = false;
        for stage,_ in pairs(unresolvedStages) do
            local workCount = (stage.locational_work or 0) +1;
            stage.locational_work = workCount;
            if workCount > 1000 then
                print(("Error: stage %q cannot find it's arrangement, skipping..."):format(stage.name))
                glue.returnMessage = "error";
                unresolvedStages[stage] = nil;
            end

            hasWork = true;
            local cont = true;
            for cmpstage,tru in pairs(stage.after) do
                if cmpstage.resolved or not cmpstage.enabled then
                    stage.after[cmpstage] = nil;
                else
                    cont = false;
                    break;
                end
            end
            if cont then
                if glue.verbose then print("stage: "..stage.name); end
                --TODO add disable and error logic
                if stage.call then
                    local ok,err = pcall(stage.call,stage.def) --TODO error handling
                    assert(ok,err);
                end
                if stage.write then
                    local ok,err = pcall(glue.writeAbstract,stage.def) --TODO error handling
                    assert(ok,err);
                end
                stage.resolved = true;
                unresolvedStages[stage] = nil
            end
        end
    end
end

local function locational_enable()
    local unresolvedStages = {};
    for k,v in pairs(stages) do
        unresolvedStages[v] = true;
    end
    local hasWork = true;
    while hasWork do
        local function handle_tripping(stage,children,tripK)
            local work = false;
            if not stage[tripK] then
                for sister,must_be in pairs(children) do
                    work = true;
                    if sister.enabled_resolved then
                        if sister.enabled == must_be then
                            stage[tripK] = true;
                        else
                            children[sister] = nil; --remove from being processed again
                        end
                    end
                end
                return not work; -- is confidant "no" verdict
            end
            return false;
        end
        hasWork = false;
        for stage,_ in pairs(unresolvedStages) do
            hasWork = true;
            -- enablers and disablers have to have all children resolve before a untripped verdict is reached
            -- a single trip is a tripped verdict.


            local enabled_no  = handle_tripping(stage,stage.enablers,"enabler_trip");
            local disabled_no = handle_tripping(stage,stage.disablers,"disabler_trip");


            if stage.enabler_trip and disabled_no then --if explicit enabled
                stage.enabled_resolved = true;
                stage.enabled = true;
                if glue.verbose then print("+  enabled: "..stage.name); end
            elseif stage.disabler_trip then --if explicit disable
                stage.enabled_resolved = true;
                stage.enabled = false;
                if glue.verbose then print("+ disabled: "..stage.name); end
            elseif enabled_no and disabled_no then --not enabled nor disabled
                stage.enabled_resolved = true;
                stage.enabled = stage.default_enabled;
                local msg = stage.enabled and " enabled" or "disabled";
                if glue.verbose then print(("- %s: %s"):format(msg,stage.name)); end
            end

            if stage.enabled_resolved then
                unresolvedStages[stage] = nil;
            end

        end
        if hasWork and glue.verbose then print("* looped") end
    end
    for stage,_ in pairs(stages) do
        if stage.enabled then
            if stage.wants then
                for sistage,should_be in pairs(stage.wants) do
                    if sistage.enabled ~= should_be then
                        local msg = sistage.enabled and "enabled" or "disabled";
                        error(("%q wants %q to be %s"):format(stage.name,sistage.name,msg));
                    end
                end
            end
        end
    end
end

-- locational_enable();
-- locational_apply()
