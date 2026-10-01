#!/usr/bin/env python3

from pathlib import Path
from PIL import Image
import colorsys
import json
import re

# ============================================================
# CONFIGURATION
# ============================================================

ROOT = Path(".")
OUTPUT = ROOT / "wall.html"

THUMB_DIR = ROOT / "wall-thumbs"

THUMB_SIZE = 360
THUMB_QUALITY = 72

IMAGE_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".webp",
    ".gif", ".bmp", ".tif", ".tiff",
}

IGNORE_DIRS = {
    ".git",
    "__pycache__",
    "wall-thumbs",
    ".wall-thumbs",
}

THUMB_DIR.mkdir(exist_ok=True)


# ============================================================
# HELPERS
# ============================================================

def natural_key(text):
    return [
        int(x) if x.isdigit() else x.casefold()
        for x in re.split(r"(\d+)", text)
    ]


def display_category(name):
    return name.replace("-", " ").title()


def display_title(filename):
    stem = Path(filename).stem
    stem = stem.replace("_", " ")
    stem = re.sub(r"\s+", " ", stem)
    return stem.strip()


def safe_part(text):
    return re.sub(
        r"[^A-Za-z0-9._()-]+",
        "_",
        text
    )


# ============================================================
# IMAGE INFORMATION
# ============================================================

def image_dimensions(path):
    try:
        with Image.open(path) as im:
            return im.size
    except Exception as exc:
        print(f"WARNING: dimensions failed for {path}: {exc}")
        return (1, 1)


def representative_color(path):
    try:
        with Image.open(path) as im:

            try:
                im.seek(0)
            except Exception:
                pass

            im = im.convert("RGB")

            im.thumbnail(
                (64, 64),
                Image.Resampling.BILINEAR
            )

            pixels = list(im.getdata())

            if not pixels:
                return (128, 128, 128)

            useful = []

            for r, g, b in pixels:
                brightness = (r + g + b) / 3

                if 18 < brightness < 238:
                    useful.append((r, g, b))

            minimum = max(
                10,
                int(len(pixels) * 0.08)
            )

            if len(useful) < minimum:
                useful = pixels

            r = sum(p[0] for p in useful) / len(useful)
            g = sum(p[1] for p in useful) / len(useful)
            b = sum(p[2] for p in useful) / len(useful)

            return (
                int(round(r)),
                int(round(g)),
                int(round(b)),
            )

    except Exception as exc:
        print(f"WARNING: colour failed for {path}: {exc}")
        return (128, 128, 128)


def color_features(rgb):

    r, g, b = [
        value / 255
        for value in rgb
    ]

    h, s, v = colorsys.rgb_to_hsv(
        r, g, b
    )

    return {
        "r": rgb[0],
        "g": rgb[1],
        "b": rgb[2],
        "h": h,
        "s": s,
        "v": v,
    }


# ============================================================
# THUMBNAILS
# ============================================================

def thumbnail_path_for(path):

    category = safe_part(
        path.parent.name
    )

    name = safe_part(
        path.stem
    )

    return (
        THUMB_DIR /
        f"{category}__{name}.webp"
    )


def make_thumbnail(path):

    thumb_path = thumbnail_path_for(
        path
    )

    if thumb_path.exists():

        try:
            if (
                thumb_path.stat().st_mtime
                >= path.stat().st_mtime
            ):
                return thumb_path.as_posix()

        except OSError:
            pass

    try:

        with Image.open(path) as im:

            try:
                im.seek(0)
            except Exception:
                pass

            if (
                im.mode in ("RGBA", "LA")
                or "transparency" in im.info
            ):

                rgba = im.convert("RGBA")

                background = Image.new(
                    "RGBA",
                    rgba.size,
                    (10, 11, 13, 255)
                )

                background.alpha_composite(
                    rgba
                )

                im = background.convert(
                    "RGB"
                )

            else:

                im = im.convert(
                    "RGB"
                )

            im.thumbnail(
                (THUMB_SIZE, THUMB_SIZE),
                Image.Resampling.LANCZOS
            )

            im.save(
                thumb_path,
                "WEBP",
                quality=THUMB_QUALITY,
                method=6
            )

        return thumb_path.as_posix()

    except Exception as exc:

        print(
            f"WARNING: thumbnail failed "
            f"for {path}: {exc}"
        )

        return path.as_posix()


# ============================================================
# DISCOVER IMAGES
# ============================================================

records = []

