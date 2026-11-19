<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Design

## Scope

The deck pushes notifications to a [Gotify](https://gotify.net) server:
`push` sends a title, a message and a priority, and `pushExtras`,
`pushMarkdown` and `pushWith` add the two client hints most senders want (a
markdown body, a URL opened on tap).

It is deliberately only the sending side of Gotify:

- **No receiving.** Reading messages over the websocket stream, listing or
  deleting messages, and managing applications, clients or users are
  client-token operations of a different kind of program.
- **No other extras.** Gotify's extras namespace is open-ended; the two that
  are supported are the ones Gotify's own clients act on for a notifier.

## Decisions

- **A deck, not a bundled module.** A client for one vendor's service belongs
  in the deck ecosystem. `gotify` is the archetype of the bundled modules that
  `jennifer` moves out (M30.1 in its milestones, formerly M28.32): the first
  one moved, and the sample the others followed.
- **Same surface as the module.** The types and functions are those of the
  standard library's `gotify` module, so migrating changes the import and
  adds `allowInsecureHttp` to `Config` literals (the module's literals may
  leave it out; a deck's may not).
- **No state.** The caller holds a `Config` (server URL and application token)
  and passes it to every call, so one program can push to several servers or
  applications without setup or teardown.
- **Form for plain pushes, JSON for extras.** `push` posts the
  form-encoded body Gotify documents for its simplest use. Extras are a nested
  object, which a form cannot carry, so the extras calls post JSON. A zero
  `Extras` sends no `extras` key, and only the keys that are set reach the
  wire.
- **Plain HTTP is an explicit opt-in.** The token is a credential, so `url`
  must be `https://`. `http://` to a loopback host (127.0.0.0/8, `[::1]`,
  `localhost`) is allowed, since the request stays on the machine and tests
  need it; this matches the Slack and Discord decks. Self-hosted Gotify on a
  home network (an Unraid box, say) often speaks only HTTP, so
  `Config.allowInsecureHttp` admits plain `http://` to any host. It is a
  field of `Config` rather than a separate call, because the decision belongs
  to the server the config describes, and it defaults to `false`. The
  loopback test cuts the host out of the URL as `http` does (authority up to
  `/`, `?` or `#`, userinfo up to the last `@`), so
  `http://127.0.0.1@evil.example` is not loopback.
- **The token goes in a header.** Gotify also accepts it as a `token` query
  parameter; the `X-Gotify-Key` header keeps it out of URLs, logs and
  proxies' access lines.
- **The response is returned, not judged.** Every push returns the
  `http.Response`. Gotify answers `200`; a wrong token is a `401` response.
  A notifier usually logs a failure and carries on, and a status is easier to
  log than a caught error.

## Errors

The deck has no error struct (as recorded for the `@jennifer` decks in
M28.57): the server's answer is the returned response. Its one throw is
`Error{kind: "gotify"}` for a refused plain `http://` URL, raised before any
connection; the message leaves the URL out. Transport failures come from `http` unchanged: `"timeout"`,
`"closed"`, `"limit"`, and on interpreters with transport error kinds
(M28.65) a `net.NetError` of kind `"net"` for a refused connection, reset,
failed lookup or TLS failure (older ones throw those as `"runtime"`).

## Security and limits

- **The application token is a credential.** It lets anyone holding it push
  to that application. The docs and `examples/push.j` read it from the
  environment (`GOTIFY_TOKEN`).
- **The token is never sent in the clear by default.** A `url` other than
  `https://` is refused unless it is `http://` to a loopback host or
  `allowInsecureHttp` is set. With the flag, the token and messages cross the
  network unencrypted, so it is for a trusted LAN only. The deck appends
  `/message` to `url` and otherwise uses it as given.
- Title, message and click URL are encoded (form or JSON), so they cannot
  change the request's structure. Priority is passed as given; Gotify
  decides what an out-of-range value means.
- Response size, deadlines and redirects are `http`'s defaults; the deck adds
  no caps of its own and no retries.

## Testing and validation

`src/gotify_test.j` tests the form and JSON bodies directly (with and
without each extra), the URL check (LAN `http://` refused, loopback and
`https://` accepted, the opt-in, look-alike hosts such as
`127.0.0.1.evil.example`), and pushes through an `httpd` server on a loopback port
that answers like Gotify: `200` with a message id for the right key, `401`
otherwise. The test replaced the module's Go test when the module moved.

The tests never reach a real Gotify server. `examples/push.j` pushes when
`GOTIFY_URL` and `GOTIFY_TOKEN` are set and posts nothing otherwise, so CI
runs it offline.

## Known limitations and open questions

- A trailing slash on `url` is not removed, so it yields `//message`.
- The returned response is not decoded; a caller that wants the new message's
  id reads it from the body.
- No retries on a `5xx` or a failed connection; a caller that needs delivery
  guarantees wraps the call.

## Dependencies on the interpreter

- The floor is `>=0.26.0`, the release that deprecates the bundled module
  (M30.1).
- `http` needs the `net` capability, so pushing needs the default `jennifer`
  binary; the stock `jennifer-tiny` has no network driver.
- Encoding uses the bundled `uri` (`encodeForm`) and `json` modules; the
  tests use `httpd` and `task` for the loopback server.
