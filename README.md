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
this example works by waiting for the "hello" variable
document level variables are lower case and global variables begin with a capitol letter
```
--> print(hello("World"))
--> function hello(name) return "Hello, " .. name end
```
results in `Hello, World`
