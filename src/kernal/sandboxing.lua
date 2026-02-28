LOADED_FILE_PATHS = {};

function new_sandbox(thread)
    local sandbox = {
        assert   = assert,
        error    = error,
        ipairs   = ipairs,
        next     = next,
        pairs    = pairs,
        pcall    = pcall,
        select   = select,
        tonumber = tonumber,
        tostring = tostring,
        type     = type,
        xpcall   = xpcall,

        math = {
            abs        = math.abs,
            acos       = math.acos,
            asin       = math.asin,
            atan       = math.atan,
            atan2      = math.atan2,
            ceil       = math.ceil,
            cos        = math.cos,
            cosh       = math.cosh,
            deg        = math.deg,
            exp        = math.exp,
            floor      = math.floor,
            fmod       = math.fmod,
            frexp      = math.frexp,
            huge       = math.huge,
            ldexp      = math.ldexp,
            log        = math.log,
            log10      = math.log10,
            max        = math.max,
            min        = math.min,
            modf       = math.modf,
            pi         = math.pi,
            pow        = math.pow,
            rad        = math.rad,
            random     = math.random,
            randomseed = math.randomseed,
            sin        = math.sin,
            sinh       = math.sinh,
            sqrt       = math.sqrt,
            tan        = math.tan,
            tanh       = math.tanh,
        },

        string = {
            byte    = string.byte,
            char    = string.char,
            dump    = string.dump,
            find    = string.find,
            format  = string.format,
            gmatch  = string.gmatch,
            gsub    = string.gsub,
            len     = string.len,
            lower   = string.lower,
            match   = string.match,
            rep     = string.rep,
            reverse = string.reverse,
            sub     = string.sub,
            upper   = string.upper,
        },

        table = {
            insert = table.insert,
            remove = table.remove,
            sort   = table.sort,
            concat = table.concat,
        },
    }

    sandbox._G = sandbox

    function sandbox.load(chunk, chunkname, mode, env)
        return load(chunk, chunkname, "t", env or sandbox)
    end

    -- TODO use the custom loader
    function sandbox.loadfile(filename, env)
        return loadfile(filename, "t", env or sandbox)
    end

    function sandbox.dofile(filename)
        local f, err = sandbox.loadfile(filename)
        if not f then error(err) end
        return f()
    end

    -- TODO build a custom system for this
    function sandbox.require()
        error("require is disabled")
    end

    function sandbox.getmetatable(t,metatable)
        local l = getmetatable(t);
        return l;
    end

    function sandbox.setmetatable(t,metatable)
        setmetatable(t,metatable);
        return t;
    end

    local meta = {
        __metatable = {},
    };
    function meta:__index(k)


        if k == nil then error(debug.traceback("Attempt to index global nil")) end

        local got = thread.p_global[k];
        if got ~= nil then return got end


        local byte = string.byte(k)
        local upper = byte >= 65 and byte <= 90;
        if upper then -- we are a global key
            got = SHARED_GLOBAL[k]
            if got ~= nil then return got end

            log("trace",thread.label,"awaiting global %q",k)
            watcher_yield(SHARED_GLOBAL_WATCHER,k,thread);
            coroutine.yield();
            return SHARED_GLOBAL[k];

        else -- we are a document-wide key
            got = thread.group_global[k]
            if got ~= nil then return got end

            log("trace",thread.label,"awaiting document %q",k)
            watcher_yield(thread.group_watcher,k,thread);
            coroutine.yield();
            return thread.group_global[k];

        end
        
    end

    function meta:__newindex(k,v)
        
        if k == nil then error(debug.traceback("Attempt to index global nil")) end
        
        local byte = string.byte(k)
        local upper = byte >= 65 and byte <= 90;
        if upper then
            log("trace",thread.label,"defined global %q",k)
            SHARED_GLOBAL[k] = v;
            watcher_resume(SHARED_GLOBAL_WATCHER,k);
        else
            log("trace",thread.label,"defined document %q",k)
            thread.group_global[k] = v;
            watcher_resume(thread.group_watcher,k);
        end
    end
    setmetatable(sandbox, meta)
    thread.global = sandbox;
end

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
    function pglobal.commands.sub(var,sub)
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

    function pglobal.commands.await(var)
        --TODO add waiter logic
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
    
    --TODO add safety
    pglobal.log = log;

    pglobal.dump = dump;

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