
CURRRENT_THREAD = nil
THREADS = { }
RESUMABLE_THREADS = { };
LATER_RESUME_THREADS = { };

SHARED_GLOBAL_WATCHER = { };
SHARED_GLOBAL = { };

EXIT_CODE = 0;
-- shim
function os.exit(code)
    EXIT_CODE = code;
    EXIT = true;
end

TAINT = nil;


local VERBOSE_THREAD_LOGGING = false;
function enable_verbose_thread_logging()
    VERBOSE_THREAD_LOGGING = true;
end

function watcher_resume(watcher,k)
    local l = watcher[k];
    watcher[k] = nil;
    if not l then return end
    for _,thread in pairs(l) do
        --log("warn",thread.label,"resume listed")
        table.insert(RESUMABLE_THREADS,thread);
    end
end

function watcher_yield(watcher,k,thread,yield_str)
    local l = watcher[k];
    if not l then
        l = {};
        watcher[k] = l;
    end

    table.insert(l,thread);
    thread.yield_to_str = (yield_str or "Awaiting global %q"):format(k);
end

function group_spawn(name)
    local group = {
        label = name,
        global = {},
        watcher = {},
    }
    return group;
end

function thread_spawn(name,group,no_start)
    local thread = {
        label = name,
        group = group,
        group_global = group.global,
        group_watcher = group.watcher,
        can_stall = false,
        alive = true,
        co = nil, -- will resume this coroutine
        call = nil, -- will call this function then return
        p_global = {}, -- read only includes in the global object
    };
    new_sandbox(thread);
    THREADS[thread] = true;
    if not no_start then table.insert(RESUMABLE_THREADS,thread); end
    return thread;
end

function main_loop()

    SYSTEM_GROUP = group_spawn("system")
    add_system_functions(SYSTEM_GROUP.global)
    
    
    SYSTEM_THREAD = thread_spawn("system",SYSTEM_GROUP);
    add_common_functions(SYSTEM_THREAD);

    SYSTEM_THREAD.co = coroutine.create(SYSTEM_THREAD.global.load(SYSTEM_APPLET));
    SYSTEM_APPLET = nil;

    while not EXIT do
        CURRENT_THREAD = table.remove(RESUMABLE_THREADS);
        
        -- try to wake a 'wake last' thread
        if not CURRENT_THREAD then 
            CURRENT_THREAD = table.remove(LATER_RESUME_THREADS);
        end
        
        -- if we still cant find anyone to resume
        if not CURRENT_THREAD then 
            --error("no more threads")  
            
            for thread,_ in pairs(THREADS) do
                if not thread.can_stall then
                    log("error",thread.label,"stalled: %s",thread.yield_to_str);
                    TAINT = true;
                end
            end
            break
        end

        -- found a thread
        CURRENT_THREAD.yield_to_str = nil;
        
        -- TODO add safety checks even tho it's kernal exclusive functionality
        local call = CURRENT_THREAD.call;
        if call then call(CURRENT_THREAD); end

        local corou = CURRENT_THREAD.co;
        if corou then 
        
            if true then 
                if VERBOSE_THREAD_LOGGING then
                    log("trace",CURRENT_THREAD.label,"thread resumed");
                end
                local ok,err = coroutine.resume(corou);
                if not ok then 
                    --TODO add error catching
                    log("error",CURRENT_THREAD.label,"uncaught: %s",err);
                    TAINT = true;  
                    THREADS[CURRENT_THREAD] = nil
                else
                    local status = coroutine.status(corou);
                    if status == "dead" then 
                        CURRENT_THREAD.state = "dead";
                        THREADS[CURRENT_THREAD] = nil;

                        if VERBOSE_THREAD_LOGGING then
                            log("trace",CURRENT_THREAD.label,"thread died");
                        end
                    end
                    if VERBOSE_THREAD_LOGGING then
                        log("trace",CURRENT_THREAD.label,"thread paused");
                    end
                end
            end
        end
    end

    if TAINT then EXIT_CODE = 1 end

end

