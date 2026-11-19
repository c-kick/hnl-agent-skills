#!/usr/bin/env bash
# agent-skills — bash helpers
# Source this file from ~/.bashrc or ~/.zshrc:
#   . "$HOME/.config/hnl-agent-skills/agent-skills.sh"
# Works in bash and zsh.

# In zsh, each command starts by switching (for that function only) to the
# bash behaviour the code below relies on: word splitting, unmatched globs
# left as-is, 0-based arrays and BASH_REMATCH. In bash this is empty.
if [ -n "${ZSH_VERSION:-}" ]; then
    _SKILL_SHELL_COMPAT='emulate -L zsh; setopt sh_word_split no_nomatch ksh_arrays bash_rematch typeset_silent'
else
    _SKILL_SHELL_COMPAT=''
fi

# ${(%):-%x} is the zsh spelling of "the file being sourced".
_agent_skills_home="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
if [ -z "${AGENT_SKILLS:-}" ]; then
    AGENT_SKILLS="${CLAUDE_SKILLS:-$_agent_skills_home}"
fi
CLAUDE_SKILLS="${CLAUDE_SKILLS:-$AGENT_SKILLS}"
AGENT_SKILLS_TARGETS="${AGENT_SKILLS_TARGETS:-.claude/skills .codex/skills}"
unset _agent_skills_home

_skill_managed_target() {
    local target="$1"
    case "$target" in
        "$AGENT_SKILLS"/*|"$AGENT_SKILLS") return 0 ;;
        "$CLAUDE_SKILLS"/*|"$CLAUDE_SKILLS") return 0 ;;
        *) return 1 ;;
    esac
}

_skill_target_dirs() {
    # tr instead of unquoted expansion: zsh does not split variables on spaces
    echo "$AGENT_SKILLS_TARGETS" | tr -s ' ' '\n' | grep .
}

_skill_target_label() {
    local target="$1"
    case "$target" in
        .claude/skills|*/.claude/skills) echo "claude" ;;
        .codex/skills|*/.codex/skills) echo "codex" ;;
        *) echo "$target" ;;
    esac
}

skill-ls() {
    eval "$_SKILL_SHELL_COMPAT"
    local skills_dir
    for d in "$AGENT_SKILLS"/*/; do
		[ -d "$d" ] || continue
		name=$(basename "$d")
		[[ "$name" == .* ]] && continue  # skip hidden directories
        local installed=0
        local total=0
        local installed_labels=()
        local missing_labels=()
        for skills_dir in $(_skill_target_dirs); do
            total=$((total + 1))
            if [ -d "$skills_dir/$name" ] || [ -L "$skills_dir/$name" ]; then
                installed=$((installed + 1))
                installed_labels+=("$(_skill_target_label "$skills_dir")")
            else
                missing_labels+=("$(_skill_target_label "$skills_dir")")
            fi
        done
        local installed_text missing_text
        installed_text=$(IFS=,; echo "${installed_labels[*]}")
        missing_text=$(IFS=,; echo "${missing_labels[*]}")
        if [ "$installed" -eq "$total" ] && [ "$total" -gt 0 ]; then
            printf "\e[32m%s [installed: %s]\e[0m\n" "$name" "$installed_text"
        elif [ "$installed" -gt 0 ]; then
            printf "\e[33m%s [partial: %s; missing: %s]\e[0m\n" "$name" "$installed_text" "$missing_text"
        else
            echo "$name"
        fi
    done
}

skill-add() {
    eval "$_SKILL_SHELL_COMPAT"
    if [ $# -eq 0 ]; then
        echo "Usage: skill-add <skill> [skill...]"
        return 1
    fi
    local skills_dir
    for skills_dir in $(_skill_target_dirs); do
        mkdir -p "$skills_dir"
    done
    for s in "$@"; do
        local src="$AGENT_SKILLS/$s"
        if [ ! -d "$src" ]; then
            echo "NOT_FOUND: $s"
            continue
        fi
        for skills_dir in $(_skill_target_dirs); do
            local dst="$skills_dir/$s"
            if [ -e "$dst" ] || [ -L "$dst" ]; then
                if [ -L "$dst" ]; then
                    local target
                    target=$(readlink "$dst")
                    if _skill_managed_target "$target"; then
                        echo "ALREADY_INSTALLED: $s ($skills_dir)"
                        continue
                    fi
                    echo "EXISTS: $s ($skills_dir; not managed by agent-skills, skipping)"
                    continue
                fi
                echo "EXISTS: $s ($skills_dir; not managed by agent-skills, skipping)"
                continue
            else
                ln -sfn "$src" "$dst"
                echo "OK: $s ($skills_dir)"
            fi
        done
    done
}

skill-add-all() {
    eval "$_SKILL_SHELL_COMPAT"
    for d in "$AGENT_SKILLS"/*/; do
        [ -d "$d" ] || continue
        skill-add "$(basename "$d")"
    done
}

