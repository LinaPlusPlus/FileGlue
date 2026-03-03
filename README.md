# File Glue
A small file preprocessor written in lua tha splits a file into headers and reconstructs it using lua code.
FileGlue statements are heavly asyncronus, you can easly define a global within a statement while it's accessors wait

Warning, this project is in active development, the syntax may radically change at any time.

# Current state of the project
Currently, only the REPL works correctly, file parsing is currently broken

# the REPL 
if you dont specify a file, it wil enter the REPL, each line is it's own thread.

# Usage

here is an exaple:
this example works by waiting for the "say_hello" variable
```lua
--> say_hello "World"
--> set say_hello @place{ "Hello ($place)" }
```
results in `Hello, World`

same thing but written in lua
```lua
--> lua "say_hello('world')"
--> lua $body
function say_hello(place)
  print("Hello, "..place)
end
```
results in `Hello, World`


# Luishe

Luishe is a custom bash-like/lisp-like language that compiles to and integrates with lua, Both Luishe and now Lua have a custom way of managing variables:
- local variables (same as lua)
- thread variables (special lua global)
- document variables (lowercase lua global)
- global variables (Uppercase lua globals)

document and global variables will block until they are defined by another thread, if by the end of the program a thread is still blocked, it will throw an error.

## Commands

Luishe searches for commands in this order:
- _G.commands
- _G.table
- _G.string
- _G.math
- thread variables
- document and global variables

### builtin commands (thread variables)
```

--> repl
-- launches the REPL

--> defer
-- await all other threads to finish or become blocked

--> await <thing>
-- await a promise or buffer

--> warn <template> ...
--> info <template> ...


```
