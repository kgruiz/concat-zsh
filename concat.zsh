# concat.zsh

# Function: concat
# Usage: concat [OPTIONS] [FILE...]
#
# Combines the contents of specified files or files within specified directories
# into a single output file. Supports filtering by extension, include/exclude
# patterns, recursive/non-recursive search, and handling hidden files.
# Generates XML (default) or plain-text output, optionally including a directory tree.

concat() {
    setopt extendedglob LOCAL_OPTIONS

    # -------------------------------------------------------------------------
    # Realpath fallback for macOS
    # -------------------------------------------------------------------------
    if ! command -v realpath >/dev/null; then
      realpath() {
        local target=$1
        if [[ -d $target ]]; then
          (cd "$target" && pwd)
        else
          # Ensure the directory part exists before trying to cd into it
          local dirpart="${target%/*}"
          [[ -z "$dirpart" ]] && dirpart="." # Handle files in current dir
          if [[ -d "$dirpart" ]]; then
              (cd "$dirpart" && printf "%s/%s" "$(pwd)" "${target##*/}")
          else
              # Fallback if directory doesn't exist or target is complex
              echo "$target" # Return original path as best effort
          fi
        fi
      }
    fi

    # -------------------------------------------------------------------------
    # Help Display
    # -------------------------------------------------------------------------
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            cat <<EOF
Usage: concat [OPTIONS] [FILE...]

Concatenates files matching specified criteria into a single output file.

Positional Arguments:
  [FILE...]
      One or more files, directories, or glob patterns to process.
      If omitted, the current directory (".") is used.

Options:
  -o, --output <file>
      Output file name (default: "_concat-output.xml" or ".txt").

  -r, --recursive
      Search directories recursively (default).

  -n, --no-recursive
      Do not search directories recursively.

  -t, --text
      Output in plain text format instead of the default XML.

  -x, --ext <ext>
      Only include files with this extension (e.g., "py", "txt").
      Can be specified multiple times. Case-insensitive. Excludes the dot.

  -I, --include <glob>
      Only include files whose full path matches this glob pattern.
      Can be specified multiple times. Globs apply after extension filtering.

  -e, -E, --exclude <glob>
      Exclude files whose full path matches this glob pattern.
      Can be specified multiple times. Exclusions apply last.

  -T, --tree
      Include a directory tree representation (of the current directory)
      in the output.

  -H, --hidden
      Include hidden files and files in hidden directories (those starting
      with '.'). By default, they are skipped unless explicitly listed
      as input or matched by an --include glob starting with '.'.

  -P, --no-purge-pycache
      Do not delete __pycache__ directories and .pyc files found within
      the current working directory.

  -v, --verbose
      Show detailed output, including matched and skipped files.

  -d, --debug
      Enable debug mode with execution tracing.

  -l, --no-dir-list
      Do not include a directory-grouped list of matched files.

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
    local outputFile=""
    local userOutputProvided=false
    local -a inputs includeGlobs excludeGlobs exts
    local recursive=true
    local includeHidden=false
    local format="xml" # xml or text
    local showTree=false
    local showDirList=true
    local delPyCache=true
    local verbose=false
    local debug=false

    # -------------------------------------------------------------------------
    # Pre-process arguments: Split flags, Expand Globs
    # -------------------------------------------------------------------------
    local -a initial_args=("${@}") # Copy original args
    local -a expanded_flags=()
    # Split grouped short flags (only those without arguments)
    for arg in "${initial_args[@]}"; do
      if [[ "$arg" =~ ^-[rntvdhTHP]+$ && ${#arg} -gt 2 ]]; then # Include uppercase T, H, P in grouped flags
        for ((i=1; i<${#arg}; i++)); do
          expanded_flags+=("-${arg:i:1}")
        done
      else
        expanded_flags+=("$arg")
      fi
    done

    # Expand only positional inputs (not flag values)
    local -a parsed_args=()
    setopt nullglob
    while (( ${#expanded_flags[@]} )); do
      arg="${expanded_flags[1]}"
      # Use shift on the array itself, not the positional parameters yet
      expanded_flags=("${expanded_flags[@]:1}") # Equivalent to shift expanded_flags

      case "$arg" in
        -o|-x|-I|-e|-E)
          # preserve flag and its next token as literal
          if (( ${#expanded_flags[@]} == 0 )); then
              echo "Error: Option $arg requires an argument." >&2; return 1
          fi
          parsed_args+=("$arg" "${expanded_flags[1]}")
          expanded_flags=("${expanded_flags[@]:1}") # Shift again for the argument
          ;;
        --output|--ext|--include|--exclude)
          if (( ${#expanded_flags[@]} == 0 )); then
              echo "Error: Option $arg requires an argument." >&2; return 1
          fi
          parsed_args+=("$arg" "${expanded_flags[1]}")
          expanded_flags=("${expanded_flags[@]:1}") # Shift again for the argument
          ;;
        -*)
          # Handle other flags (like -r, -n, -t, -H, -P, -v, -d, -h, -T)
          parsed_args+=("$arg")
          ;;
        *)
          # only now expand globs for real inputs
            if [[ "$arg" == *[\*\?\[]* ]]; then
            # expand the glob in $arg into an array
            local expanded_globs=("${(@)~arg}")
            # only add if there are matches
            if (( ${#expanded_globs[@]} > 0 )); then
                parsed_args+=( "${expanded_globs[@]}" )
            else
                echo "Warning: Input glob pattern matched no files: $arg" >&2
            fi
            else
                parsed_args+=( "$arg" )
            fi
          ;;
      esac
    done
    setopt no_nullglob
    set -- "${parsed_args[@]}" # Update positional parameters for parsing


    # -------------------------------------------------------------------------
    # Parse Command-Line Options
    # -------------------------------------------------------------------------
    while (( $# )); do
        case "$1" in
            -o|--output)
                if [[ -n "$2" && "$2" != --* ]]; then
                    outputFile="$2"
                    userOutputProvided=true
                    shift 2
                else
                    # This case should ideally be caught during pre-processing, but double-check
                    echo "Error: --output requires a filename argument." >&2
                    return 1
                fi
            ;;
            -r|--recursive)
                recursive=true
                shift
            ;;
            -n|--no-recursive)
                recursive=false
                shift
            ;;
            -t|--text)
                format="text"
                shift
            ;;
            -x|--ext)
                if [[ -n "$2" && "$2" != --* ]]; then
                    # Store extension without leading dot, lowercase for case-insensitivity
                    exts+=("${(L)2#.}")
                    shift 2
                else
                     echo "Error: --ext requires an extension argument." >&2
                     return 1
                fi
            ;;
            -I|--include)
                 if [[ -n "$2" && "$2" != --* ]]; then
                    includeGlobs+=("$2")
                    shift 2
                else
                     echo "Error: --include requires a glob pattern argument." >&2
                     return 1
                fi
            ;;
            -e|-E|--exclude)
                 if [[ -n "$2" && "$2" != --* ]]; then
                    # If the user gave just a filename (no slash or wildcard),
                    # match it anywhere in the tree.
                    if [[ "$2" != */* && "$2" != *[\*\?\[]* ]]; then
                        excludeGlobs+=("**/$2")
                    else
                        excludeGlobs+=("$2")
                    fi
                    shift 2
                else
                     echo "Error: --exclude requires a glob pattern argument." >&2
                     return 1
                fi
            ;;
            -T|--tree)
                showTree=true
                shift
            ;;
            -H|--hidden)
                includeHidden=true
                shift
            ;;
            -P|--no-purge-pycache)
                delPyCache=false
                shift
            ;;
            -v|--verbose)
                verbose=true
                shift
            ;;
            -d|--debug)
                debug=true
                set -x # Enable shell debug mode.
                trap 'set +x' RETURN
                shift
            ;;
            -l|--no-dir-list)
                showDirList=false
                shift
            ;;
            -h|--help) # Already handled, but catch here too
                shift
                # Help text displayed at the top, just exit
                return 0
            ;;
            -?*)                           # any unrecognised short option
                echo "Unknown option: $1" >&2
                echo "Usage: concat [OPTIONS] [FILE...]" >&2
                return 1
            ;;
            --*)                           # any unrecognised long option
                echo "Unknown option: $1" >&2
                echo "Usage: concat [OPTIONS] [FILE...]" >&2
                return 1
            ;;
            *)
                # Assume anything else is an input file/dir (already expanded)
                inputs+=("$1")
                shift
            ;;
        esac
    done

    # -------------------------------------------------------------------------
    # Set Default Input if None Provided
    # -------------------------------------------------------------------------
    if [[ ${#inputs[@]} -eq 0 ]]; then
        # If after processing args, inputs is still empty, default to "."
        # This handles the case where user provides only options, e.g., `concat -x txt`
        inputs=(".")
    fi

    # Track the (only) input directory for later relative-path mapping
    local inputDir="${inputs[1]}"

    # -------------------------------------------------------------------------
    # Determine Output File Path
    # -------------------------------------------------------------------------
    local outputDir="." # Default output dir is current dir
    local outputBaseName=""
    if [[ "$userOutputProvided" == true ]]; then
        outputDir="$(dirname "$outputFile")"
        outputBaseName="$(basename "$outputFile")"
        # Ensure output directory exists
        mkdir -p "$outputDir" || {
            echo "Error: Cannot create output directory \"$outputDir\"." >&2
            return 1
        }
    else
        # Default output filename based on extension filters, user args, or project name
        if [[ ${#exts[@]} -gt 0 ]]; then
            # Extension-based defaults
            if [[ ${#exts[@]} -eq 1 ]]; then
                ext="${exts[1]}"
                if [[ "$ext" == "txt" ]]; then
                    outputBaseName="_concat-txt.txt"
                else
                    outputBaseName="_concat-${ext}.xml"
                fi
            else
                outputBaseName="_concat-output.xml"
            fi
        elif [[ ${#originalArgs[@]} -eq 0 ]]; then
            projectBase="$(basename "$(realpath ".")" | tr -d '\n\r')"
            if [[ -n "$projectBase" ]]; then
                outputBaseName="_concat-${projectBase}.txt"
            else
                outputBaseName="_concat-output.txt"
            fi
        elif [[ ${#inputs[@]} -eq 1 && -d "${inputs[1]}" ]]; then
            singleDirBase="$(basename "$(realpath "${inputs[1]}")" | tr -d '\n\r')"
            outputBaseName="_concat-${singleDirBase}.txt"
        else
            outputBaseName="_concat-output.txt"
        fi
        outputFile="$outputDir/$outputBaseName"

    fi

    # Ensure the final output file has the correct extension based on format
    local requiredExt=".$format"
    if [[ "$outputBaseName" != *"$requiredExt" ]]; then
        outputBaseName="${outputBaseName%.*}${requiredExt}" # Replace or append extension
        outputFile="$outputDir/$outputBaseName"
    fi

    # Normalize outputFile path manually (works on macOS)
    local outputFilePath
    if [ -n "$outputFile" ]; then
        outputDir=$(dirname "$outputFile")
        outputBase=$(basename "$outputFile")

        if cd "$outputDir" 2>/dev/null; then
            outputFilePath="$(pwd)/$outputBase"
            cd - >/dev/null
        else
            echo "Error: Invalid output path: $outputFile" >&2
            exit 1
        fi
    else
        echo "Error: No output file specified." >&2
        exit 1
    fi

    # ---------------------------------------------------------------------
    # Path normalisation & directory assurance
    # ---------------------------------------------------------------------
    # Remove any embedded newlines or carriage returns
    outputFilePath="${outputFilePath//$'\n'/}"
    outputFilePath="${outputFilePath//$'\r'/}"
    # Collapse “/./” sequences and repeated slashes
    outputFilePath="${outputFilePath//\/.\//\/}"
    while [[ "$outputFilePath" == *//* ]]; do
        outputFilePath="${outputFilePath//\/\//\/}"
    done
    # Ensure destination directory exists
    mkdir -p "$(dirname "$outputFilePath")" || {
        echo "Error: Cannot create output directory \"$(dirname "$outputFilePath")\"." >&2
        return 1
    }


    # Remove existing output file
    if [[ -e "$outputFilePath" ]]; then
        [[ "$verbose" == true ]] && echo "Removing existing output file: \"$outputFilePath\""
        rm "$outputFilePath" || { echo "Error: Cannot remove existing output file \"$outputFilePath\"." >&2; return 1; }
    fi


    # -------------------------------------------------------------------------
    # Verbose: Output Configuration Summary
    # -------------------------------------------------------------------------
    if [[ "$verbose" == true ]]; then
        echo "----------------------------------------"
        echo "Configuration:"
        echo "Inputs: ${inputs[@]}"
        echo "Output File: \"$outputFilePath\""
        echo "Format: $format"
        echo "Recursive: $recursive"
        echo "Include Hidden: $includeHidden"
        echo "Show Tree: $showTree"
        echo "Show Dir List: $showDirList"
        echo "Purge Pycache (in CWD): $delPyCache"
        if [[ ${#exts[@]} -gt 0 ]]; then
            echo "Include Extensions: ${exts[@]}"
        else
            echo "Include Extensions: All"
        fi
        if [[ ${#includeGlobs[@]} -gt 0 ]]; then
            echo "Include Globs: ${includeGlobs[@]}"
        else
            echo "Include Globs: All"
        fi
         if [[ ${#excludeGlobs[@]} -gt 0 ]]; then
            echo "Exclude Globs: ${excludeGlobs[@]}"
        else
            echo "Exclude Globs: None"
        fi
        echo "Debug Mode: $debug"
        echo "----------------------------------------"
    fi

    # -------------------------------------------------------------------------
    # Delete Python Cache Files (.pyc and __pycache__) in CWD
    # -------------------------------------------------------------------------
    if [[ "$delPyCache" == true ]]; then
        [[ "$verbose" == true ]] && echo "Searching for and removing __pycache__ directories and .pyc files in ."
        # Use find in current directory (.)
        find . -type d -name "__pycache__" -print0 | xargs -0 --no-run-if-empty rm -rf
        find . -type f -name "*.pyc" -print0 | xargs -0 --no-run-if-empty rm -f
    fi

    # -------------------------------------------------------------------------
    # Collect Candidate Files
    # -------------------------------------------------------------------------
    local -a raw_candidates candidates matchedFiles
    local item file file_path file_ext_lower file_basename is_hidden explicit_or_include_hidden

    [[ "$verbose" == true ]] && echo "Collecting candidate files..."
    for item in "${inputs[@]}"; do
        # Check if item exists before processing
        if [[ ! -e "$item" ]]; then
            # Don't warn again if we already warned during glob expansion
            # Check if the original args contained this exact pattern
            local was_glob_pattern=false
            for orig_arg in "${originalArgs[@]}"; do
                if [[ "$orig_arg" == "$item" && "$orig_arg" == *[\*\?\[]* ]]; then
                    was_glob_pattern=true
                    break
                fi
            done
            if ! $was_glob_pattern; then
                 echo "Warning: Input item not found, skipping: \"$item\"" >&2
            fi
            continue
        fi

        # Use realpath to resolve symlinks and get absolute paths early
        local resolved_item="$(realpath "$item")" || { echo "Warning: Cannot resolve path for input item, skipping: \"$item\"" >&2; continue; }


        if [[ -f "$resolved_item" ]]; then
            # If it's a file, add it directly
             raw_candidates+=("$resolved_item")
             [[ "$verbose" == true ]] && echo "Input item is file: \"$resolved_item\""
        elif [[ -d "$resolved_item" ]]; then
            # If it's a directory, use find
            [[ "$verbose" == true ]] && echo "Input item is directory, searching: \"$resolved_item\" (Recursive: $recursive)"
            local -a find_cmd=("find" "$resolved_item")
            if [[ "$recursive" == false ]]; then
                find_cmd+=("-maxdepth" "1")
            fi

            # Add pruning logic for hidden files/dirs if -H is not set
            if [[ "$includeHidden" == false ]]; then
                # Prune any hidden file or directory at any depth under $resolved_item
                # Ensure we don't prune the starting directory itself if it's hidden but explicitly given
                if [[ "$resolved_item" == */.* && "$item" == "$resolved_item" ]]; then
                     # If the starting point is hidden and explicitly given, find files within it
                     # but still prune deeper hidden dirs/files unless -H is set
                     find_cmd+=( '(' \
                                 -path "${resolved_item}/.*/*" -o -name '.*' \
                             ')' '-prune' '-o' '-type' 'f' '-print' )
                else
                     # Standard pruning: prune anything starting with . inside the resolved_item path
                     find_cmd+=( '(' \
                                 -path "${resolved_item}/.*" \
                             ')' '-prune' '-o' '-type' 'f' '-print' )
                fi
            else
                # If including hidden, just find all files
                find_cmd+=( '-type' 'f' '-print' )
            fi

            # Use zsh array assignment with process substitution
            local -a found_files
            # Ensure find command doesn't fail silently if dir is unreadable
            found_files=("${(@f)$( "${find_cmd[@]}" 2>/dev/null )}")
            if [[ $? -ne 0 && "$verbose" == true ]]; then
                 echo "Warning: 'find' command may have encountered errors in \"$resolved_item\"." >&2
            fi
            raw_candidates+=("${found_files[@]}")
            [[ "$verbose" == true ]] && echo "Found ${#found_files[@]} files in \"$resolved_item\""
        else
             echo "Warning: Input item is neither a file nor a directory, skipping: \"$item\" (Resolved: \"$resolved_item\")" >&2
        fi
    done

    # Make candidate list unique and sort
    candidates=("${(@u)raw_candidates}")
    candidates=("${(@f)$(printf '%s\n' "${candidates[@]}" | sort -V)}")
    [[ "$verbose" == true ]] && echo "Total unique candidate files found: ${#candidates[@]}"

    # -------------------------------------------------------------------------
    # Filter Files
    # -------------------------------------------------------------------------
    [[ "$verbose" == true ]] && echo "Filtering candidate files..."
    for file_path in "${candidates[@]}"; do
        # Skip the output file itself if it happens to be collected
        if [[ "$file_path" == "$outputFilePath" ]]; then
             [[ "$verbose" == true ]] && echo "Skipped file: \"$file_path\" (is the output file)"
            continue
        fi

        file_basename="$(basename "$file_path")"
        is_hidden=false
        explicit_or_include_hidden=false

        # Check if hidden (basename starts with .)
        # This handles explicitly listed hidden files or top-level hidden files found by find (if -H was true).
        if [[ "$file_basename" == .* ]]; then
            is_hidden=true
        fi
        # Also check if any directory component is hidden (e.g., /path/.hidden/file)
        # This catches cases potentially missed if find started above the hidden dir but -H was true.
        if ! $is_hidden && [[ "$file_path" == */.*/* ]]; then
             is_hidden=true
        fi

        # Check if the hidden file was explicitly provided or matches an include glob starting with '.'
        if $is_hidden; then
            # Was it explicitly listed in inputs? Resolve input items again for comparison.
            for item in "${inputs[@]}"; do
                 if [[ -e "$item" ]]; then # Check existence before realpath
                     resolved_item="$(realpath "$item" 2>/dev/null)"
                     if [[ "$resolved_item" == "$file_path" ]]; then
                         explicit_or_include_hidden=true
                         break
                     fi
                 fi
            done
            # Does it match an include glob starting with '.'?
            if ! $explicit_or_include_hidden && [[ ${#includeGlobs[@]} -gt 0 ]]; then
                 for pattern in "${includeGlobs[@]}"; do
                     # Check if glob pattern itself implies hidden (starts with . or contains /.)
                     if [[ "$pattern" == .* || "$pattern" == */.* || "$pattern" == *'/.'* ]]; then
                         # Use zsh globbing ($~)
                         if [[ ${~file_path} == ${~pattern} ]]; then
                             explicit_or_include_hidden=true
                             break
                         fi
                     fi
                 done
            fi
        fi

        # Apply hidden filter: Skip if hidden AND includeHidden is false AND it wasn't explicitly included
        if $is_hidden && [[ "$includeHidden" == false ]] && ! $explicit_or_include_hidden; then
            [[ "$verbose" == true ]] && echo "Skipped file: \"$file_path\" (hidden and not explicitly included)"
            continue
        fi

        # Apply extension filter (-x)
        if [[ ${#exts[@]} -gt 0 ]]; then
            # Get extension, remove dot, lowercase
            file_ext_lower="${(L)file_path:e}"
            local ext_match=false
            for ext in "${exts[@]}"; do
                if [[ "$file_ext_lower" == "$ext" ]]; then
                    ext_match=true
                    break
                fi
            done
            if [[ "$ext_match" == false ]]; then
                [[ "$verbose" == true ]] && echo "Skipped file: \"$file_path\" (extension mismatch: '${file_path:e}' not in {${exts[*]}})"
                continue
            fi
        fi

        # Apply include filter (-I)
        if [[ ${#includeGlobs[@]} -gt 0 ]]; then
            local include_match=false
            for pattern in "${includeGlobs[@]}"; do
                # Match pattern against full path using zsh globbing
                if [[ ${~file_path} == ${~pattern} ]]; then
                    include_match=true
                    break
                fi
            done
            if [[ "$include_match" == false ]]; then
                 [[ "$verbose" == true ]] && echo "Skipped file: \"$file_path\" (include glob mismatch)"
                continue
            fi
        fi

        # Apply exclude filter (-E)
        if [[ ${#excludeGlobs[@]} -gt 0 ]]; then
            local exclude_match=false
            for pattern in "${excludeGlobs[@]}"; do
                # Match against full path *or* basename
                # Use zsh globbing ($~) for pattern matching
                if [[ ${~file_path} == ${~pattern} || "$file_basename" == ${~pattern} ]]; then
                    exclude_match=true
                    break
                fi
            done
            if [[ "$exclude_match" == true ]]; then
                 [[ "$verbose" == true ]] && echo "Skipped file: \"$file_path\" (exclude glob match: '$pattern')"
                continue
            fi
        fi

        # Skip non-text files
        if ! grep -Iq . "$file_path"; then
          [[ "$verbose" == true ]] && echo "Skipped file: \"$file_path\" (not text)"
          continue
        fi
        # If we reach here, the file is matched
        matchedFiles+=("$file_path")
        [[ "$verbose" == true ]] && echo "Matched file: \"$file_path\""

    done

    [[ "$verbose" == true ]] && echo "Total matched files: ${#matchedFiles[@]}"

    # -------------------------------------------------------------------------
    # Build Directory Tree Representation (if requested)
    # -------------------------------------------------------------------------
    local fullTree=""
    if [[ "$showTree" == true ]]; then
        if command -v tree >/dev/null 2>&1; then
             [[ "$verbose" == true ]] && echo "Generating directory tree for current directory (.)"
            local tree_opts=()
            [[ "$format" == "xml" ]] && tree_opts+=("-X") # XML output for tree
            # Tell tree to ignore hidden files/dirs if -H was not passed to concat
            # Use -a to include hidden, then -I to filter if needed.
            # tree_opts+=("-a") # Always include hidden for tree's perspective initially
            # [[ "$includeHidden" == false ]] && tree_opts+=("-I" ".*") # Then filter if needed
            # Simpler: Use -a only if includeHidden is true
            [[ "$includeHidden" == true ]] && tree_opts+=("-a")

            # Run tree on current directory, capture output, remove first line ('.')
            fullTree="$(tree "${tree_opts[@]}" . | sed '1d')" || {
                 echo "Warning: 'tree' command failed." >&2
                 fullTree="Error generating tree."
            }
        else
            echo "Warning: 'tree' command not found, cannot generate tree." >&2
            fullTree="Tree command not available."
        fi
    fi

    # -------------------------------------------------------------------------
    # Final Output Generation
    # -------------------------------------------------------------------------
    [[ "$verbose" == true ]] && echo "Generating output file: \"$outputFilePath\" (Format: $format)"

    # Use a subshell for redirection to avoid issues with file descriptors
    (
    if [[ "$format" == "xml" ]]; then
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo "<concatenation>" # Generic root element

        # Add Tree if requested
        if [[ "$showTree" == true ]]; then
            echo "  <directoryTree context=\".\">" # Indicate context is CWD
            # Check if tree output itself is XML (-X flag was used)
            # Simple check for XML structure - might not be perfect
            if [[ "$fullTree" == *"<directory"* || "$fullTree" == *"<file"* ]]; then
                 # If tree output looks like XML, embed it directly
                 # Remove potential <?xml ...?> header from tree output if present
                 echo "${fullTree#<\?xml*?\>}"
            else
                 # If tree output is plain text, wrap in CDATA
                 echo "    <representation><![CDATA["
                 echo "$fullTree"
                 echo "]]></representation>"
            fi
            echo "  </directoryTree>"
        fi

        # ---------------------------------------------------------------------
        # Optional matched-file directory list
        # ---------------------------------------------------------------------
        if [[ "$showDirList" == true ]]; then
            echo "  <matchedFilesDirStructureList>"
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
                echo "    <dirEntry>\"$relativeDir\": [${matchedDirMap[$dir]}]</dirEntry>"
            done | sort -V
            echo "  </matchedFilesDirStructureList>"
        fi

        # Add File Contents
        echo "  <fileContents count=\"${#matchedFiles[@]}\">"
        if [[ ${#matchedFiles[@]} -gt 0 ]]; then
            for file in "${matchedFiles[@]}"; do
                local filename="$(basename "$file")"
                # Use realpath again just to be absolutely sure it's canonical
                local absolutePath
                absolutePath="$(realpath "$file" 2>/dev/null)" || absolutePath="$file" # Fallback if realpath fails
                echo "    <file>"
                echo "      <path>$absolutePath</path>" # Use absolute path
                echo "      <content><![CDATA["
                if [[ -r "$file" ]]; then
                    cat "$file" || echo "Error reading file content for $file"
                else
                    echo "Error: Cannot read file '$file'."
                fi
                echo "]]></content>"
                echo "    </file>"
            done
        else
            echo "    <message>No files matched the criteria.</message>"
        fi
        echo "  </fileContents>"
        echo "</concatenation>"

    else # Plain Text Format
        # Add Tree if requested
        if [[ "$showTree" == true ]]; then
            echo "--------------------------------------------------------------------------------"
            echo "# Directory Tree (from current directory)"
            echo "********************************************************************************"
            echo "." # Show the root context
            echo "$fullTree"
            echo "================================================================================"
            echo ""
        fi

        # Add File Contents
        echo "--------------------------------------------------------------------------------"
        echo "# File Contents (${#matchedFiles[@]} files)"
        echo "********************************************************************************"
        if [[ ${#matchedFiles[@]} -gt 0 ]]; then
            local currentFile=0
            for file in "${matchedFiles[@]}"; do
                ((currentFile++))
                local absolutePath
                absolutePath="$(realpath "$file" 2>/dev/null)" || absolutePath="$file" # Fallback
                echo ""
                echo "--------------------------------------------------------------------------------"
                echo "# File ${currentFile}/${#matchedFiles[@]}: $absolutePath"
                echo "********************************************************************************"
                if [[ -r "$file" ]]; then
                    cat "$file" || echo "Error reading file content for $file"
                    # Add a newline if cat doesn't end with one, for cleaner separation
                    [[ $(tail -c1 "$file" | wc -l) -eq 0 ]] && echo
                    echo ""
                    echo "# EOF: $absolutePath"
                    echo "================================================================================"
                else
                    echo "Error: Cannot read file '$absolutePath'." >&2
                    echo "================================================================================"
                fi
                # Add extra newline between files unless it's the last one
                # if [[ "$file" != "${matchedFiles[-1]}" ]]; then
                #     echo ""
                # fi
            done
        else
            echo "No files matched the criteria."
            echo "================================================================================"
        fi
    fi
    ) > "$outputFilePath" || { echo "Error: Failed to write to output file \"$outputFilePath\"." >&2; return 1; }


    # -------------------------------------------------------------------------
    # Final Status Message and Cleanup
    # -------------------------------------------------------------------------
    if [[ "$verbose" == true ]]; then
        echo "Concatenation complete. Output written to \"$outputFilePath\"."
    fi

    if [[ "$debug" == true ]]; then
        set +x # Disable debug mode.
    fi

    return 0
}