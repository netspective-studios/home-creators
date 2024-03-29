# Show all Git repos in managed Git workspaces home
inspect:
    #!/bin/bash
    set -euo pipefail
    git mgitstatus -d 0

# Show summary of commits across all authors and repos over the past 3 days
@standup:
    git standup -sm 5 -d 3 -a "all"

# Create a new managed Git repo directory using proper structure
repo-init gitURL:
    #!/bin/bash
    set -euo pipefail
    workspaceHome="{{gitURL}}"
    if [ ! -e "$workspaceHome" ]; then
        mkdir -p "$workspaceHome"
        git -C "$workspaceHome" init
        echo "Ready: cd $workspaceHome"
    else
        echo "$workspaceHome exists, unable to initialize new repo"
    fi

# Clone or pull gitURL from a managed git supplier's HTTP endpoint
repo-ensure gitURL context="interactive":
    #!/bin/bash
    set -euo pipefail
    workspaceHome={{gitURL}}
    if [ -d "$workspaceHome" ]; then
        echo "`basename $workspaceHome` found, pulling latest in `realpath --relative-to=. $workspaceHome`"
        git -C "$workspaceHome" pull --quiet 
    else
        mkdir -p `dirname "$workspaceHome"`
        git clone "https://{{gitURL}}" "$workspaceHome" --quiet || (echo "https://{{gitURL}} is not a valid URL"; exit 1)
        if [ -f "$workspaceHome/.envrc" ]; then
            direnv allow "$workspaceHome"
        fi
        echo "`basename $workspaceHome` not found, cloned `realpath --relative-to=. \"$workspaceHome\"`"
    fi
    case "{{context}}" in
        interactive)
            echo "Ready: cd $workspaceHome"
            find "$workspaceHome" -type f -name "*.code-workspace" -printf "   or: just vscws-repos-ensure-ref `realpath --relative-to=. \"$workspaceHome\"`/%P\n"
            ;;

        batch) ;; # nothing special required
        *) echo -n "unknown context: {{context}}" ;;
    esac

# List all *.code-workspace files available
vscws-inspect in=".":
    #!/bin/bash
    set -euo pipefail
    find {{in}} -type f -name "*.code-workspace" -exec realpath --relative-to=. {} \;

# List all *.code-workspace files available and generate code to clone/pull content
vscws-inspect-ensure in=".":
    #!/bin/bash
    set -euo pipefail
    find {{in}} -type f -name "*.code-workspace" -printf "just vscws-repos-ensure-ref %P\n" 

# List all managed Git suppliers (e.g. github.com) referenced in all VS Code *.code-workspace files
vscws-inspect-git-managers in=".":
    #!/bin/bash
    set -euo pipefail
    find {{in}} -type f -name "*.code-workspace" -printf "cat %p | jq -r '.folders[] | .path | split(\"/\")[0]'\n" | sh | sort | uniq

# List all folders for which Git servers are referenced in a single VS Code *.code-workspace file
vscws-inspect-git-managers-single vscws:
    #!/bin/bash
    set -euo pipefail
    cat {{vscws}} | jq -r '.folders[] | .path | split("/")[0]' | sort | uniq

# List file counts for all folders in a VS Code *.code-workspace file
vscws-inspect-path-files-count vscws:
    #!/bin/bash
    set -euo pipefail
    cat {{vscws}} | jq -r '.folders[] | "FC=`find \(.path)/* -type f | wc -l`; echo \"$FC\t\(.path)\""' | sh

# List path sizes for all folders in a VS Code *.code-workspace file
vscws-inspect-path-size vscws:
    #!/bin/bash
    set -euo pipefail
    cat {{vscws}} | jq -r '.folders[] | "du -s \(.path)"' | sh

# Run 'just repo-ensure' on all folders in a VS Code *.code-workspace file
vscws-repos-ensure vscws:
    #!/bin/bash
    set -euo pipefail
    cat {{vscws}} | jq -r '.folders[] | "just repo-ensure \(.path) batch"' | sh
    
# Run 'just repo-ensure' on all folders in a VS Code *.code-workspace file and symlink the file for opening in VSC
vscws-repos-ensure-ref vscws:
    #!/bin/bash
    set -euo pipefail
    just vscws-repos-ensure {{vscws}}
    # create a symlink to the workspaces home which, when opened from VS Code
    # will be able properly access all repos properly
    vscwsRef=`basename {{vscws}}`    
    if [ -L $vscwsRef ]; then
        rm -f $vscwsRef
    fi
    ln -s {{vscws}} $vscwsRef
    echo "Ready: code $vscwsRef"

# Return the relative path to the target of the given *.code-workspace symlink
vscws-ref-target vscws:
    realpath --relative-to=. `readlink -f {{vscws}}`

# Return the relative path to the directory of the target of the given *.code-workspace symlink
vscws-ref-target-dir vscws:
    dirname $(realpath --relative-to=. `readlink -f {{vscws}}`)

# Create a new managed Git repo directory and *.code-workspace symlink
vscws-repo-init-ref gitURL vscws="`basename $workspaceHome`.mgit.code-workspace":
    #!/bin/bash
    set -euo pipefail
    workspaceHome="{{gitURL}}"
    workspaceProjectFile="$workspaceHome/{{vscws}}"
    if [ ! -e "$workspaceHome" ]; then
        mkdir -p "$workspaceHome"
        git -C "$workspaceHome" init
        echo '{ "folders": [{ "path": "{{gitURL}}" } ], "settings": { "git.autofetch": true	} }' | jq > "$workspaceProjectFile"
        if [ -L "{{vscws}}" ]; then
            rm -f "{{vscws}}"
        fi
        ln -s "$workspaceProjectFile" "{{vscws}}"
        echo "Ready: cd $workspaceHome"
        echo "   or: code {{vscws}}"
    else
        echo "$workspaceHome exists, unable to initialize new repo"
    fi