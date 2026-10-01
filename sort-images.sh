#!/usr/bin/env bash
set -uo pipefail

# ============================================================
# sort-images.sh
#
# Sort a directory of images into subject folders using
# filename-based rules.
#
# DEFAULT: dry run. Nothing is moved.
#
# Usage:
#   ./sort-images.sh
#   ./sort-images.sh --dry-run
#   ./sort-images.sh --apply
#
# Optional:
#   ./sort-images.sh --apply /path/to/images
#
# The script deliberately prefers specific project categories
# over broad subjects. Thus:
#
#   Spherepop Boolean synthesis.png
#
# goes to spherepop-mem8 rather than mathematics-logic.
# ============================================================

MODE="dry-run"
ROOT="."

case "${1:-}" in
    --apply)
        MODE="apply"
        shift
        ;;
    --dry-run)
        MODE="dry-run"
        shift
        ;;
esac

if [[ $# -gt 0 ]]; then
    ROOT="$1"
fi

if [[ ! -d "$ROOT" ]]; then
    echo "Directory not found: $ROOT" >&2
    exit 1
fi

cd "$ROOT" || exit 1

# ------------------------------------------------------------
# Categories
# ------------------------------------------------------------

CATEGORIES=(
    "admissibility-adversaria"
    "continuation-geometry"
    "spherepop-mem8"
    "industrial-ecology"
    "technology-computing"
    "physics-cosmology"
    "mathematics-logic"
    "cognition-neuroscience"
    "biology-life"
    "history-religion"
    "society-economics-politics"
    "writing-language-education"
    "media-fiction"
    "food"
    "art-design"
    "personal-projects"
    "bad-filenames"
    "unsorted"
)

# Counts without requiring associative arrays.
declare -A COUNTS
for c in "${CATEGORIES[@]}"; do
    COUNTS["$c"]=0
done

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

lower()
{
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

matches()
{
    local text="$1"
    local regex="$2"
    [[ "$text" =~ $regex ]]
}

is_image()
{
    local f
    f="$(lower "$1")"

    [[ "$f" =~ \.(png|jpg|jpeg|webp|gif|bmp|tif|tiff)$ ]]
}

# ------------------------------------------------------------
# Classification
#
# ORDER MATTERS.
#
# Specific projects come before general academic subjects.
# ------------------------------------------------------------

classify()
{
    local original="$1"
    local f
    f="$(lower "$original")"

    # --------------------------------------------------------
    # Obviously malformed/generated filenames
    # --------------------------------------------------------

    if matches "$f" \
       '^(we need|you need|respond with title|submitting image generation|the user wants a title|gute )'
    then
        echo "bad-filenames"
        return
    fi

    if matches "$f" \
       '(__end|need answer title|need title|max 7 words|sentence case|image described)'
    then
        echo "bad-filenames"
        return
    fi

    # --------------------------------------------------------
    # ADMISSIBILITY / ADVERSARIA / EPISTEMIC SYSTEMS
    # --------------------------------------------------------

    if matches "$f" \
       '(admissib|adversaria|claimshift|epistemic|non-scalar ledger|claim record|machine.?s claim|machine.?s testimony|machine witness|hardware result.*claim|verification.*commitment|custodian|warranted worlds|latency of evidence)'
    then
        echo "admissibility-adversaria"
        return
    fi

    if matches "$f" \
       '(admit everything|guard the crossing|guardians of the epistemic|signed identification|provenance|authority.*machine)'
    then
        echo "admissibility-adversaria"
        return
    fi

    # --------------------------------------------------------
    # SPHEREPOP / MEM|8 / SYSTEM 08
    # --------------------------------------------------------

    if matches "$f" \
       '(sphere.?pop|spherepop|mem.?8|system 08|system viii|guardian.?s refuse|canonical history|galactromeda|eight-cubed typed lattice)'
    then
        echo "spherepop-mem8"
        return
    fi

    # --------------------------------------------------------
    # INDUSTRIAL ECOLOGY / REPAIR / METABOLISM
    # --------------------------------------------------------

    if matches "$f" \
       '(industrial ecol|industrial ecolog|industrial metabolism|metabolic engine|recovery loop|bounded metabolism|living datacenter|vertical machine ecology|self-balancing datacenter|grown datacenter|v8tr)'
    then
        echo "industrial-ecology"
        return
    fi

    if matches "$f" \
       '(automated recycling|recycling facility|planetary infrastructure|material waterworks|rooftop wetlands|basement kelp|kelp city|living wetland|living mountain|ecological factory)'
    then
        echo "industrial-ecology"
        return
    fi

    # --------------------------------------------------------
    # CONTINUATION / REACHABILITY / PERSISTENCE
    # --------------------------------------------------------

    if matches "$f" \
       '(continuation|reachability|reachable|persistence|admissible world|possible tomorrow|paths and possibilities|futures not counted|futures that weren|future.*paths|three structures)'
    then
        echo "continuation-geometry"
        return
    fi

    if matches "$f" \
       '(constraint before capacity|constraint gives shape|protected interval|unruly possibility|recursive continuation|returning light|intersecting futures|common future|preservation des futurs)'
    then
        echo "continuation-geometry"
        return
    fi

    # --------------------------------------------------------
    # TECHNOLOGICAL ARCHAEOLOGY / COMPUTING
    # --------------------------------------------------------

    if matches "$f" \
       '(technological archaeolog|git archaeolog|inside git|git in the open|git_ histories|history machine|z80|commodore|dos typing|typing tutor|compiler|rust|arm and fpga|computer|computing|datacenter)'
    then
        echo "technology-computing"
        return
    fi

    if matches "$f" \
       '(boolean synthesis|information flow|radiative switch|physical computing|autonomous systems|control states|hyperbionic|dashboard|terminal|interface|yarncrawler)'
    then
        echo "technology-computing"
        return
    fi

    # --------------------------------------------------------
    # PHYSICS / COSMOLOGY / ASTRONOMY
    # --------------------------------------------------------

    if matches "$f" \
       '(cosmic|cosmos|cosmolog|stellar|stars revealed|hydrogen|gravity|antigrav|quantum|wave interference|dark energy|universe|planet|orbital|observatory|stargaz|moon|titan|field before|where fields meet)'
    then
        echo "physics-cosmology"
        return
    fi

    if matches "$f" \
       '(momentum before position|momentum science|dip of the horizon|orthodromic|expanded violet spectrum|plenum|radiative|great-circle|caldera reactor)'
    then
        echo "physics-cosmology"
        return
    fi

    # --------------------------------------------------------
    # MATHEMATICS / LOGIC
    # --------------------------------------------------------

    if matches "$f" \
       '(mathemat|proof|boolean|logical|logic|calculus|lambda calculus|hypercube|tesseract|typed lattice|fixpoint|recursion|geometric framework|geometry of|formulation variables)'
    then
        echo "mathematics-logic"
        return
    fi

    if matches "$f" \
       '(cycle notes|three values|twelvefold harmony|commuting transformations|königsberg|lullian|ramon llull|bilateral circle of fifths)'
    then
        echo "mathematics-logic"
        return
    fi

    # --------------------------------------------------------
    # COGNITION / NEUROSCIENCE / PSYCHOLOGY
    # --------------------------------------------------------

    if matches "$f" \
       '(cognit|neuro|synaptic|cortex|brain|mind|perception|prediction before interpretation|hyperthymesia|neural network|neurotransmitter|receptor|conscience|conscious)'
    then
        echo "cognition-neuroscience"
        return
    fi

    if matches "$f" \
       '(making thought visible|source pc|labels shape|semantic distinction|naming is not explaining|cognitive cost|coût cognitif|simulated agency)'
    then
        echo "cognition-neuroscience"
        return
    fi

    # --------------------------------------------------------
    # BIOLOGY / LIFE / ORIGINS
    # --------------------------------------------------------

    if matches "$f" \
       '(biology|life|evolution|first cycle of life|premier cycle|dna|organs|physiome|chimpanzee|bonobo|bonovo|zebra|aloe|botanical)'
    then
        echo "biology-life"
        return
    fi

    if matches "$f" \
       '(mechanical inheritance|matrix remembers|movement shapes the matrix|cultured baths|living ship|living world)'
    then
        echo "biology-life"
        return
    fi

    # --------------------------------------------------------
    # HISTORY / RELIGION
    # --------------------------------------------------------

    if matches "$f" \
       '(history|histor|ancient|medieval|imperial|empire|scribe|scriptorium|gazette|chronicle|herald|1899|1920|1925|al-biruni|al-maghrib|fez|pasteur)'
    then
        echo "history-religion"
        return
    fi

    if matches "$f" \
       '(god|holy|gospel|noah|ark|golden calf|orthodox|faith|prayer|orphic|church|cathedral|catedral|sacrifice|spirit seer)'
    then
        echo "history-religion"
        return
    fi

    # --------------------------------------------------------
    # SOCIETY / ECONOMICS / GOVERNMENT / POLITICS
    # --------------------------------------------------------

    if matches "$f" \
       '(debt|econom|state|government|authority|regulation|administrative|cities|society|communal|managed world|allocation|freedom|progress|replacement|future for whom|private sky|super intelligence luncheon)'
    then
        echo "society-economics-politics"
        return
    fi

    if matches "$f" \
       '(morlock|eloi|acceleration|world ardiente|cohetes|búnkeres|planetary subject|commonwealth|cities beyond nations|megaworks|glorious zero-work|feeds the machine)'
    then
        echo "society-economics-politics"
        return
    fi

    # --------------------------------------------------------
    # WRITING / LANGUAGE / EDUCATION
    # --------------------------------------------------------

    if matches "$f" \
       '(writing|language|letter|alphabet|rune|cipher|reading|reader|paper tutor|typing tutor|curriculum|shorthand|words|semantic|spell checker|latex|book|library of ideas)'
    then
        echo "writing-language-education"
        return
    fi

    if matches "$f" \
       '(sproll|hyperbionic reading|borrowed voices|ordered words|paper tutor|letter invaders)'
    then
        echo "writing-language-education"
        return
    fi

    # --------------------------------------------------------
    # MEDIA / FICTION / COMICS / FILM
    # --------------------------------------------------------

    if matches "$f" \
       '(aniara|moonwatcher|movie|cinema|comic|graphic novel|galactic comics|game-show|game show|hals|fiction|yarncrawler|carbonite|smuggler|lizard of menlo|lizard rulers|lizard emperors)'
    then
        echo "media-fiction"
        return
    fi

    if matches "$f" \
       '(whales return|exit that cannot exit|wall with no witness|gospel of acceleration|your replacement is progress|who feeds the machine|tract-back-cover)'
    then
        echo "media-fiction"
        return
    fi

    # --------------------------------------------------------
    # FOOD
    # --------------------------------------------------------

    if matches "$f" \
       '(food|soup|taco|cattail|spice|beef|vegan|plant protein|yogurt|bite|meal|recipe|bubblegum)'
    then
        echo "food"
        return
    fi

    # --------------------------------------------------------
    # ART / DESIGN / VISUAL EXPERIMENTS
    # --------------------------------------------------------

    if matches "$f" \
       '(inkblot|stained glass|golden light|waterfall|pine forest|retro logo|logo|rock tee|t-shirt|catalog|business card|model sheet|celtic knot|illuminated|parchment|pergamino)'
    then
        echo "art-design"
        return
    fi

    if matches "$f" \
       '(neón|neon|psychedelic|psicodélic|visualizador|túnel|portal|cathedral of forms|radiant beauty)'
    then
        echo "art-design"
        return
    fi

    # --------------------------------------------------------
    # PERSONAL / FLYXION META-PROJECT MATERIAL
    # --------------------------------------------------------

    if matches "$f" \
       '(flyxion|frameworks issue|world laboratory|accountable systems|next move|filename status berm)'
    then
        echo "personal-projects"
        return
    fi

    # --------------------------------------------------------
    # Everything else
    # --------------------------------------------------------

    echo "unsorted"
}

# ------------------------------------------------------------
# Collision-safe destination
# ------------------------------------------------------------

destination_for()
{
    local category="$1"
    local filename="$2"

    local destination="$category/$filename"

    if [[ ! -e "$destination" ]]; then
        printf '%s\n' "$destination"
        return
    fi

    local stem ext n

    if [[ "$filename" == *.* ]]; then
        stem="${filename%.*}"
        ext=".${filename##*.}"
    else
        stem="$filename"
        ext=""
    fi

    n=2

    while [[ -e "$category/${stem}-${n}${ext}" ]]; do
        ((n++))
    done

    printf '%s\n' "$category/${stem}-${n}${ext}"
}

# ------------------------------------------------------------
# Main pass
# ------------------------------------------------------------

echo
echo "Image sorter"
echo "Directory: $(pwd)"
echo "Mode:      $MODE"
echo

TOTAL=0

while IFS= read -r -d '' file; do

    filename="${file#./}"

    # Ignore the script itself and non-images.
    is_image "$filename" || continue

    category="$(classify "$filename")"

    ((COUNTS["$category"]++))
    ((TOTAL++))

    if [[ "$MODE" == "apply" ]]; then

        mkdir -p "$category"

        destination="$(destination_for "$category" "$filename")"

        printf '%-28s  %s\n' "$category" "$filename"
        mv -- "$filename" "$destination"

    else

        printf '%-28s  %s\n' "$category" "$filename"

    fi

done < <(find . -maxdepth 1 -type f -print0)

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo "============================================================"
echo "SUMMARY"
echo "============================================================"

for category in "${CATEGORIES[@]}"; do
    printf '%-28s %5d\n' "$category" "${COUNTS[$category]}"
done

echo "------------------------------------------------------------"
printf '%-28s %5d\n' "TOTAL" "$TOTAL"
echo

if [[ "$MODE" == "dry-run" ]]; then
    echo "DRY RUN ONLY — no files were moved."
    echo
    echo "Review the classifications above."
    echo "When satisfied, run:"
    echo
    echo "    ./sort-images.sh --apply"
else
    echo "Files moved."
fi
