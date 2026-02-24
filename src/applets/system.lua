
--[=[
local cool = kernal.thread_spawn("system2",kernal.SYSTEM_GROUP);

cool.co = kernal.coroutine.create(cool.global.load([[
    k = 7
]]));

kernal.log("info","hello","%s",k);
]=]

if #kernal.LOAD_APPLETS > 0 then
    for k,v in pairs() do

    end
else
    -- TODO run the REPL under a new group
    -- TODO handle thr error returns
    repl();
end