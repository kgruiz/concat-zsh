# concat.zsh

# -----------------------------------------------------------------------------
# concat
# -----------------------------------------------------------------------------
#
# Description:
#   Combines the contents of files that match a set of optional file extensions
#   into a single output file. Also supports various filtering and formatting
#   options, including excluding certain paths, deleting Python cache directories,
#   generating a directory tree overview, and optionally excluding binary or
#   unreadable files.
#
# Usage:
#   concat [extensions] [OPTIONS]
#
#   - If [extensions] are provided, only files with those extensions will be considered.
#   - You can specify multiple extensions in a comma-separated list, like ".py,.js"
#     or "txt,md".
#
# Options:
#   --output-file, -f <file>          Name/path of the output file. Defaults to "concatOutput.txt".
#   --output-dir, -d <dir>           Directory where the output file is placed. Defaults to the current directory.
#   --input-dir, -i <dir>            Directory to search for matching files. Defaults to the current directory.
#   --exclude, -e <patterns>         Comma-separated list of paths or patterns to exclude (supports wildcards).
#   --exclude-extensions, -X <exts>  Comma-separated list of file extensions to exclude (e.g., "txt,log").
#                                    Extensions can be prefixed with '.' or given as plain text.
#   --recursive, -r                  Recursively search subdirectories. Default is true.
#   --no-recursive                   Disable recursive search.
#   --title, -t                      Include a title at the start of the output file. Default is true.
#   --no-title                       Exclude the title from the output file.
#   --verbose, -v                    Show verbose output, including debug-like logs of matched files.
#   --case-sensitive-extensions, -c  Match extensions in a case-sensitive manner. Default is false.
#   --case-sensitive-excludes, -s    Match exclude patterns in a case-sensitive manner. Default is false.
#   --case-sensitive-all, -a         Case-sensitive matching for both extensions and excludes (overrides the above two).
#   --tree, -T                       Include a tree representation of the directory. Default is true.
#   --no-tree                        Disable the tree representation in the output file, overriding --tree.
#   --include-hidden, -H             Include hidden files and directories in the search. Default is false.
#   --no-include-hidden              Exclude hidden files and directories.
#   --delPyCache, -p                 Delete __pycache__ directories and .pyc files automatically. Default is true.
#   --no-delPyCache                  Disable the deletion of __pycache__ and .pyc files.
#   --exclude-binary, -B             Automatically exclude unreadable or binary files. Default is true.
#   --no-exclude-binary              Do not exclude unreadable or binary files (overrides --exclude-binary).
#   --debug, -x                      Enable debug mode (with trace output).
#   --help, -h                       Display this help message and exit.
#
# Examples:
#   concat .py --output-file allPython.txt --exclude __init__.py
#   concat py,js -r -v
#   concat --no-title --input-dir ~/project --output-dir ~/Desktop

