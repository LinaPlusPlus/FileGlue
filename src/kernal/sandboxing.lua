
local GLOBALDEF_LOGGING = false;
function globals_logging(on)
    GLOBALDEF_LOGGING = on ~= false;
end

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

    -------[Modified Loaders]--------

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

    -------[Modified type logic]--------

    function sandbox.type(t)
        local typeof = type(t);

        if typeof == "table" then 
            local a = debug.getmetatable(t);
            local try = a and rawget(a,"__type");
            if try then return try end
        end

        return typeof;
    end

    function sandbox.getmetatable(t,metatable)
        local l = getmetatable(t);
        return l;
    end

    function sandbox.setmetatable(t,metatable)
        setmetatable(t,metatable);
        return t;
    end

    -------[extended IO logic]--------

    -- doubles as a 'read' function
    function sandbox.await(t)
        local typeof = type(t);

        if typeof ~= "table" then 
            return t;
        end

        local a = debug.getmetatable(t);
        local try = a and rawget(a,"__await");
        if try then return try(t) end

        try = t.await;
        if try then return try(t) end

        return t;
    end

    function sandbox.writef(t,...)
        return sandbox.write(t,string.format(...));
    end

    -- this can in theory also block
    function sandbox.write(t,...)
        local typeof = type(t);

        if typeof ~= "table" then 
            error(("%s: not a writable"):format(t));
        end

        local a = debug.getmetatable(t);
        local try = a and rawget(a,"__write");
        if try then return try(t,...) end
        error(("%s: not a writable"):format(t));
    end

    -------[Done]--------

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

            if GLOBALDEF_LOGGING then 
                log("trace",thread.label,"awaiting global %q",k)
            end
            watcher_yield(SHARED_GLOBAL_WATCHER,k,thread);
            coroutine.yield();
            return SHARED_GLOBAL[k];

        else -- we are a document-wide key
            got = thread.group_global[k]
            if got ~= nil then return got end
            if GLOBALDEF_LOGGING then 
                log("trace",thread.label,"awaiting document %q",k)
            end
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
            if GLOBALDEF_LOGGING then 
                log("trace",thread.label,"defined  global %q",k)
            end
            SHARED_GLOBAL[k] = v;
            watcher_resume(SHARED_GLOBAL_WATCHER,k);
        else
            if GLOBALDEF_LOGGING then 
                log("trace",thread.label,"defined  document %q",k)
            end
            thread.group_global[k] = v;
            watcher_resume(thread.group_watcher,k);
        end
    end
    setmetatable(sandbox, meta)
    thread.global = sandbox;
end

