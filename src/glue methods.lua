--! stage {name = "glue.methods", after={"glue.declare","declarations"}, write=block}
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



-- like write but allows for abstraction
-- is made to be overritten
function glue.writeAbstract(stage)
return glue.write("%s",stage.write);
end

function glue.write(...)
glue.outputFile:write(string.format(...));
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

function glue.outputFile()
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

    glue._outputFile = assert(io.open(outputPath,"w+"));

    function glue.outputFile()
        return glue._outputFile;
    end
    return glue._outputFile;
end
