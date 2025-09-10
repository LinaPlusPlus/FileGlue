
rawset(ENV,"extract_arrow_text",function(filename,cb)
    local pattern = "^%s*%-%->%s*(.+)$"
    local buildup = {};
    local heading = nil;
    local lineno = 0;
    local headline = 0;

    local file = io.open(filename, "r")
    if not file then
        error("Failed to open file: " .. filename) --HACK builtin failure
    end

    for line in file:lines() do
        lineno = lineno +1;
        local text = line:match(pattern)
        if text then
            local ok,err = cb(heading,buildup,headline);
            if ok == false then return ok,err end;
            headline = lineno;
            buildup = {}
            heading = text
        else
            table.insert(buildup,line);
        end
    end

    if heading then
       return cb(heading,buildup,headline);
    end

    file:close()
    return;
end)


rawset(ENV,"use",function(filename)
    local localzone = {
        filename=filename,

    };
    localzone._LZ = localzone;

    return ENV.extract_arrow_text(filename,function(header,body,lineno)
        if header then

            local thread = NEW_THREAD({
                name = ("%s:%s"):format(filename,lineno),
                localzone = localzone,
                specificzone = {
                    -- a context even more specific than localzone
                    --TODO implement into __index
                    section = {
                        -- HACK: this is a shim until actual file slice object type can be written
                        __string=body,
                        tostring = function(self) return table.concat(self.__string,"\n") end,
                    },
                }
            });

            local unit,err = ENV.load(header);
            if not unit then
                log("error",SYNTAX_THREAD(thread),"Parse error: %s",err);
                thread.finished = true;
                ACTIVE_THREADS[thread] = nil;
                return unit,err;
            end

            thread.coro = coroutine.create(unit);
            ENQUEUE_THREAD(thread);

        end
    end)
end)