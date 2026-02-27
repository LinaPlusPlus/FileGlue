if #kernal.LOAD_APPLETS > 0 then
    for k,v in ipairs(kernal.LOAD_APPLETS) do
        import(v);
    end
else
    -- TODO run the REPL under a new group
    -- TODO handle thr error returns
    repl();
end