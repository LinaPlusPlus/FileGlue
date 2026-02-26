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
```
--> say_hello "World"
--> set say_hello @place{ "Hello ($place)" }
```
results in `Hello, World`

same thing but written in lua
```
--> lua "say_hello('world')"
--> lua $body
function say_hello(place)
  print("Hello, "..place)
end
```
results in `Hello, World`


# Luishe

Luishe is a custom bash-like/lisp-like language that compiles to and integrates with lua, Both Luishe and now Lua has a custom way of managing variables, both document-level (lowercase) and global (Uppercase) variables will block until they are defined by another thread.




