# @jennifer/gotify

[![test](https://github.com/jennifer-language/deck-gotify/actions/workflows/test.yml/badge.svg)](https://github.com/jennifer-language/deck-gotify/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://jennifer-language.github.io/deck-gotify/)
[![release](https://img.shields.io/github/v/release/jennifer-language/deck-gotify)](https://github.com/jennifer-language/deck-gotify/releases/latest)

Sends push notifications to a [Gotify™](https://gotify.net) server from a
[Jennifer](https://jennifer-lang.dev/) program, with optional markdown bodies
and tap-to-open URLs. Replaces the `gotify` module of Jennifer's standard
library (shipped since 0.18.0, deprecated from 0.26.0, removed in 0.28.0)
with the same calls; `Config` gains `allowInsecureHttp`, and a plain
`http://` server URL to a non-loopback host is refused unless it is set.

**[Documentation](https://jennifer-language.github.io/deck-gotify/)**

## Install

```sh
jvc add @jennifer/gotify
```

This vendors the deck to `vendor/jennifer/gotify/`. Without `jvc`, unpack the
`src/` subtree of a release archive (`jennifer-gotify-<version>.tar.gz`) there.

## Usage

```jennifer
import "@jennifer/gotify/" as gotify;
import "http.j" as http;

def g as gotify.Config init gotify.Config{
    url: os.getEnv("GOTIFY_URL"),
    token: os.getEnv("GOTIFY_TOKEN"),
    allowInsecureHttp: false
};
def r as http.Response init gotify.push($g, "Deploy", "build 1234 is live", 5);
io.printf("%d\n", $r.status);   # 200; a wrong token is 401, not an error
```

`examples/push.j` pushes a plain and a tap-to-open notification.

The URL must be `https://`; plain `http://` is accepted only to a loopback
host, or with `allowInsecureHttp: true` for a server on a trusted LAN (the
token is then sent unencrypted).

## Requirements

Jennifer 0.27.0 or newer and network access to the Gotify server. Pushes need
the default `jennifer` binary; the stock `jennifer-tiny` has no network driver.

## Development

```sh
tools/check-all.sh                   # the full gate, as CI runs it
jennifer test src/gotify_test.j      # the test overlay
tools/check-docs.sh                  # docs against the code
tools/pack.sh dist                   # build the release archive
```

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.

`tools/check-headers.sh` checks every source file's SPDX header against
`deck.toml`.

## Trademarks

Gotify™ and other product and company names may be trademarks of their
respective owners. They are used only to identify the products this deck works
with. This deck is an independent project, not affiliated with, sponsored or
endorsed by the Gotify project.