concat() {
    # Don't modify the core logic; simply display usage if -h or --help is called.

    for arg in "$@"; do

      if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        cat <<EOF
Usage: concat [extensions] [OPTIONS]

Combines the contents of files that match a set of optional file extensions
into a single output file. Also supports excluding paths, deleting
Python cache directories, generating a tree view, and more. Now also supports
excluding binary or unreadable files if desired.

Arguments:
  [extensions]
      Either a single extension (e.g., "txt" or ".txt") or a comma-separated list
      (e.g., "txt,md" or ".py,.js"). If not specified, all file extensions are included.

Options:
  --output-file, -f <file>
      Name or path for the concatenated output file. Defaults to "concatOutput.txt".

  --output-dir, -d <dir>
      Directory where the output file will be saved. Defaults to current directory.

  --input-dir, -i <dir>
      Directory to search for files. Can be relative or absolute. Defaults to current directory.

  --exclude, -e <patterns>
      Comma-separated list of file or directory paths/patterns to exclude. Wildcards supported.

  --exclude-extensions, -X <exts>
      Comma-separated list of file extensions to exclude (e.g., "txt,log").
      Extensions can be prefixed with '.' or given as plain text.

  --recursive, -r
      Recursively search subdirectories. Default is true.

  --no-recursive
      Disable recursive search.

  --title, -t
      Include a title line at the start of the output file. Default is true.

  --no-title
      Exclude the title line from the output file.

  --verbose, -v
      Enable verbose output, showing matched files and other details.

  --case-sensitive-extensions, -c
      Match file extensions case-sensitively. Default is false.

  --case-sensitive-excludes, -s
      Match exclude patterns case-sensitively. Default is false.

  --case-sensitive-all, -a
      Enables case-sensitive matching for both extensions and exclude patterns,
      overriding the two options above. Default is false.

  --tree, -T
      Include a tree representation of directories in the output. Default is true.

  --no-tree
      Disable the tree representation in the output (overrides --tree).

  --include-hidden, -H
      Include hidden files/directories in the search. Default is false.

  --no-include-hidden
      Exclude hidden files/directories.

  --delPyCache, -p
      Automatically delete '__pycache__' folders and '.pyc' files. Default is true.

  --no-delPyCache
      Disable automatic deletion of '__pycache__' and '.pyc' files.

  --exclude-binary, -B
      Automatically exclude unreadable or binary files from concatenation. Default is true.

  --no-exclude-binary
      Include all files (overrides --exclude-binary).

  --debug, -x
      Enable debug mode with verbose execution tracing.

  --help, -h
      Show this help message and exit.

Examples:
  concat .py --output-file allPython.txt --exclude __init__.py
  concat py,js -r -v
  concat --no-title --input-dir ~/project --output-dir ~/Desktop
EOF
        return 0
      fi

    done

    # ------------------------------
    # Default Configuration
    # ------------------------------

    outputFile="concatOutput.txt"
    outputDir="."
    inputDir="."
    excludePatterns=()
    excludeExtensionsArray=()
    recursive=true
    addTitle=true
    verbose=false
    caseSensitiveExtensions=false
    caseSensitiveExcludes=false
    caseSensitiveAll=false
    tree=true
    extensions=""
    includeHidden=false
    delPyCache=true
    debug=false
    excludeBinary=true

    # ------------------------------
    # Parse Command-Line Options
    # ------------------------------

    while (( $# )); do

        case "$1" in

            --debug|-x)

                debug=true

                set -x

                shift
            ;;
            --output-file|-f)

                if [[ -n "$2" && "$2" != --* ]]; then

                    outputFile="$2"

                    shift 2

                else

                    echo "Error: --output-file requires a filename argument."

                    return 1

                fi
            ;;
            --output-dir|-d)

                if [[ -n "$2" && "$2" != --* ]]; then

                    outputDir="$2"

                    shift 2

                else

                    echo "Error: --output-dir requires a directory argument."

                    return 1

                fi
            ;;
            --input-dir|-i)

                if [[ -n "$2" && "$2" != --* ]]; then

                    inputDir="$2"

                    shift 2

                else

                    echo "Error: --input-dir requires a directory argument."

                    return 1

                fi
            ;;
            --exclude|-e)

                if [[ -n "$2" && "$2" != --* ]]; then

                    IFS=',' read -A tempExcludes <<< "$2"

                    for pattern in "${tempExcludes[@]}"; do

                        pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                        excludePatterns+=("$pattern")

                    done

                    shift 2

                else

                    echo "Error: --exclude requires a patterns argument."

                    return 1
                fi
            ;;
            --exclude-extensions|-X)

                if [[ -n "$2" && "$2" != --* ]]; then

                    IFS=',' read -A rawExcludeExtensions <<< "$2"

                    for ext in "${rawExcludeExtensions[@]}"; do

                        ext=$(echo "$ext" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                        [[ "$ext" != .* ]] && ext=".$ext"

                        excludeExtensionsArray+=("$ext")

                    done

                    shift 2

                else

                    echo "Error: --exclude-extensions requires an extension argument."

                    return 1
                fi
            ;;
            --recursive|-r)
                recursive=true
                shift
            ;;
            --no-recursive)
                recursive=false
                shift
            ;;
            --title|-t)
                addTitle=true
                shift
            ;;
            --no-title)
                addTitle=false
                shift
            ;;
            --verbose|-v)
                verbose=true
                shift
            ;;
            --case-sensitive-extensions|-c)
                caseSensitiveExtensions=true
                shift
            ;;
            --case-sensitive-excludes|-s)
                caseSensitiveExcludes=true
                shift
            ;;
            --case-sensitive-all|-a)
                caseSensitiveAll=true
                shift
            ;;
            --tree|-T)
                tree=true
                shift
            ;;
            --no-tree)
                tree=false
                shift
            ;;
            --include-hidden|-H)
                includeHidden=true
                shift
            ;;
            --no-include-hidden)
                includeHidden=false
                shift
            ;;
            --delPyCache|-p)
                delPyCache=true
                shift
            ;;
            --no-delPyCache)
                delPyCache=false
                shift
            ;;
            --exclude-binary|-B)
                excludeBinary=true
                shift
            ;;
            --no-exclude-binary)
                excludeBinary=false
                shift
            ;;
            --*)
                echo "Unknown option: $1"
                return 1
            ;;
            *)

                if [[ -z "$extensions" ]]; then

                    extensions="$1"

                else

                    echo "Unknown argument: $1"

                    return 1

                fi

                shift
            ;;
        esac
    done

    inputDirName="$(basename "$(realpath "$inputDir")")"

    # ------------------------------
    # Process Extensions
    # ------------------------------

    if [[ -n "$extensions" ]]; then

        IFS=',' read -A rawExtensions <<< "$extensions"

        extensionsArray=()

        for ext in "${rawExtensions[@]}"; do

            ext=$(echo "$ext" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            [[ "$ext" != .* ]] && ext=".$ext"

            extensionsArray+=("$ext")

        done

    else

        extensionsArray=()

    fi

    # ------------------------------
    # Determine Case Sensitivity
    # ------------------------------

    if [[ "$caseSensitiveAll" == true ]]; then

        caseSensitiveExtensions=true
        caseSensitiveExcludes=true

    fi

    # ------------------------------
    # Verbose Output of Configuration
    # ------------------------------

    if [[ "$verbose" == true ]]; then

        echo "----------------------------------------"

        echo "Configuration:"
        echo "Input Directory: $inputDir"
        echo "Output Directory: $outputDir"
        echo "Output File: $outputFile"

        if [[ ${#extensionsArray[@]} -gt 0 ]]; then

            echo "Extensions: ${extensionsArray[@]}"

        else

            echo "Extensions: All"

        fi

        echo "Exclude Patterns: ${excludePatterns[@]}"
        echo "Exclude Extensions: ${excludeExtensionsArray[@]}"
        echo "Recursive: $recursive"
        echo "Add Title: $addTitle"
        echo "Case Sensitive Extensions: $caseSensitiveExtensions"
        echo "Case Sensitive Excludes: $caseSensitiveExcludes"
        echo "Case Sensitive All: $caseSensitiveAll"
        echo "Tree Output: $tree"
        echo "Include Hidden: $includeHidden"
        echo "Delete Pycache: $delPyCache"
        echo "Exclude Binary: $excludeBinary"
        echo "Debug Mode: $debug"
        echo "----------------------------------------"

    fi

    # ------------------------------
    # Prepare Output Directory and File
    # ------------------------------

    mkdir -p "$outputDir" || { echo "Error: Cannot create output directory '$outputDir'." >&2; return 1; }

    outputFilePath="$outputDir/$outputFile"

    if [[ -e "$outputFilePath" ]]; then

        fullOutputPath="$(realpath "$outputFilePath")"

        rm "$fullOutputPath"

    fi

    # ------------------------------
    # Delete __pycache__ and .pyc Files
    # ------------------------------

    if [[ "$delPyCache" == true ]]; then

        fullInputDir="$(realpath "$inputDir")"

        find "$fullInputDir" -type d -name "__pycache__" -print0 | xargs -0 rm -rf

        find "$fullInputDir" -type f -name "*.pyc" -print0 | xargs -0 rm -f

    fi

    # ------------------------------
    # Construct Find Command
    # ------------------------------

    findCommand=("find" "$inputDir" "-type" "f")

    if [[ "$recursive" == false ]]; then

        findCommand+=("-maxdepth" "1")

    fi

    for pattern in "${excludePatterns[@]}"; do

        if [[ "$caseSensitiveExcludes" == true ]]; then

            findCommand+=("!" "-path" "$pattern")

        else

            regexPattern=$(echo "$pattern" | sed 's/\./\\./g; s/\*/.*/g; s/\?/.?/g')

            findCommand+=("!" "-iregex" ".*$regexPattern.*")

        fi

    done

    if [[ "$verbose" == true ]]; then

        echo "Executing find command: ${findCommand[@]}"

    fi

    # ------------------------------
    # Helpers for hidden, binary checks
    # ------------------------------

    IsPathHidden() {
        local path="$1"

        [[ $path == */.* ]] && return 0

        local dir
        for dir in ${(s:/:)path}; do
            [[ $dir == .* ]] && return 0
        done

        return 1
    }

    matchedFiles=()

    while IFS= read -r file; do

        fullPath="$(realpath "$file")"

        # Skip hidden files if includeHidden=false
        if IsPathHidden "$fullPath" && [[ "$includeHidden" == false ]]; then
            continue
        fi

        fileExt=".${file##*.}"
        skipFile=false

        # ------------------------------
        # 1) Skip if extension is excluded
        # ------------------------------

        if [[ ${#excludeExtensionsArray[@]} -gt 0 ]]; then

            if [[ "$caseSensitiveExtensions" == false ]]; then

                fileExtLower="${fileExt:l}"

                for exExt in "${excludeExtensionsArray[@]}"; do
                    exExtLower="${exExt:l}"
                    if [[ "$fileExtLower" == "$exExtLower" ]]; then
                        skipFile=true
                        break
                    fi
                done

            else

                for exExt in "${excludeExtensionsArray[@]}"; do
                    if [[ "$fileExt" == "$exExt" ]]; then
                        skipFile=true
                        break
                    fi
                done

            fi

            $skipFile && continue

        fi

        # ------------------------------
        # 2) If the user specified an extension list, only include those
        # ------------------------------

        if [[ ${#extensionsArray[@]} -gt 0 ]]; then

            foundMatchingExt=false

            if [[ "$caseSensitiveExtensions" == false ]]; then

                fileExtLower="${fileExt:l}"
                for ext in "${extensionsArray[@]}"; do
                    extLower="${ext:l}"
                    if [[ "$fileExtLower" == "$extLower" ]]; then
                        foundMatchingExt=true
                        break
                    fi
                done

            else

                for ext in "${extensionsArray[@]}"; do
                    if [[ "$fileExt" == "$ext" ]]; then
                        foundMatchingExt=true
                        break
                    fi
                done

            fi

            if [[ "$foundMatchingExt" == false ]]; then
                continue
            fi

        fi

        # ------------------------------
        # 3) Exclude unreadable/binary if excludeBinary=true
        # ------------------------------

        if [[ "$excludeBinary" == true ]]; then

            # If not readable, skip immediately
            if [[ ! -r "$file" ]]; then
                skipFile=true
            else

                # Check if file is binary:
                if ! grep -Iq . "$file" 2>/dev/null; then
                    skipFile=true
                fi
            fi

            $skipFile && continue

        fi

        matchedFiles+=("$file")

        if [[ "$verbose" == true ]]; then
            echo "Matched file: $file"
        fi

    done < <("${findCommand[@]}")

    if [[ "$verbose" == true ]]; then
        echo "Total matched files: ${#matchedFiles[@]}"
    fi

    # ------------------------------
    # Build Tree Representation (if enabled)
    # ------------------------------

    if [[ "$tree" == true ]]; then

        tempInputDir="$inputDir"
        tempInputDir="${tempInputDir/#.\//}"
        tempInputDir="${tempInputDir%/}"

        fullTree="$(tree "$tempInputDir")"
        fullTree=$(sed '1d' <<< "$fullTree")
    fi

    # ------------------------------
    # Write to Output File
    # ------------------------------

    {
        if [[ "$addTitle" == true ]]; then
            if $recursive; then
                echo "Contents of '$inputDirName' and its subdirectories"
            else
                echo "Contents of '$inputDirName' (not including its subdirectories)"
            fi
            echo '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
            echo ""
        fi

        echo "--------------------------------------------------------------------------------"
        echo "Parameters:"
        echo "- - - - - - - - - - - - - - - - - - - -"
        echo "Extensions:"
        if [[ ${#extensionsArray[@]} -eq 0 ]]; then
            echo "  - All"
        else
            printf '  - %s\n' "${extensionsArray[@]}"
        fi

        echo "Exclude Patterns:"
        if [[ ${#excludePatterns[@]} -eq 0 ]]; then
            echo "  - N/A"
        else
            printf '  - %s\n' "${excludePatterns[@]}"
        fi

        echo "Case Sensitivity Options:"
        echo "  - Extensions: $caseSensitiveExtensions"
        echo "  - Excludes: $caseSensitiveExcludes"
        echo "  - All: $caseSensitiveAll"

        echo "Other Options:"
        echo "  - Include Hidden: $includeHidden"

        echo "- - - - - - - - - - - - - - - - - - - -"
        echo "Total matched files: ${#matchedFiles[@]}"
        echo "================================================================================"
        echo ""

        if [[ "$tree" == true ]]; then
            tempInputDir="$inputDir"
            tempInputDir="${tempInputDir/#.\//}"
            tempInputDir="${tempInputDir%/}"

            echo "--------------------------------------------------------------------------------"
            echo "# Tree Representation"
            echo "********************************************************************************"
            echo "Full tree of '$inputDirName':"
            echo ""
            echo "$(basename "$(realpath "$tempInputDir")")"

            echo "$fullTree"
            echo "================================================================================"

            echo ""
            echo "--------------------------------------------------------------------------------"
            echo "# Directory Structure List"
            echo "********************************************************************************"

            typeset -A dirMap

            fullOutputPath="$(realpath "$outputFilePath")"

            while IFS= read -r dir; do
                fullPath="$(realpath "$dir")"

                if IsPathHidden "$fullPath" && [[ "$includeHidden" == false ]]; then
                    continue
                fi

                children=("${(@f)$(find "$dir" -mindepth 1 -maxdepth 1 | sort)}")
                childrenBase=()

                for child in "${children[@]}"; do
                    if [[ -z "$child" ]]; then
                        continue
                    fi

                    fullChildPath="$(realpath "$child")"
                    if IsPathHidden "$fullChildPath" && [[ "$includeHidden" == false ]]; then
                        continue
                    elif [[ "$fullChildPath" == "$fullOutputPath" ]]; then
                        continue
                    fi

                    childrenBase+=("$(basename "$child")")
                done

                if [[ ${#childrenBase[@]} -gt 0 ]]; then
                    childrenStr=$(printf ", %s" "${childrenBase[@]}")
                    childrenStr="${childrenStr:2}"
                    dirMap["$dir"]="[\"$childrenStr\"]"
                else
                    dirMap["$dir"]="[]"
                fi
            done < <(find "$inputDir" -type d | sort)

            for dir in ${(k)dirMap}; do
                if [[ "$dir" == "$inputDir" ]]; then
                    relativeDir="$inputDir"
                else
                    relativeDir="${dir#$fullInputDir/}"
                fi

                if [[ "$relativeDir" == "\".\"" ]]; then
                    relativeDir="\"$inputDirName\""
                elif [[ "$relativeDir" == "\"./"* ]]; then
                    remainingRelativeDir="${relativeDir#\"./}"
                    relativeDir="\"${inputDirName}/${remainingRelativeDir}"
                fi

                echo "$relativeDir: ${dirMap[$dir]}"
            done | sort

            echo "================================================================================"
            echo ""

            echo "--------------------------------------------------------------------------------"
            echo "# File Contents"
            echo "********************************************************************************"

            totalFiles=${#matchedFiles[@]}
            if [[ $totalFiles -gt 0 ]]; then
                currentFile=0
                for file in "${matchedFiles[@]}"; do
                    ((currentFile++))
                    relativePath="${file#$inputDir/}"
                    relativePath="${inputDirName}/${relativePath}"
                    absolutePath=$(realpath "$file")
                    filename="$(basename "$file")"

                    echo ""
                    echo "--------------------------------------------------------------------------------"
                    echo "# Filename: \"$filename\""
                    echo "# Relative to Input Dir: \"$relativePath\""
                    echo "# Absolute Path: \"$absolutePath\""
                    echo "********************************************************************************"
                    echo "# Start of Content in \"$file\":"

                    if [[ -r "$file" ]]; then
                        cat "$file"
                        echo ""
                        echo "# EOF: $file"
                        echo "================================================================================"
                    else
                        echo "Error: Cannot read file '$file'." >&2
                    fi

                    if [[ "$file" != "${matchedFiles[-1]}" ]]; then
                        echo ""
                    fi
                done
            else
                echo "No files to concatenate."
            fi
        fi
    } > "$outputFilePath"

    if [[ "$verbose" == true ]]; then
        echo "All files have been concatenated into '$outputFilePath'."
    fi

    if [[ "$debug" == true ]]; then
        set +x
    fi

    return 0
}
