function read_arrow_file(file,cb)
    local pattern = "^%s*%-%->%s*(.+)$"
    local buildup = {};
    local heading = nil;
    local lineno = 0;
    local headline = 0;

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
end

function read_arrow_string(input, cb)
    local pattern = "^%s*%-%->%s*(.+)$"
    local buildup = {}
    local heading = nil
    local lineno = 0
    local headline = 0

    -- iterate over each line in the string
    for line in input:gmatch("([^\n]*)\n?") do
        lineno = lineno + 1
        local text = line:match(pattern)
        if text then
            local ok, err = cb(heading, buildup, headline)
            if ok == false then return ok, err end
            headline = lineno
            buildup = {}
            heading = text
        else
            table.insert(buildup, line)
        end
    end

    if heading then
        return cb(heading, buildup, headline)
    end

    return
end

