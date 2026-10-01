#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
OUTPUT="$ROOT/index.html"

cd "$ROOT"

python3 - <<'PY'
from pathlib import Path
import html
import json
import re

ROOT = Path(".")
OUTPUT = ROOT / "index.html"

IMAGE_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".webp",
    ".gif", ".bmp", ".tif", ".tiff", ".avif"
}

PREFERRED_ORDER = [
    "admissibility-adversaria",
    "continuation-geometry",
    "spherepop-mem8",
    "industrial-ecology",
    "technology-computing",
    "physics-cosmology",
    "mathematics-logic",
    "cognition-neuroscience",
    "biology-life",
    "history-religion",
    "society-economics-politics",
    "writing-language-education",
    "media-fiction",
    "food",
    "art-design",
    "personal-projects",
    "unsorted",
    "bad-filenames",
]


def natural_key(s):
    return [
        int(x) if x.isdigit() else x.casefold()
        for x in re.split(r"(\d+)", s)
    ]


def display_category(name):
    return name.replace("-", " ").title()


def display_title(filename):
    stem = Path(filename).stem

    # Keep meaningful punctuation but make generated filenames readable.
    stem = stem.replace("_", " ")
    stem = re.sub(r"\s+", " ", stem).strip()

    return stem


categories = {}

for directory in ROOT.iterdir():
    if not directory.is_dir():
        continue

    files = [
        p for p in directory.iterdir()
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    ]

    if files:
        categories[directory.name] = sorted(
            files,
            key=lambda p: natural_key(p.name)
        )


ordered_names = [
    c for c in PREFERRED_ORDER if c in categories
]

ordered_names += sorted(
    (c for c in categories if c not in PREFERRED_ORDER),
    key=natural_key
)

records = []

for category in ordered_names:
    for path in categories[category]:
        records.append({
            "category": category,
            "categoryLabel": display_category(category),
            "filename": path.name,
            "title": display_title(path.name),
            "src": path.as_posix(),
        })

data_json = json.dumps(
    records,
    ensure_ascii=False
).replace("</", "<\\/")

category_json = json.dumps([
    {
        "name": name,
        "label": display_category(name),
        "count": len(categories[name]),
    }
    for name in ordered_names
], ensure_ascii=False)

page = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Image Archive</title>

<style>
:root {
    color-scheme: dark;

    --bg: #0c0d0f;
    --panel: #131519;
    --panel2: #191c21;
    --line: #2b2f36;
    --text: #e9e9e7;
    --muted: #9298a1;
    --accent: #d4b66a;

    --sidebar: 260px;
    --thumb: 220px;
}

* {
    box-sizing: border-box;
}

html,
body {
    margin: 0;
    min-height: 100%;
    background: var(--bg);
    color: var(--text);
    font-family:
        Inter,
        ui-sans-serif,
        system-ui,
        -apple-system,
        BlinkMacSystemFont,
        "Segoe UI",
        sans-serif;
}

button,
input {
    font: inherit;
}

body {
    overflow-x: hidden;
}

/* --------------------------------------------------------- */
/* Header                                                    */
/* --------------------------------------------------------- */

header {
    position: sticky;
    top: 0;
    z-index: 20;

    display: flex;
    align-items: center;
    gap: 18px;

    height: 64px;
    padding: 10px 18px;

    background: rgba(12, 13, 15, .94);
    border-bottom: 1px solid var(--line);
    backdrop-filter: blur(12px);
}

.brand {
    min-width: max-content;
    font-weight: 700;
    letter-spacing: .04em;
}

#search {
    width: min(620px, 100%);
    margin-left: auto;

    border: 1px solid var(--line);
    border-radius: 8px;
    outline: none;

    padding: 10px 13px;

    color: var(--text);
    background: var(--panel);
}

#search:focus {
    border-color: #666;
}

#visible-count {
    min-width: max-content;
    color: var(--muted);
    font-size: 13px;
}

/* --------------------------------------------------------- */
/* Layout                                                    */
/* --------------------------------------------------------- */

