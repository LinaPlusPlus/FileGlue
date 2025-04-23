--BUG file commands must have a command or they are inserted into the document

local args = {...}

local attaches = {}; --files to be consumed
local resolveds = {}; --resolved files

--BEGIN the global object
local glue = {
    commandGlob="(.*)%-%-!(.+)%s-",
    commandExtendedGlob="(.*)%-%-%+(.+)%s-",
    changeGlobGlob="(.*)FILEGLUE_COMMAND_GLOB%=(.*)%s-",
    fileLocals = {},
    masterFile = nil, -- file for setup reasons
    target = nil, -- sets the target, `if enabled ~= a boolean then enabled = (enabledString or name) == target end`
    verbose = true,
};


for k,v in pairs(_G) do
    glue[k] = v;
end
--END

glue.docs = {};
glue.stages = {};
glue.bounds = {};

local anon_stage_name = 0;
local anon_bound_name = 0;

function glue.fileLocalRestore()
    for k,v in pairs(glue.fileLocals) do
        if glue.verbose then
            print(("reverting %q to: %s"):format(k,v));
        end
        glue[k] = v;
    end
    glue.fileLocals = {};
end
function glue.fileLocal(...)
    for i=1,select("#",...) do
        local saveK = select(i,...);
        glue.fileLocals[saveK] = glue[saveK]
    end
end

function glue.basepath(filePath)
    return filePath:match("^(.*[\\/])") or "./"
end

function glue.stage(stage)
    if not stage.name then
        stage.name = "stage"..tostring(anon_stage_name);
        anon_stage_name = anon_stage_name + 1
    end

    if not stage.fromFile then --some syntax shugar
        stage.fromFile = glue.currentFile or "unknown";
    end

    stage.explicit = true;

    -- NOTE interesting quirk, non explicit elements are: stage.inside = {};
    if not stage.inside then --some syntax shugar
        stage.inside = {"document"}
    end
    if glue.stages[stage.name] then
        error("stage names are unique, cannot create: "..stage.name)
    end
    glue.stages[stage.name] = stage;
end

function glue.smartUpdate(host,changes,weak)
    for name,change in pairs(changes) do
        local original = host[name];
        local originalType,changeType = type(original),type(change);
        print("smart",name,change,originalType,changeType);
        if originalType == "table" then
            if changeType ~= "table" then
                error(("type mismatch updating %q: because original value is a table: expected table, got %s")
                :format(name,changeType))
            end

            local existMap = {};
            for k,v in ipairs(original) do
                existMap[v] = k;
            end

            for k,v in pairs(change) do
                if type(k) == "number" then
                    if existMap[v] then
                    else
                        table.insert(original,v);
                    end
                elseif not weak then
                    original[k] = v;
                end
            end

        elseif not weak or original == nil then
            host[name] = change;
        end
    end
end

function glue.bound(bound)
    if not bound.name then
        bound.name = "bound"..tostring(anon_bound_name);
        anon_bound_name = anon_bound_name + 1
    end
    if glue.bounds[bound.name] then
        error("bound names are unique, cannot create: "..bound.name)
    end
    glue.bounds[bound.name] = bound;
end

function glue.include(file,rel)
    if rel ~= false then
        local basepath = glue.basepath(glue.currentFile or ".");
        file = basepath .. file;
    end
    if glue.verbose then
        print("scheduled: "..file);
    end
    if resolveds[file] then return end;
    attaches[file] = true;
    resolveds[file] = true;
end

function glue.load(code,name,typeof,global)
    global = global or glue;
    return load(code,name,typeof,global);
end

function glue.linemap(inp,map)
    local lines = {};
    for str in inp:gmatch("([^\n]+)") do
        if map then str = map(str) end
        table.insert(lines,str);
    end
    return table.concat(lines,"\n")
end

glue.cantWrite = glue.cantWrite or "cant write to file during declaration,\ntry: stage{ name = 'yourstage', inside={'body'} }"


glue.bound{
    name="body",
    before={"footer"},
    after={"header"},
    wants={"header","footer"},
}

glue.bound{
    name="header",
    before={"footer","header"},
    after={"first"},
    wants={"header","footer"},
}

glue.bound{
    name="footer",
    after={"header","footer"},
    before={"last"},
    wants={"header","footer"},
}

glue.stage{
    disabled=true,
    name="first",
    before={"header"},
    wants={"header","footer"},
}

glue.stage{
    disabled=true,
    name="last",
    after={"footer"},
    wants={"header","footer"},
}

glue.bound{
    name="last",
    after={"last"},
    before={"teardown"},
    wants={"last","header","footer"},
}

glue.bound{
    name="first",
    before={"first"},
    after={"setup"},
    wants={"last","header","footer"},
}


glue.bound{
    name="document",
    after={"setup"},
    before={"teardown"},
    enables={"setup","teardown"},
}

glue.bound{
    name = "noCode",
    enabled_by = {"noCode"},
}

glue.stage{
    name = "noCode",
    enabled_without = {"header","footer"},
    enabled = false,
    call = function() print("WARN: no code was generated") end,
    inside = {},
}


glue.stage{
    name = "setup",
    before = {"header"},
    call = function() glue.cantWrite = nil end,
    inside = {},
}

glue.stage{
    name = "header",
    enabled = false,
}

glue.stage{
    name = "footer",
    after = {"header"},
    before = {"teardown"},
    enabled = false,
}

