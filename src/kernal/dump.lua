
function dump(o, indent, visited, depth, maxDepth)
    indent = indent or ""
    visited = visited or {}
    depth = depth or 0
    maxDepth = maxDepth or 5

    local function colorize(val, valType)
        if valType == "string" then
            return ("\27[32m\"%s\"\27[0m"):format(val);
        elseif valType == "number" then
            return ("\27[35m%s\27[0m"):format(val)
        elseif valType == "boolean" then
            return ("\27[31m%s\27[0m"):format(tostring(val))
        elseif valType == "nil" then
            return "\27[90mnil\27[0m"
        else
            return tostring(val)
        end
    end

    local function formatKey(k)
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
            return ("\27[33m%s\27[0m"):format(k)
        else
            return ("\27[36m[%s\27[36m]\27[0m"):format(dump(k,nextIndent,visited, depth + 1))
        end
    end

    if type(o) == "table" then
        if visited[o] then
            return "\27[36m<recursion>\27[0m"
        end
        if depth >= maxDepth then
            return "\27[36m{...}\27[0m"
        end

        visited[o] = true

        local nextIndent = indent .. "  "
        local s = "\27[36m{\27[0m\n"
        for k, v in pairs(o) do
            local keyStr = formatKey(k)
            local sep = keyStr:match("^%[%") and " = " or " = ";
            local valueStr = dump(v, nextIndent, visited, depth + 1, maxDepth);
            s = s .. ("%s%s%s%s,\n"):format(nextIndent, keyStr, sep, valueStr);
        end
        s = s .. indent .. "\27[36m}\27[0m"
        return s
    else
        return colorize(o, type(o))
    end
end