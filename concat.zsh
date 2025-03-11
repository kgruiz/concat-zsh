# concat.zsh

# Function: concat
# Usage: concat [extensions] [OPTIONS]
#
# Combines the contents of files matching optional file extensions into a single output file.
# Supports excluding/including specific paths, deleting Python cache files, generating a tree view,
# and excluding non-text/unreadable files. Both XML and plain-text outputs are supported.

concat() {

    # -------------------------------------------------------------------------
    # Help Display
    # -------------------------------------------------------------------------
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
    Output file name (default: "concat-<rootdirname>.txt" or ".xml").

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

  -H, --hidden
      Include hidden files and directories.

  -n, --non-text
      Include non-text files.

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

  -m, --minimal
      Minimal mode. By default outputs matched directory list and file contents,
      but omits file paths. See --paths.

  -p, --paths <TRUE|FALSE>
      Explicitly set whether to output the relative and absolute paths for each file.
      Accepts TRUE, FALSE, 1, or 0 (not case sensitive). In minimal mode the default is FALSE,
      in non-minimal mode the default is TRUE.

  -N, --no-params
      Do not output the parameters block.

  -L, --no-dir-list
      Do not output the matched directory list.

  -W, --no-tree
      Do not include a directory tree representation in the output.

Miscellaneous:
  -P, --no-purge-pycache
      Do not delete __pycache__ directories and .pyc files.

  -v, --verbose
      Show detailed output, including matched and skipped files.

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
    originalArgs=("$@")

    # -------------------------------------------------------------------------
    # Set Default Configuration Values
    # -------------------------------------------------------------------------
    outputFile=""
    userOutputProvided=false
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
    includeHidden=false
    delPyCache=true
    debug=false
    excludeNonText=true
    xmlOutput=false
    minimalMode=false

    showParams=true
    showDirList=true

    # In non‑minimal mode default is TRUE.
    showPaths=true

    # -------------------------------------------------------------------------
    # Parse Command-Line Options
    # -------------------------------------------------------------------------
    while (( $# )); do
        case "$1" in

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
                    userOutputProvided=true
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

            --hidden|-H)
                includeHidden=true
                shift
            ;;

            --non-text|-n)
                excludeNonText=false
                shift
            ;;

            --no-recursive|-R)
                recursive=false
                shift
            ;;

            --case-sensitive|-C)
                caseSensitive=true
                shift
            ;;

            --no-title|-T)
                addTitle=false
                shift
            ;;

            --xml|-x)
                xmlOutput=true
                shift
            ;;

            --minimal|-m)
                minimalMode=true
                # In minimal mode, default showPaths to FALSE unless overridden later.
                showPaths=false
                shift
            ;;

            --paths|-p)
                if [[ -n "$2" && "$2" != --* ]]; then
                    lowerVal=$(echo "$2" | tr '[:upper:]' '[:lower:]')
                    if [[ "$lowerVal" == "true" || "$lowerVal" == "1" ]]; then
                        showPaths=true
                    elif [[ "$lowerVal" == "false" || "$lowerVal" == "0" ]]; then
                        showPaths=false
                    else
                        echo "Error: --paths requires either TRUE or FALSE (or 1 or 0)."
                        return 1
                    fi
                    shift 2
                else
                    echo "Error: --paths requires an argument (TRUE or FALSE, or 1 or 0)."
                    return 1
                fi
            ;;

            --no-params|-N)
                showParams=false
                shift
            ;;

            --no-dir-list|-L)
                showDirList=false
                shift
            ;;

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
    # Update default output file extension based on input directory name if not user-provided
    # -------------------------------------------------------------------------

    # -------------------------------------------------------------------------
    # Determine Input Directory Base Name
    # -------------------------------------------------------------------------
    inputDirName="$(basename "$(realpath "$inputDir")")"
    # Update default output file based on input directory name if user did not provide one
    if [[ "$userOutputProvided" == false ]]; then
        if [[ "$xmlOutput" == true ]]; then
            outputFile="concat-${inputDirName}.xml"
        else
            outputFile="concat-${inputDirName}.txt"
        fi
    fi

    # -------------------------------------------------------------------------
    # Process Extensions
    # -------------------------------------------------------------------------
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
        echo "Input Directory: \"$inputDir\""
        echo "Output Directory: \"$outputDir\""
        echo "Output File: \"$outputFile\""
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
        echo "Ignore Non-Text: $excludeNonText"
        echo "XML Output: $xmlOutput"
        echo "Minimal Mode: $minimalMode"
        echo "Show Params: $showParams"
        echo "Show Directory List: $showDirList"
        echo "Show Paths: $showPaths"
        echo "Debug Mode: $debug"
        echo "----------------------------------------"
    fi

    # -------------------------------------------------------------------------
    # Prepare Output File and Directory
    # -------------------------------------------------------------------------
    # Ensure output directory exists
    mkdir -p "$outputDir" || { echo "Error: Cannot create output directory \"$outputDir\"." >&2; return 1; }

    # Define default output file names (for both text and XML)
    defaultTextOutput="$outputDir/concat-${inputDirName}.txt"
    defaultXmlOutput="$outputDir/concat-${inputDirName}.xml"

    # Delete any old default output files, regardless of current run settings
    if [[ -e "$defaultTextOutput" ]]; then
        rm "$(realpath "$defaultTextOutput")"
    fi

    if [[ -e "$defaultXmlOutput" ]]; then
        rm "$(realpath "$defaultXmlOutput")"
    fi

    # Ensure the current run's output file has the proper extension
    if [[ "$xmlOutput" == true ]]; then
        case "$outputFile" in
            *.xml) ;;  # Already correct
            *) outputFile="${outputFile}.xml" ;;  # Append .xml if missing
        esac
    else
        case "$outputFile" in
            *.txt) ;;  # Already correct
            *) outputFile="${outputFile}.txt" ;;  # Append .txt if missing
        esac
    fi

    # Build the current output file path and remove it if it exists
    outputFilePath="$outputDir/$outputFile"
    if [[ -e "$outputFilePath" ]]; then
        rm "$(realpath "$outputFilePath")"
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
    foundFiles=("${(@f)$(printf '%s\n' "${foundFiles[@]}" | sort -V)}")
    totalFound=${#foundFiles[@]}
    currentScan=0

    for file in "${foundFiles[@]}"; do
        currentScan=$(( currentScan + 1 ))

        if [[ "$xmlOutput" == false ]]; then
            if type UpdateScanProgressBar >/dev/null 2>&1; then
                UpdateScanProgressBar "$currentScan" "$totalFound"
            fi
        fi

        fullPath="$(realpath "$file")"

        if IsPathHidden "$fullPath" && [[ "$includeHidden" == false ]]; then
            [[ "$verbose" == true ]] && echo "Skipped file: \"$file\" (hidden)"
            continue
        fi

        fileExt=".${file##*.}"
        skipFile=false

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
            if $skipFile; then
                [[ "$verbose" == true ]] && echo "Skipped file: \"$file\" (ignored extension)"
                continue
            fi
        fi

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
                [[ "$verbose" == true ]] && echo "Skipped file: \"$file\" (extension not matched)"
                continue
            fi
        fi

        if [[ "$excludeNonText" == true ]]; then
            lowerExt="${fileExt:l}"
            nonTextExts=(".pdf" ".png" ".jpg" ".jpeg" ".gif" ".bmp" ".tiff" ".ico" ".zip" ".rar" ".7z" ".exe" ".dll")
            for ntExt in "${nonTextExts[@]}"; do
                if [[ "$lowerExt" == "$ntExt" ]]; then
                    skipFile=true
                    break
                fi
            done
            if ! $skipFile; then
                if [[ ! -r "$file" ]]; then
                    skipFile=true
                else
                    if ! grep -Iq . "$file" 2>/dev/null; then
                        skipFile=true
                    fi
                fi
            fi
            if $skipFile; then
                [[ "$verbose" == true ]] && echo "Skipped file: \"$file\" (non-text or unreadable)"
                continue
            fi
        fi

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
                [[ "$verbose" == true ]] && echo "Skipped file: \"$file\" (include pattern not matched)"
                continue
            fi
        fi

        matchedFiles+=("$file")
        [[ "$verbose" == true ]] && echo "Matched file: \"$file\""
    done

    [[ "$verbose" == true ]] && echo "Total matched files: ${#matchedFiles[@]}"

    # -------------------------------------------------------------------------
    # Build Directory Tree Representation (if not in minimal mode)
    # -------------------------------------------------------------------------
    if [[ "$tree" == true && "$minimalMode" == false ]]; then
        tempInputDir="$inputDir"
        tempInputDir="${tempInputDir/#.\//}"
        tempInputDir="${tempInputDir%/}"
        if [[ "$xmlOutput" == true ]]; then
            fullTree="$(tree -X "$tempInputDir")"
        else
            fullTree="$(tree "$tempInputDir")"
        fi
        fullTree=$(sed '1d' <<< "$fullTree")
    fi

    # -------------------------------------------------------------------------
    # Final Output Block(s)
    # -------------------------------------------------------------------------
    if [[ "$minimalMode" == true ]]; then
        # In minimal mode, normally both the matched directory list and file contents are output.
        # However, if showDirList is false (i.e. -L/--no-dir-list given), only file contents are output.
        if [[ "$xmlOutput" == true ]]; then
        {
            echo '<?xml version="1.0" encoding="UTF-8"?>'
            if [[ "$showDirList" == true ]]; then
                echo "<concat${inputDirName}>"
                # Output matched directory list
                echo "  <MatchedFilesDirectoryStructureList>"
                typeset -A matchedDirMap
                fullInputDir="$(realpath "$inputDir")"
                for file in "${matchedFiles[@]}"; do
                    fileFullPath="$(realpath "$file")"
                    dir=$(dirname "$fileFullPath")
                    base=$(basename "$fileFullPath")
                    if [[ -n "$base" ]]; then
                        if [[ -n "${matchedDirMap[$dir]}" ]]; then
                            matchedDirMap[$dir]="${matchedDirMap[$dir]}, \"$base\""
                        else
                            matchedDirMap[$dir]="\"$base\""
                        fi
                    fi
                done
                for dir in ${(k)matchedDirMap}; do
                    if [[ "$dir" == "$fullInputDir" ]]; then
                        relativeDir="$(basename "$fullInputDir")"
                    else
                        relativeDir="$(basename "$fullInputDir")/${dir#$fullInputDir/}"
                    fi
                    echo "    <DirectoryEntry>\"$relativeDir\": [${matchedDirMap[$dir]}]</DirectoryEntry>"
                done | sort -V
                echo "  </MatchedFilesDirectoryStructureList>"
            fi
            # Always output file contents.
            echo "  <FileContents>"
            totalFiles=${#matchedFiles[@]}
            if [[ $totalFiles -gt 0 ]]; then
                currentFile=0
                for file in "${matchedFiles[@]}"; do
                    ((currentFile++))
                    relativePath="${file#$inputDir/}"
                    relativePath="$(basename "$fullInputDir")/${relativePath}"
                    absolutePath="$(realpath "$file")"
                    filename="$(basename "$file")"
                    echo "    <File>"
                    echo "      <Filename>$filename</Filename>"
                    if [[ "$showPaths" == true ]]; then
                        echo "      <RelativePath>\"$relativePath\"</RelativePath>"
                        echo "      <AbsolutePath>\"$absolutePath\"</AbsolutePath>"
                    fi
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
            if [[ "$showDirList" == true ]]; then
                echo "</concat${inputDirName}>"
            else
                echo "</FileContentsOnly>"
            fi
        } > "$outputFilePath"
        else
        {
            # Non-XML Minimal Mode
            if [[ "$showDirList" == true ]]; then
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
                            matchedDirMap[$dir]="${matchedDirMap[$dir]}, \"$base\""
                        else
                            matchedDirMap[$dir]="\"$base\""
                        fi
                    fi
                done
                for dir in ${(k)matchedDirMap}; do
                    if [[ "$dir" == "$fullInputDir" ]]; then
                        relativeDir="$(basename "$fullInputDir")"
                    else
                        relativeDir="$(basename "$fullInputDir")/${dir#$fullInputDir/}"
                    fi
                    echo "\"$relativeDir\": [${matchedDirMap[$dir]}]"
                done | sort -V
                echo "================================================================================"
                echo ""
            fi

            echo "--------------------------------------------------------------------------------"
            echo "# File Contents"
            echo "********************************************************************************"
            totalFiles=${#matchedFiles[@]}
            if [[ $totalFiles -gt 0 ]]; then
                currentFile=0
                for file in "${matchedFiles[@]}"; do
                    ((currentFile++))
                    relativePath="${file#$inputDir/}"
                    relativePath="$(basename "$fullInputDir")/${relativePath}"
                    absolutePath="$(realpath "$file")"
                    filename="$(basename "$file")"
                    echo ""
                    echo "--------------------------------------------------------------------------------"
                    echo "# Filename: \"$filename\""
                    if [[ "$showPaths" == true ]]; then
                        echo "# Relative to Input Dir: \"$relativePath\""
                        echo "# Absolute Path: \"$absolutePath\""
                    fi
                    echo "********************************************************************************"
                    if [[ -r "$file" ]]; then
                        cat "$file"
                        echo ""
                        echo "# EOF: \"$file\""
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
    else
        # -------------------------------------------------------------------------
        # Standard Output (Non‑Minimal Mode)
        # -------------------------------------------------------------------------
        if [[ "$xmlOutput" == true ]]; then
        {
            fullCommand=$(printf '%q ' "${originalArgs[@]}")
            fullCommand=${fullCommand% }

            echo '<?xml version="1.0" encoding="UTF-8"?>'
            echo "<concat${inputDirName}>"

            if [[ "$addTitle" == true ]]; then
                echo "  <Title>"
                echo "    <Text>Contents of '$inputDirName'</Text>"
                echo "  </Title>"
            fi

            if [[ "$showParams" == true ]]; then
                echo "  <Parameters>"
                echo "  <Command>concat ${fullCommand}</Command>"
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
            fi

            if [[ "$showDirList" == true ]]; then
                echo "  <MatchedFilesDirectoryStructureList>"
                typeset -A matchedDirMap
                fullInputDir="$(realpath "$inputDir")"
                for file in "${matchedFiles[@]}"; do
                    fileFullPath="$(realpath "$file")"
                    dir=$(dirname "$fileFullPath")
                    base=$(basename "$fileFullPath")
                    if [[ -n "$base" ]]; then
                        if [[ -n "${matchedDirMap[$dir]}" ]]; then
                            matchedDirMap[$dir]="${matchedDirMap[$dir]}, \"$base\""
                        else
                            matchedDirMap[$dir]="\"$base\""
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
                done | sort -V
                echo "  </MatchedFilesDirectoryStructureList>"
            fi

            echo "  <TreeOutput>"
            echo "    <TreeRepresentation>"
            tempInputDir="$inputDir"
            tempInputDir="${tempInputDir/#.\//}"
            tempInputDir="${tempInputDir%/}"
            echo "      <Directory>\"$(basename "$(realpath "$tempInputDir")")\"</Directory>"
            echo "      <Tree><![CDATA["
            echo "$fullTree"
            echo "]]></Tree>"
            echo "    </TreeRepresentation>"

            if [[ "$showDirList" == true ]]; then
                echo "    <DirectoryStructureList>"
                typeset -A dirMap
                fullOutputPath="$(realpath "$outputFilePath")"
                while IFS= read -r dir; do
                    fullPath="$(realpath "$dir")"
                    if IsPathHidden "$fullPath" && [[ "$includeHidden" == false ]]; then
                        continue
                    fi
                    children=("${(@f)$(find "$dir" -mindepth 1 -maxdepth 1 | sort -V)}")
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
                done < <(find "$inputDir" -type d | sort -V)
                for dir in ${(k)dirMap}; do
                    if [[ "$dir" == "$inputDir" ]]; then
                        relativeDir="$inputDirName"
                    else
                        relativeDir="$inputDirName/${dir#$fullInputDir/}"
                    fi
                    echo "      <DirectoryEntry>\"$relativeDir\": ${dirMap[$dir]}</DirectoryEntry>"
                done | sort -V
                echo "    </DirectoryStructureList>"
            fi
            echo "  </TreeOutput>"

            echo "  <FileContents>"
            totalFiles=${#matchedFiles[@]}
            if [[ $totalFiles -gt 0 ]]; then
                currentFile=0
                for file in "${matchedFiles[@]}"; do
                    ((currentFile++))
                    relativePath="${file#$inputDir/}"
                    relativePath="${inputDirName}/${relativePath}"
                    absolutePath="$(realpath "$file")"
                    filename="$(basename "$file")"
                    echo "    <File>"
                    echo "      <Filename>$filename</Filename>"
                    if [[ "$showPaths" == true ]]; then
                        echo "      <RelativePath>\"$relativePath\"</RelativePath>"
                        echo "      <AbsolutePath>\"$absolutePath\"</AbsolutePath>"
                    fi
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

            echo "</concat${inputDirName}>"
        } > "$outputFilePath"
        else
        {
            if [[ "$showDirList" == true ]]; then
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
                            matchedDirMap[$dir]="${matchedDirMap[$dir]}, \"$base\""
                        else
                            matchedDirMap[$dir]="\"$base\""
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
                done | sort -V
                echo "================================================================================"
                echo ""
            fi

            echo "--------------------------------------------------------------------------------"
            echo "# File Contents"
            echo "********************************************************************************"
            totalFiles=${#matchedFiles[@]}
            if [[ $totalFiles -gt 0 ]]; then
                currentFile=0
                for file in "${matchedFiles[@]}"; do
                    ((currentFile++))
                    relativePath="${file#$inputDir/}"
                    relativePath="$(basename "$fullInputDir")/${relativePath}"
                    absolutePath="$(realpath "$file")"
                    filename="$(basename "$file")"
                    echo ""
                    echo "--------------------------------------------------------------------------------"
                    echo "# Filename: \"$filename\""
                    if [[ "$showPaths" == true ]]; then
                        echo "# Relative to Input Dir: \"$relativePath\""
                        echo "# Absolute Path: \"$absolutePath\""
                    fi
                    echo "********************************************************************************"
                    if [[ -r "$file" ]]; then
                        cat "$file"
                        echo ""
                        echo "# EOF: \"$file\""
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
    fi

    # -------------------------------------------------------------------------
    # Final Status Message and Cleanup
    # -------------------------------------------------------------------------
    if [[ "$verbose" == true ]]; then
        echo "All files have been concatenated into \"$outputFilePath\"."
    fi

    if [[ "$debug" == true ]]; then
        set +x  # Disable debug mode.
    fi

    return 0
}
