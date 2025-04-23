--BUG file commands must have a command or they are inserted into the document

--! stage {name="glue.declare",inside={"header"},write=block}
--BEGIN the global object
local glue = {
    commandGlob="(.*)%-%-!(.+)%s-",
    commandExtendedGlob="(.*)%-%-%+(.+)%s-",
    changeGlobGlob="(.*)FILEGLUE_COMMAND_GLOB%=(.*)%s-",
    fileLocals = {},
    masterFile = nil, -- file for setup reasons
    target = nil, -- sets the target, `if enabled ~= a boolean then enabled = (enabledString or name) == target end`
    verbose = true,
    docs = {},
    stages = {},
    bounds = {},
};

glue.cantWrite = glue.cantWrite or "cant write to file during declaration,\ntry adding this:\n\tawait(stage{ name = 'yourstage', inside={'body'} })"

for k,v in pairs(_G) do
    glue[k] = v;
end
--END


--! stage {name="declarations",inside={"header"},write=block}
local args = {...}

local anon_stage_name = 0;
local anon_bound_name = 0;

local attaches = {}; --files to be consumed
local resolveds = {}; --resolved files

local did_work = false;

local FILEGLUE_NO_OS_EXIT = _G.FILEGLUE_NO_OS_EXIT --apptly for external programs for some reason


--! stage {name="return", inside={"last"}}
glue.outputFile():close();

if glue.returnMessage == "error" then
    print("Output FAILED.")
elseif glue.returnMessage == "warn" then
    print("Compilation Generated Warnings.")
elseif glue.returnMessage then
    print(glue.returnMessage);
else
    print("All OK.")
end

return glue.returnCode or 0;

