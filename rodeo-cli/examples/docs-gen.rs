//! Generate the CLI reference markdown page for the docs site.
//!
//! Run with:
//!   cargo run --example docs-gen > docs/src/content/docs/cli.md

use rodeo::cli::Cli;

fn main() {
    println!("---");
    println!("title: CLI reference");
    println!("description: Every rodeo subcommand and flag (auto-generated).");
    println!("---");
    println!();
    println!("> _This page is auto-generated from clap definitions. Edits will be overwritten — change the `#[arg(...)]` attributes in `rodeo-cli/src/cli.rs` instead._");
    println!();
    print!("{}", clap_markdown::help_markdown::<Cli>());
}
