# Auth screens: design and task status

Sign in and Sign up for the StrideQuest app. The behavior comes from the [auth API contract](api/auth.md); the visuals come from the Figma file [StrideQuest](https://www.figma.com/design/XGEN3s49mw5stkWl5AvoLX/StrideQuest) (frames `Auth - Sign In` and `Auth - Sign Up`, 393×852).

The Figma file had no sign-in or sign-up design, so both frames reuse the style of the Account screens (dark surfaces, Lime accent, Inter). Items marked **Assumption** were chosen by us and need the designer's confirmation.

## Screens

| Screen | Route | Purpose |
| --- | --- | --- |
| Sign in | `/sign-in` | Where a signed-out user starts. Email and password. On success the router redirect goes to the first tab (Challenges); the screen never navigates itself. No Back button. |
| Sign up | `/sign-up` | Display name, email and password. The backend signs the user in, so success also goes to the first tab through the redirect. Back goes to Sign in. |
| Tabs | `/challenges`, `/active`, `/medals`, `/profile` | Protected: signed-in users only, in a shell with a bottom bar of four tabs (Figma component `Tab Bar`). A signed-in user opens on Challenges; `/` redirects there. While the stored session is being read the shell shows progress, so a signed-out user never sees it. Sign out (on Profile) returns to Sign in. |

Layout, top to bottom: back button and centered title; heading and one line of subtext; the form; a flexible gap; the primary button; the link to the other screen. The form scrolls, so the keyboard and large text never overflow.

- **Sign in:** heading "Welcome back", fields Email and Password (with Show/Hide), button "Sign in", link "New to StrideQuest? Sign up".
- **Sign up:** heading "Create your account", fields Display name, Email and Password (with Show/Hide and the hint "Use at least one letter and one number."), button "Create account", link "Already have an account? Sign in".

**Assumption:** the primary button is filled Lime with dark text; the Account screens use an outlined Lime button. **Assumption:** the password hint follows the API contract (8 to 128 characters), not the 12 characters shown on `Account - Password`.

## Fields and validation

The app checks these before calling the API; the backend checks them again. Source of truth: [Field rules](api/auth.md#field-rules).

| Field | Rule | Message |
| --- | --- | --- |
| Display name (sign up) | 1 to 50 characters after trimming, no control characters | Enter a name (up to 50 characters). |
| Email | Required, shaped like an address, at most 254 characters | Enter a valid email address. |
| Password (sign up) | 8 to 128 characters, at least one letter `A`–`Z`/`a`–`z` and one digit | Use 8–128 characters with a letter and a number. |
| Password (sign in) | Required only; no password rules at sign in | Enter your password. |

Local checks run on submit. Server `422` messages appear under the matching field and clear when that field is edited.

## Server errors on screen

| `error.code` | Status | What the user sees |
| --- | --- | --- |
| `invalid_credentials` | 401 | Banner: wrong email or password (sign in). |
| `email_taken` | 409 | The email field shows "An account with this email already exists." (sign up); no banner, so it is not announced twice. |
| `validation_error` | 422 | Each `fields[]` message under its field. |
| `rate_limited` | 429 | Banner: "Try again in N minutes." from `Retry-After`. |
| network or server error | none | Banner; the entered values stay. |

An expired session shows "Your session has expired. Sign in again." The banner is a live region, so screen readers announce it.

## States to cover

Initial, focused field, field error, banner error, submitting (button shows progress, fields disabled), password shown. Every state at both phone sizes and both text scales from the [ticket evidence gate](../.claude/workflow/plan.md#ticket-evidence-gate) default (375×667 and 430×932 at 1.0 and 2.0), with `expectAccessible` and a golden test (`goldenScreen`). Figma has the two default frames only; the other states are described here, not drawn.

## Design tokens

Figma has no variables or color styles yet, so the values below were read from the Colors section and the Account frames.

| Token | Value | Use |
| --- | --- | --- |
| Surfaces / Darkest | `#0F0F0F` | Screen background |
| Surfaces / Dark | `#202020` | Input fill |
| Surfaces / Default | `#303030` | Input stroke |
| Brand / Lime | `#D0EC60` | Primary button, links |
| Text / Primary | `#FFFFFF` | Titles |
| Text / Secondary | `#A1A1A2` | Labels, secondary text |
| Text / Disabled | `#5F5E60` | Placeholders, hints |
| System / Error | `#E54D4F` | Error text and field stroke |
| Radius | Input 5, button 10 | Corners |

Text styles in Figma (Inter): Display / Bold 32, Heading / Bold 24, Title / Semi Bold 18, Button / Semi Bold 16, Body L / Regular 14, Body / Regular 13, Body / Medium 13, Body / Semi Bold 13.

Mapping to code (done in #52): colors go into `ColorScheme` and `TextTheme` in `lib/core/theme/app_theme.dart`; the 5 and 10 radii and any spacing the scale lacks go into `app_tokens.dart`. Inter is bundled as a font asset, not fetched at run time. The Account frames are dark-only, so the app theme is dark unless the designer provides a light one.

## Task status

Review of the first auth task split against the repo, with the current state:

| Task | Status |
| --- | --- |
| BE-1: security core, config, `users` and `refresh_tokens` models, migration | Done (#46) |
| BE-2: sign up and sign in | Done (#46) |
| BE-3: refresh, sign out, `GET /users/me`, `get_current_user` | Done (#46) |
| BE-4: sign-in rate limit | Done (#46) |
| Fuzz, `hurl` replay files, query counts for the auth API | Done (#47) |
| FE: sign-in form and the sign-in/sign-out actions | Done (#48), with Material defaults |
| FE: apply the Figma theme (colors, Inter, radii) | Done (#52) |
| FE: restyle Sign in to the Figma frame | Done (#53) |
| FE: Sign up page, `/sign-up` route, link from Sign in | Done (#54) |
| FE: start on Sign in, protect Home | Done (#55) |
| FE: four-tab bottom navigation shell | Done (#56); the tab contents are placeholders until they are designed |
| Optional: Patrol native-dialog tests | Blocked (#49): `patrol` needs `equatable ^2`, the app uses `^3` |

Where the app differs from Figma, for the designer to confirm:

- Error banners use a dark red tint (`#3B1C1D`) with light red text (`#FFB4B5`), and notices use `#303030`, because the default white on `#E54D4F` has a contrast of 3.81 (the guideline is 4.5).
- The hint under the password field uses Text / Secondary (`#A1A1A2`), not Text / Disabled (`#5F5E60`), which has a contrast of 2.97 on the background.
- The Show/Hide action is a 48 × 48 tap target, larger than its text.
- A focused input has a Lime border.

Open: a password reset link and a light theme, neither of which is in the design or the API.
