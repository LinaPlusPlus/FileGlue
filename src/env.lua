-- unlike the kernal project, this is not about supervised code's ~~safety~~ or efficency
-- it's now about safety too!

REMOTE_META = {};

function REMOTE_META:__index(k)
    --
end

function REMOTE_META:__newindex(k,v)
    --
end

function REMOTE_META:__newindex(k,v)

COMMON_G = {};

SYMBOL_UNITS = {}; -- a map of remote objects
SYMBOL_SOURCE = {}; -- the underlying lua value
SYMBOL_KEY = {}; -- key of
SYMBOL_BLOCKING_THREADS = {};
SYMBOL_NAME = {};

function NEW_REMOTE(t)
    setmetatable(REMOTE_META,t);
    return t;
end

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

