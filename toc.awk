#!/bin/awk -f

match($0, /^#(#+) (.*)/, m) {
    p = substr(m[1], 2)
    gsub("#", "  ", p)
    link = tolower(m[2])
    gsub(" ", "-", link)
    gsub("[/.'`]", "", link)
    printf "%s* [%s](#%s)\n", p, m[2], link
}
