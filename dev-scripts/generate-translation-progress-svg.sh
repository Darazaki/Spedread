#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Avoid issues with formatting
export LC_ALL=C

root="po/"
output="data/translation-progress.svg"

command -v msgfmt >/dev/null || {
    echo "Error: msgfmt not found; install GNU gettext." >&2
    exit 1
}

files=()
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find "$root" -type f -name '*.po' -print0 | sort -z)

((${#files[@]})) || {
    echo "No .po files found under: $root." >&2
    exit 1
}

xml_escape() {
    local s=$1
    s=${s//&/&amp;}
    s=${s//</&lt;}
    s=${s//>/&gt;}
    s=${s//\"/&quot;}
    s=${s//\'/&apos;}
    printf '%s' "$s"
}

extract_count() {
    local pattern=$1 stats=$2
    printf '%s\n' "$stats" |
        grep -oE "[0-9]+ ${pattern}" |
        awk '{print $1}' || true
}

width=760
left=90
right=90
bar_width=$((width - left - right))
top=90
row_height=32
height=$((top + ${#files[@]} * row_height + 35))
text_y_displacement=12

{
    printf '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s">\n' \
        "$width" "$height" "$width" "$height"
    printf '<style>text{font-family:Arial,sans-serif;fill:#f2f5f3}.muted{fill:#b6bfb8;font-size:12px}.muted.big{font-size:16px}</style>\n'
    printf '<rect width="100%%" height="100%%" rx="5" fill="#0d1117" stroke="#353d37" stroke-with="1"/>\n'
    printf '<text x="32" y="42" font-size="22" font-weight="bold">UI translation progress per language</text>\n'
    printf '<text x="32" y="64" class="muted big">with "translated/total" messages</text>\n'

    for tick in 0 25 50 75 100; do
        x=$((left + bar_width * tick / 100))
        end_y=$((top + ${#files[@]} * row_height - 10))
        printf '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#353d37"/>\n' \
            "$x" "$((top - 10))" "$x" "$end_y"
        printf '<text x="%s" y="%s" text-anchor="middle" class="muted">%s%%</text>\n' \
            "$x" "$((height - 20))" "$tick"
    done

    i=0
    for file in "${files[@]}"; do
        stats=$(msgfmt --statistics -o /dev/null "$file" 2>&1) || {
            echo "msgfmt failed on: $file" >&2
            exit 1
        }

        translated=$(extract_count 'translated messages?' "$stats")
        fuzzy=$(extract_count 'fuzzy translations?' "$stats")
        untranslated=$(extract_count 'untranslated messages?' "$stats")

        translated=${translated:-0}
        fuzzy=${fuzzy:-0}
        untranslated=${untranslated:-0}
        total=$((translated + fuzzy + untranslated))

        if ((total == 0)); then
            percent=0
        else
            percent=$((100 * translated / total))
        fi

        # Use the PO filename without the .po as the chart label (e.g. fr)
        label=$(xml_escape "$(basename "${file%.po}")")
        y=$((top + i * row_height))
        filled=$((bar_width * percent / 100))

        if ((percent == 100)); then
            fill_color="#c7a60b"
        else
            fill_color="#0fbf3e"
        fi

        printf '<text x="32" y="%s" font-size="14">%s</text>\n' "$((y + $text_y_displacement))" "$label"
        printf '<rect x="%s" y="%s" width="%s" height="16" rx="5" fill="%s"/>\n' \
            "$left" "$y" "$filled" "$fill_color"
        printf '<text x="%s" y="%s" font-size="13">%s</text>\n' \
            "$((left + filled + 8))" "$((y + $text_y_displacement))" "$translated/$total"

        i=$((i + 1))
    done

    printf '</svg>\n'
} > "$output"

echo "Saved progress report to $output."
