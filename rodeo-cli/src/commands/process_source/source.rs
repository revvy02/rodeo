/// If the script has no top-level return statement, append `\nreturn nil`
/// so Roblox's require() on the ModuleScript doesn't error.
pub fn ensure_return(source: &str) -> String {
    match full_moon::parse(source) {
        Ok(ast) => {
            if ast.nodes().last_stmt().is_some() {
                source.to_string()
            } else {
                format!("{source}\nreturn nil")
            }
        }
        Err(_) => {
            // Parse error — append anyway, Roblox will show the real error
            format!("{source}\nreturn nil")
        }
    }
}
