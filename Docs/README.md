# concat-zsh

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Stars](https://img.shields.io/github/stars/yourusername/concat.zsh.svg)
![Forks](https://img.shields.io/github/forks/yourusername/concat.zsh.svg)

## Short Description

A robust Zsh function to efficiently combine file contents based on specified extensions and filtering criteria.

## Table of Contents

- [Title](#title)
- [Banner](#banner)
- [Badges](#badges)
- [Short Description](#short-description)
- [Long Description](#long-description)
- [Install](#install)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

## Long Description

`concat.zsh` is a powerful Zsh function designed to simplify the process of merging file contents within your projects. Whether you're a developer managing multiple scripts or a system administrator handling configuration files, `concat.zsh` provides a streamlined solution to aggregate files based on various criteria. Key features include:

- **Extension Filtering**: Select files by single or multiple extensions.
- **Recursive Search**: Traverse directories recursively or limit to top-level.
- **Exclusion Patterns**: Exclude specific files or directories using patterns or wildcards.
- **Hidden Files Handling**: Include or exclude hidden files and directories.
- **Python Cache Cleanup**: Automatically remove `__pycache__` directories and `.pyc` files.
- **Directory Tree Overview**: Generate a comprehensive tree structure of the target directory in the output.
- **Verbose and Debug Modes**: Enable detailed logging and execution tracing for better insight and troubleshooting.
- **Customizable Output**: Specify output file names and directories to suit your workflow.

This function enhances productivity by automating repetitive tasks, ensuring consistency, and providing customizable options to fit diverse project requirements.

## Install

Integrate the `concat.zsh` function into your Zsh environment by following one of the two methods below: sourcing all custom functions from a directory or sourcing the `concat.zsh` file directly.

### Method 1: Source All Custom Functions Automatically

This method is ideal if you plan to manage multiple custom functions.

1. **Create a Directory for Custom Functions**

   ```zsh
   mkdir -p ~/.zsh_functions
   ```

2. **Add the `concat.zsh` File**

   Place the `concat.zsh` file into the `~/.zsh_functions` directory.

   ```zsh
   mv path_to_concat.zsh ~/.zsh_functions/concat.zsh
   ```

3. **Configure Your Zsh Profile**

   Open your `~/.zshrc` file in your preferred text editor:

   ```zsh
   nano ~/.zshrc
   ```

   Add the following lines to source all `.zsh` files in the `~/.zsh_functions` directory:

   ```zsh
   # Source all custom Zsh functions from ~/.zsh_functions
   if [[ -d "$HOME/.zsh_functions" ]]; then
     for func_file in "$HOME/.zsh_functions"/*.zsh; do
       if [[ -f "$func_file" ]]; then
         source "$func_file"
       fi
     done
   fi
   ```

4. **Reload Your Zsh Configuration**

   Apply the changes by sourcing your `~/.zshrc`:

   ```zsh
   source ~/.zshrc
   ```

### Method 2: Source the `concat.zsh` Function Directly

Use this method if you prefer to source the `concat.zsh` function individually.

1. **Create a Directory for Custom Functions**

   ```zsh
   mkdir -p ~/.zsh_functions
   ```

2. **Add the `concat.zsh` File**

   Place the `concat.zsh` file into the `~/.zsh_functions` directory.

   ```zsh
   mv path_to_concat.zsh ~/.zsh_functions/concat.zsh
   ```

3. **Configure Your Zsh Profile**

   Open your `~/.zshrc` file in your preferred text editor:

   ```zsh
   nano ~/.zshrc
   ```

   Add the following line to source the `concat.zsh` function directly:

   ```zsh
   # Source the concat function
   source "$HOME/.zsh_functions/concat.zsh"
   ```

4. **Reload Your Zsh Configuration**

   Apply the changes by sourcing your `~/.zshrc`:

   ```zsh
   source ~/.zshrc
   ```

## Usage

The `concat` function is designed to be flexible and customizable. Below are detailed instructions on how to use it effectively.

### Basic Syntax

```zsh
concat [extensions] [OPTIONS]
```

**Arguments:**

- `[extensions]`: Specify a single extension (e.g., `.py`) or a comma-separated list of extensions (e.g., `.py,.js` or `txt,md`). If omitted, all file extensions are included.

### Options

- `--output-file, -f <file>`: Name/path of the output file. Defaults to `concatOutput.txt`.
- `--output-dir, -d <dir>`: Directory where the output file is placed. Defaults to the current directory.
- `--input-dir, -i <dir>`: Directory to search for matching files. Defaults to the current directory.
- `--exclude, -e <patterns>`: Comma-separated list of paths or patterns to exclude (supports wildcards).
- `--exclude-extensions, -X <exts>`: Comma-separated list of file extensions to exclude (e.g., `txt,log`). Extensions can be prefixed with `.` or provided as plain text.
- `--recursive, -r`: Recursively search subdirectories. Default is true.
- `--no-recursive`: Disable recursive search.
- `--title, -t`: Include a title at the start of the output file. Default is true.
- `--no-title`: Exclude the title from the output file.
- `--verbose, -v`: Show verbose output, including debug-like logs of matched files.
- `--case-sensitive-extensions, -c`: Match extensions in a case-sensitive manner. Default is false.
- `--case-sensitive-excludes, -s`: Match exclude patterns in a case-sensitive manner. Default is false.
- `--case-sensitive-all, -a`: Case-sensitive matching for both extensions and excludes (overrides the above two).
- `--tree, -T`: Include a tree representation of the directory. Default is true.
- `--no-tree`: Disable the tree representation in the output file, overriding `--tree`.
- `--include-hidden, -H`: Include hidden files and directories in the search. Default is false.
- `--no-include-hidden`: Exclude hidden files and directories from the search.
- `--delPyCache, -p`: Delete `__pycache__` directories and `.pyc` files automatically. Default is true.
- `--no-delPyCache`: Disable the deletion of `__pycache__` and `.pyc` files.
- `--debug, -x`: Enable debug mode (with trace output).
- `--help, -h`: Display the help message and exit.

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

## Contributing

Contributions are welcome! If you have suggestions for improvements, bug fixes, or new features, please follow these guidelines:

1. **Fork the Repository**

   Click the "Fork" button at the top right of the repository page to create your own copy.

2. **Create a Branch**

   ```zsh
   git checkout -b feature/YourFeatureName
   ```

3. **Commit Your Changes**

   Ensure your code follows the project's coding standards and includes necessary documentation.

   ```zsh
   git commit -m "Add feature: YourFeatureName"
   ```

4. **Push to Your Fork**

   ```zsh
   git push origin feature/YourFeatureName
   ```

5. **Open a Pull Request**

   Navigate to the original repository and click "New Pull Request." Provide a clear description of your changes and their purpose.

### Reporting Issues

If you encounter any issues or have feature requests, please open an issue in the repository's [Issues](https://github.com/yourusername/concat.zsh/issues) section.

### Code of Conduct

Please adhere to the [Code of Conduct](https://github.com/yourusername/concat.zsh/blob/main/CODE_OF_CONDUCT.md) when contributing to this project.

## License

The GNU General Public License version 3 (GPLv3). Please see [License File](LICENSE) for more information.