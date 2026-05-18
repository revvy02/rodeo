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

    // clap-markdown emits a stock preamble + a "Command Overview" anchor list
    // that duplicates Starlight's right-rail TOC. Skip everything until the
    // first H2 (the root command's own section).
    let md = clap_markdown::help_markdown::<Cli>();
    let cleaned = md
        .lines()
        .skip_while(|line| !line.starts_with("## "))
        .collect::<Vec<_>>()
        .join("\n");
    print!("{}", cleaned);
}
