use std::{collections::HashMap, rc::Rc, sync::Mutex};

use mlua::Lua;
use rustyline::{DefaultEditor, Editor, history::FileHistory};
mod flags;


fn main() {
    let mut lua = Lua::new();

    let flags: flags::Flags = flags::parse_flags();

    
    load_gluecore(&mut lua);
    load_reader(&mut lua);

    //lua.create_string(include_str!("applets/repl.lua"));
    let mut load_applets: Vec<String> = vec![];
    for unit in flags.units {
        load_applets.push(unit);
    }

    let mut name_flags: HashMap<String,String> = HashMap::new();
    for (k,v) in flags.flags {
        name_flags.insert(k, v);
    }

    lua.globals().set("FLAGS", name_flags).unwrap();
    
    lua.globals().set("LOAD_APPLETS",load_applets).unwrap();

    lua.globals().set("SYSTEM_APPLET", include_str!("applets/system.lua")).unwrap();

    // TODO error handling
    lua.load("
        local ok,err = pcall(main_loop); 
        if ok then
            --
        else
            log(\"error\",\"panic\",\"%s\",err);
        end
    ").exec().unwrap();

    let exit_code: i32 = lua.globals().get("EXIT_CODE").unwrap();
    std::process::exit(exit_code);
}

fn load_gluecore(lua: &mut Lua) {


    let includes = vec![
        ("dump.lua",include_str!("kernal/dump.lua")),
        ("main.lua",include_str!("kernal/main.lua")),
        ("sandboxing.lua",include_str!("kernal/sandboxing.lua")),
        ("logging.lua",include_str!("kernal/logging.lua")),
        ("file_reader.lua",include_str!("kernal/file_reader.lua")),
        ("luishe.lua",include_str!("kernal/luishe.lua")),
    ];

    for k in includes {
        let chk: mlua::Chunk<'_> = lua.load(k.1).set_name(k.0);
        if let Err(err) = chk.exec() { //mlua::Result<()>
            panic!("Internal Lua Errored: {}",err);
        }
    };
}


fn load_reader(lua: &mut Lua) {
    let reader: Rc<Mutex<Option<Editor<(),FileHistory>>>> = Rc::new(Mutex::new(None));

    // Create a Rust function callable from Lua
    let hello = lua.create_function(move |_lua, prompt: String| 
        -> Result<(Option<String>,Option<String>),mlua::Error> {
        let mut edit = reader.lock().unwrap();

        if let None = *edit {
            *edit = Some(DefaultEditor::new().unwrap())
        };

        if let Some(edit) = edit.as_mut() {
            let res = edit.readline(&prompt);
            match res {
                Ok(k) => {
                    edit.add_history_entry(k.as_str()).unwrap();
                    return Ok((Some(k),None));
                },
                Err(err) => {
                    let a = match err {
                        rustyline::error::ReadlineError::Io(error) => format!("IO error {}",error),
                        rustyline::error::ReadlineError::Eof => format!("eof"),
                        rustyline::error::ReadlineError::Interrupted => format!("interrupted"),
                        rustyline::error::ReadlineError::Errno(errno) => format!("errno {}",errno),
                        rustyline::error::ReadlineError::Signal(signal) => format!("signal {:?}",signal),
                        _ => format!("unknown line reader error"),
                    };
                    return Ok((None,Some(a)));
                }
            };
        }

        unreachable!();
    }).unwrap();

    // Register it in Lua globals
    lua.globals().set("repl_prompt", hello).unwrap();

}