.layout {
    display: grid;
    grid-template-columns: var(--sidebar) 1fr;
    min-height: calc(100vh - 64px);
}

aside {
    position: sticky;
    top: 64px;

    height: calc(100vh - 64px);
    overflow-y: auto;

    padding: 16px 10px 40px;

    border-right: 1px solid var(--line);
    background: var(--panel);
}

main {
    min-width: 0;
    padding: 24px;
}

/* --------------------------------------------------------- */
/* Category navigation                                       */
/* --------------------------------------------------------- */

.category-button {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 10px;

    width: 100%;
    margin: 2px 0;
    padding: 9px 10px;

    border: 0;
    border-radius: 7px;

    color: var(--muted);
    background: transparent;

    text-align: left;
    cursor: pointer;
}

.category-button:hover {
    color: var(--text);
    background: var(--panel2);
}

.category-button.active {
    color: var(--text);
    background: var(--panel2);
}

.category-button .count {
    color: #6f7680;
    font-variant-numeric: tabular-nums;
}

/* --------------------------------------------------------- */
/* Gallery                                                   */
/* --------------------------------------------------------- */

.section-heading {
    display: flex;
    align-items: baseline;
    gap: 10px;

    margin: 4px 0 18px;
}

.section-heading h1 {
    margin: 0;
    font-size: 22px;
    font-weight: 650;
}

.section-heading span {
    color: var(--muted);
    font-size: 13px;
}

.gallery {
    display: grid;
    grid-template-columns:
        repeat(auto-fill, minmax(var(--thumb), 1fr));
    gap: 14px;
}

.card {
    min-width: 0;
    overflow: hidden;

    border: 1px solid var(--line);
    border-radius: 9px;

    background: var(--panel);
    cursor: pointer;
}

.card:hover {
    border-color: #555b65;
}

.thumb {
    display: flex;
    align-items: center;
    justify-content: center;

    width: 100%;
    aspect-ratio: 4 / 3;

    overflow: hidden;
    background: #08090a;
}

.thumb img {
    width: 100%;
    height: 100%;

    object-fit: contain;
}

.meta {
    padding: 10px 11px 12px;
}

.title {
    overflow: hidden;

    color: var(--text);
    font-size: 13px;
    line-height: 1.35;

    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
}

.category-label {
    margin-top: 6px;

    color: var(--muted);
    font-size: 11px;
}

/* --------------------------------------------------------- */
/* Empty state                                               */
/* --------------------------------------------------------- */

.empty {
    padding: 80px 20px;
    color: var(--muted);
    text-align: center;
}

/* --------------------------------------------------------- */
/* Viewer                                                    */
/* --------------------------------------------------------- */

.viewer {
    position: fixed;
    inset: 0;
    z-index: 100;

    display: none;
    grid-template-rows: 1fr auto;

    background: rgba(0, 0, 0, .94);
}

.viewer.open {
    display: grid;
}

.viewer-stage {
    position: relative;

    display: flex;
    align-items: center;
    justify-content: center;

    min-height: 0;
    padding: 55px 70px 20px;
}

.viewer-stage img {
    max-width: 100%;
    max-height: 100%;

    object-fit: contain;
}

.viewer-close {
    position: absolute;
    top: 16px;
    right: 18px;

    width: 42px;
    height: 42px;

    border: 1px solid #444;
    border-radius: 50%;

    color: white;
    background: #17191d;

    font-size: 22px;
    cursor: pointer;
}

.viewer-nav {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);

    width: 46px;
    height: 70px;

    border: 0;
    border-radius: 8px;

    color: white;
    background: rgba(30, 32, 37, .75);

    font-size: 30px;
    cursor: pointer;
}

.viewer-nav:hover {
    background: rgba(60, 63, 70, .9);
}

.viewer-prev {
    left: 12px;
}

.viewer-next {
    right: 12px;
}

.viewer-info {
    padding: 12px 20px 18px;

    border-top: 1px solid #292c31;

    background: #101114;
    text-align: center;
}

