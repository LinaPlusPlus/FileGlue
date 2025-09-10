local FLAGS = {};
local USED_FLAGS = {}; -- flags used by the program
local ENV = {
    coroutine=false,
    unsafe_coroutine=coroutine,
    CLI_ARGS={...},
};
ENV._G = _G;
local THREADS = {};
local CO_CURRENT = nil;
local NEW_THREAD,NEW_PROMISE,NEW_FILE_PART,NEW_SIMPLE_ASSIGNER;
local ACTIVE_THREADS = {};
local MAIN_THREAD,CURRENT_THREAD,LAST_THREAD;
local ENQUEUE_THREAD;
local GLOBAL_AWAITERS = {};
local PRINT_TRACE;
local DO_TRACE = false;
local STALLED_AWAITERS = {};
local ENV_THREAD = {};

local function SYNTAX_THREAD(thread)
    return (thread and thread.name) or ("Invalid Thread: "..tostring(thread));
end

local unpack = _G.unpack or table.unpack;

local function ASSIGN_TO_AWAIT_LIST(list,blocker,k)
    assert(list);
    assert(blocker);
    local v = list[k];
    if not v then v = {}; list[k] = v; end
    table.insert(v,blocker);
end
local colors = {
    reset   = "\27[0m",
    bold    = "\27[1m",

    TRACE   = "\27[90m",
    ETRACE  = "\27[35m",
    WTRACE  = "\27[33m",
    WARN    = "\27[1;33m",
    ERROR   = "\27[1;31m",
    INFO    = "\27[1;34m",
    FAIL    = "\27[1;97;41m",
    PRINT = "\27[1;36m",
}

local function pad(str, len)
    return str .. string.rep(" ", math.max(0, len - #str))
end

function log(mode, src, fmt, ...)
    local lvl = mode:upper()
    local color = colors[lvl] or ""
    local reset = colors.reset
    local bold = colors.bold

    local level_str = pad(lvl, 6)          -- e.g., "INFO  "
    local source_str = pad(src, 15)        -- e.g., "main.lua      "
    local message = fmt:format(...)

    print(("%s[%s]%s  %s%s%s  %s"):format(
        color, level_str, reset,
        bold, source_str, reset,
        message
    ))
end