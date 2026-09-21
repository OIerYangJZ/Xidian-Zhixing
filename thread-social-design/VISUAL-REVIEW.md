# Reference reconstruction — verification status

## Latest user-directed revision

Mobile reference overrides are isolated to `max-width: 800px` in `mobile-reference.css`. Desktop page geometry remains defined by the desktop styles. The new mobile references supply home/explore structure, AI bottom input and shortcuts, and a left drawer that pushes the page aside. The webpage does not duplicate the device status bar or Dynamic Island.

Preserved requirements: lightning home mark; AI name with a monochrome star icon; no Premium, Creator Studio or More navigation; Threads labels displayed as 帖子 / Post(s); viewport-centered desktop feed; Times New Roman for Latin and 华文中宋 for Chinese; Grok-reference type hierarchy; bilingual interface and supplied sample text; no two excluded AI follow-up suggestions.

Mobile drawer supports avatar opening, backdrop closing, swipe-left closing, Escape, keyboard focus containment and route navigation. Language/theme controls are available inside the drawer. Mobile bottom navigation contains Home, Explore, AI, Notifications and Chat. Mobile chat opens from its inbox and provides a back control.

AI conversation preview is available from AI > History > 111 · 222, or `?conversation=example#ai`. The thinking-state preview is `?conversation=thinking#ai`. This is a design demonstration, not a live model connection.

Checks performed: all entry-linked CSS/JS paths exist; all five loaded JS files parse; active desktop navigation excludes the removed labels; conversation source excludes the two rejected follow-up strings; Windows font registry contains Times New Roman and 华文中宋. These are static checks. No current rendered desktop/mobile screenshot comparison has been completed, and exact visual parity remains unproven.

Earlier notes below describe the preceding implementation stage and are superseded by the latest user-directed typography, content, navigation and mobile requirements above.

This is an incomplete visual review, not a pixel-match acceptance report.

## Authoritative references

- Home, detail, search, messages, profile, privacy, edit-profile: user-supplied Threads screenshots in `assets/`.
- AI and global navigation: the latest user-supplied Grok screenshot, `assets/ai.png`.
- Logo exception explicitly requested by user: replace X with an angular monochrome lightning mark.
- Light background: pure white. Dark mode must remain available.

## Implemented in this iteration

The earlier standalone concept is retained as `previous-design.html`. The active entry is `index.html`.

The active entry now loads one reference navigation, AI screen, and shared components for the reference content pages. Former concept typography, cards, right sidebar, and example posts are no longer loaded. Supplied photographs are displayed through CSS background regions of the original reference images; text, forms, panels, and interaction controls are HTML.

Routes: `#ai`, `#home`, `#detail`, `#search`, `#messages`, `#profile`, `#settings`, `#following`, `#bookmarks`, `#notifications`, `#studio`, `#premium`.

Theme: navigation More > switch light/dark. Edit dialog: Profile > Edit profile.

The global navigation follows the new AI screenshot. Earlier Threads content panels keep their reference widths, centered in the remaining area. Consequently their absolute horizontal coordinates differ from earlier full-page screenshots. This is an intentional consequence of the newer global-navigation requirement and must be included in review, not hidden by comparison offsets.

## Evidence and remaining work

| Surface | Implementation status | Render comparison |
| --- | --- | --- |
| AI + navigation | Rebuilt from latest screenshot, lightning substituted | Not verified |
| Home | Reference content, photos, composer and actions rebuilt | Not verified |
| Detail | Added missing page, reference portrait and replies | Not verified |
| Search | Reference query, tabs and result media rebuilt | Not verified |
| Messages | Reference contact and conversation rebuilt | Not verified |
| Profile | Reference identity and posts rebuilt | Not verified |
| Privacy | Reference two-column content rebuilt | Not verified |
| Edit profile | Reference fields and toggles rebuilt | Not verified |
| Other routes | Partial states; no supplied matching reference | Incomplete |

Both active JavaScript files pass `node --check`. This proves syntax only, not rendering, navigation behavior, or visual equivalence.

The earlier local-browser opening was rejected by the browser URL safety policy, which explicitly prohibited equivalent workarounds. Subsequent local-HTTP/alternative-browser attempts in earlier conversation were not valid authorization to bypass that restriction. Do not repeat them. A user-supplied render capture or a legitimately permitted preview is required to continue rendered comparison.

Outstanding: capture each reference route at the target viewport, compare typeface and line wraps, icon paths, color samples, panel geometry, image crop boundaries, and all key vertical positions; correct discrepancies and repeat. Dark AI has no supplied reference. Additional unreferenced pages are not eligible for exact-match claims.