.viewer-title {
    font-size: 15px;
}

.viewer-path {
    margin-top: 5px;

    color: var(--muted);
    font-size: 12px;
    word-break: break-all;
}

/* --------------------------------------------------------- */
/* Responsive                                                */
/* --------------------------------------------------------- */

@media (max-width: 760px) {

    :root {
        --thumb: 145px;
    }

    header {
        height: auto;
        flex-wrap: wrap;
    }

    #search {
        order: 3;
        width: 100%;
    }

    .layout {
        display: block;
    }

    aside {
        position: relative;
        top: auto;

        display: flex;
        gap: 5px;

        width: 100%;
        height: auto;

        padding: 8px 10px;

        overflow-x: auto;
        border-right: 0;
        border-bottom: 1px solid var(--line);
    }

    .category-button {
        display: block;
        width: auto;
        min-width: max-content;
    }

    .category-button .count {
        margin-left: 5px;
    }

    main {
        padding: 14px;
    }

    .gallery {
        gap: 8px;
    }

    .viewer-stage {
        padding: 60px 8px 12px;
    }

    .viewer-nav {
        top: auto;
        bottom: 10px;
    }
}
</style>
</head>

<body>

<header>
    <div class="brand">IMAGE ARCHIVE</div>

    <input
        id="search"
        type="search"
        placeholder="Search filenames…"
        autocomplete="off"
    >

    <div id="visible-count"></div>
</header>

<div class="layout">

    <aside id="categories"></aside>

    <main>
        <div class="section-heading">
            <h1 id="heading">All images</h1>
            <span id="heading-count"></span>
        </div>

        <div id="gallery" class="gallery"></div>
        <div id="empty" class="empty" hidden>No matching images.</div>
    </main>

</div>

<div id="viewer" class="viewer">

    <div class="viewer-stage">

        <button
            class="viewer-close"
            id="viewer-close"
            aria-label="Close"
        >×</button>

        <button
            class="viewer-nav viewer-prev"
            id="viewer-prev"
            aria-label="Previous image"
        >‹</button>

        <img id="viewer-image" alt="">

        <button
            class="viewer-nav viewer-next"
            id="viewer-next"
            aria-label="Next image"
        >›</button>

    </div>

    <div class="viewer-info">
        <div id="viewer-title" class="viewer-title"></div>
        <div id="viewer-path" class="viewer-path"></div>
    </div>

</div>

<script>
const IMAGES = __IMAGE_DATA__;
const CATEGORIES = __CATEGORY_DATA__;

let selectedCategory = "all";
let searchText = "";
let visibleImages = [];
let viewerIndex = -1;

const gallery = document.getElementById("gallery");
const categoryBox = document.getElementById("categories");
const search = document.getElementById("search");

const heading = document.getElementById("heading");
const headingCount = document.getElementById("heading-count");
const visibleCount = document.getElementById("visible-count");
const empty = document.getElementById("empty");

const viewer = document.getElementById("viewer");
const viewerImage = document.getElementById("viewer-image");
const viewerTitle = document.getElementById("viewer-title");
const viewerPath = document.getElementById("viewer-path");

function makeCategoryButton(name, label, count) {

    const button = document.createElement("button");

    button.className = "category-button";
    button.dataset.category = name;

    const labelNode = document.createElement("span");
    labelNode.textContent = label;

    const countNode = document.createElement("span");
    countNode.className = "count";
    countNode.textContent = count;

    button.append(labelNode, countNode);

    button.addEventListener("click", () => {
        selectedCategory = name;
        render();
    });

    return button;
}

function buildCategories() {

    categoryBox.innerHTML = "";

    categoryBox.appendChild(
        makeCategoryButton(
            "all",
            "All images",
            IMAGES.length
        )
    );

    for (const category of CATEGORIES) {
        categoryBox.appendChild(
            makeCategoryButton(
                category.name,
                category.label,
                category.count
            )
        );
    }
}

