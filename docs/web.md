# Play it in a browser (GitHub Pages)

The game also exports to the web, and a GitHub Action publishes it for free.

**One-time setup**
1. The repository must be **public** (GitHub Pages is free only for public repositories on a free account; a
   private repository needs a paid plan). If you'd rather keep the code private, export the web build
   (below) and upload the `build/web` folder to a free static host such as itch.io (type "HTML") or
   Cloudflare Pages instead.
2. In the repository on GitHub: **Settings > Pages > Source: GitHub Actions**.
3. Push to `main`. The workflow [.github/workflows/pages.yml](../.github/workflows/pages.yml) installs Godot
   and its export templates, exports the **Web** preset and deploys it. The link is shown in the workflow
   run (and under Settings > Pages): `https://<your-user>.github.io/<repo-name>/`. If you upgrade Godot,
   change `GODOT_VERSION` in that file to match.

**Build and try it locally** (needs the Godot export templates, installed through the editor once:
Editor > Manage Export Templates)
```bash
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
cd build/web && python -m http.server 8060     # then open http://localhost:8060 in a browser
```
(Opening `index.html` as a file does not work: browsers only run WebAssembly from a web server.)

Notes: the web preset uses the single-threaded build, so it needs no special server headers and runs on
GitHub Pages; it is somewhat slower than the app. The phone controls appear in phone browsers (play in
landscape); on a computer you use the keyboard. `SABOTAGE_LEVEL` and the other environment variables do not
exist on the web: it always starts on the first level. The first load downloads about 10 MB (compressed).

