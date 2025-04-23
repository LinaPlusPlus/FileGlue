--! stage {name="glue.defaults", after = {"glue.methods"}, write=block}
glue.bound{
    name="body",
    before={"footer"},
    after={"header"},
    wants={"header","footer"},
}

glue.bound{
    name="header",
    before={"footer","header"},
    after={"first"},
    wants={"header","footer"},
}

glue.bound{
    name="footer",
    after={"header","footer"},
    before={"last"},
    wants={"header","footer"},
}

glue.stage{
    disabled=true,
    name="first",
    before={"header"},
    wants={"header","footer"},
}

glue.stage{
    disabled=true,
    name="last",
    after={"footer"},
    wants={"header","footer"},
}

glue.bound{
    name="last",
    after={"last"},
    before={"teardown"},
    wants={"last","header","footer"},
}

glue.bound{
    name="first",
    before={"first"},
    after={"setup"},
    wants={"last","header","footer"},
}


glue.bound{
    name="document",
    after={"setup"},
    before={"teardown"},
    enables={"setup","teardown"},
}

glue.bound{
    name = "noCode",
    enabled_by = {"noCode"},
}

glue.stage{
    name = "noCode",
    enabled_without = {"header","footer"},
    enabled = false,
    call = function() print("WARN: no code was generated") end,
    inside = {},
}


glue.stage{
    name = "setup",
    before = {"header"},
    call = function() glue.cantWrite = nil end,
    inside = {},
}

glue.stage{
    name = "header",
    enabled = false,
}

glue.stage{
    name = "footer",
    after = {"header"},
    before = {"teardown"},
    enabled = false,
}

glue.stage{
    name = "teardown",
    after = {"footer"},
    inside = {},
    call = function() glue.cantWrite = "cant write during teardown" end
}
