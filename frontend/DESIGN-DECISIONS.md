# Design decisions

Why the frontend looks the way it does. Each entry is a decision plus the
reason for it, so a change can be judged against the reason instead of taste.

Status: these choices were made by the developer without a design brief.
They are provisional until a `DESIGN.md` with the product's own direction
exists; when it does, it wins and this file gets updated to match.

## Color

Tokens live in `src/styles.css`. Every text pair meets WCAG AA (4.5:1) and
every control boundary or state indicator meets 3:1, in both themes.

| Role | Light | Dark | Why |
|------|-------|------|-----|
| Base (`--bg`, `--surface`) | warm paper `#f6f4f0` / white | `#141918` / `#1b2120` | A chat tool is read for hours; a slightly warm base is calmer than pure white. |
| Ink green (`--sidebar-*`, `--link`, `--focus`, `--mention-*`) | `#1d2b2a`, `#2c6158` | `#101615`, `#8cc7bb` | The one "brand" hue. It anchors navigation (sidebar) and marks everything you can follow: links, thread links, focus, mentions of other people. |
| Clay accent (`--accent*`) | `#b9532f` | `#e07a52` | Reserved for what needs *you*: unread badges, mentions of you, the primary action and send. Used nowhere else so it keeps meaning "look here". |
| Semantic | green `--online`, red `--danger` | lighter variants | Online presence and destructive or error states only. |

That is two hues (ink green, clay) plus two semantic colors. Blue and gold
were removed in audit 001 because nothing said what they meant.

- `--border` (light dividers) is for separators that only group content.
  `--border-control` is for anything you type into or press (inputs,
  buttons, reaction chips, the composer) and is 3:1 against the surface.
- The sidebar stays dark in both themes, so it brings its own focus color
  (white) and presence colors.

## Theme

Light is the default because the content is text. Dark exists for long
evening sessions. The app follows the device setting until the user picks
Light or Dark under Profile, Appearance (stored per browser).

## Typography

- System UI stack (`system-ui`, `-apple-system`, `Segoe UI`, `Roboto`):
  a chat app is a tool people sit in all day, so it should read like the rest
  of their OS, render instantly, and need no webfont download.
- Body 15px with 1.45 line height: messages are short paragraphs read in a
  narrow column; 15px keeps density close to other chat tools without
  dropping below comfortable size.
- Monospace only for the `cable: <pod>` label in the sidebar footer. It is a
  machine hostname used to verify the multi-pod setup, so it is shown as a
  technical value, not as UI text.

## Layout

- Three columns (sidebar, conversation, optional side panel) because those
  are the three things a user switches between: where am I, what is being
  said, what am I looking at in detail (thread, members, search).
- Below 1000px the side panel covers the conversation; below 760px the
  sidebar becomes a drawer. One focused column on a phone beats three cramped
  ones.
- Consecutive messages from the same person within 5 minutes collapse into a
  compact row, because repeating the name and avatar adds noise, not content.

## Spacing, radius, elevation

- Radii: 4px (inline marks), 6px (controls, avatars), 10px (cards, dialogs,
  composer). Square-ish avatars separate people from the round presence dot.
  Only reaction chips and the unread badge are fully rounded, since they are
  counters, not controls with labels.
- Shadow only on things that float above the page (dialogs, popovers, the
  emoji picker, toasts). Everything else sits flat so elevation means
  "temporary, dismissable".
- Tap targets: 44px on touch screens (`--tap`), 32px with a mouse, so
  desktop keeps its density and phones stay usable.

## Icons

- A small hand-drawn set (`src/components/AppIcon.vue`): 24px grid, 1.8
  stroke, round caps. Thin strokes match the weight of the system font at
  15px, so icons sit next to text without shouting. Only glyphs the UI uses
  are included; no icon library is imported.
- Every icon button also has an `aria-label` and a tooltip.
- An action that is easy to confuse with another gets a text label instead of
  an icon: "Leave" (channel) is a text button so it cannot be mistaken for the
  sign out icon.

## Presence

Online is a filled green dot; offline is a hollow ring. The shape carries the
state, so people who cannot tell the colors apart still can read it, and the
text "online" or "offline" is in the accessible name and in the Members
panel.

## Open items

- Logo: the speech-bubble mark was made without a brief and is pending the
  owner's decision (audit 001, item 8).
- Identity beyond color (audit 001, item 16) waits on the design direction.
