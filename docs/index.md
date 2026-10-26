<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @jennifer/gotify

Sends push notifications to a [Gotify](https://gotify.net) server through
Jennifer's `http` module. The full API is on the
[cheatsheet](cheatsheet.md).

## Conventions

Snippets assume these imports:

```jennifer
import "@jennifer/gotify/" as gotify;
import "http.j" as http;
```

The trailing slash resolves to the entry module.

## Pushing

```jennifer
def g as gotify.Config init gotify.Config{url: "https://push.example.com", token: "AqB3cD..."};
def r as http.Response init gotify.push($g, "Deploy", "build 1234 is live", 5);
if ($r.status != 200) {
    io.printf("gotify: %d %s\n", $r.status, $r.body);
}
```

`push` POSTs `title`, `message` and `priority` form-encoded to
`<url>/message` with the token in the `X-Gotify-Key` header, as described in
Gotify's [push-message](https://gotify.net/docs/pushmsg) docs. `url` has no
trailing slash. Priority is an int, 0 lowest; how a client shows each level is
in Gotify's [priority](https://gotify.net/docs/priority) docs.

The deck keeps no state: pass the `Config` to every call. Read the URL and
token from the environment or a config file; `examples/push.j` uses
`GOTIFY_URL` and `GOTIFY_TOKEN`.

## Extras

Gotify [extras](https://gotify.net/docs/msgextras) are client hints. Two are
supported:

| Extra | Call | Sets |
|---|---|---|
| Markdown body | `pushMarkdown` | `client::display.contentType = "text/markdown"` |
| Open a URL on tap | `pushWith(..., clickUrl)` | `client::notification.click.url` |

`pushExtras` takes an `Extras` with both:

```jennifer
def ex as gotify.Extras init gotify.Extras{markdown: true, clickUrl: "https://ci.example.com/builds/1234"};
def r as http.Response init gotify.pushExtras($g, "Deploy", "**build 1234** is live", 5, $ex);
```

which sends:

```json
{"title":"Deploy","message":"**build 1234** is live","priority":5,"extras":{"client::display":{"contentType":"text/markdown"},"client::notification":{"click":{"url":"https://ci.example.com/builds/1234"}}}}
```

The extras calls post JSON (`application/json`), since extras are nested.
With a zero `Extras` the body has no `extras` key.

## Errors

Every push returns the `http.Response` and does not inspect it. Gotify answers
`200` on success; a wrong token is a `401` response, not an error. A
transport failure (no server, refused connection, TLS) throws from `http`.

## Runtime

Needs `net`, so it runs on the default `jennifer` binary. The stock
`jennifer-tiny` has no network driver and every push throws.

## Moving from the standard library module

Jennifer has shipped `gotify` as a standard library module
(`modules/gotify.j`) since 0.18.0; the extras calls (`pushExtras`,
`pushMarkdown`, `pushWith`) came in 0.23.0. The module is deprecated from
Jennifer 0.26.0 and removed in 0.28.0. This deck replaces it with the same
types and functions; only the import changes:

```jennifer
import "gotify.j" as gotify;            # before
import "@jennifer/gotify/" as gotify;   # after: jvc add @jennifer/gotify
```
