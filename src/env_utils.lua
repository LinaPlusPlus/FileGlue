

-- TODO no API to declare your thread evergreen
-- meaning infinite loops need to die (somehow, they're usually blocked and can't express agency) once all threads stop or it will be concidered a failure

rawset(ENV,"print",function(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    log("print", SYNTAX_THREAD(CURRENT_THREAD),"%s",table.concat(parts, "\t\t"));
end)

--TODO add object parsing
rawset(ENV,"dbg",function(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    log("trace", SYNTAX_THREAD(CURRENT_THREAD),"%s",table.concat(parts, "\t\t"));
end)

rawset(ENV,"thread",ENV_THREAD);
NEW_SIMPLE_ASSIGNER(ENV_THREAD);

function ENV_THREAD.get_list()
    --TODO
end

function ENV_THREAD.stop(...)
    CURRENT_THREAD.finished = "stopped"
    CURRENT_THREAD.result = {...};
end

function ENV_THREAD.onsettled()
    CURRENT_THREAD.blocker = "Other Threads settled/stalled";
    table.insert(STALLED_AWAITERS,CURRENT_THREAD);
    return coroutine.yield();
end

function ENV_THREAD.get_internal_structure()
    if not CURRENT_THREAD.allow_unsafe then
        error("this thread is not allowed to access unsafe apis");
    end
end

function ENV_THREAD.get_allow_unsafe()
    return CURRENT_THREAD.allow_unsafe;
end

function ENV_THREAD.get_name()
    return ENV_THREAD.name;
end

function ENV_THREAD.set_name(v)
    ENV_THREAD.name = tostring(v); --TODO enshure uniqueness and other important naming things
end

function ENV_THREAD.get_evergreen()
    return CURRENT_THREAD.evergreen or false;
end

function ENV_THREAD.set_evergreen(v)
    CURRENT_THREAD.evergreen = not not v;
end

