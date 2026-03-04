


--> assert_eq "hello1" (await (write $Factory "hello1") ) 
--> assert_eq "hello2" (await (write $Factory "hello2") ) 


--> lua $body
Factory = {};
local meta = {};

function meta:__write(d)
    while true do
        if factory_ready then 
            factory_ready = false;
            info("inserted into factory")
            break
        end
    end

    -- the order matters
    factory_slot = d;
    factory_prom = promise();
    return factory_prom;
end

setmetatable(Factory,meta);

while Factory do
    factory_ready = true;

    local prom = factory_prom; -- can await
    local recev = factory_slot; -- the order matters
    factory_prom = nil; -- re-locks it


    info("got data:",recev);

    write(prom,recev); -- pass it back

end

--> lua $body
function assert_eq(a,b)
    if a == b then 
        info("OK,",a);
    else
        error(("mismatch! %s ~= %s"):format(a,b));
    end
end


--> assert_eq "hello3" (await (write $Factory "hello3") ) 
--> assert_eq "hello4" (await (write $Factory "hello4") ) 
