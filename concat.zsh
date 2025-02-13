# concat.zsh

# Function: concat
# Usage: concat [extensions] [OPTIONS]
#
# Combines the contents of files matching optional file extensions into a single output file.
# Supports excluding/including specific paths, deleting Python cache files, generating a tree view,
# and excluding binary/unreadable files. Both XML and plain-text outputs are supported.

concat() {

    # -------------------------------------------------------------------------
    # Help Display
    # -------------------------------------------------------------------------
    # If a help flag is provided, output usage instructions and exit.
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            cat <<EOF
concat [extensions] [OPTIONS]

Positional Argument:
  [extensions]
      One or more file extensions to match (e.g., "txt" or ".txt").
      Comma-separated lists are allowed (e.g., "txt,md,.log").
      If omitted, all file extensions are included.

Input/Output:
  -i, --input <dir>
      Directory to search for files (default: current directory).

  -o, --output <file>
      Name or path of the concatenated output file (default: "concatOutput.txt").

  -D, --output-dir <dir>
      Directory to save the output file (default: current directory).

Filtering:
  -e, --exclude <patterns>
      Exclude files or directories matching these patterns (wildcards supported).

  -I, --include <patterns>
      Only include files or directories matching these patterns (wildcards supported).

  -E, --ignore-ext <exts>
      Ignore files with these extensions (e.g., "log,bin,.tmp").
      Extensions can be prefixed with '.' or written as plain text.

  -H, --no-hidden
      Skip hidden files and directories.

  -B, --no-binary
      Ignore unreadable or binary files.

Behavior Control:
  -R, --no-recursive
      Disable searching in subdirectories (default is recursive search).

  -C, --case-sensitive
      Enable case-sensitive matching for extensions and exclude patterns.

Formatting:
  -T, --no-title
      Do not add a title/header line at the start of the output file.

  -x, --xml
      Format the output as XML instead of plain text.

Miscellaneous:
  -W, --no-tree
      Do not include a directory tree representation in the output.

  -P, --no-purge-pycache
      Do not delete \`__pycache__\` directories and \`.pyc\` files.

  -v, --verbose
      Show detailed output, including matched files.

  -d, --debug
      Enable debug mode with execution tracing.

  -h, --help
      Show this help message and exit.
EOF
            return 0
        fi
    done

    # -------------------------------------------------------------------------
    # Save Original Arguments
    # -------------------------------------------------------------------------
    # Store the original command-line arguments for later use in output.
    originalArgs=("$@")

    # -------------------------------------------------------------------------
    # Set Default Configuration Values
    # -------------------------------------------------------------------------
    outputFile="concatOutput.txt"
    outputDir="."
    inputDir="."
    excludePatterns=()
    includePatterns=()
    excludeExtensionsArray=()
    recursive=true
    addTitle=true
    verbose=false
    caseSensitive=false
    tree=true
    extensions=""
    includeHidden=true
    delPyCache=true
    debug=false
    excludeBinary=false
    xmlOutput=false

    # -------------------------------------------------------------------------
    # Parse Command-Line Options
    # -------------------------------------------------------------------------
    while (( $# )); do
        case "$1" in

            # Input/Output:
            --input|-i)
                if [[ -n "$2" && "$2" != --* ]]; then
                    inputDir="$2"
                    shift 2
                else
                    echo "Error: --input requires a directory argument."
                    return 1
                fi
            ;;

            --output|-o)
                if [[ -n "$2" && "$2" != --* ]]; then
                    outputFile="$2"
                    shift 2
                else
                    echo "Error: --output requires a filename argument."
                    return 1
                fi
            ;;

            --output-dir|-D)
                if [[ -n "$2" && "$2" != --* ]]; then
                    outputDir="$2"
                    shift 2
                else
                    echo "Error: --output-dir requires a directory argument."
                    return 1
                fi
            ;;

            # Filtering:
            --exclude|-e)
                if [[ -n "$2" && "$2" != --* ]]; then
                    IFS=',' read -A tempExcludes <<< "$2"
                    # Process each exclusion pattern.
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

            --include|-I)
                if [[ -n "$2" && "$2" != --* ]]; then
                    IFS=',' read -A tempIncludes <<< "$2"
                    for pattern in "${tempIncludes[@]}"; do
                        pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        includePatterns+=("$pattern")
                    done
                    shift 2
                else
                    echo "Error: --include requires a patterns argument."
                    return 1
                fi
            ;;

            --ignore-ext|-E)
                if [[ -n "$2" && "$2" != --* ]]; then
                    IFS=',' read -A rawExcludeExtensions <<< "$2"
                    for ext in "${rawExcludeExtensions[@]}"; do
                        ext=$(echo "$ext" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        [[ "$ext" != .* ]] && ext=".$ext"
                        excludeExtensionsArray+=("$ext")
                    done
                    shift 2
                else
                    echo "Error: --ignore-ext requires an extension argument."
                    return 1
                fi
            ;;

            --no-hidden|-H)
                includeHidden=false
                shift
            ;;

            --no-binary|-B)
                excludeBinary=true
                shift
            ;;

            # Behavior Control:
            --no-recursive|-R)
                recursive=false
                shift
            ;;

            --case-sensitive|-C)
                caseSensitive=true
                shift
            ;;

            # Formatting:
            --no-title|-T)
                addTitle=false
                shift
            ;;

            --xml|-x)
                xmlOutput=true
                shift
            ;;

            # Miscellaneous:
            --no-tree|-W)
                tree=false
                shift
            ;;

            --no-purge-pycache|-P)
                delPyCache=false
                shift
            ;;

            --verbose|-v)
                verbose=true
                shift
            ;;

            --debug|-d)
                debug=true
                set -x  # Enable shell debug mode.
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

    # -------------------------------------------------------------------------
    # Determine Input Directory Base Name
    # -------------------------------------------------------------------------
    inputDirName="$(basename "$(realpath "$inputDir")")"

    # -------------------------------------------------------------------------
    # Process Extensions
    # -------------------------------------------------------------------------
    # Convert the comma-separated extensions string into an array.
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

    # -------------------------------------------------------------------------
    # Verbose: Output Configuration Summary
    # -------------------------------------------------------------------------
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
        echo "Include Patterns: ${includePatterns[@]}"
        echo "Ignore Extensions: ${excludeExtensionsArray[@]}"
        echo "Recursive: $recursive"
        echo "Add Title: $addTitle"
        echo "Case Sensitive: $caseSensitive"
        echo "Tree Output: $tree"
        echo "Include Hidden: $includeHidden"
        echo "Purge Pycache: $delPyCache"
        echo "Ignore Binary: $excludeBinary"
        echo "Debug Mode: $debug"
        echo "----------------------------------------"
    fi

    # -------------------------------------------------------------------------
    # Prepare Output File and Directory
    # -------------------------------------------------------------------------
    mkdir -p "$outputDir" || { echo "Error: Cannot create output directory '$outputDir'." >&2; return 1; }
    outputFilePath="$outputDir/$outputFile"
    if [[ -e "$outputFilePath" ]]; then
        fullOutputPath="$(realpath "$outputFilePath")"
        rm "$fullOutputPath"
    fi

    # -------------------------------------------------------------------------
    # Delete Python Cache Files (.pyc and __pycache__)
    # -------------------------------------------------------------------------
    if [[ "$delPyCache" == true ]]; then
        fullInputDir="$(realpath "$inputDir")"
        find "$fullInputDir" -type d -name "__pycache__" -print0 | xargs -0 rm -rf
        find "$fullInputDir" -type f -name "*.pyc" -print0 | xargs -0 rm -f
    fi

    # -------------------------------------------------------------------------
    # Construct the 'find' Command to Locate Files
    # -------------------------------------------------------------------------
    findCommand=("find" "$inputDir" "-type" "f")
    if [[ "$recursive" == false ]]; then
        findCommand+=("-maxdepth" "1")
    fi
    for pattern in "${excludePatterns[@]}"; do
        regexPattern=$(echo "$pattern" | sed 's/\./\\./g; s/\*/.*/g; s/\?/.?/g')
        findCommand+=("!" "-iregex" ".*$regexPattern.*")
    done
    if [[ "$verbose" == true ]]; then
        echo "Executing find command: ${findCommand[@]}"
    fi

    # -------------------------------------------------------------------------
    # Helper Function: IsPathHidden
    # -------------------------------------------------------------------------
    # Returns 0 (true) if the given path is hidden.
    IsPathHidden() {
        local path="$1"
        [[ $path == */.* ]] && return 0
        local dir
        for dir in ${(s:/:)path}; do
            [[ $dir == .* ]] && return 0
        done
        return 1
    }

    # -------------------------------------------------------------------------
    # Find and Filter Files
    # -------------------------------------------------------------------------
    matchedFiles=()
    foundFiles=("${(@f)$( "${findCommand[@]}" )}")
    totalFound=${#foundFiles[@]}
    currentScan=0

    for file in "${foundFiles[@]}"; do
        currentScan=$(( currentScan + 1 ))

        # Update progress bar if available (only in non-XML mode).
        if [[ "$xmlOutput" == false ]]; then
            if type UpdateScanProgressBar >/dev/null 2>&1; then
                UpdateScanProgressBar "$currentScan" "$totalFound"
            fi
        fi

        fullPath="$(realpath "$file")"

        # Skip hidden files if includeHidden is false.
        if IsPathHidden "$fullPath" && [[ "$includeHidden" == false ]]; then
            continue
        fi

        fileExt=".${file##*.}"
        skipFile=false

        # Exclude files with specific extensions.
        if [[ ${#excludeExtensionsArray[@]} -gt 0 ]]; then
            if [[ "$caseSensitive" == false ]]; then
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

        # If extensions are specified, check if the file matches.
        if [[ ${#extensionsArray[@]} -gt 0 ]]; then
            foundMatchingExt=false
            if [[ "$caseSensitive" == false ]]; then
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

        # Exclude unreadable or binary files if requested.
        if [[ "$excludeBinary" == true ]]; then
            if [[ ! -r "$file" ]]; then
                skipFile=true
            else
                if ! grep -Iq . "$file" 2>/dev/null; then
                    skipFile=true
                fi
            fi
            $skipFile && continue
        fi

        # Apply include patterns if provided.
        if [[ ${#includePatterns[@]} -gt 0 ]]; then
            includeFile=false
            for pattern in "${includePatterns[@]}"; do
                if [[ "$caseSensitive" == true ]]; then
                    if [[ "$fullPath" == *"$pattern"* ]]; then
                        includeFile=true
                        break
                    fi
                else
                    regexPattern=$(echo "$pattern" | sed 's/\./\\./g; s/\*/.*/g; s/\?/.?/g')
                    if [[ "$fullPath" =~ $regexPattern ]]; then
                        includeFile=true
                        break
                    fi
                fi
            done
            if [[ "$includeFile" == false ]]; then
                continue
            fi
        fi

        # Add the file to the matched list.
        matchedFiles+=("$file")
        if [[ "$verbose" == true ]]; then
            echo "Matched file: $file"
        fi
    done

    if [[ "$verbose" == true ]]; then
        echo "Total matched files: ${#matchedFiles[@]}"
    fi

    # -------------------------------------------------------------------------
    # Build Directory Tree Representation
    # -------------------------------------------------------------------------
    if [[ "$tree" == true ]]; then
        tempInputDir="$inputDir"
        # Normalize the input directory path.
        tempInputDir="${tempInputDir/#.\//}"
        tempInputDir="${tempInputDir%/}"
        if [[ "$xmlOutput" == true ]]; then
            fullTree="$(tree -X "$tempInputDir")"
        else
            fullTree="$(tree "$tempInputDir")"
        fi
        # Remove the header line from the tree output.
        fullTree=$(sed '1d' <<< "$fullTree")
    fi

    # -------------------------------------------------------------------------
    # XML Output Block
    # -------------------------------------------------------------------------
    if [[ "$xmlOutput" == true ]]; then
    {
        fullCommand=$(printf '%q ' "${originalArgs[@]}")
        fullCommand=${fullCommand% }

        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<ConcatOutput>'

        # Title Section
        if [[ "$addTitle" == true ]]; then
            echo "  <Title>"
            echo "    <Text>Contents of '$inputDirName'</Text>"
            echo "  </Title>"
        fi

        # Command and Parameters Section
        echo "  <Command>concat ${fullCommand}</Command>"
        echo "  <Parameters>"
        echo "    <Extensions>"
        if [[ ${#extensionsArray[@]} -eq 0 ]]; then
            echo "      <Value>All</Value>"
        else
            for ext in "${extensionsArray[@]}"; do
                echo "      <Value>$ext</Value>"
            done
        fi
        echo "    </Extensions>"
        echo "    <ExcludePatterns>"
        if [[ ${#excludePatterns[@]} -eq 0 ]]; then
            echo "      <Value>N/A</Value>"
        else
            for pat in "${excludePatterns[@]}"; do
                echo "      <Value>$pat</Value>"
            done
        fi
        echo "    </ExcludePatterns>"
        echo "    <IncludePatterns>"
        if [[ ${#includePatterns[@]} -eq 0 ]]; then
            echo "      <Value>All</Value>"
        else
            for pat in "${includePatterns[@]}"; do
                echo "      <Value>$pat</Value>"
            done
        fi
        echo "    </IncludePatterns>"
        echo "    <CaseSensitive>$caseSensitive</CaseSensitive>"
        echo "    <TotalMatchedFiles>${#matchedFiles[@]}</TotalMatchedFiles>"
        echo "  </Parameters>"

        # Matched Files Directory Structure List
        echo "    <MatchedFilesDirectoryStructureList>"
        typeset -A matchedDirMap
        fullInputDir="$(realpath "$inputDir")"
        for file in "${matchedFiles[@]}"; do
            fileFullPath="$(realpath "$file")"
            dir=$(dirname "$fileFullPath")
            base=$(basename "$fileFullPath")
            if [[ -n "$base" ]]; then
                if [[ -n "${matchedDirMap[$dir]}" ]]; then
                    matchedDirMap[$dir]="${matchedDirMap[$dir]}, $base"
                else
                    matchedDirMap[$dir]="$base"
                fi
            fi
        done
        for dir in ${(k)matchedDirMap}; do
            if [[ "$dir" == "$fullInputDir" ]]; then
                relativeDir="$inputDirName"
            else
                relativeDir="$inputDirName/${dir#$fullInputDir/}"
            fi
            echo "      <DirectoryEntry>\"$relativeDir\": [${matchedDirMap[$dir]}]</DirectoryEntry>"
        done | sort
        echo "    </MatchedFilesDirectoryStructureList>"

        # Tree Representation and Full Directory Structure List
        echo "  <TreeOutput>"
        echo "    <TreeRepresentation>"
        tempInputDir="$inputDir"
        tempInputDir="${tempInputDir/#.\//}"
        tempInputDir="${tempInputDir%/}"
        echo "      <Directory>$(basename "$(realpath "$tempInputDir")")</Directory>"
        echo "      <Tree><![CDATA["
        echo "$fullTree"
        echo "]]></Tree>"
        echo "    </TreeRepresentation>"

        echo "    <DirectoryStructureList>"
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
                relativeDir="$inputDirName"
            else
                relativeDir="$inputDirName/${dir#$fullInputDir/}"
            fi
            echo "      <DirectoryEntry>$relativeDir: ${dirMap[$dir]}</DirectoryEntry>"
        done | sort
        echo "    </DirectoryStructureList>"
        echo "  </TreeOutput>"

        # File Contents Section
        echo "  <FileContents>"
        totalFiles=${#matchedFiles[@]}
        if [[ $totalFiles -gt 0 ]]; then
            currentFile=0
            for file in "${matchedFiles[@]}"; do
                ((currentFile++))
                if [[ "$xmlOutput" == false ]]; then
                    if type UpdateProgressBar >/dev/null 2>&1; then
                        UpdateScanProgressBar "$currentFile" "$totalFiles"
                    fi
                fi
                relativePath="${file#$inputDir/}"
                relativePath="${inputDirName}/${relativePath}"
                absolutePath=$(realpath "$file")
                filename="$(basename "$file")"
                echo "    <File>"
                echo "      <Filename>$filename</Filename>"
                echo "      <RelativePath>$relativePath</RelativePath>"
                echo "      <AbsolutePath>$absolutePath</AbsolutePath>"
                echo "      <Content><![CDATA["
                if [[ -r "$file" ]]; then
                    cat "$file"
                else
                    echo "Error: Cannot read file '$file'."
                fi
                echo "]]></Content>"
                echo "    </File>"
            done
        else
            echo "    <Message>No files to concatenate.</Message>"
        fi
        echo "  </FileContents>"

        echo "</ConcatOutput>"
    } > "$outputFilePath"

    # -------------------------------------------------------------------------
    # Non-XML Output Block
    # -------------------------------------------------------------------------
    else
    {
        fullCommand=$(printf '%q ' "${originalArgs[@]}")
        fullCommand=${fullCommand% }

        # Title Section
        if [[ "$addTitle" == true ]]; then
            echo "Contents of '$inputDirName'"
            echo '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
            echo ""
        fi

        # Command and Parameters Summary
        echo "--------------------------------------------------------------------------------"
        echo "Full command: \"concat ${fullCommand}\""
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
        echo "Include Patterns:"
        if [[ ${#includePatterns[@]} -eq 0 ]]; then
            echo "  - All"
        else
            printf '  - %s\n' "${includePatterns[@]}"
        fi
        echo "Ignore Extensions:"
        if [[ ${#excludeExtensionsArray[@]} -eq 0 ]]; then
            echo "  - N/A"
        else
            printf '  - %s\n' "${excludeExtensionsArray[@]}"
        fi
        echo "Case Sensitive: $caseSensitive"
        echo "Other Options:"
        echo "  - Recursive Search: $recursive"
        echo "  - Include Hidden: $includeHidden"
        echo "  - Purge Pycache: $delPyCache"
        echo "  - Ignore Binary: $excludeBinary"
        echo "- - - - - - - - - - - - - - - - - - - -"
        echo "Total matched files: ${#matchedFiles[@]}"
        echo "================================================================================"
        echo ""

        # Directory Structure List (Matched Files Only)
        echo "--------------------------------------------------------------------------------"
        echo "# Directory Structure List (Matched Files Only)"
        echo "********************************************************************************"
        typeset -A matchedDirMap
        fullInputDir="$(realpath "$inputDir")"
        for file in "${matchedFiles[@]}"; do
            fileFullPath="$(realpath "$file")"
            dir=$(dirname "$fileFullPath")
            base=$(basename "$fileFullPath")
            if [[ -n "$base" ]]; then
                if [[ -n "${matchedDirMap[$dir]}" ]]; then
                    matchedDirMap[$dir]="${matchedDirMap[$dir]}, $base"
                else
                    matchedDirMap[$dir]="$base"
                fi
            fi
        done
        for dir in ${(k)matchedDirMap}; do
            if [[ "$dir" == "$fullInputDir" ]]; then
                relativeDir="$inputDirName"
            else
                relativeDir="$inputDirName/${dir#$fullInputDir/}"
            fi
            echo "\"$relativeDir\": [${matchedDirMap[$dir]}]"
        done | sort
        echo "================================================================================"
        echo ""

        # Tree Representation and Directory Structure List
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
                    relativeDir="$inputDirName"
                else
                    relativeDir="$inputDirName/${dir#$fullInputDir/}"
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
        fi

        # File Contents Section
        echo "--------------------------------------------------------------------------------"
        echo "# File Contents"
        echo "********************************************************************************"
        totalFiles=${#matchedFiles[@]}
        if [[ $totalFiles -gt 0 ]]; then
            currentFile=0
            for file in "${matchedFiles[@]}"; do
                ((currentFile++))
                if type UpdateProgressBar >/dev/null 2>&1; then
                    UpdateProgressBar "$currentFile" "$totalFiles"
                fi
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
    } > "$outputFilePath"
    fi

    # -------------------------------------------------------------------------
    # Final Status Message and Cleanup
    # -------------------------------------------------------------------------
    if [[ "$verbose" == true ]]; then
        echo "All files have been concatenated into '$outputFilePath'."
    fi

    if [[ "$debug" == true ]]; then
        set +x  # Disable debug mode.
    fi

    return 0
}
