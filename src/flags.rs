use std::env;

#[derive(Debug)] 
pub struct Flags {
    pub flags: Vec<(String,String)>,
    pub units: Vec<String>,
}

pub fn parse_flags() -> Flags{
    let mut flags: Vec<(String,String)> = Vec::new();
    let mut units: Vec<String> = Vec::new();
    let mut flag_key: Option<String> = None;
    let mut locked = false;


    for mut arg in env::args().skip(1) {

        if locked {
            units.push(arg.clone());
            continue;
        }
        
        if arg == "--" {
            if let Some(ref f) = flag_key.take() {
                flags.push((f.clone(),String::from("true")));
            }

            locked = true;
            continue;
        }

        if arg.starts_with('-') {
            if let Some(f) = flag_key {
                flags.push((f,String::from("true")));
            }
            let argk = arg.split_off(1);
            flag_key = Some(argk);
            continue;
        }

        if let Some(ref f) = flag_key {
            flags.push((f.clone(),arg.clone()));
            flag_key = None;
        } else {
            units.push(arg);
        }
    }

    if let Some(f) = flag_key {
        flags.push((f,String::from("true")));
    };

    return Flags { flags, units };

}