directories = sorted(
    [
        path
        for path in ROOT.iterdir()
        if path.is_dir()
        and path.name not in IGNORE_DIRS
        and not path.name.startswith(".")
    ],
    key=lambda p: natural_key(p.name)
)


print()
print("Building justified chromatic wall")
print("=" * 60)
print()


for directory in directories:

    files = sorted(
        [
            path
            for path in directory.iterdir()
            if path.is_file()
            and path.suffix.lower()
            in IMAGE_EXTENSIONS
        ],
        key=lambda p: natural_key(
            p.name
        )
    )

    if not files:
        continue

    print(
        f"{directory.name:30} "
        f"{len(files):5} images"
    )

    for index, path in enumerate(
        files,
        1
    ):

        width, height = image_dimensions(
            path
        )

        if height <= 0:
            height = 1

        aspect = width / height

        # Prevent bizarre panoramas from wrecking
        # the justified layout.
        aspect = max(
            0.25,
            min(aspect, 4.0)
        )

        rgb = representative_color(
            path
        )

        colour = color_features(
            rgb
        )

        thumb = make_thumbnail(
            path
        )

        records.append({
            "category":
                directory.name,

            "categoryLabel":
                display_category(
                    directory.name
                ),

            "filename":
                path.name,

            "title":
                display_title(
                    path.name
                ),

            "src":
                path.as_posix(),

            "thumb":
                thumb,

            "width":
                width,

            "height":
                height,

            "aspect":
                aspect,

            **colour,
        })

        if index % 25 == 0:

            print(
                f"    processed "
                f"{index}/{len(files)}"
            )


# ============================================================
# CHROMATIC ORDER
# ============================================================

def color_sort_key(item):

    # Grayscale / near-grayscale images are
    # collected after the chromatic sequence.

    if item["s"] < 0.10:

        return (
            1,
            item["v"],
            item["s"],
            item["filename"].casefold(),
        )

    return (
        0,
        item["h"],
        item["v"],
        item["s"],
        item["filename"].casefold(),
    )


records.sort(
    key=color_sort_key
)


# ============================================================
# SERIALIZE
# ============================================================

DATA = json.dumps(
    records,
    ensure_ascii=False
).replace(
    "</",
    "<\\/"
)


# ============================================================
# HTML
# ============================================================

