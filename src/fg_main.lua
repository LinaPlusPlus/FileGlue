
--! stage {name="remainder", after={"glue.methods"}}
local function runMainFile() --or at leas I think
    if glue.masterFile then
        local ok,err = glue._readFile(glue.masterFile);
        if not ok then
            print(err);
            if os.exit and not FILEGLUE_NO_OS_EXIT then os.exit(5); end
            return false;
        end
    end
    for k,v in pairs(attaches) do
        attaches[k] = nil;
        local ok,err = glue._readFile(k);
        if not ok then
            print(err);
            if os.exit and not FILEGLUE_NO_OS_EXIT then os.exit(5); end
            return false;
        end
    end
end

runMainFile() --TEMP

print(("preparing stages:\n"));

local stagedefs = glue.stages;
local stages = {};

--...

for name,stagedef in pairs(stagedefs) do
    apply_inside(stagedef,stagedef.inside);
end

for name,stagedef in pairs(stagedefs) do
    local stage = getStage(name);
    local function sis_apply(opt,mykey,mystate,siskey,sistate)
        if opt then
            for _,name in pairs(opt) do
                local sister = getStage(name);
                if siskey then sister[siskey][stage] = sistate; end
                if mykey then stage[mykey][sister] = mystate; end
            end
        end
    end

    sis_apply(stagedef.before,nil,nil,"after",true);
    sis_apply(stagedef.after,"after",true,nil,nil);

    sis_apply(stagedef.else_enables,nil,nil,"enablers",false);
    sis_apply(stagedef.else_disables,nil,nil,"disablers",false);
    sis_apply(stagedef.enables,nil,nil,"enablers",true);
    sis_apply(stagedef.disables,nil,nil,"disablers",true);
    sis_apply(stagedef.enabled_by,"enablers",true);
    sis_apply(stagedef.disabled_by,"disablers",true);
    sis_apply(stagedef.enabled_without,"enablers",false);
    sis_apply(stagedef.disabled_without,"enablers",false);

    sis_apply(stagedef.wants,"wants",true,"enablers",true);
    sis_apply(stagedef.phobic,"wants",false,"disablers",true);

    stage.call = stagedef.call;
    stage.write = stagedef.write;
    stage.fromFile = stagedef.fromFile;
    stage.state = stage.state or "ready"

    local target = glue.target;
    local defn_enabled = stagedef.enabled;

    if defn_enabled == nil and stagedef.explicit then
        defn_enabled = true;
    end

    if target and type(defn_enabled) == "string" then
        stage.default_enabled = defn_enabled == glue.target;
    elseif target and stagedef.enabled == nil then
        stage.default_enabled = stage.name == glue.target;
    else
        stage.default_enabled = not not defn_enabled;
    end

    if glue["disabled-"..stage.name] then
        stage.default_enabled = false; --override default enabled status
        --FIXME work this form of disabled handling
    end
    if glue["enabled-"..stage.name] then
        stage.default_enabled = true; --override default enabled status
    end

    stage.def = stagedef;
    stagedef.__stage = stage;
end
