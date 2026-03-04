
if kernal.FLAGS.trace then
    kernal.globals_logging(true);
end

if kernal.FLAGS["full-trace"] then
    kernal.globals_logging(true);
    kernal.verbose_thread_logging(true);
end

if #kernal.LOAD_APPLETS > 0 then
    for k,v in ipairs(kernal.LOAD_APPLETS) do
        import(v);
    end
else

    -- this is on because people will become 
    -- confused at the lack of feedback
    kernal.globals_logging(true);
    
    -- TODO run the REPL under a new group
    -- TODO handle thr error returns
    repl();
end