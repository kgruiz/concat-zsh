use std::env;
use std::fs::{self, File};
use std::io::{self, Write, BufWriter};
use std::path::{Path, PathBuf};

#[derive(Default)]
struct Options {
    exts: Vec<String>,
    includes: Vec<String>,
    excludes: Vec<String>,
    hidden: bool,
    tree: bool,
    text: bool,
    output: Option<String>,
    inputs: Vec<String>,
}

fn print_help() {
    println!("concat - merge file contents\n");
    println!("Usage: concat [options] [files or directories]\n");
    println!("Options:");
    println!("  -x, --ext EXT          Filter by extension (may repeat)");
    println!("  -i, --include PATTERN  Include glob pattern (may repeat)");
    println!("  -e, --exclude PATTERN  Exclude glob pattern (may repeat)");
    println!("      --hidden           Include hidden files");
    println!("  -t, --tree             Include directory tree in output");
    println!("      --text             Output plain text (default XML)");
    println!("  -o, --output FILE      Output filename");
    println!("  -h, --help             Show this help");
}

fn matches_pattern(pattern: &str, text: &str) -> bool {
    if pattern == "*" {
        return true;
    }
    let mut rest = text;
    let mut first = true;
    for part in pattern.split('*') {
        if part.is_empty() {
            continue;
        }
        if let Some(idx) = rest.find(part) {
            if first && !pattern.starts_with('*') && idx != 0 {
                return false;
            }
            rest = &rest[idx + part.len()..];
        } else {
            return false;
        }
        first = false;
    }
    if !pattern.ends_with('*') && !rest.is_empty() {
        return false;
    }
    true
}

fn should_include(path: &Path, opts: &Options) -> bool {
    if !opts.hidden {
        if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
            if name.starts_with('.') {
                return false;
            }
        }
    }
    if !opts.exts.is_empty() {
        if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
            if !opts.exts.iter().any(|x| x == ext) {
                return false;
            }
        } else {
            return false;
        }
    }
    let path_str = path.to_string_lossy();
    if !opts.includes.is_empty()
        && !opts
            .includes
            .iter()
            .any(|p| matches_pattern(p, &path_str))
    {
        return false;
    }
    if opts
        .excludes
        .iter()
        .any(|p| matches_pattern(p, &path_str))
    {
        return false;
    }
    true
}

fn gather_files(path: &Path, files: &mut Vec<PathBuf>, opts: &Options) -> io::Result<()> {
    if path.is_file() {
        if should_include(path, opts) {
            files.push(path.to_path_buf());
        }
        return Ok(());
    }
    if path.is_dir() {
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            let p = entry.path();
            if p.is_dir() {
                gather_files(&p, files, opts)?;
            } else if p.is_file() {
                if should_include(&p, opts) {
                    files.push(p);
                }
            }
        }
    }
    Ok(())
}

fn write_tree(root: &Path, writer: &mut dyn Write) -> io::Result<()> {
    fn walk(dir: &Path, prefix: String, writer: &mut dyn Write) -> io::Result<()> {
        let mut entries: Vec<_> = fs::read_dir(dir)?.collect();
        entries.sort_by_key(|e| e.as_ref().unwrap().path());
        for entry in entries {
            let entry = entry?;
            let path = entry.path();
            let name = path.file_name().unwrap().to_string_lossy();
            writeln!(writer, "{}{}", prefix, name)?;
            if path.is_dir() {
                walk(&path, format!("{}  ", prefix), writer)?;
            }
        }
        Ok(())
    }
    writeln!(writer, "Directory tree:")?;
    walk(root, String::new(), writer)
}

fn escape_xml(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

fn main() -> io::Result<()> {
    let mut opts = Options::default();
    let mut args = env::args().skip(1).peekable();
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "-x" | "--ext" => {
                if let Some(val) = args.next() {
                    opts.exts.push(val);
                }
            }
            "-i" | "--include" => {
                if let Some(val) = args.next() {
                    opts.includes.push(val);
                }
            }
            "-e" | "--exclude" => {
                if let Some(val) = args.next() {
                    opts.excludes.push(val);
                }
            }
            "--hidden" => opts.hidden = true,
            "-t" | "--tree" => opts.tree = true,
            "--text" => opts.text = true,
            "--xml" => opts.text = false,
            "-o" | "--output" => {
                if let Some(val) = args.next() {
                    opts.output = Some(val);
                }
            }
            "-h" | "--help" => {
                print_help();
                return Ok(());
            }
            _ => opts.inputs.push(arg),
        }
    }
    if opts.inputs.is_empty() {
        opts.inputs.push(".".to_string());
    }
    let mut files = Vec::new();
    for inp in &opts.inputs {
        let p = Path::new(inp);
        gather_files(p, &mut files, &opts)?;
    }
    let out_name = opts.output.unwrap_or_else(|| {
        if opts.text {
            "_concat-output.txt".to_string()
        } else {
            "_concat-output.xml".to_string()
        }
    });
    let file = File::create(&out_name)?;
    let mut writer = BufWriter::new(file);
    if !opts.text {
        writeln!(writer, "<files>")?;
    }
    for f in &files {
        let content = fs::read_to_string(f)?;
        if opts.text {
            writeln!(writer, "{}", content)?;
        } else {
            writeln!(
                writer,
                "<file path=\"{}\"><![CDATA[{}]]></file>",
                f.display(),
                escape_xml(&content)
            )?;
        }
    }
    if opts.tree {
        if !opts.text {
            writeln!(writer, "<tree>")?;
            let mut buf = Vec::new();
            write_tree(Path::new(&opts.inputs[0]), &mut buf)?;
            writeln!(writer, "{}", escape_xml(&String::from_utf8_lossy(&buf)))?;
            writeln!(writer, "</tree>")?;
        } else {
            write_tree(Path::new(&opts.inputs[0]), &mut writer)?;
        }
    }
    if !opts.text {
        writeln!(writer, "</files>")?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_matches_pattern() {
        assert!(matches_pattern("*.rs", "src/main.rs"));
        assert!(matches_pattern("src/*", "src/main.rs"));
        assert!(!matches_pattern("src/*.rs", "tests/main.rs"));
    }
}
