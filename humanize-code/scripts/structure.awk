# structure.awk — per-file shape metrics for scan-tells.sh; prints only files with a finding.
# Run once per file: awk -f structure.awk FILE

function indent_of(line,    lead, n, i, c) {
    match(line, /^[ \t]*/)
    lead = substr(line, 1, RLENGTH)
    n = 0
    for (i = 1; i <= length(lead); i++) {
        c = substr(lead, i, 1)
        n += (c == "\t") ? 4 : 1
    }
    return n
}

BEGIN { unit = 0 }

{
    total++
    if (length($0) > 100) long++
    if ($0 ~ /^[ \t]*$/) next
    if (!first_seen) {
        first_seen = 1
        if ($0 ~ /^[ \t]*(#!|<\?php)/) { first_seen = 0 }
        else has_header = ($0 ~ /^[ \t]*(#|\/\/|\/\*|\*|"""|''')/)
    }
    ind = indent_of($0)
    if (ind > 0 && (unit == 0 || ind < unit)) unit = ind
    if (ind > max_ind) max_ind = ind

    named = 0
    if ($0 ~ /^[ \t]*(export[ \t]+)?(default[ \t]+)?(async[ \t]+)?function[ \t]*\*?[ \t]+[A-Za-z_$]/) named = 1
    else if ($0 ~ /^[ \t]*((public|private|protected|static|final|abstract)[ \t]+)*function[ \t]+&?[A-Za-z_]/) named = 1
    else if ($0 ~ /^[ \t]*(async[ \t]+)?def[ \t]+[A-Za-z_]/) named = 1
    else if ($0 ~ /^[ \t]*func[ \t]+/ || $0 ~ /^[ \t]*(pub[ \t]+)?fn[ \t]+/) named = 1
    else if ($0 ~ /^[ \t]*(export[ \t]+)?(const|let|var)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*[ \t]*=[ \t]*(async[ \t]+)?(\([^)]*\)|[A-Za-z_$][A-Za-z0-9_$]*)[ \t]*=>/) named = 1
    else if ($0 ~ /^[ \t]*(export[ \t]+)?(const|let|var)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*[ \t]*=[ \t]*(async[ \t]+)?function/) named = 1

    if (named) {
        if (ind == 0) top_named++
        else nested_named++
    } else {
        inline += gsub(/=>|function[ \t]*\(/, "&")
    }
}

END {
    if (unit < 2) unit = 4
    depth = int(max_ind / unit)
    named_all = top_named + nested_named
    reasons = ""
    if (total > 80 && !has_header) reasons = reasons "; no file header"
    if (top_named == 0 && nested_named >= 5) reasons = reasons "; everything in one scope (" nested_named " nested functions, none top-level)"
    if (inline >= 15 && inline > 2 * named_all) reasons = reasons "; " inline " inline callbacks vs " named_all " named functions"
    if (depth >= 6) reasons = reasons "; nesting depth " depth
    if (long > 10) reasons = reasons "; " long " lines over 100 chars"
    if (reasons != "") { name = FILENAME; sub(/^\.\//, "", name); printf "%s: %d lines%s\n", name, total, reasons }
}