skill-remove() {
    eval "$_SKILL_SHELL_COMPAT"
    if [ $# -eq 0 ]; then
        echo "Usage: skill-remove <skill> [skill...]"
        return 1
    fi
    for s in "$@"; do
        local skills_dir
        for skills_dir in $(_skill_target_dirs); do
            local dst="$skills_dir/$s"
            if [ -e "$dst" ] || [ -L "$dst" ]; then
                rm -f "$dst"
                echo "REMOVED: $s ($skills_dir)"
            else
                echo "NOT FOUND: $s ($skills_dir)"
            fi
        done
    done
}

_load_bundles() {
    eval "$_SKILL_SHELL_COMPAT"
    local conf="$AGENT_SKILLS/bundles.conf"
    if [ ! -f "$conf" ]; then
        echo "ERROR: bundles.conf not found in $AGENT_SKILLS" >&2
        return 1
    fi

    _BUNDLE_NAMES=()

    # patterns live in variables: bash and zsh parse inline regexes differently
    local re_comment='^[[:space:]]*#'
    local re_section='^\[([^]]+)\]$'
    local re_extends='^extends=(.+)$'

    local current=""
    while IFS= read -r line || [ -n "$line" ]; do
        # strip carriage return
        line="${line%$'\r'}"
        # skip comments and empty lines
        [[ "$line" =~ $re_comment ]] && continue
        [[ -z "${line// /}" ]] && continue

        # section header
        if [[ "$line" =~ $re_section ]]; then
            current="${BASH_REMATCH[1]}"
            _BUNDLE_NAMES+=("$current")
            eval "_BUNDLE_SKILLS_${current}=''"
            eval "_BUNDLE_EXTENDS_${current}=''"
            continue
        fi

        [ -z "$current" ] && continue

        # extends directive
        if [[ "$line" =~ $re_extends ]]; then
            eval "_BUNDLE_EXTENDS_${current}='${BASH_REMATCH[1]}'"
            continue
        fi

        # skill name — append with newline separator
        local current_skills
        eval "current_skills=\"\$_BUNDLE_SKILLS_${current}\""
        if [ -n "$current_skills" ]; then
            eval "_BUNDLE_SKILLS_${current}=\"\${current_skills}
${line}\""
        else
            eval "_BUNDLE_SKILLS_${current}=\"${line}\""
        fi
    done < "$conf"
}

_resolve_bundle() {
    eval "$_SKILL_SHELL_COMPAT"
    local name="$1"
    shift
    # remaining args are the visiting stack
    local visiting=("$@")

    # circular dependency check
    for v in "${visiting[@]}"; do
        if [ "$v" = "$name" ]; then
            echo "ERROR: Circular extends detected at bundle '$name'" >&2
            return 1
        fi
    done

    # existence check
    local found=0
    for b in "${_BUNDLE_NAMES[@]}"; do
        if [ "$b" = "$name" ]; then
            found=1
            break
        fi
    done
    if [ "$found" -eq 0 ]; then
        echo "ERROR: Bundle '$name' not found" >&2
        return 1
    fi

    visiting+=("$name")

    # resolve parents
    local extends_val
    eval "extends_val=\"\$_BUNDLE_EXTENDS_${name}\""
    if [ -n "$extends_val" ]; then
        local parent
        for parent in $(echo "$extends_val" | tr ',' '\n' | tr -d ' ' | grep .); do
            _resolve_bundle "$parent" "${visiting[@]}" || return 1
        done
    fi

    # add own skills (deduplicated)
    local skills_val
    eval "skills_val=\"\$_BUNDLE_SKILLS_${name}\""
    if [ -n "$skills_val" ]; then
        while IFS= read -r skill; do
            skill="${skill// /}"
            [ -z "$skill" ] && continue
            # deduplicate
            local dup=0
            for existing in "${_RESOLVED_SKILLS[@]}"; do
                if [ "$existing" = "$skill" ]; then
                    dup=1
                    break
                fi
            done
            if [ "$dup" -eq 0 ]; then
                _RESOLVED_SKILLS+=("$skill")
            fi
        done <<< "$skills_val"
    fi
}

skill-ls-bundles() {
    eval "$_SKILL_SHELL_COMPAT"
    local filter="${1:-}"
    _load_bundles || return 1

    local names=()
    if [ -n "$filter" ]; then
        local found=0
        for b in "${_BUNDLE_NAMES[@]}"; do
            if [ "$b" = "$filter" ]; then
                found=1
                break
            fi
        done
        if [ "$found" -eq 0 ]; then
            echo "ERROR: Bundle '$filter' not found"
            return 1
        fi
        names=("$filter")
    else
        names=("${_BUNDLE_NAMES[@]}")
    fi

    for name in "${names[@]}"; do
        _RESOLVED_SKILLS=()
        _resolve_bundle "$name" || return 1
        echo ""
        echo "[$name]"
        for skill in "${_RESOLVED_SKILLS[@]}"; do
            echo "  $skill"
        done
    done
}

skill-bundle-add() {
    eval "$_SKILL_SHELL_COMPAT"
    local bundle="${1:-}"
    if [ -z "$bundle" ]; then
        echo "Usage: skill-bundle-add <bundle>"
        echo "Run 'skill-ls-bundles' to see available bundles"
        return 1
    fi
    _load_bundles || return 1
    _RESOLVED_SKILLS=()
    _resolve_bundle "$bundle" || return 1
    echo "Installing bundle '$bundle' (${#_RESOLVED_SKILLS[@]} skills):"
    for skill in "${_RESOLVED_SKILLS[@]}"; do
        skill-add "$skill"
    done
}

skill-bundle-remove() {
    eval "$_SKILL_SHELL_COMPAT"
    local bundle="${1:-}"
    if [ -z "$bundle" ]; then
        echo "Usage: skill-bundle-remove <bundle>"
        echo "Run 'skill-ls-bundles' to see available bundles"
        return 1
    fi
    _load_bundles || return 1
    _RESOLVED_SKILLS=()
    _resolve_bundle "$bundle" || return 1
    echo "Removing bundle '$bundle' (${#_RESOLVED_SKILLS[@]} skills):"
    for skill in "${_RESOLVED_SKILLS[@]}"; do
        skill-remove "$skill"
    done
}

skill-ls-installed() {
    eval "$_SKILL_SHELL_COMPAT"
    local count=0
    local skills_dir
    for skills_dir in $(_skill_target_dirs); do
        [ -d "$skills_dir" ] || continue
        echo "[$skills_dir]"
        for item in "$skills_dir"/*/; do
            [ -d "$item" ] || continue
            count=1
            local name
            name=$(basename "$item")
            if [ -L "$item" ] || [ -L "${item%/}" ]; then
                local target
                target=$(readlink "${item%/}")
                if _skill_managed_target "$target"; then
                    echo "LINKED:   $name -> $target"
                else
                    echo "EXTERNAL: $name -> $target"
                fi
            else
                echo "EXTERNAL: $name (local directory)"
            fi
        done
    done
    if [ "$count" -eq 0 ]; then
        echo "No skills installed in current project."
    fi
}

skill-update() {
    eval "$_SKILL_SHELL_COMPAT"
    echo "Updating agent-skills..."
    (cd "$AGENT_SKILLS" && git pull && git submodule update --remote)
}