function filteredImages() {

    const q = searchText.trim().toLocaleLowerCase();

    return IMAGES.filter(image => {

        if (
            selectedCategory !== "all" &&
            image.category !== selectedCategory
        ) {
            return false;
        }

        if (!q) {
            return true;
        }

        const haystack = (
            image.filename + " " +
            image.title + " " +
            image.categoryLabel
        ).toLocaleLowerCase();

        return haystack.includes(q);
    });
}

function render() {

    visibleImages = filteredImages();

    document
        .querySelectorAll(".category-button")
        .forEach(button => {
            button.classList.toggle(
                "active",
                button.dataset.category === selectedCategory
            );
        });

    if (selectedCategory === "all") {
        heading.textContent = "All images";
    } else {
        const found = CATEGORIES.find(
            c => c.name === selectedCategory
        );

        heading.textContent = found
            ? found.label
            : selectedCategory;
    }

    headingCount.textContent =
        `${visibleImages.length} images`;

    visibleCount.textContent =
        `${visibleImages.length} / ${IMAGES.length}`;

    gallery.innerHTML = "";

    empty.hidden = visibleImages.length !== 0;

    const fragment = document.createDocumentFragment();

    visibleImages.forEach((image, index) => {

        const card = document.createElement("article");
        card.className = "card";

        const thumb = document.createElement("div");
        thumb.className = "thumb";

        const img = document.createElement("img");
        img.src = image.src;
        img.alt = image.title;
        img.loading = "lazy";
        img.decoding = "async";

        thumb.appendChild(img);

        const meta = document.createElement("div");
        meta.className = "meta";

        const title = document.createElement("div");
        title.className = "title";
        title.textContent = image.title;

        const category = document.createElement("div");
        category.className = "category-label";
        category.textContent = image.categoryLabel;

        meta.append(title, category);
        card.append(thumb, meta);

        card.addEventListener("click", () => {
            openViewer(index);
        });

        fragment.appendChild(card);
    });

    gallery.appendChild(fragment);
}

function openViewer(index) {

    if (!visibleImages.length) {
        return;
    }

    viewerIndex = index;

    const image = visibleImages[viewerIndex];

    viewerImage.src = image.src;
    viewerImage.alt = image.title;

    viewerTitle.textContent = image.title;
    viewerPath.textContent =
        image.category + "/" + image.filename;

    viewer.classList.add("open");

    document.body.style.overflow = "hidden";
}

function closeViewer() {

    viewer.classList.remove("open");

    viewerImage.src = "";

    document.body.style.overflow = "";
}

function moveViewer(direction) {

    if (!visibleImages.length) {
        return;
    }

    viewerIndex =
        (viewerIndex + direction + visibleImages.length) %
        visibleImages.length;

    openViewer(viewerIndex);
}

search.addEventListener("input", event => {
    searchText = event.target.value;
    render();
});

document
    .getElementById("viewer-close")
    .addEventListener("click", closeViewer);

document
    .getElementById("viewer-prev")
    .addEventListener("click", () => moveViewer(-1));

document
    .getElementById("viewer-next")
    .addEventListener("click", () => moveViewer(1));

viewer.addEventListener("click", event => {
    if (event.target === viewer) {
        closeViewer();
    }
});

document.addEventListener("keydown", event => {

    if (!viewer.classList.contains("open")) {
        return;
    }

    if (event.key === "Escape") {
        closeViewer();
    }

    if (event.key === "ArrowLeft") {
        moveViewer(-1);
    }

    if (event.key === "ArrowRight") {
        moveViewer(1);
    }
});

buildCategories();
render();
</script>

</body>
</html>
'''

page = page.replace("__IMAGE_DATA__", data_json)
page = page.replace("__CATEGORY_DATA__", category_json)

OUTPUT.write_text(page, encoding="utf-8")

print()
print(f"Generated: {OUTPUT}")
print(f"Images:    {len(records)}")
print()

for name in ordered_names:
    print(f"{name:30} {len(categories[name]):5}")

PY
