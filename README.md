# concat-zsh

`concat` is a Zsh function designed to merge the contents of multiple files or files within specified directories into a single output file. It supports filtering by extension, include/exclude patterns, recursive search, and handling hidden files. Developed initially to aggregate files for use as context in Large Language Model (LLM) queries, `concat` is a versatile tool for developers and system administrators seeking to organize and consolidate project files efficiently.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
  - [Method 1: Automatic Sourcing of All Custom Functions](#method-1-automatic-sourcing-of-all-custom-functions)
  - [Method 2: Direct Sourcing of the `concat` Function](#method-2-direct-sourcing-of-the-concat-function)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Basic Syntax](#basic-syntax)
  - [Positional Arguments](#positional-arguments)
- [Options](#options)
- [Output Filename Logic](#output-filename-logic)
- [Examples](#examples)
- [Contributing](#contributing)
- [Reporting Issues](#reporting-issues)
- [Support](#support)
- [License](#license)

## Overview

`concat` facilitates the combination of file contents by providing flexible filtering and concatenation options. Whether preparing code snippets for LLMs, consolidating logs, or managing files within larger projects, this tool offers a straightforward and customizable approach.

## Features

- **Flexible Input**: Accepts multiple files, directories, or glob patterns as input.
- **Extension Filtering**: Select files by one or multiple extensions (e.g., `py`, `js`, `txt`).
- **Recursive Search**: Traverse directories recursively (default) or limit the search to the top level.
- **Include/Exclude Patterns**: Filter files based on full path glob patterns. Exclude patterns match against both full path and basename, and simple filenames are treated as `**/filename`.
- **Hidden Files Handling**: Option to include hidden files and directories.
  - **Automatic Text Detection**: Automatically skip binary or non-text files during concatenation.
- **Python Cache Cleanup**: Optionally remove `__pycache__` directories and `.pyc` files found in the current working directory.
- **Directory Tree Overview**: Optionally include a `tree` representation of the current directory in the output.
- **Output Formats**: Generate output in XML (default) or plain text format.
- **Verbose and Debug Modes**: Enable detailed logging and execution tracing for troubleshooting.
- **Customizable Output**: Specify output file names.

## Installation

Integrate the `concat` function into your Zsh environment by selecting one of the following methods based on your preference and setup requirements.

### Method 1: Automatic Sourcing of All Custom Functions

**Suitable for users managing multiple custom Zsh functions.**

1. **Create a Directory for Custom Functions**

   Ensure a dedicated directory for your custom Zsh functions exists. If not, create one:

   ```zsh
   mkdir -p ~/.zsh_functions
   ```

2. **Add the `concat.zsh` File**

   Move the `concat.zsh` file into your functions directory:

   ```zsh
   mv /path/to/concat.zsh ~/.zsh_functions/concat.zsh
   ```

3. **Configure Your Zsh Profile**

   Open `~/.zshrc` and add:

   ```zsh
   # Source all custom Zsh functions from ~/.zsh_functions
   ZSH_FUNCTIONS_DIR="$HOME/.zsh_functions"
   if [ -d "$ZSH_FUNCTIONS_DIR" ]; then
     for funcPath in "$ZSH_FUNCTIONS_DIR"/*.zsh; do
       [ -f "$funcPath" ] || continue
       if ! . "$funcPath" 2>&1; then
         echo "Error: Failed to source \"$(basename "$funcPath")\"" >&2
       fi
     done
   else
     echo "Error: \"$ZSH_FUNCTIONS_DIR\" not found or not a directory" >&2
   fi
   unset ZSH_FUNCTIONS_DIR
   ```

4. **Reload Your Zsh Configuration**

   ```zsh
   source ~/.zshrc
   ```

### Method 2: Direct Sourcing of the `concat` Function

**Recommended for users who prefer to source the `concat` function individually.**

1. **(Optional) Create a Functions Directory**

   ```zsh
   mkdir -p ~/.zsh_functions
   ```

2. **Add the `concat.zsh` File**

   ```zsh
   mv /path/to/concat.zsh ~/.zsh_functions/concat.zsh
   ```

3. **Configure Your Zsh Profile**

   Open `~/.zshrc` and add:

   ```zsh
   # Source the concat function
   CONCAT_FUNC_PATH="$HOME/.zsh_functions/concat.zsh"
   if [ -f "$CONCAT_FUNC_PATH" ]; then
     if ! . "$CONCAT_FUNC_PATH" 2>&1; then
       echo "Error: Failed to source \"$(basename "$CONCAT_FUNC_PATH")\"" >&2
     fi
   else
     echo "Error: \"$(basename "$CONCAT_FUNC_PATH")\" not found at:" >&2
     echo "  $CONCAT_FUNC_PATH" >&2
   fi
   unset CONCAT_FUNC_PATH
   ```

4. **Reload Your Zsh Configuration**

   ```zsh
   source ~/.zshrc
   ```

## Quick Start

1. **Merge Python files (XML)**

   ```zsh
   concat -x py .
   # -> _concat-py.xml
   ```

2. **Plain text for `src/` directory**

   ```zsh
   concat --text src/
   # -> _concat-src.txt
   ```

3. **Concatenate Markdown files (wildcard)**

   ```zsh
   concat -x md '*.md'
   # -> _concat-md.xml
   ```

4. **Wildcard logs to plain text**

   ```zsh
   concat -t '*.log'
   # -> _concat-log.txt
   ```

5. **Custom output filename**

   ```zsh
   concat -o summary.txt project/
   # -> summary.txt
   ```

6. **Remove old output files**

   ```zsh
   concat clean
   ```

## Usage

### Basic Syntax

```zsh
concat [OPTIONS] [FILE...]
```

Run `concat clean` to delete existing `_concat-*` files without performing a new concatenation.

### Positional Arguments

- `[FILE...]`: One or more files, directories, or glob patterns to process. If omitted, the current directory (`.`) is used.

## Options

| Option                   | Short     | Description                                                                 | Default                            |
|--------------------------|-----------|-----------------------------------------------------------------------------|------------------------------------|
| `--output <file>`        | `-o`      | Output file name.                                                           | `_concat-output.xml` or `.txt`     |
| `--recursive`            | `-r`      | Search directories recursively.                                              | Enabled                            |
| `--no-recursive`         | `-n`      | Do not search directories recursively.                                       | Disabled                           |
| `--text`                 | `-t`      | Output in plain text format instead of XML.                                  | XML                                |
| `--ext <ext>`            | `-x`      | Only include files with this extension (e.g., `py`, `txt`). Can be repeated. | All                                |
| `--include <glob>`       | `-I`      | Include files whose full path matches this glob pattern.                     | After extension filter             |
| `--exclude <glob>`       | `-e`, `-E`| Exclude files matching the glob pattern (full path or basename).              | None                               |
| `--tree`                 | `-T`      | Include a directory tree representation (requires the `tree` command).       | Disabled                           |
| `--hidden`               | `-H`      | Include hidden files and directories.                                        | Disabled                           |
| `--no-purge-pycache`     | `-P`      | Do not delete `__pycache__` directories and `.pyc` files.                    | Purge enabled                      |
| `--verbose`              | `-v`      | Show matched/skipped files and settings.                                     | Disabled                           |
| `--debug`                | `-d`      | Enable debug mode with Zsh execution tracing (`set -x`).                     | Disabled                           |
| `--no-dir-list`          | `-l`      | Do not list input directories at the top of the output.                      | Disabled                           |
| `--help`                 | `-h`      | Show the help message and exit.                                              | N/A                                |

## Output Filename Logic

| Input Scenario                              | Output Filename         | Format |
|---------------------------------------------|-------------------------|--------|
| `-o custom.xml`                             | `custom.xml`            | XML    |
| `-x md`, all files are `.md`                | `_concat-md.xml`        | XML    |
| `-x txt`, all files are `.txt`              | `_concat-txt.txt`       | Text   |
| `-x py -x js`, mixed extensions             | `_concat-output.xml`    | XML    |
| No `-x`, single dir (e.g. `src/`)           | `_concat-src.txt`       | Text   |
| No args, cwd = `myproject/`                 | `_concat-myproject.txt` | Text   |
| No args, unresolvable basename (e.g. `/`)   | `_concat-output.txt`    | Text   |

## Examples

1. **Custom output**

   ```zsh
   concat -o custom.xml file1.py file2.js
   # -> custom.xml
   ```

2. **Markdown to XML**

   ```zsh
   concat -x md docs/
   # -> _concat-md.xml
   ```

3. **Text to plain text**

   ```zsh
   concat -x txt notes/
   # -> _concat-txt.txt
   ```

4. **Mixed Python and JavaScript**

   ```zsh
   concat -x py -x js src/
   # -> _concat-output.xml
   ```

5. **Single dir default text**

   ```zsh
   concat src/
   # -> _concat-src.txt
   ```

6. **Default in project root**

   ```zsh
   concat
   # -> _concat-myproject.txt
   ```

7. **Fallback default**

   ```zsh
   concat /
   # -> _concat-output.txt
   ```

8. **Clean up old outputs**

   ```zsh
   concat clean
   ```


## Rust CLI
This repository also provides a Rust-based version in `concat-rs`. Build it:

```sh
cd concat-rs && cargo build --release
mv target/release/concat ~/bin/
```

After installing, call `concat` from Zsh like any command:

```zsh
concat -x rs src/
```

Run `concat --help` to see all options.

 
## Contributing

Contributions are welcome! Whether you're reporting a bug, suggesting a feature, or submitting a pull request, your input helps improve `concat`.

### How to Contribute

1. **Fork the Repository**

   Navigate to the repository page and click the "Fork" button to create your own copy.

2. **Clone Your Fork**

   ```zsh
   git clone https://github.com/kgruiz/concat-zsh.git
   cd concat-zsh
   ```

3. **Create a Feature Branch**

   ```zsh
   git checkout -b feature/YourFeatureName
   ```

4. **Make Your Changes**

   Ensure your code adheres to the project's coding standards and includes necessary documentation. Update the README if options or behavior change.

5. **Commit Your Changes**

   ```zsh
   git commit -m "Add feature: YourFeatureName"
   ```

6. **Push to Your Fork**

   ```zsh
   git push origin feature/YourFeatureName
   ```

7. **Open a Pull Request**

   Navigate to the original repository (`kgruiz/concat-zsh`) and click "New Pull Request." Provide a clear description of your changes and their purpose.

## Reporting Issues

If you encounter any issues or have feature requests, please open an issue in the repository's [Issues](https://github.com/kgruiz/concat-zsh/issues) section. Include detailed information, steps to reproduce, expected vs. actual behavior, and your environment details (OS, Zsh version) to help maintainers address the problem effectively.

## Support

For support, please open an issue in the [Issues](https://github.com/kgruiz/concat-zsh/issues) section of the repository.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE). You are free to use, modify, and distribute this software in accordance with the terms of the license.
