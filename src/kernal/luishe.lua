local Lib = {};
Luishe = Lib;

function Lib.parse(codestr)
    local h,i = 1,1;
    local err = nil;

    local tree,tree_string,tree_arguments;
    function tree(depth,ender)
        ender = ender or ")";
        local unit = { type = "call" };
        local unit_argument = nil;
        local multi_unit = {};
        local scope = {};
        local var_mode = false;
        multi_unit.type = "multi_call"

        local function reset()
            local statement = codestr:sub(h,i-1);
            if var_mode then 
                var_mode = false;
                if h < i then table.insert(unit,{type="var",statement}); end
            else
                local asnum = tonumber(statement);
                if h < i then table.insert(unit,asnum or statement); end
            end
        end

        while true do
            local char = codestr:sub(i,i);
            --print("cb",h,i,char)
            if true then
                if char == "@" then
                    reset();
                    i = i + 1; h = i;
                    local arguments = tree_arguments(depth+1);
                    table.insert(unit,arguments);

                elseif char == "$" then
                    reset();
                    h = i + 1;
                    var_mode = true;

                elseif char == " " then
                    reset()
                    h = i + 1;
                elseif char == "(" then
                    reset()
                    i = i + 1; h = i;
                    table.insert(unit,tree(depth+1));
                elseif char == "\"" then
                    reset()
                    i = i + 1; h = i;
                    table.insert(unit,tree_string(depth+1));
                elseif char == ender or char == "" then
                    if depth == 1 and char ~= "" then
                        err = ("unexpected ')'\n\n`%s`\n%s^"):format(codestr,string.rep("-",i));
                    end
                    reset()
                    h = i + 1;
                    table.insert(multi_unit,unit);
                    return multi_unit;
                elseif char == ";" then
                    reset()
                    h = i + 1;
                    table.insert(multi_unit,unit);
                    unit = { type = "call" };
                end
            end
            if err then return false end
            i=i+1;
        end
        
    end

    function tree_arguments(depth) 

        local unit = { type = "function" };

        local function reset()
            local statement = codestr:sub(h,i-1);
            local asnum = tonumber(statement);
            if h < i then table.insert(unit,asnum or statement); end
        end

        while true do
            local char = codestr:sub(i,i);

            if char == " " then
                reset();
                h = i + 1;
            elseif char == "{" then
                reset()
                h = i + 1;
                local res = tree(depth + 1,"}");
                unit.body = res;
                return unit;
            elseif char == "" then
                reset();
                h = i + 1;
                return unit;
            end

            if err then return false end
            i=i+1;
        end
    end

    function tree_string(depth,closer)
        local unit = {};
        unit.type = "string"
        while true do
            local char = codestr:sub(i,i);
            --print("str",h,i,char)
            if char == "(" then
                table.insert(unit,codestr:sub(h,i-1));
                i = i + 1; h = i;
                table.insert(unit,tree(depth+1));
            elseif char == "" then
                err = ("unclosed string\n\n`%s`\n%s^"):format(codestr,string.rep("-",i));
            elseif char == "\"" then
                table.insert(unit,codestr:sub(h,i-1));
                h = i + 1;
                return unit;
            end
            if err then return false end
            i=i+1;
        end
    end

    local base = tree(1);
    if err then return false,err end;
    return base;
end

Lib.varlookup = {
    table=table,
    string=string,
    _G=_G,
}

