#!/usr/bin/env bash
# scan-tells.sh — heuristic first pass for AI code tells; every hit needs verifying by reading.
# Usage: scan-tells.sh [path] [max-hits-per-category]
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${1:-.}"
max="${2:-15}"
cd "$root" || { echo "cannot cd to $root" >&2; exit 1; }

src_ext='py|js|mjs|cjs|jsx|ts|tsx|php|go|rs|java|kt|cs|rb|sh|bash|swift|c|h|cpp|hpp|scss|css|vue|svelte'

# Tracked files if this is a git repo (respects .gitignore), otherwise a find with common excludes.
list_files() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git ls-files --cached --others --exclude-standard
    else
        find . -type f \
            -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/vendor/*' \
            -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/.venv/*' \
            -not -path '*/venv/*' -not -path '*/__pycache__/*' | sed 's|^\./||'
    fi
}

mapfile -t src < <(list_files | grep -E "\.($src_ext)$" | grep -vE '(\.min\.|/vendor/|/node_modules/|/dist/|/build/)')
[ "${#src[@]}" -eq 0 ] && { echo "no source files found under $root"; exit 0; }

section() {
    local title="$1"; shift
    local hits
    hits="$("$@" 2>/dev/null)"
    [ -z "$hits" ] && return
    local n
    n=$(printf '%s\n' "$hits" | wc -l | tr -d ' ')
    printf '\n## %s (%s)\n' "$title" "$n"
    printf '%s\n' "$hits" | head -n "$max"
    [ "$n" -gt "$max" ] && printf '  … %s more\n' "$((n - max))"
}

g() { grep -nHiE "$1" -- "${src[@]}"; }

c='(#|//|/\*|\*|<!--)'

echo "# AI code tell scan: $(pwd)"
echo "# ${#src[@]} source files. Heuristic: verify every hit before acting."

section "Narrating comments" \
    g "$c\s*(step [0-9]+|first,? we|now we|next,? we|then we|finally,? we|loop (through|over)|iterate (through|over)|initiali[sz]e the|check (if|whether)|return the|create (a|the) new|call the|import (the )?(necessary|required))"

section "Changelog / hedging comments" \
    g "$c\s*(updated|changed|modified|fixed|added|refactored|improved)( to| per| as| the| this)|as requested|per (the )?request|now (uses|handles|supports)|should (now )?work|just in case|to be safe|for now|FIXED:|NEW:"

section "Emphatic comments" \
    g "$c\s*(IMPORTANT|CRITICAL|NOTE|WARNING)[:!]"

section "Banner comments" \
    g "$c\s*[=#*~-]{8,}"

section "Placeholder TODOs" \
    g "$c\s*TODO:?\s*(add|implement|handle|improve|consider)"

section "Hype / version-suffix names" \
    g "\b(enhanced|robust|advanced|smart|comprehensive|optimi[sz]ed|improved)_[a-z]|\b(enhanced|robust|advanced|smart|comprehensive|optimi[sz]ed|improved)[A-Z][a-z]|[a-z](_v[0-9]+|_new|_old|_fixed|_final|_backup|_copy)\b"

section "Vague function names" \
    g "(def|function|func|fn)\s+(handle|process|manage|do)_?(data|result|stuff|items?|info|things?)\b|(def|function|func|fn)\s+(handle|process|manage|do)(Data|Result|Stuff|Items?|Info|Things?)\b"

section "Swallowed errors" \
    g "except(\s+[A-Za-z_.]+)?(\s+as\s+\w+)?:\s*(pass|continue|return( None)?)?\s*$|catch\s*(\(\s*\w*\s*\))?\s*\{\s*\}|catch\s*(\(\s*\w*\s*\))?\s*\{\s*return (null|undefined|false|\[\]|\{\})"

section "Bare / broad except (check what follows)" \
    g "^\s*except\s*:|except (Exception|BaseException)\b|catch \((e|err|error)\) \{\s*$"

section "Emoji in code" \
    perl -CSD -e 'for my $f (@ARGV) { open(my $fh, "<", $f) or next; while (<$fh>) { print "$f:$.:$_" if /[\x{2600}-\x{27BF}\x{1F300}-\x{1FAFF}\x{2705}\x{274C}]/ } close $fh }' -- "${src[@]}"

section "Debug prints" \
    g "print\(f?[\"'](DEBUG|debug)|console\.(log|debug)\([\"'\`](DEBUG|debug)|\bvar_dump\(|\bdd\("

section "Factories / managers / base classes (check implementation count)" \
    g "(class|interface)\s+\w*(Factory|Manager|Helper|Handler|Base|Abstract)\w*|(class|interface)\s+I[A-Z]\w+|def (create|make|build)_\w+\(\s*\w*type"

# Artefact files anywhere in the tree.
section "Artefact files" \
    bash -c 'list() { if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then git ls-files --cached --others --exclude-standard; else find . -type f -not -path "*/.git/*" | sed "s|^\./||"; fi; }
             list | grep -iE "(^|/)([A-Z_]*(SUMMARY|REPORT|CHANGES|IMPLEMENTATION|NOTES)[A-Z_]*\.md|(example_usage|demo|test_output|output)\.(py|js|txt|log)|[^/]*(_v[0-9]+|_new|_old|_backup|_copy|_final)\.[a-z]+)$"'

section "Grab-bag modules" \
    bash -c 'printf "%s\n" "$@" | grep -iE "(^|/)(utils?|helpers?|common|misc|shared|tools)(\.[a-z]+|/)"' _ "${src[@]}"

section "Large files (>500 lines)" \
    bash -c 'wc -l -- "$@" | grep -v " total$" | awk "\$1 > 500 {print \$2\": \"\$1\" lines\"}" | sort -t: -k2 -nr' _ "${src[@]}"

# Same function name defined in more than one file: likely duplicated helpers.
section "Function names defined in several files" \
    bash -c 'grep -hoE "^\s*(export )?(async )?(def|function|func|fn)\s+[A-Za-z_][A-Za-z0-9_]*" -- "$@" \
        | awk "{print \$NF}" | grep -vE "^(main|__init__|init|setup|teardown|constructor|render|run|test\w*)$" \
        | sort | uniq -c | awk "\$1 > 1 {print \$2\": defined \"\$1\"x\"}" | sort -t: -k2 -nr' _ "${src[@]}"

# Files where comment lines outnumber a third of code lines.
section "Comment-heavy files (comments > 1/3 of lines)" \
    bash -c 'for f in "$@"; do
        awk -v f="$f" "{ t++ } /^[[:space:]]*(#|\/\/|\/\*|\*)/ && !/^#!/ { c++ } END { if (t > 20 && c * 3 > t) printf \"%s: %d/%d comment lines\n\", f, c, t }" "./$f"
    done' _ "${src[@]}"

section "Structure (files a reader can't navigate)" \
    bash -c 'awk_file="$1"; shift; for f in "$@"; do awk -f "$awk_file" "./$f"; done' _ "$here/structure.awk" "${src[@]}"

echo
echo "# Not detectable by grep: one-implementation interfaces, impossible-case guards, masking"
echo "# fallbacks, unused options, dead code. Read the code for those (references/ai-code-tells.md)."