PAGE = r'''<!doctype html>

<html lang="en">

<head>

<meta charset="utf-8">

<meta
    name="viewport"
    content="width=device-width, initial-scale=1"
>

<title>Chromatic Image Wall</title>

<style>

:root {
    color-scheme: dark;

    --bg: #070809;
    --panel: rgba(15,17,20,.93);
    --line: rgba(255,255,255,.16);
    --text: #f0f0ee;
    --muted: #999fa8;
}

* {
    box-sizing: border-box;
}

html,
body {
    width: 100%;
    height: 100%;

    margin: 0;
    overflow: hidden;

    background: var(--bg);
    color: var(--text);

    font-family:
        ui-sans-serif,
        system-ui,
        -apple-system,
        BlinkMacSystemFont,
        "Segoe UI",
        sans-serif;
}


/* ======================================================== */
/* WALL VIEWPORT                                            */
/* ======================================================== */

#viewport {
    position: fixed;
    inset: 0;

    overflow: hidden;

    cursor: grab;
    user-select: none;

    background:
        radial-gradient(
            circle at center,
            #15171a,
            #070809 72%
        );
}

#viewport.dragging {
    cursor: grabbing;
}


#world {
    position: absolute;

    left: 0;
    top: 0;

    transform-origin: 0 0;

    will-change: transform;
}


/* ======================================================== */
/* MOSAIC IMAGES                                            */
/* ======================================================== */

.tile {
    position: absolute;

    overflow: hidden;

    background: #111;

    cursor: pointer;

    box-shadow:
        0 0 0 1px
        rgba(255,255,255,.06);

    transition:
        opacity .14s ease,
        filter .14s ease,
        box-shadow .14s ease;
}


.tile:hover {
    z-index: 20;

    box-shadow:
        0 0 0 2px
        rgba(255,255,255,.95),
        0 10px 32px
        rgba(0,0,0,.7);
}


.tile img {
    display: block;

    width: 100%;
    height: 100%;

    /*
     * Because each tile itself now has the
     * image's aspect ratio, there is neither
     * cropping nor letterboxing.
     */
    object-fit: fill;

    pointer-events: none;

    user-select: none;
}


.tile.hidden {
    opacity: .025;

    filter:
        grayscale(1)
        brightness(.45);
}


/* ======================================================== */
/* PANELS                                                   */
/* ======================================================== */

.panel {
    position: fixed;

    z-index: 100;

    border:
        1px solid
        var(--line);

    border-radius: 8px;

    background:
        var(--panel);

    backdrop-filter:
        blur(10px);

    box-shadow:
        0 8px 28px
        rgba(0,0,0,.38);
}


#title-panel {
    top: 14px;
    left: 14px;

    padding:
        11px 14px;
}


#title-panel strong {
    display: block;

    font-size: 13px;

    letter-spacing:
        .08em;
}


#title-panel span {
    display: block;

    margin-top: 4px;

    color:
        var(--muted);

    font-size:
        11px;
}


/* ======================================================== */
/* CONTROLS                                                 */
/* ======================================================== */

#controls {
    top: 14px;
    right: 14px;

    display: flex;

    gap: 7px;

    padding: 8px;
}


button,
select {
    border:
        1px solid
        #393d44;

    border-radius: 6px;

    color: var(--text);

    background:
        #181a1f;

    font: inherit;
}


button {
    padding:
        7px 10px;

    cursor: pointer;
}


button:hover {
    background:
        #272a30;
}


select {
    max-width: 230px;

    padding:
        7px 9px;
}


#zoom-panel {
    left: 14px;
    bottom: 14px;

    padding:
        8px 11px;

    color:
        var(--muted);

    font-size:
        11px;
}


#help {
    right: 14px;
    bottom: 14px;

    padding:
        8px 11px;

    color:
        var(--muted);

    font-size:
        11px;
}


/* ======================================================== */
/* FULL-SCREEN IMAGE VIEWER                                 */
/* ======================================================== */

#viewer {
    display: none;

    position: fixed;

    inset: 0;

    z-index: 1000;

    overflow: hidden;

    background:
        rgba(3,4,5,.985);

    cursor: grab;

    touch-action: none;
}


#viewer.open {
    display: block;
}


#viewer.dragging {
    cursor: grabbing;
}


#viewer-stage {
    position: absolute;

    inset: 0;

    overflow: hidden;
}


#viewer-image {
    position: absolute;

    left: 0;
    top: 0;

    display: block;

    max-width: none;
    max-height: none;

    transform-origin: 0 0;

    user-select: none;
    pointer-events: none;

    will-change: transform;
}


/* ======================================================== */
/* VIEWER TOOLBAR                                           */
/* ======================================================== */

#viewer-toolbar {
    position: fixed;

    z-index: 1020;

    top: 14px;
    right: 14px;

    display: flex;

    gap: 7px;

    padding: 8px;

    border:
        1px solid
        var(--line);

    border-radius: 8px;

    background:
        rgba(15,17,20,.94);

    backdrop-filter:
        blur(10px);
}


#viewer-info {
    position: fixed;

    z-index: 1020;

    left: 14px;
    bottom: 14px;

    max-width:
        min(700px, calc(100vw - 28px));

    padding:
        10px 13px;

    border:
        1px solid
        var(--line);

    border-radius: 8px;

    background:
        rgba(15,17,20,.94);

    backdrop-filter:
        blur(10px);
}


#viewer-title {
    overflow: hidden;

    font-size: 13px;

    text-overflow:
        ellipsis;

    white-space: nowrap;
}


#viewer-meta {
    margin-top: 4px;

    color:
        var(--muted);

    font-size: 11px;
}


/* ======================================================== */
/* MOBILE                                                   */
/* ======================================================== */

@media (
    max-width: 700px
) {

    #controls {
        top: auto;
        right: 8px;
        bottom: 8px;

        max-width: 82vw;

        flex-wrap: wrap;

        justify-content:
            flex-end;
    }

    #help {
        display: none;
    }

}

</style>

</head>


<body>


<div id="viewport">
    <div id="world"></div>
</div>


<div
    id="title-panel"
    class="panel"
>
    <strong>
        CHROMATIC IMAGE WALL
    </strong>

    <span id="count"></span>
</div>


<div
    id="controls"
    class="panel"
>

    <select id="category">

        <option value="all">
            All categories
        </option>

    </select>

    <button id="fit-wall">
        Fit
    </button>

    <button id="wall-minus">
        −
    </button>

    <button id="wall-plus">
        +
    </button>

</div>


<div
    id="zoom-panel"
    class="panel"
>
    Wall
    <span id="wall-zoom-value">
        100%
    </span>
</div>


<div
    id="help"
    class="panel"
>
    drag to pan · wheel to zoom · click image to open
</div>


<!-- ===================================================== -->
<!-- IMAGE VIEWER                                          -->
<!-- ===================================================== -->

<div id="viewer">

    <div id="viewer-stage">

        <img
            id="viewer-image"
            alt=""
        >

    </div>


    <div id="viewer-toolbar">

        <button
            id="viewer-minus"
            title="Zoom out"
        >
            −
        </button>

        <button
            id="viewer-fit"
            title="Fit image"
        >
            Fit
        </button>

        <button
            id="viewer-actual"
            title="Actual size"
        >
            100%
        </button>

        <button
            id="viewer-plus"
            title="Zoom in"
        >
            +
        </button>

        <button
            id="viewer-close"
            title="Close"
        >
            ×
        </button>

    </div>


    <div id="viewer-info">

        <div id="viewer-title"></div>

        <div id="viewer-meta"></div>

    </div>

</div>


<script>

const IMAGES = __DATA__;


/* ======================================================== */
/* WALL CONFIGURATION                                       */
/* ======================================================== */

const WALL_WIDTH = 4200;

const TARGET_ROW_HEIGHT = 230;

const GAP = 5;


/*
 * Rather than assigning every image the same rectangle,
 * construct rows whose images preserve their aspect ratios.
 *
 * Each completed row is scaled so that it fills WALL_WIDTH.
 */

function buildJustifiedLayout(images) {

    const placements = [];

    let row = [];

    let aspectSum = 0;

    let y = 0;


    function commitRow(
        items,
        sum,
        finalRow = false
    ) {

        if (!items.length) {
            return;
        }


        const gaps =
            GAP * (items.length - 1);


        let rowHeight;


        if (finalRow) {

            /*
             * Don't stretch a sparse final row to ridiculous
             * dimensions.
             */

            rowHeight =
                Math.min(
                    TARGET_ROW_HEIGHT,
                    (
                        WALL_WIDTH
                        - gaps
                    ) / sum
                );

        } else {

            rowHeight =
                (
                    WALL_WIDTH
                    - gaps
                ) / sum;
        }


        let x = 0;


        items.forEach(
            (image, index) => {

                let width =
                    image.aspect
                    * rowHeight;


                /*
                 * Absorb floating-point remainder into the
                 * last tile of a completed row.
                 */

                if (
                    !finalRow
                    &&
                    index ===
                    items.length - 1
                ) {

                    width =
                        WALL_WIDTH - x;
                }


                placements.push({
                    image,
                    x,
                    y,
                    width,
                    height:
                        rowHeight
                });


                x +=
                    width + GAP;
            }
        );


        y +=
            rowHeight + GAP;
    }


    for (
        const image
        of images
    ) {

        row.push(
            image
        );

        aspectSum +=
            image.aspect;


        const estimatedWidth =
            aspectSum
            * TARGET_ROW_HEIGHT
            +
            GAP
            * (row.length - 1);


        if (
            estimatedWidth
            >= WALL_WIDTH
        ) {

            commitRow(
                row,
                aspectSum,
                false
            );

            row = [];
            aspectSum = 0;
        }
    }


    if (row.length) {

        commitRow(
            row,
            aspectSum,
            true
        );
    }


    return {
        placements,
        width:
            WALL_WIDTH,
        height:
            Math.max(
                1,
                y - GAP
            )
    };
}


const LAYOUT =
    buildJustifiedLayout(
        IMAGES
    );


/* ======================================================== */
/* WALL STATE                                               */
/* ======================================================== */

let wallScale = 1;

let wallX = 0;
let wallY = 0;

let wallPointerDown = false;
let wallDragged = false;

let wallStartPointerX = 0;
let wallStartPointerY = 0;

let wallStartX = 0;
let wallStartY = 0;

let pressedImage = null;

const DRAG_THRESHOLD = 6;


/* ======================================================== */
/* ELEMENTS                                                 */
/* ======================================================== */

const viewport =
    document.getElementById(
        "viewport"
    );

const world =
    document.getElementById(
        "world"
    );

const categorySelect =
    document.getElementById(
        "category"
    );

const count =
    document.getElementById(
        "count"
    );

const wallZoomValue =
    document.getElementById(
        "wall-zoom-value"
    );


const viewer =
    document.getElementById(
        "viewer"
    );

const viewerImage =
    document.getElementById(
        "viewer-image"
    );

const viewerTitle =
    document.getElementById(
        "viewer-title"
    );

const viewerMeta =
    document.getElementById(
        "viewer-meta"
    );


/* ======================================================== */
/* CREATE MOSAIC                                            */
/* ======================================================== */

function createWall() {

    world.style.width =
        LAYOUT.width + "px";

    world.style.height =
        LAYOUT.height + "px";


    const fragment =
        document.createDocumentFragment();


    for (
        const placement
        of LAYOUT.placements
    ) {

        const image =
            placement.image;


        const tile =
            document.createElement(
                "div"
            );


        tile.className =
            "tile";


        tile.style.left =
            placement.x + "px";

        tile.style.top =
            placement.y + "px";

        tile.style.width =
            placement.width + "px";

        tile.style.height =
            placement.height + "px";


        tile.dataset.category =
            image.category;


        /*
         * Store the actual image record on the DOM node.
         * The pointer handler can therefore open whichever
         * tile was pressed without relying on click events.
         */

        tile._imageRecord =
            image;


        const img =
            document.createElement(
                "img"
            );


        img.src =
            image.thumb;

        img.alt =
            image.title;

        img.loading =
            "lazy";

        img.decoding =
            "async";

        img.draggable =
            false;


        tile.appendChild(
            img
        );


        fragment.appendChild(
            tile
        );
    }


    world.appendChild(
        fragment
    );


    count.textContent =
        `${IMAGES.length} images · justified chromatic mosaic`;
}


/* ======================================================== */
/* CATEGORIES                                               */
/* ======================================================== */

function buildCategories() {

    const categories =
        [
            ...new Set(
                IMAGES.map(
                    image =>
                        image.category
                )
            )
        ].sort();


    for (
        const category
        of categories
    ) {

        const option =
            document.createElement(
                "option"
            );


        option.value =
            category;


        option.textContent =
            category.replaceAll(
                "-",
                " "
            );


        categorySelect.appendChild(
            option
        );
    }
}


function applyCategoryFilter() {

    const selected =
        categorySelect.value;

    let visible = 0;


    document
        .querySelectorAll(
            ".tile"
        )
        .forEach(
            tile => {

                const show =
                    selected === "all"
                    ||
                    tile.dataset.category
                    === selected;


                tile.classList.toggle(
                    "hidden",
                    !show
                );


                if (show) {
                    visible++;
                }
            }
        );


    if (
        selected === "all"
    ) {

        count.textContent =
            `${IMAGES.length} images · justified chromatic mosaic`;

    } else {

        count.textContent =
            `${visible} of ${IMAGES.length} images · ${selected}`;
    }
}


/* ======================================================== */
/* WALL TRANSFORM                                           */
/* ======================================================== */

function applyWallTransform() {

    world.style.transform =
        `translate(${wallX}px, ${wallY}px) scale(${wallScale})`;


    wallZoomValue.textContent =
        Math.round(
            wallScale * 100
        ) + "%";
}


function fitWall() {

    const margin = 42;


    const sx =
        (
            innerWidth
            - margin * 2
        ) / LAYOUT.width;


    const sy =
        (
            innerHeight
            - margin * 2
        ) / LAYOUT.height;


    wallScale =
        Math.min(
            sx,
            sy
        );


    wallScale =
        Math.max(
            .02,
            Math.min(
                wallScale,
                4
            )
        );


    wallX =
        (
            innerWidth
            - LAYOUT.width
            * wallScale
        ) / 2;


    wallY =
        (
            innerHeight
            - LAYOUT.height
            * wallScale
        ) / 2;


    applyWallTransform();
}


function zoomWallAt(
    screenX,
    screenY,
    factor
) {

    const oldScale =
        wallScale;


    const newScale =
        Math.max(
            .025,
            Math.min(
                oldScale * factor,
                8
            )
        );


    const wx =
        (
            screenX - wallX
        ) / oldScale;


    const wy =
        (
            screenY - wallY
        ) / oldScale;


    wallScale =
        newScale;


    wallX =
        screenX
        - wx * wallScale;


    wallY =
        screenY
        - wy * wallScale;


    applyWallTransform();
}


/* ======================================================== */
/* WALL POINTER INTERACTION                                 */
/* ======================================================== */

viewport.addEventListener(
    "pointerdown",
    event => {

        if (
            viewer.classList.contains(
                "open"
            )
        ) {
            return;
        }


        wallPointerDown =
            true;

        wallDragged =
            false;


        wallStartPointerX =
            event.clientX;

        wallStartPointerY =
            event.clientY;


        wallStartX =
            wallX;

        wallStartY =
            wallY;


        /*
         * Remember the tile underneath the initial press.
         */

        const tile =
            event.target.closest(
                ".tile"
            );


        pressedImage =
            tile
            ? tile._imageRecord
            : null;


        viewport.setPointerCapture(
            event.pointerId
        );


        viewport.classList.add(
            "dragging"
        );
    }
);


viewport.addEventListener(
    "pointermove",
    event => {

        if (!wallPointerDown) {
            return;
        }


        const dx =
            event.clientX
            - wallStartPointerX;


        const dy =
            event.clientY
            - wallStartPointerY;


        const distance =
            Math.hypot(
                dx,
                dy
            );


        if (
            distance >=
            DRAG_THRESHOLD
        ) {

            wallDragged =
                true;
        }


        if (!wallDragged) {
            return;
        }


        wallX =
            wallStartX + dx;


        wallY =
            wallStartY + dy;


        applyWallTransform();
    }
);


viewport.addEventListener(
    "pointerup",
    event => {

        if (!wallPointerDown) {
            return;
        }


        wallPointerDown =
            false;


        viewport.classList.remove(
            "dragging"
        );


        try {

            viewport.releasePointerCapture(
                event.pointerId
            );

        } catch (_) {
        }


        /*
         * THIS is the image-open action.
         *
         * We don't wait for a browser click event.
         * If the pointer did not travel far enough to
         * constitute a pan, open the image directly.
         */

        if (
            !wallDragged
            &&
            pressedImage
        ) {

            openViewer(
                pressedImage
            );
        }


        pressedImage =
            null;
    }
);


viewport.addEventListener(
    "pointercancel",
    () => {

        wallPointerDown =
            false;

        wallDragged =
            false;

        pressedImage =
            null;


        viewport.classList.remove(
            "dragging"
        );
    }
);


viewport.addEventListener(
    "wheel",
    event => {

        event.preventDefault();


        const factor =
            Math.exp(
                -event.deltaY
                * .0012
            );


        zoomWallAt(
            event.clientX,
            event.clientY,
            factor
        );
    },
    {
        passive: false
    }
);


/* ======================================================== */
/* IMAGE VIEWER STATE                                       */
/* ======================================================== */

let viewerScale = 1;

let viewerX = 0;
let viewerY = 0;

let viewerNaturalWidth = 1;
let viewerNaturalHeight = 1;

let viewerFitScale = 1;

let viewerPointerDown = false;

let viewerStartPointerX = 0;
let viewerStartPointerY = 0;

let viewerStartX = 0;
let viewerStartY = 0;


/* ======================================================== */
/* VIEWER TRANSFORM                                         */
/* ======================================================== */

function applyViewerTransform() {

    viewerImage.style.transform =
        `translate(${viewerX}px, ${viewerY}px) scale(${viewerScale})`;
}


function fitViewerImage() {

    if (
        !viewerNaturalWidth
        ||
        !viewerNaturalHeight
    ) {
        return;
    }


    /*
     * Leave some breathing room for the toolbar
     * and filename display.
     */

    const marginX = 70;
    const marginY = 100;


    const availableWidth =
        Math.max(
            100,
            innerWidth - marginX
        );


    const availableHeight =
        Math.max(
            100,
            innerHeight - marginY
        );


    viewerFitScale =
        Math.min(
            availableWidth
            / viewerNaturalWidth,

            availableHeight
            / viewerNaturalHeight,

            1
        );


    viewerScale =
        viewerFitScale;


    viewerX =
        (
            innerWidth
            - viewerNaturalWidth
            * viewerScale
        ) / 2;


    viewerY =
        (
            innerHeight
            - viewerNaturalHeight
            * viewerScale
        ) / 2;


    applyViewerTransform();
}


function actualSizeViewer() {

    viewerScale = 1;


    viewerX =
        (
            innerWidth
            - viewerNaturalWidth
        ) / 2;


    viewerY =
        (
            innerHeight
            - viewerNaturalHeight
        ) / 2;


    applyViewerTransform();
}


function zoomViewerAt(
    screenX,
    screenY,
    factor
) {

    const oldScale =
        viewerScale;


    const newScale =
        Math.max(
            .03,
            Math.min(
                oldScale * factor,
                12
            )
        );


    const ix =
        (
            screenX
            - viewerX
        ) / oldScale;


    const iy =
        (
            screenY
            - viewerY
        ) / oldScale;


    viewerScale =
        newScale;


    viewerX =
        screenX
        - ix * viewerScale;


    viewerY =
        screenY
        - iy * viewerScale;


    applyViewerTransform();
}


/* ======================================================== */
/* OPEN / CLOSE VIEWER                                      */
/* ======================================================== */

function openViewer(image) {

    viewer.classList.add(
        "open"
    );


    viewerTitle.textContent =
        image.title;


    viewerMeta.textContent =
        `${image.categoryLabel} · ${image.filename}`;


    /*
     * Start blank while the original loads.
     */

    viewerImage.removeAttribute(
        "src"
    );


    viewerNaturalWidth =
        image.width;

    viewerNaturalHeight =
        image.height;


    viewerImage.onload =
        () => {

            viewerNaturalWidth =
                viewerImage.naturalWidth;

            viewerNaturalHeight =
                viewerImage.naturalHeight;


            viewerImage.style.width =
                viewerNaturalWidth
                + "px";


            viewerImage.style.height =
                viewerNaturalHeight
                + "px";


            fitViewerImage();
        };


    /*
     * Full-resolution original is loaded only now.
     */

    viewerImage.src =
        image.src;
}


function closeViewer() {

    viewer.classList.remove(
        "open"
    );


    viewerImage.onload =
        null;


    viewerImage.removeAttribute(
        "src"
    );


    viewerPointerDown =
        false;
}


/* ======================================================== */
/* VIEWER PAN                                               */
/* ======================================================== */

viewer.addEventListener(
    "pointerdown",
    event => {

        /*
         * Toolbar buttons should behave as buttons,
         * not initiate image panning.
         */

        if (
            event.target.closest(
                "#viewer-toolbar"
            )
            ||
            event.target.closest(
                "#viewer-info"
            )
        ) {
            return;
        }


        viewerPointerDown =
            true;


        viewerStartPointerX =
            event.clientX;

        viewerStartPointerY =
            event.clientY;


        viewerStartX =
            viewerX;

        viewerStartY =
            viewerY;


        viewer.setPointerCapture(
            event.pointerId
        );


        viewer.classList.add(
            "dragging"
        );
    }
);


viewer.addEventListener(
    "pointermove",
    event => {

        if (!viewerPointerDown) {
            return;
        }


        const dx =
            event.clientX
            - viewerStartPointerX;


        const dy =
            event.clientY
            - viewerStartPointerY;


        viewerX =
            viewerStartX + dx;


        viewerY =
            viewerStartY + dy;


        applyViewerTransform();
    }
);


viewer.addEventListener(
    "pointerup",
    event => {

        viewerPointerDown =
            false;


        viewer.classList.remove(
            "dragging"
        );


        try {

            viewer.releasePointerCapture(
                event.pointerId
            );

        } catch (_) {
        }
    }
);


viewer.addEventListener(
    "pointercancel",
    () => {

        viewerPointerDown =
            false;


        viewer.classList.remove(
            "dragging"
        );
    }
);


/* ======================================================== */
/* VIEWER WHEEL ZOOM                                        */
/* ======================================================== */

viewer.addEventListener(
    "wheel",
    event => {

        event.preventDefault();


        const factor =
            Math.exp(
                -event.deltaY
                * .0015
            );


        zoomViewerAt(
            event.clientX,
            event.clientY,
            factor
        );
    },
    {
        passive: false
    }
);


/* ======================================================== */
/* DOUBLE CLICK                                             */
/* ======================================================== */

viewer.addEventListener(
    "dblclick",
    event => {

        if (
            event.target.closest(
                "#viewer-toolbar"
            )
        ) {
            return;
        }


        /*
         * If approximately at fitted size,
         * jump to 100%.
         *
         * Otherwise return to fit.
         */

        if (
            Math.abs(
                viewerScale
                - viewerFitScale
            ) < .02
        ) {

            const oldScale =
                viewerScale;


            const ix =
                (
                    event.clientX
                    - viewerX
                ) / oldScale;


            const iy =
                (
                    event.clientY
                    - viewerY
                ) / oldScale;


            viewerScale = 1;


            viewerX =
                event.clientX
                - ix;


            viewerY =
                event.clientY
                - iy;


            applyViewerTransform();

        } else {

            fitViewerImage();
        }
    }
);


/* ======================================================== */
/* WALL BUTTONS                                             */
/* ======================================================== */

document
    .getElementById(
        "fit-wall"
    )
    .addEventListener(
        "click",
        fitWall
    );


document
    .getElementById(
        "wall-plus"
    )
    .addEventListener(
        "click",
        () => {

            zoomWallAt(
                innerWidth / 2,
                innerHeight / 2,
                1.35
            );
        }
    );


document
    .getElementById(
        "wall-minus"
    )
    .addEventListener(
        "click",
        () => {

            zoomWallAt(
                innerWidth / 2,
                innerHeight / 2,
                1 / 1.35
            );
        }
    );


categorySelect.addEventListener(
    "change",
    applyCategoryFilter
);


/* ======================================================== */
/* VIEWER BUTTONS                                           */
/* ======================================================== */

document
    .getElementById(
        "viewer-close"
    )
    .addEventListener(
        "click",
        event => {

            event.stopPropagation();

            closeViewer();
        }
    );


document
    .getElementById(
        "viewer-fit"
    )
    .addEventListener(
        "click",
        event => {

            event.stopPropagation();

            fitViewerImage();
        }
    );


document
    .getElementById(
        "viewer-actual"
    )
    .addEventListener(
        "click",
        event => {

            event.stopPropagation();

            actualSizeViewer();
        }
    );


document
    .getElementById(
        "viewer-plus"
    )
    .addEventListener(
        "click",
        event => {

            event.stopPropagation();


            zoomViewerAt(
                innerWidth / 2,
                innerHeight / 2,
                1.4
            );
        }
    );


document
    .getElementById(
        "viewer-minus"
    )
    .addEventListener(
        "click",
        event => {

            event.stopPropagation();


            zoomViewerAt(
                innerWidth / 2,
                innerHeight / 2,
                1 / 1.4
            );
        }
    );


/* ======================================================== */
/* KEYBOARD                                                 */
/* ======================================================== */

document.addEventListener(
    "keydown",
    event => {

        if (
            viewer.classList.contains(
                "open"
            )
        ) {

            if (
                event.key ===
                "Escape"
            ) {

                closeViewer();
                return;
            }


            if (
                event.key === "f"
                ||
                event.key === "F"
            ) {

                fitViewerImage();
                return;
            }


            if (
                event.key === "0"
            ) {

                actualSizeViewer();
                return;
            }


            if (
                event.key === "+"
                ||
                event.key === "="
            ) {

                zoomViewerAt(
                    innerWidth / 2,
                    innerHeight / 2,
                    1.4
                );

                return;
            }


            if (
                event.key === "-"
            ) {

                zoomViewerAt(
                    innerWidth / 2,
                    innerHeight / 2,
                    1 / 1.4
                );

                return;
            }


            return;
        }


        if (
            event.key === "f"
            ||
            event.key === "F"
        ) {

            fitWall();
        }
    }
);


/* ======================================================== */
/* RESIZE                                                   */
/* ======================================================== */

window.addEventListener(
    "resize",
    () => {

        if (
            viewer.classList.contains(
                "open"
            )
        ) {

            fitViewerImage();
        }
    }
);


/* ======================================================== */
/* INITIALIZE                                               */
/* ======================================================== */

createWall();

buildCategories();


requestAnimationFrame(
    fitWall
);

</script>

</body>

</html>
'''


# ============================================================
# WRITE HTML
# ============================================================

PAGE = PAGE.replace(
    "__DATA__",
    DATA
)


OUTPUT.write_text(
    PAGE,
    encoding="utf-8"
)


# ============================================================
# REPORT
# ============================================================

thumb_files = list(
    THUMB_DIR.glob(
        "*.webp"
    )
)


thumb_bytes = sum(
    path.stat().st_size
    for path in thumb_files
)


thumb_mb = (
    thumb_bytes
    / 1024
    / 1024
)


print()
print("=" * 60)
print("DONE")
print("=" * 60)
print()

print(
    f"Generated:   {OUTPUT}"
)

print(
    f"Images:      {len(records)}"
)

print(
    f"Wall size:   {4200}px wide"
)

print(
    f"Thumbnails:  {len(thumb_files)}"
)

print(
    f"Thumb size:  {thumb_mb:.1f} MB"
)

print()
print(
    "Open wall.html in your browser."
)
print()
