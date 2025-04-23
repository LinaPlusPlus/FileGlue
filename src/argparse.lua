
--! stage {name="argparse", after = {"declarations"}}

local outputPath
local function argparse(args,glue)
    local locked = false;
    local kmode = false;
    for i,k in pairs(args) do
        if locked then
            if not outputPath then
                outputPath = k
            else
                glue.include(k);
            end
        elseif k == "--" then
            locked = true
        elseif kmode then

            glue[kmode] = v;
            kmode = false;
        else
            local a = k:match("%-%-(.+)");
            local k,v;
            if a then
                k,v = a:match("(.-)=(.+)");
            end
            if a then
                if k then
                    v = tonumber(v) or v;
                    if v == "true" then v = true end
                    if v == "false" then v = false end
                    if v == "nil" then v = nil end
                    if glue["verbose-params"] then
                        print(("param: --%s is %s: %q"):format(kmode,type(v),v));
                    end
                    glue[k] = v;
                else
                    glue[a] = true
                end
            else
                locked = true;
                outputPath = a;
            end
        end
    end


    if not outputPath then
        print "usage: lua fileglue.lua [options...] <output> <files...>"
        return
    end

end
