# Gluon setup-mode preview

A static, browser-viewable rendering of Gluon's **config mode** (a.k.a. setup
mode) — the setup **wizard** *and* the **Advanced settings** pages (network,
WLAN, remote access / SSH keys, automatic updates, node role, …) — generated
with **mock data**. No router, no flashing, no Lua runtime needed to view it.

It renders against a real [Gluon](https://github.com/freifunk-gluon/gluon)
source checkout (pinned here as the `gluon` submodule), so it stays in sync with
upstream and **any package — including plugins — that registers config-mode
pages shows up automatically**.

It exists so config mode can be:

- **referred to** when discussing or reviewing changes (link to the hosted page),
- **eyeballed** while iterating on the theme/CSS or a model/section,
- **published from CI** as a GitHub Pages site.

## How it works

Config mode is a tree of pages registered by `entry()` controllers (the wizard
is just one such page). `generate.lua`:

1. runs the **real** controllers from every package in the Gluon checkout to
    build the same navigation tree the dispatcher builds;
2. for each `model()` entry, runs the **real** model file (and, for the wizard,
    every package's `config-mode/wizard/*.lua` section) against small stubbed
    backends (uci, `gluon.site`, platform, wireless, …);
3. walks each resulting form tree and emits HTML mirroring the gluon-web view
    templates, writing **one HTML file per page** with a working menu.

The output is paired with the unmodified `gluon.css` and `gluon-web-model.js`
from the checkout, so dependency show/hide, validation, dynamic lists and the
menu behave as on a device.

Pages that genuinely need live device state and fail to render **degrade to a
placeholder** (with the error) rather than breaking the whole site — so one
hardware-bound plugin can't take the preview down.

The only hand-written surface is the HTML emitter in `generate.lua`, which
mirrors the (rarely-changing) widget templates in
`gluon/package/gluon-web-model/files/lib/gluon/web/view/model/`.

## Usage

```sh
git clone --recurse-submodules <this-repo>
cd gluon-setup-mode-preview
./build.sh
python3 -m http.server -d out 8000
# open http://localhost:8000/
```

If you already cloned without submodules:

```sh
git submodule update --init gluon
```

`build.sh` renders against the `gluon` submodule by default; point it at any
other checkout with `GLUON_ROOT`:

```sh
GLUON_ROOT=~/src/gluon ./build.sh
```

It uses `lua`/`lua5.1` if present, otherwise falls back to `nix-shell -p
lua5_1`. Output lands in `out/` (git-ignored): `index.html` (redirects to the
wizard), one `*.html` per page, and `static/` holding the verbatim `gluon.css`
and `gluon-web-model.js`.

### Tracking upstream Gluon

The submodule pins a specific Gluon commit for reproducible local builds. To
render against the current upstream `main`:

```sh
git submodule update --remote gluon   # fast-forward the submodule to main's tip
./build.sh
```

Commit the bumped submodule pointer to publish that state. A manual CI run
does this refresh for one build without a commit (see below).

## Mock data

All the values a real router would read from uci/site live in the `MOCK`,
`MOCK.site` and `MOCK_UCI` tables at the top of `generate.lua`. Tweak them to
exercise different states, e.g.:

- `outdoor_device` / `cellular_device` — gate the outdoor section / cellular page,
- `mesh_vpn_provider = nil` — hide the wizard's mesh-VPN section,
- `MOCK_UCI.network.wan.proto = "static"` — reveal the static WAN address fields,
- `MOCK.site.roles.list` — the roles offered on the Node role page,
- `MOCK.domains` — the list offered by domain-select.

## CI / GitHub Pages

`.github/workflows/deploy.yml` builds the preview and deploys it to GitHub Pages
on every push to `main`, and on manual runs (**Actions → Build & deploy preview
→ Run workflow**). Builds render against the **pinned** `gluon` submodule
commit; a manual run additionally does `git submodule update --remote gluon`
first, so it previews Gluon's current `main` without a commit here. Pull
requests build (and fail on any `error500` render box) but do not deploy.

Enable publishing once via the repo's **Settings → Pages → Source → GitHub
Actions**; after that every push to `main` (and manual run) deploys.

## Caveats

- `template()` pages (e.g. Information) and `call()` actions (firmware upgrade)
    are shown in the navigation as **placeholders** — they render device-side
    templates/actions outside this static preview's scope.
- The WLAN page is rendered against **mock radios** (one 2.4 GHz, one 5 GHz)
    with representative txpower/HT-mode lists, since real values come from
    `iwinfo` on the device.
- The OpenStreetMap map widget (geo-location) is not rendered; its lat/lon
    fields are.
- Translations use the English source strings (plus a few mocked `gluon-site`
    keys); this is a layout/behaviour preview, not an i18n preview.
- The emitter mirrors the widget templates by hand. If those templates change,
    update `generate.lua` to match (the CI job and a glance at the pages make
    drift obvious).
