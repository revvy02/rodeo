/// Initialize color detection for stderr (used by console crate in other modules).
pub fn init() {
    console::set_colors_enabled(console::colors_enabled_stderr());
}
