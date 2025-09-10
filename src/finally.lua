MAIN_THREAD = NEW_THREAD({
    name = "Main",
});

--HACK, technically, no non coroutine code should call (or even read/write)
-- anything inside ENV as it is *designed* to cause side-effects on calling code!
-- however, nothing is loaded yet so no untrusted code. I can hand verify this is safe to call.
MAIN_THREAD.coro = coroutine.create(ENV.load([[
    -- a flag for disabling the standard Main thread
    -- just leaving the threading engine itself,
    -- why is this a useful feature? I dont know!

    if CLI_ARGS[1] == "--nostd" then
        table.remove(CLI_ARGS,1)
        local loadpath = table.remove(CLI_ARGS,1);
        assert(load(loadpath))();
        return
    end

    local kv,infiles = parse_cli_args(CLI_ARGS);

    -- TODO make an "annoying warnings" flag to enable "annoying" (extremely helpful but verbose) warnings
    -- cheating here to avoid locking the tracing variable
    tracing = kv.trace;

    for k,v in pairs(kv) do
        flag[k] = v;
    end

    for i,k in pairs(infiles) do
        use(k);
    end

    -- I will likely make a name based ordering structure that threads can use to wait
    -- there will be a default one that everyone is expected to use probably just called "stage";
    -- NOTE the stage object should be assigned created as late as possable and stage:fire() should be delayed until all others settle

    thread.onsettled();

]]));


CURRENT_THREAD = MAIN_THREAD;
LAST_THREAD = MAIN_THREAD;

-- a lot of logic from the main loop,
-- exported here to handle the variadic `coroutine.resume` function and
-- skip throwaway table creation
local function coro_next(ok,err,...)
    if not ok then
        if CURRENT_THREAD.manager then
            --TODO add manager code here
        else
            log("fail",SYNTAX_THREAD(CURRENT_THREAD),"Runtime error: %s",err);
        end
    end

    if coroutine.status(CURRENT_THREAD.coro) == "dead" then
        ACTIVE_THREADS[CURRENT_THREAD] = nil;
        CURRENT_THREAD.finished = "returned";
        CURRENT_THREAD.result = {ok,err,...};
        if DO_TRACE then
            log("trace",SYNTAX_THREAD(CURRENT_THREAD),"Finished")
        end
    end

    local next_thread = CURRENT_THREAD.next; --TODO when `next == current` will there be problems?
    CURRENT_THREAD.next = nil;
    CURRENT_THREAD = next_thread;

    if not CURRENT_THREAD then

        -- I made this a `pop()` instead,
        -- making it first come last served
        -- that way older callers will get priority,
        -- meaning `Main` will always be able to get the last execution if it wants to.

        CURRENT_THREAD = table.remove(STALLED_AWAITERS);
        if DO_TRACE and CURRENT_THREAD then
            log("trace",SYNTAX_THREAD(CURRENT_THREAD),"Awoke from settle")
        end
    end
end

-- main thread loop;
while CURRENT_THREAD do
    if DO_TRACE then -- TODO make this behind a more extreme trace setting
        log("trace",SYNTAX_THREAD(CURRENT_THREAD),"Execution Turn")
    end

    coro_next(coroutine.resume(CURRENT_THREAD.coro,unpack(CURRENT_THREAD.resume_data or {})));
end

-- code that runs after main loop
local function anti_stall()
    local test_failed = false;
    for k,v in pairs(ACTIVE_THREADS) do
        if not k.evergreen then
            test_failed = true;
        end
    end

    if test_failed then
        log("fail","program_stall","complation target did not finish all non evergreen threads");
    end

    PRINT_TRACE();
end

anti_stall();
anti_unused_flags();