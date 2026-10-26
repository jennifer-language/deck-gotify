<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# gotify cheatsheet

Every export of `@jennifer/gotify`. Background is in
[the introduction](index.md).

```jennifer
import "@jennifer/gotify/" as gotify;
import "http.j" as http;
```

Every push POSTs to `<url>/message` with `X-Gotify-Key: <token>` and returns
the `http.Response` unchecked: `200` on success, `401` for a wrong token.
Transport failures throw from `http`.

## Types

### `Config`

| Field | Meaning |
|---|---|
| `url as string` | server URL without a trailing slash |
| `token as string` | application token |

### `Extras`

| Field | Meaning |
|---|---|
| `markdown as bool` | render the body as markdown |
| `clickUrl as string` | URL opened on tap; `""` for none |

## Pushing

| Function | Returns | Body |
|---|---|---|
| `gotify.push(cfg, title, message, priority)` | `http.Response` | form |
| `gotify.pushMarkdown(cfg, title, message, priority)` | `http.Response` | JSON, markdown extra |
| `gotify.pushWith(cfg, title, message, priority, clickUrl)` | `http.Response` | JSON, click extra |
| `gotify.pushExtras(cfg, title, message, priority, extras)` | `http.Response` | JSON, the extras set in `extras` |
