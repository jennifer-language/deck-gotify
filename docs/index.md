<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @deckyard/gotify

Sends push notifications to a [Gotify™](https://gotify.net) server through
Jennifer's `http` module. The full API is on the
[cheatsheet](cheatsheet.md).

## Conventions

Snippets assume these imports:

```jennifer
import "@deckyard/gotify/" as gotify;
import "http.j" as http;
```

The trailing slash resolves to the entry module.

## Pushing

```jennifer
def g as gotify.Config init gotify.Config{
    url: "https://push.example.com",
    token: "AqB3cD...",
    allowInsecureHttp: false
};
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

## Transport security

The application token travels in a header, so `url` must be `https://`. Plain
`http://` is accepted without asking only to a loopback host (127.0.0.0/8,
`[::1]`, `localhost`), where the request never leaves the machine. Any other
URL throws `Error{kind: "gotify"}` before a connection is made; the message
leaves the URL out.

A self-hosted Gotify that only speaks plain HTTP, such as a homelab server on
Unraid™ reached as `http://tower.lan:8080`, needs an explicit opt-in:

```jennifer
def g as gotify.Config init gotify.Config{
    url: "http://tower.lan:8080",
    token: os.getEnv("GOTIFY_TOKEN"),
    allowInsecureHttp: true
};
```

The token and every message then cross the network unencrypted: anyone on the
path can read the token and push with it. Use this only on a trusted LAN, and
prefer putting the server behind a TLS reverse proxy. `examples/push.j` sets
the flag when `GOTIFY_INSECURE_HTTP=1`.

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
transport failure (no server, refused connection, TLS) throws from `http`. A
refused plain `http://` URL (see [Transport security](#transport-security))
throws `Error{kind: "gotify"}`.

## Runtime

Needs `net`, so it runs on the default `jennifer` binary. The stock
`jennifer-tiny` has no network driver and every push throws.

## Moving from `@jennifer/gotify`

Up to 0.3.0 this deck was `@jennifer/gotify`. Change the `[decks]` entry to
`"@deckyard/gotify" = "^0.4.0"` and the imports:

```jennifer
import "@deckyard/gotify/" as gotify;
```

## Moving from the standard library module

Jennifer has shipped `gotify` as a standard library module
(`modules/gotify.j`) since 0.18.0; the extras calls (`pushExtras`,
`pushMarkdown`, `pushWith`) came in 0.23.0. The module is deprecated from
Jennifer 0.26.0 and removed in 0.28.0. This deck replaces it with the same
types and functions. The import changes, and a `Config` literal names the
`allowInsecureHttp` field (a deck's struct literal must name every field):

```jennifer
import "gotify.j" as gotify;            # before
import "@deckyard/gotify/" as gotify;   # after: jvc add @deckyard/gotify
```

## Trademarks

Unraid™ is a trademark of Lime Technology, Inc. Gotify™ and other product and
company names may be trademarks of their respective owners. They are used only
to identify the products this deck works with. This deck is an independent
project, not affiliated with, sponsored or endorsed by the Gotify project or
Lime Technology, Inc.
