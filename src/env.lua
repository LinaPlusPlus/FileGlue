-- unlike the kernal project, this is not about supervised code's safety or efficency

local env_mt = {};

function env_mt:__index(k)
    local tryval;
    if DO_TRACE then
        log("trace",SYNTAX_THREAD(CURRENT_THREAD),"Global Get %q",k);
    end
    --TODO add the awaiters to localzone, have the on resource found for globals scan all threads for `thread.blocker_global_key == key_being_assigned` rather than the big global awaitlist.
    --TODO: add the awaiting system to localzone
    --NOTE: the task of resuming a blocked thread by writing to global or localzone are going to be slightly diffrent
    -- the correct table should receve the written value,
    -- reading from pure global should avoid including localzone
    -- writing to this should mainly block awaiting a localzone change but global assignment of the same key can wake it.
    --



    tryval = _G[k];
    if tryval ~= nil then return tryval end

    local lz = CURRENT_THREAD and CURRENT_THREAD.localzone;
    tryval = lz and lz[k];
    if tryval ~= nil then return tryval end

    local sz = CURRENT_THREAD and CURRENT_THREAD.specificzone;
    tryval = sz and sz[k];
    if tryval ~= nil then return tryval end



    if k == "tracing" then
        return DO_TRACE;
    end

    -- try to await our global to be written to

    CURRENT_THREAD.blocker = ("Global %q"):format(k);
    CURRENT_THREAD.blocker_global_key = k;
    ASSIGN_TO_AWAIT_LIST(GLOBAL_AWAITERS,CURRENT_THREAD,k);
    return coroutine.yield();
end

function env_mt:__newindex(k,v)
    local awaiters = GLOBAL_AWAITERS[k];

    if k == "tracing" then
        DO_TRACE = not not v;
        return true;
    end

    if DO_TRACE then
        log("trace",SYNTAX_THREAD(CURRENT_THREAD),"Global Set %s = %s",k,v);
    end

    local lz = CURRENT_THREAD and CURRENT_THREAD.localzone;
    lz = lz and lz[k];
    if lz ~= nil then
        CURRENT_THREAD.localzone[k] = v;
        return true;
    end

    if awaiters then
        for i,t in ipairs(awaiters) do
            t.resume_data = {v};
            ENQUEUE_THREAD(t);
        end
    end

    rawset(self,k,v);

    return true; --is this correct/needed?
end

setmetatable(ENV,env_mt);

function PRINT_TRACE()
    for t,v in pairs(ACTIVE_THREADS) do
        log("trace",SYNTAX_THREAD(t),("Evergreen: %s\tAwaiting: %s"):format(t.evergreen,t.blocker));
    end
end
rawset(ENV,"trace",PRINT_TRACE);

function ENQUEUE_THREAD(t)
    assert(t and t._type == "thread","ENQUEUE_THREAD: thats not a thread");
    LAST_THREAD.next = t;
    LAST_THREAD = t;
end

function NEW_THREAD(t)
    t = t or {};
    t._type = "thread"
    t.name = t.name or ("Thread "..tostring(t):sub(6));
    t.evergreen = false;
    ACTIVE_THREADS[t] = true;
    return t;
end

function NEW_PROMISE(t)
    t = t or {};
    t._type = "promise";
    t.name = t.name or ("Promise "..tostring(t):sub(6));;

    return t;
end

local simple_assigner_mt = {};

function NEW_SIMPLE_ASSIGNER(t)
    t = t or {};
    setmetatable(t,simple_assigner_mt);
end

function simple_assigner_mt:__index(k)
    if type(k) ~= "string" then return end;

    local v = self["get_"..k];
    if v then return v() end
end

function simple_assigner_mt:__index(k,nv)
    if type(k) ~= "string" then
        rawset(self,k,nv);
        return true;
    end;

    local v = self["set_"..k];
    if v then
        v(nv);
        return true;
    end

    rawset(self,k,nv);
end

-- these are just shims so they live here
rawset(ENV,"load",function(chunk, chunkname, mode, env)
    env = env or ENV;
    return load(chunk, chunkname, mode, env)
end)

rawset(ENV,"loadfile",function(filename, mode, env)
    env = env or ENV
    return loadfile(filename, mode, env)
end)

