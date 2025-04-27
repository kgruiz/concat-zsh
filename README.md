# concat-zsh

`concat` is a Zsh function designed to merge the contents of multiple files based on specified extensions and filtering criteria. Developed to aggregate files for use as context in Large Language Model (LLM) queries, `concat` is a useful tool for developers and system administrators seeking to organize and consolidate project files efficiently.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
  - [Method 1: Automatic Sourcing of All Custom Functions](#method-1-automatic-sourcing-of-all-custom-functions)
  - [Method 2: Direct Sourcing of the `concat` Function](#method-2-direct-sourcing-of-the-concat-function)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Basic Syntax](#basic-syntax)
  - [Options](#options)
  - [Examples](#examples)
- [Contributing](#contributing)
  - [How to Contribute](#how-to-contribute)
  - [Reporting Issues](#reporting-issues)
- [Support](#support)
- [License](#license)

## Overview

`concat` facilitates the combination of file contents by providing filtering and concatenation options. Whether preparing code snippets for LLMs, consolidating logs, or managing files within larger projects, this tool offers a straightforward and customizable approach.

## Features

- **Extension Filtering**: Select files by one or multiple extensions (e.g., `.py`, `.js`, `.txt`).
- **Recursive Search**: Traverse directories recursively or limit the search to the top level.
- **Exclusion Patterns**: Exclude specific files or directories using patterns or wildcards.
- **Hidden Files Handling**: Option to include or exclude hidden files and directories.
- **Python Cache Cleanup**: Automatically remove `__pycache__` directories and `.pyc` files.
- **Directory Tree Overview**: Generate a tree structure of the target directory in the output.
- **Verbose and Debug Modes**: Enable logging and execution tracing for troubleshooting.
- **Binary File Exclusion**: Automatically skip unreadable or binary files if desired.
- **Customizable Output**: Specify output file names and directories.
- **LLM-Friendly Concatenation**: Organize file aggregation for compatibility with Large Language Models.

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

   *Replace `/path/to/concat.zsh` with the actual path to your `concat.zsh` file.*

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

   *Replace `/path/to/concat.zsh` with the actual path to your `concat.zsh` file.*

3. **Configure Your Zsh Profile**

   Open your `~/.zshrc` file in your preferred text editor:

   ```zsh
   nano ~/.zshrc
   ```

   Append the following script to source the `concat.zsh` function directly:

   ```zsh
   # Source the concat function
   CONCAT_FUNC_PATH="$HOME/.zsh_functions/concat.zsh"

   if [[ -f "$CONCAT_FUNC_PATH" ]]; then
       if ! source "$CONCAT_FUNC_PATH" 2>/dev/null; then
           echo "Error: Failed to source 'concat.zsh'. Please verify the file's path and integrity." >&2
       fi
   else
       echo "Error: 'concat.zsh' not found in '$HOME/.zsh_functions/'. Please ensure the file exists." >&2
   fi
   ```

4. **Reload Your Zsh Configuration**

   Apply the changes by sourcing your updated `~/.zshrc`:

   ```zsh
   source ~/.zshrc
   ```

   **Note:** Only error messages will appear if issues are encountered during sourcing.

## Quick Start

After installation, you can concatenate files by specifying the desired extensions. For example, to concatenate all Python files in the current directory:

```zsh
concat .py
```

## Usage

The `concat` function offers various options to customize how files are merged. Below are detailed instructions on its usage.

### Basic Syntax

```zsh
concat [extensions] [OPTIONS]
```

**Arguments:**

- `[extensions]`: Specify a single extension (e.g., `.py`) or a comma-separated list of extensions (e.g., `.py,.js` or `txt,md`). If omitted, all file extensions are included.

### Options

| Option                        | Short | Description                                                                                                                                          |
|-------------------------------|-------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| `--output-file <file>`        | `-f`  | Name or path for the concatenated output file. Defaults to `concatOutput.txt`.                                                                       |
| `--output-dir <dir>`          | `-d`  | Directory where the output file will be saved. Defaults to the current directory.                                                                    |
| `--input-dir <dir>`           | `-i`  | Directory to search for files. Can be relative or absolute. Defaults to the current directory.                                                        |
| `--exclude <patterns>`        | `-e`  | Comma-separated list of file or directory paths/patterns to exclude. Supports wildcards.                                                             |
| `--exclude-extensions <exts>` | `-X`  | Comma-separated list of file extensions to exclude (e.g., `txt,log`). Extensions can be prefixed with `.` or provided as plain text.                 |
| `--recursive`                 | `-r`  | Recursively search subdirectories. Default is `true`.                                                                                                |
| `--no-recursive`              |       | Disable recursive search.                                                                                                                            |
| `--title`                     | `-t`  | Include a title line at the start of the output file. Default is `true`.                                                                             |
| `--no-title`                  |       | Exclude the title line from the output file.                                                                                                         |
| `--verbose`                   | `-v`  | Enable verbose output, showing matched files and other details.                                                                                      |
| `--case-sensitive-extensions` | `-c`  | Match file extensions case-sensitively. Default is `false`.                                                                                          |
| `--case-sensitive-excludes`   | `-s`  | Match exclude patterns case-sensitively. Default is `false`.                                                                                         |
| `--case-sensitive-all`        | `-a`  | Enable case-sensitive matching for both extensions and exclude patterns, overriding the two options above. Default is `false`.                        |
| `--tree`                      | `-T`  | Include a tree representation of directories in the output. Default is `true`.                                                                        |
| `--no-tree`                   |       | Disable the tree representation in the output (overrides `--tree`).                                                                                   |
| `--include-hidden`            | `-H`  | Include hidden files and directories in the search. Default is `false`.                                                                               |
| `--no-include-hidden`         |       | Exclude hidden files and directories from the search.                                                                                                |
| `--delPyCache`                | `-p`  | Automatically delete `__pycache__` folders and `.pyc` files. Default is `true`.                                                                       |
| `--no-delPyCache`             |       | Disable automatic deletion of `__pycache__` and `.pyc` files.                                                                                        |
| `--exclude-binary`            | `-B`  | Automatically exclude unreadable or binary files from concatenation. Default is `true`.                                                              |
| `--no-exclude-binary`         |       | Do not exclude unreadable or binary files (overrides `--exclude-binary`).                                                                             |
| `--debug`                     | `-x`  | Enable debug mode with verbose execution tracing.                                                                                                     |
| `--help`                      | `-h`  | Display the help message and exit.                                                                                                                    |

### Examples

1. **Concatenate Python Files, Exclude `__init__.py`, and Specify Output File**

    ```zsh
    concat .py --output-file allPython.txt --exclude __init__.py
    ```

2. **Concatenate Python and JavaScript Files Recursively with Verbose Output**

    ```zsh
    concat py,js -r -v
    ```

3. **Concatenate Files Without Adding a Title, Specify Input and Output Directories**

    ```zsh
    concat --no-title --input-dir ~/project --output-dir ~/Desktop
    ```

4. **Exclude Specific Extensions and Include Hidden Files**

    ```zsh
    concat txt,md -X log,tmp -H
    ```

5. **Enable Debug Mode for Troubleshooting**

    ```zsh
    concat .sh --debug
    ```

6. **Disable Automatic Exclusion of Binary Files**

    ```zsh
    concat .sh --no-exclude-binary
    ```

## Contributing

Contributions are welcome! Whether you're reporting a bug, suggesting a feature, or submitting a pull request, your input helps improve `concat`.

### How to Contribute

1. **Fork the Repository**

    Navigate to the repository page and click the "Fork" button to create your own copy.

2. **Clone Your Fork**

    ```zsh
    git clone https://github.com/your-username/concat-zsh.git
    cd concat-zsh
    ```

3. **Create a Feature Branch**

    ```zsh
    git checkout -b feature/YourFeatureName
    ```

4. **Make Your Changes**

    Ensure your code adheres to the project's coding standards and includes necessary documentation.

5. **Commit Your Changes**

    ```zsh
    git commit -m "Add feature: YourFeatureName"
    ```

6. **Push to Your Fork**

    ```zsh
    git push origin feature/YourFeatureName
    ```

7. **Open a Pull Request**

    Navigate to the original repository and click "New Pull Request." Provide a clear description of your changes and their purpose.

### Reporting Issues

If you encounter any issues or have feature requests, please open an issue in the repository's [Issues](https://github.com/your-username/concat-zsh/issues) section. Include detailed information to help maintainers address the problem effectively.

## Support

For support, please open an issue in the [Issues](https://github.com/your-username/concat-zsh/issues) section of the repository.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE). You are free to use, modify, and distribute this software in accordance with the terms of the license.