function Lib.toLua(ast,varlookup)
    varlookup = varlookup or Lib.varlookup;
    local lines = {};
    local next_var = 0;
    local stack = {};
    local uvars = {};
    local next_uvar = 0;

    local function varword(a)

        local try;
        try = uvars[a];
        if try then return "u"..tostring(try); end

        for i = #stack, 1, -1 do
            try = stack[i][a];
            if try then return "u"..tostring(try); end
        end

        for k,v in pairs(varlookup) do
            if v[a] ~= nil then 
                return ("%s[%q]"):format(k,a);
            end
        end
        return ("_G[%q]"):format(a);
    end
    local function word(a)
        return ("%q"):format(a);
    end
    local function tree(ast)
        if type(ast) == "string" then
            return ("%q"):format(ast);
        elseif ast.type == "function" then
            next_var = next_var +1;
            local ret_var = next_var;

            table.insert(stack,uvars);
            uvars = {};
            for i,v in ipairs(ast) do
                next_uvar = next_uvar +1;
                uvars[v] = next_uvar;
            end

            table.insert(lines,("local v%s = function("):format(ret_var));
            local struts = {};
            for i,v in ipairs(ast) do
                table.insert(struts,"u"..tostring(uvars[v]));
            end
            table.insert(lines,table.concat(struts,","));
            table.insert(lines,") ");

            local ret = "nil";
            if ast.body then
                ret = tree(ast.body);
            end
            table.insert(lines,("return %s; end"):format(ret));

            return "v"..tostring(ret_var);

        elseif ast.type == "multi_call" then
            local a = 'nil';
            for k,v in ipairs(ast) do
                a = tree(v);
            end
            return a;
        elseif ast.type == "call" then
            local args = {};
            local call;

            if ast[1] == "let" then
                --TODO
            end

            if ast[1] == "if" then
                if ast[4] then -- if-else case
                    next_var = next_var +1;
                    local ret_var = next_var;

                    local predicate = tree(ast[2]);

                    local ret = ("local v%s; if %s then "):format(ret_var,predicate);
                    table.insert(lines,ret);

                    local p_then = tree(ast[3]);
                    ret = ("v%s = %s; else"):format(ret_var,p_then);
                    table.insert(lines,ret);
                    

                    local p_else = tree(ast[4]);
                    ret = ("v%s = %s; end"):format(ret_var,p_else);
                    table.insert(lines,ret);
                    
                    return "v"..tostring(ret_var);

                elseif ast[3] then
                    next_var = next_var +1;
                    local ret_var = next_var;

                    local predicate = tree(ast[2]);

                    local ret = ("local v%s; if %s then "):format(ret_var,predicate);
                    table.insert(lines,ret);

                    local a = tree(ast[3]);

                    ret = ("v%s = %s; end"):format(ret_var,a);
                    table.insert(lines,ret);


                    return "v"..tostring(ret_var);
                    
                elseif ast[2] then -- empty body
                    return tree(ast[2]);
                else -- empty predicate
                    return "nil"
                end
            end

            for i,v in ipairs(ast) do
                if i == 1 then 
                    if type(v) ~= "table" then
                        call = varword(v)
                    elseif #ast == 1 then
                        call = tree(v);
                        return ("(%s)"):format(call);
                    else
                        call = tree(v)
                    end
                elseif type(v) ~= "table" then
                    args[i-1] = word(v);
                else
                    args[i-1] = tree(v);
                end
            end
            if call == nil then 
                return nil
            end

            next_var = next_var +1;
            local ret = ("local v%s = %s(%s)"):format(next_var,call,table.concat(args,","))
            table.insert(lines,ret);
            return "v"..next_var;
        elseif ast.type == "string" then
            local args = {};
            local stubs = {};
            for i,v in ipairs(ast) do
                if type(v) ~= "table" then
                    table.insert(stubs,v);
                else
                    table.insert(stubs,"%s");
                    table.insert(args,tree(v) or "\"nil\"")
                end
            end
            local fmtstr = table.concat(stubs,"");
            local args_str = table.concat(args,",")
            
            next_var = next_var +1;
            local ret = ("local v%s = (%q):format(%s)"):format(next_var,fmtstr,args_str);
            table.insert(lines,ret);
            return "v"..next_var;
        elseif ast.type == "var" then
            return varword(ast[1]);
        else 
            error("unknown AST statement");
        end
    end
    local ret = tree(ast);
    table.insert(lines,"return "..(ret or "nil"));
    return table.concat(lines,"\n")
end

