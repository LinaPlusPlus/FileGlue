local unpack = _G.unpack or table.unpack;

function add_common_functions(thread)
    local global = thread.global;
    local pglobal = thread.p_global;
    --TODO add more
    function pglobal.repl()  

        local group = CURRENT_THREAD.group;
        local counter = 0;

        while true do
            counter = counter +1
            --io.write(("(%s) --> "):format(counter));
            --local code = io.read();
            local ok,err = repl_prompt(("(%s) --> "):format(counter));
            if not ok then return ok,err end

            local child_thread = thread_spawn(("repl%s"):format(counter),group);
            add_common_functions(child_thread);

            if ok then 
                child_thread.co = coroutine.create(function()
                        -- YAY, now we are async parsing
                        ok = child_thread.global.luishe.tolua(ok);
                        ok,err = child_thread.global.load(ok,"");
                        assert(ok,err) -- HACK    
                        ok();
                end);
            else
                child_thread.co = coroutine.create(function()
                    log("error",child_thread.label,"%s",err:sub(16))    
                end);
            end

            global.defer();

        end
        
        
    end

    function pglobal.defer() 
        table.insert(LATER_RESUME_THREADS,CURRENT_THREAD);
        coroutine.yield()
    end

    pglobal.luishe = {};

    function pglobal.luishe.tolua(statement)
        local ok = Luishe.parse( statement );
            
        ok = Luishe.toLua(ok,{
            {"commands",global.commands},
            {"table",global.table},
            {"string",global.string},
            {"math",global.math},
            {"_G",global}, -- index last
        })
        return ok;
    end

    pglobal.commands = {};

    function pglobal.commands.stage(...)
        -- TODO implement the Stage object
        -- do arg parsing and apply to "apon $mystage" or the _G.Stage object
        -- blocks if "await" is set, calls any "then <callback>"s

        -- stage <name> [before <stage>|after <stage>|apon <stageObject>|
        -- enables <stage>|disables <stage>|enabled-by <stage>|disabled-by <stage>|
        -- then <callback>|await]
        local do_await = false;
        local apon = global.Stage;
        local commands = {};
        local stage_name = nil;

        local n = select("#", ...)  -- total number of args (including nil)
        local k = nil;
        for i = 1, n do
            local v = select(i, ...)
            if stage_name == nil then
                stage_name = v;
            elseif k then
                if k == "apon" then 
                    apon = v;
                else
                    table.insert(commands,{
                        command = k,
                        value = v,
                    });
                end
                k = nil;
            else 
                if v == "await" then 
                    do_await = true;
                else
                    k = v;
                end
            end
        end

        for k,v in ipairs(commands) do
            if v.command == "before" then
                apon:order(stage_name, v.value); -- b after a
            elseif v.command == "after" then
                apon:order(v.value, stage_name); 
            elseif v.command == "enables" then
                --TODO
            elseif v.command == "disables" then
                --TODO
            elseif v.command == "enabled-by" then
                --TODO
            elseif v.command == "disabled-by" then    
                --TODO
            else 
                error(("stage: unknown argument: %s"):format(v.value))
            end
        end

    end


    -- TODO allow deep paths
    function pglobal.commands.unsetsub(var,sub)
        var[sub] = nil
    end 

    function pglobal.commands.setsub(var,sub,value)
        var[sub] = value or false
    end 

    function pglobal.commands.getsub(var,sub)
        return var[sub]
    end 

    function pglobal.commands.unset(var)
        global[var] = nil
    end

    function pglobal.commands.set(var,value)
        -- the "or false" is a HACK
        -- setting a global to nil unblocks once
        -- rather than staying unblocked

        global[var] = value or false; 
    end 

    function pglobal.commands.eval(statement)
        local l = global.luishe.tolua(statement);
        local ok,err = global.load(l,statement);
        assert(ok,err);
        return ok;
    end

    function pglobal.commands.lua(statement,...)
        local ok,err = global.load(statement);
        assert(ok,err);
        return ok(...);
    end

    --TODO add wrapper to log
    pglobal.print = print;

    function pglobal.print(...)
        local lstr = string.rep("%s\t", select("#",...));
        log("print",thread.label,lstr,...);
    end
    
    --pglobal.log = log;
    function pglobal.warn(...)
        local lstr = string.rep("%s\t", select("#",...));
        log("warn",thread.label,lstr,...);
    end

    --pglobal.log = log;
    function pglobal.info(...)
        local lstr = string.rep("%s\t", select("#",...));
        log("info",thread.label,lstr,...);
    end
    
    --TODO add safety
    pglobal.dump = dump;

    pglobal.promise = new_promise;

    function pglobal.import(file)
        if LOADED_FILE_PATHS[file] then 
            return true --TODO return a handle to document variables
        end

        --TODO add search functionality
        local handle,err = io.open(file,"r");

        if not handle then 
            error("Cannot load file: "..err);
        end

        local group = group_spawn(file);
        LOADED_FILE_PATHS[file] = group;

        read_arrow_file(handle,function(heading,buildup,line)
            local name = ("%s:%s"):format(file,line);

            if not heading then return end
            
            local child_thread = thread_spawn(name,group);
            add_common_functions(child_thread);
            
            local body = table.concat(buildup,"\n");
            child_thread.p_global.body = body;
            child_thread.p_global.__FILE = file;
            --child_thread.p_global.__DIR = 

            child_thread.co = coroutine.create(function()
                local ok,err;
                ok,err = child_thread.global.luishe.tolua(heading);
                assert(ok,err) -- HACK
                ok,err = child_thread.global.load(ok,name);
                assert(ok,err) -- HACK
                ok();
            end)
            

        end);

    end
end

function add_system_functions(global)
    global.kernal = _G;
    --TODO add more
end

function new_promise(name)

    -- also prevents memory leak for
    -- the life of the promise
    -- if `name` is evil
    local promise = {}
    name = ("promise: %s"):format(name or tostring(promise):sub(8));
    
    local awaiters = {};
    local resolved = nil;
    local meta = {}
    
    meta.__metatable = {}

    meta.__type = "promise";
    function meta:__tostring()
        return name
    end

    function meta:__read()
        if resolved then 
            return unpack(resolved)
        end
        
        table.insert(awaiters,CURRENT_THREAD)
        CURRENT_THREAD.yield_to_str = name
        coroutine.yield();
    
        return unpack(resolved)
    end

    function meta:__write(...)
        resolved = {...};
        for k,thread in ipairs(awaiters) do
            table.insert(RESUMABLE_THREADS,thread);
        end
        awaiters = {};
    end

    setmetatable(promise,meta);
    return promise;
    
end