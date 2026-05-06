# docs/visuals

Social media and website-ready graphics for the AWACS Zero Trust Lab Data Consolidation project.

## Files

| File | Format | Size | Use |
|------|--------|------|-----|
| `social-linkedin-twitter.svg` | SVG (vector) | 1200×628 | LinkedIn posts, Twitter/X cards, website hero banner |
| `social-instagram.svg` | SVG (vector) | 1080×1080 | Instagram feed, Facebook square posts |
| `website-mermaid-diagrams.md` | Mermaid/Markdown | — | Website architecture pages, GitHub README, docs sites |

## Converting SVG to PNG

Open the SVG in a browser, right-click and "Save as image," or use one of these tools:

**Inkscape (free, recommended):**
```
inkscape social-linkedin-twitter.svg --export-type=png --export-dpi=144 -o social-linkedin-twitter.png
```

**Node (no install needed):**
```
npx svgexport social-linkedin-twitter.svg social-linkedin-twitter.png 1200:628
```

**Browser method:** Open the `.svg` file directly in Chrome or Edge, use DevTools device emulation to set the exact pixel size, then screenshot.

## Design Notes

- Both SVGs use a **dark navy palette** (`#040c1a` background) consistent with AWACS brand.
- The **concentric ring diagram** maps directly to the trust zones defined in `architecture/trust-boundaries.md` (Z1–Z8).
- Component callout dots sit on the correct ring for each component (Ring 4 = workstation, Ring 2 = Azure boundary, Ring 1 = high trust).
- The **six property cards** on the LinkedIn version correspond exactly to the six zero-trust design decisions documented in `docs/decisions/`.
- Fonts: `'Segoe UI', Arial, Helvetica, sans-serif` — standard system fonts, no web font dependency.

## Zero Trust Ring Key

| Ring | Color | Trust Zone | Components |
|------|-------|------------|------------|
| Outer (5) | Red | Untrusted Internet (Z3) | — |
| Ring 4 | Orange | Low Trust — Lab Workstation (Z1) | Scheduled Task, push-files.ps1, SP Cert |
| Ring 3 | Amber | Identity Verification Layer | TLS, Entra ID token exchange |
| Ring 2 | Blue | Azure Cloud Boundary (Z4–Z7) | Key Vault, daily SAS, Log Analytics |
| Ring 1 | Green | High Trust Zone | WORM storage, immutability lock |
| Center | White lock | Protected Data | Files under 90-day immutable policy |
