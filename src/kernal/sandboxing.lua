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
        local byte = string.byte(k)
        local upper = byte >= 65 and byte <= 90;
        if upper then -- we are a global key
            local got = SHARED_GLOBAL[k]
            if got ~= nil then return got end

            log("trace",thread.label,"awaiting global %q",k)
            watcher_yield(SHARED_GLOBAL_WATCHER,k,thread);
            coroutine.yield();
            return SHARED_GLOBAL[k];

        else -- we are a document-wide key
            local got = thread.group_global[k]
            if got ~= nil then return got end

            log("trace",thread.label,"awaiting document %q",k)
            watcher_yield(thread.group_watcher,k,thread);
            coroutine.yield();
            return thread.group_global[k];

        end
        
    end

    function meta:__newindex(k,v)
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

function add_common_functions(global)
    --TODO add more
    function global.repl()  

        local group = CURRENT_THREAD.group;
        local counter = 0;

        while true do
            counter = counter +1
            --io.write(("(%s) --> "):format(counter));
            --local code = io.read();
            local ok,err = repl_prompt(("(%s) --> "):format(counter));
            if not ok then return ok,err end

            local thread = thread_spawn(("repl%s"):format(counter),group);

            ok = global.luishe.tolua(ok);
            
            ok,err = thread.global.load(ok,"");

            if ok then 
                thread.co = coroutine.create(ok);
            else
                thread.co = coroutine.create(function()
                    log("error",CURRENT_THREAD.label,"%s",err:sub(16))    
                end);
            end

            global.defer();


        end
        
        
    end

    function global.defer() 
        table.insert(LATER_RESUME_THREADS,CURRENT_THREAD);
        coroutine.yield()
    end

    global.luishe = {};

    function global.luishe.tolua(statement)
        local ok = Luishe.parse( statement );
            
        ok = Luishe.toLua(ok,{
            _G = global,
            table = global.table,
            string = global.string,
            math = global.math,
            commands = global.commands,
        })
        return ok;
    end

    global.commands = {};

    function global.commands.stage(...)
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

    function global.commands.set(var,value)
        global[var] = value;
    end 

    function global.commands.await(var)
        --TODO add waiter logic
    end

    function global.commands.eval(statement)
        local l = global.luishe.tolua(statement);
        local ok,err = global.load(l,statement);
        assert(ok,err);
        return ok;
    end

    function global.commands.lua(statement)
        local ok,err = global.load(statement);
        assert(ok,err);
        return ok;
    end

    --TODO add wrapper to log
    global.print = print;
    
    --TODO add safety
    global.log = log;

    global.dump = dump;
end

function add_system_functions(global)
    global.kernal = _G;
    --TODO add more
end