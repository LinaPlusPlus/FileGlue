# FileGlue
A small file preprocessor written in lua tha splits a file into headers and reconstructs it using lua code.
FileGlue statements are heavly asyncronus, you can easly define a variable within another statement across any file and it will wait 


# Usage
Warning, this project is in active development, the syntax may radically change at any time

## Example

examples/helloworld1.lua
```
-- !!FILEGLUE_STATEMENT_SYNTAX=-->
-- !!FILEGLUE_MULTILINE_SYNTAX=--+

--> print(hello("Wonderful"));

--> function hello(noun) return "Hello, "..(noun or "World") end

```

expected result
```
[PRINT ]  tests/helloworld1.lua:4  Hello, Wonderful
```

`FILEGLUE_STATEMENT_SYNTAX` tells the file processor that the statement syntax is `-->`

NOTE: the `section` syntax describing the file below will likely change
NOTE: the multi-line syntax is currently broken
NOTE: the whole file processor may change

### Failing Examples

```

# Building

to

# Validation

Because File Glue should be deturministic, validation is simple