glue.stage{
    name = "teardown",
    after = {"footer"},
    inside = {},
    call = function() glue.cantWrite = "cant write during teardown" end
}


local outputPath
do
    local locked = false;
    local kmode = false;
    for i,k in pairs(args) do
        if locked then
            if not outputPath then
                outputPath = k
            else
                glue.include(k);
            end
        elseif k == "--" then
            locked = true
        elseif kmode then

            glue[kmode] = v;
            kmode = false;
        else
            local a = k:match("%-%-(.+)");
            local k,v;
            if a then
                k,v = a:match("(.-)=(.+)");
            end
            if a then
                if k then
                    v = tonumber(v) or v;
                    if v == "true" then v = true end
                    if v == "false" then v = false end
                    if v == "nil" then v = nil end
                    if glue["verbose-params"] then
                        print(("param: --%s is %s: %q"):format(kmode,type(v),v));
                    end
                    glue[k] = v;
                else
                    glue[a] = true
                end
            else
                locked = true;
                outputPath = a;
            end
        end
    end


    if not outputPath then
        print "usage: lua fileglue.lua [options...] <output> <files...>"
        return
    end

end

local exists = io.open(outputPath,"r");
if exists then
    exists:close();
    print (("the output %q already exists..."):format(outputPath));
    io.write("overrite? [y/n] ");
    local got = io.read();
    if got ~= "y" then
        error("not overriting file...");
        return;
    end
end

glue.outputFile = assert(io.open(outputPath,"w+"));

-- like write but allows for abstraction
-- is made to be overritten
function glue.writeAbstract(stage)
    return glue.write("%s",stage.write);
end

function glue.write(...)
    glue.outputFile:write(string.format(...));
end

local did_work = false;

function glue.statement(command)
    local ok;
    local fname = ("inside: %s"):format(glue.currentFile);
    local blob,err = load("local glue = ...; "..command,fname,nil,glue);
    if not blob then
        if glue.onError then return glue.onError(command,err,"parse") else
            local c =
            "\n\n\27[90m from file: %s"..
            "\n\27[90m----- command -----\n\27[0m%s" ..
            "\n\27[90m-------------------\27[0m" ..
            "\n\27[31m%s\27[0m"
            return false,c:format(glue.currentFile,command,err);
        end
    end
    ok,err = pcall(blob,glue);
    if not ok then
        if glue.onError then return glue.onError(command,err,"eval") else
            local c =
            "\n\n\27[90mfrom file: %s"..
            "\n\27[90m----- command -----\n\27[0m%s" ..
            "\n\27[90m-------------------\27[0m" ..
            "\n\27[31m%s\27[0m"
            return false,c:format(glue.currentFile,command,err);
        end
    end
    return true;
end



function glue._readFile(path)
    glue.currentFile = path;
    if glue.verbose then print("read file: "..path) end
    local bld = {};
    local upcoming_cmd = "";
    local script = assert(io.open(path,"r"));
    local blob = function(glue) end --ignore first lines
    local line = nil;
    local function do_cmd(command)
        if glue['verbose-lines'] then print("command: "..command) end
        table.insert(bld,"");
        glue.block = table.concat(bld,"\n");
        glue.lastCommand = command;
        bld = {};
        local ok,err = glue.statement(command);
        if glue.hault then ok,err = false,glue.hault end
        if not ok then return ok,err end;
        return true;
    end
    while not glue.hault do
        line = script.readLine and script.readLine() or script.read(script,"*l");
        if not line then break end
        local eccess,_command = line:match(glue.commandGlob);
        local eeccess,_ecommand = line:match(glue.commandExtendedGlob);
        local eee_eccess,_ch_command;
        if glue.changeGlobGlob then
           eee_eccess,_ch_command = line:match(glue.changeGlobGlob);
        end
        if _ch_command then
            if glue.verbose then print("command glob changed: ".._ch_command) end
            glue.fileLocal("commandGlob","changeGlobGlob");
            glue.changeGlobGlob = false;
            glue.commandGlob = _ch_command;
        end
        if _command and eccess == "" then
            did_work = true;
            local command = upcoming_cmd or "";
            upcoming_cmd = _command;
            local ok,err = do_cmd(command);
            if not ok then return ok,err; end
        elseif _ecommand and eeccess == "" then
            did_work = true;
            upcoming_cmd = ("%s\n%s"):format(upcoming_cmd,_ecommand);
        else
            if glue['verbose-lines'] then print("line: "..line) end
            table.insert(bld,line);
        end
    end
    if not did_work then
        print ("no commands, converted to stage: "..glue.currentFile);
        glue.stage {
            name= glue.currentFile,
            enabled=false,
            write=table.concat(bld,"\n"),
        }
    else
        local ok,err = do_cmd(upcoming_cmd)
        if not ok then return ok,err; end
    end
    glue.fileLocalRestore();
    return true;
end

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

print(("preparing stages:\n"));

local stagedefs = glue.stages;
local stages = {};

local function getStage(name)
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
local function apply_inside(stagedef,inside,seen)
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

locational_enable();
print("")
locational_apply()

glue.outputFile:close();


if glue.returnMessage == "error" then
    print("Output FAILED.")
elseif glue.returnMessage == "warn" then
    print("Compilation Generated Warnings.")
elseif glue.returnMessage then
    print(glue.returnMessage);
else
    print("All OK.")
end

return glue.returnCode or 0;
