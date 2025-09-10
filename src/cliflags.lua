
-- arg_parser.lua
function ENV.parse_cli_args(args)
  local kv = {}
  local positional = {}

  for _, arg in ipairs(args) do
    if arg:sub(1, 2) == "--" then
      local key, val = arg:match("^%-%-([^=]+)=(.*)$")
      if key then
        kv[key] = val
      else
        -- Handle flags without =value as boolean true
        key = arg:sub(3)
        kv[key] = true
      end
    else
      positional[#positional + 1] = arg
    end
  end

  return kv, positional
end

local ENV_FLAG = {};
local ENV_FLAG_MT = {};

function ENV_FLAG_MT:__index(k)
    USED_FLAGS[k] = true;

    local got =  FLAGS[k]
    if got == nil then
        log("warn",SYNTAX_THREAD(CURRENT_THREAD),"flag %q is unset",k);
    end
    return got;
end

function ENV_FLAG_MT:__newindex(k,v)
    FLAGS[k] = v;
    if USED_FLAGS[k] then
      log("error",SYNTAX_THREAD(CURRENT_THREAD),"flag %q was changed after it was already used somwhere else",k);
      error("unsafe flag reassignment");
    end
end

local function anti_unused_flags()
    for k,v in pairs(FLAGS) do
      if not USED_FLAGS[k] then
        log("warn","unused_flags","flag %q was set but never used",k);
      end
    end
end

local ENV_FLAGON = {};
local ENV_FLAGON_MT = {};

function ENV_FLAGON_MT:__index(k)
    USED_FLAGS[k] = true; --TODO: should flagon be able to lock
    return FLAGS[k] or false;
end

-- just a shim but forced value into a boolean
function ENV_FLAGON_MT:__newindex(k,v)
    ENV_FLAG[k] = not not v;
    return true;
end

setmetatable(ENV_FLAG,ENV_FLAG_MT);
setmetatable(ENV_FLAGON,ENV_FLAGON_MT);

--TODO make a system where the flag data cannot be written to
rawset(ENV,"flag",ENV_FLAG);
rawset(ENV,"flagon",ENV_FLAGON);
