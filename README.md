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

Ensure a dedicated directory for your custom Zsh functions exists. If not, create one using the following command:

```zsh
mkdir -p ~/.zsh_functions
```

2. **Add the `concat.zsh` File**

Move the `concat.zsh` file into the `~/.zsh_functions` directory:

```zsh
mv /path/to/concat.zsh ~/.zsh_functions/concat.zsh
```

3. **Configure Your Zsh Profile**

Open your `~/.zshrc` file in your preferred text editor:

```zsh
nano ~/.zshrc
```

Append the following script to source all `.zsh` files within the `~/.zsh_functions` directory:

```zsh
# Source all custom Zsh functions from ~/.zsh_functions
ZSH_FUNCTIONS_DIR="$HOME/.zsh_functions"
    if [ -d "$ZSH_FUNCTIONS_DIR" ]; then
        for funcPath in "$ZSH_FUNCTIONS_DIR"/*.zsh; do
            [ -f "$funcPath" ] || continue
            fileName="$(basename "$funcPath")"
            if ! . "$funcPath" 2>&1; then
                echo "Error: Failed to source \"$fileName\"" >&2
            fi
        done
    else
        echo "Error: \"$ZSH_FUNCTIONS_DIR\" not found or not a directory" >&2
    fi
    unset ZSH_FUNCTIONS_DIR
```

4. **Reload Your Zsh Configuration**

Apply the changes by sourcing your updated `~/.zshrc`:

```zsh
source ~/.zshrc
```

### Method 2: Direct Sourcing of the `concat` Function

**Recommended for users who prefer to source the `concat` function individually. Creating a directory for functions is optional but recommended for better organization.**

1. **Create a Directory for Custom Functions (Optional but Recommended)**

While optional, organizing your custom functions in a dedicated directory enhances maintainability. Create one if you haven't already:

```zsh
mkdir -p ~/.zsh_functions
```

2. **Add the `concat.zsh` File**

Move the `concat.zsh` file into the `~/.zsh_functions` directory:

```zsh
mv /path/to/concat.zsh ~/.zsh_functions/concat.zsh
```

3. **Configure Your Zsh Profile**

Open your `~/.zshrc` file in your preferred text editor:

```zsh
nano ~/.zshrc
```

Append the following script to source the `concat.zsh` function directly:

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

Apply the changes by sourcing your updated `~/.zshrc`:

```zsh
source ~/.zshrc
```

**Note:** Only error messages will appear if issues are encountered during sourcing.

## Quick Start

After installation, you can concatenate files by specifying input files/directories and desired options.

```zsh
# Concatenate all Python files in the current directory and subdirectories (default XML output)
concat -x py .

# Concatenate all files in 'src' directory, output as plain text
concat -t src/

# Concatenate specific files and files matching a pattern
concat main.py utils.py 'lib/**/*.js'

# Concatenate Python files, include hidden files, show directory tree
concat -x py -H -T .
```

## Usage

The `concat` function offers various options to customize how files are found and merged.

### Basic Syntax

```zsh
concat [OPTIONS] [FILE...]
```

### Positional Arguments

- `[FILE...]`: One or more files, directories, or glob patterns to process. If omitted, the current directory (`.`) is used.

### Options

| Option                 | Short | Description                                                                                                                                                           | Default                               |
| ---------------------- | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| `--output <file>`      | `-o`  | Output file name.                                                                                                                                                     | `_concat-output.xml` or `.txt`        |
| `--recursive`          | `-r`  | Search directories recursively.                                                                                                                                       | Enabled                               |
| `--no-recursive`       | `-n`  | Do not search directories recursively.                                                                                                                                | Disabled                              |
| `--text`               | `-t`  | Output in plain text format instead of XML.                                                                                                                           | XML format                            |
| `--ext <ext>`          | `-x`  | Only include files with this extension (e.g., `py`, `txt`). Can be specified multiple times. Case-insensitive. Excludes the dot.                                      | All extensions                        |
| `--include <glob>`     | `-I`  | Only include files whose full path matches this glob pattern. Can be specified multiple times. Applied after extension filtering.                                     | Include all (after extension filter)  |
| `--exclude <glob>`     | `-e`, `-E` | Exclude files matching the glob pattern. Can be specified multiple times. Applied last. Patterns match against the full path **or** the basename. Simple filenames (no `/` or wildcards) are treated as `**/filename`. | Exclude none                          |
| `--tree`               | `-T`  | Include a directory tree representation (of the current directory) in the output. Requires the `tree` command.                                                        | Disabled                              |
| `--hidden`             | `-H`  | Include hidden files and files in hidden directories (starting with `.`). By default, they are skipped unless explicitly listed or matched by an include glob.        | Disabled                              |
| `--no-purge-pycache`   | `-P`  | Do not delete `__pycache__` directories and `.pyc` files found within the current working directory.                                                                  | Purge enabled                         |
| `--verbose`            | `-v`  | Show detailed output, including matched and skipped files, configuration, etc.                                                                                        | Disabled                              |
| `--debug`              | `-d`  | Enable debug mode with Zsh execution tracing (`set -x`).                                                                                                              | Disabled                              |
| `--no-dir-list`       | `-l`  | Do not list input directories at the top of the output | Disabled |
| `--help`               | `-h`  | Show the help message and exit.                                                                                                                                       | N/A                                   |

### Examples

1. **Concatenate Python Files in Current Directory (XML Output)**

    ```zsh
    concat -x py .
    # Output: `<current-directory>-output.xml`
    # (e.g. if cwd is `flatten-zsh`, file is `flatten-zsh-output.xml`)
    ```

2. **Concatenate Python and JavaScript Files in `src`, Output as Plain Text**

    ```zsh
    concat -t -x py -x js src/
    # Output: `src-output.txt`
    ```

3. **Concatenate All Files in `project`, Exclude `*.log` and `build/` dir, Custom Output**

    ```zsh
    # Excludes *.log (basename match) and */build/* (full-path match)
    concat -o my_project.xml -E '*.log' -E '*/build/*' ~/project
    ```

4. **Exclude a Specific Filename Everywhere**

    ```zsh
    concat -E config.json .
    # Output: `<current-directory>-output.txt`
    # (e.g. `flatten-zsh-output.txt`)
    ```

5. **Concatenate Text Files, Include Hidden Files, Show Tree, Verbose Output**

    ```zsh
    concat -x txt -H -T -v .
    # Output: `<current-directory>-output.xml`
    # (includes tree, verbose messages printed)
    ```

6. **Concatenate Specific Files and Non-Recursive Search in a Directory**

    ```zsh
    concat -n config.yaml main.py data/
    # Concatenates config.yaml, main.py, and files directly inside data/
    # Output: `data-output.xml`
    ```

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

### Reporting Issues

If you encounter any issues or have feature requests, please open an issue in the repository's [Issues](https://github.com/kgruiz/concat-zsh/issues) section. Include detailed information, steps to reproduce, expected vs. actual behavior, and your environment details (OS, Zsh version) to help maintainers address the problem effectively.

## Support

For support, please open an issue in the [Issues](https://github.com/kgruiz/concat-zsh/issues) section of the repository.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE). You are free to use, modify, and distribute this software in accordance with the terms of the license.
