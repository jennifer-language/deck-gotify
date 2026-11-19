# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * Push notifications to a Gotify server (https://gotify.net) through the
 * `http` module. The caller holds a `Config` (server URL and application
 * token) and passes it to each push; the deck keeps no state. Needs the
 * default `jennifer` binary, since `http` uses `net`. A server URL other than
 * `https://` (or `http://` to a loopback host) throws `Error{kind: "gotify"}`
 * before the token is sent, unless the `Config` sets `allowInsecureHttp`.
 *
 * Replaces the `gotify` module of the Jennifer standard library (since 0.18.0,
 * deprecated from 0.26.0, removed in 0.28.0) with the same surface.
 *
 * @module gotify
 * @example
 *   def g as gotify.Config init gotify.Config{
 *       url: "https://push.example.com", token: "tok", allowInsecureHttp: false};
 *   def r as http.Response init gotify.push($g, "Deploy", "build 1234 is live", 5);
 */
use json;
use regex;
use strings;
import "http.j" as http;
import "uri.j" as uri;

/**
 * A Gotify server and the application token to push with.
 *
 * @field url {string} server URL without a trailing slash
 * @field token {string} application token, sent as `X-Gotify-Key`
 * @field allowInsecureHttp {bool} allow plain `http://` to a non-loopback host (default false)
 */
export def struct Config {
    url as string,
    token as string,
    allowInsecureHttp as bool
};

/**
 * Whether a URL names a loopback host: 127.0.0.0/8, `[::1]` or `localhost`.
 * The host is cut out the way `http` does it: the authority ends at the
 * first `/`, `?` or `#`, and userinfo ends at the last `@`.
 *
 * @param rest {string} the URL after `http://`
 * @return {bool} true for a loopback host
 */
func isLoopback(rest as string) {
    def authority as string init $rest;
    for (def stop in ["/", "?", "#"]) {
        def i as int init strings.indexOf($authority, $stop);
        if ($i >= 0) {
            $authority = $authority[..$i];
        }
    }
    def at as int init strings.lastIndexOf($authority, "@");
    if ($at >= 0) {
        $authority = $authority[$at + 1..];
    }
    def host as string init $authority;
    if (strings.startsWith($host, "[")) {
        def rb as int init strings.indexOf($host, "]");
        if ($rb >= 0) {
            $host = $host[..$rb + 1];
        }
    } else {
        def colon as int init strings.indexOf($host, ":");
        if ($colon >= 0) {
            $host = $host[..$colon];
        }
    }
    $host = strings.lower($host);
    if ($host == "localhost" or $host == "[::1]") {
        return true;
    }
    return regex.matches('^127(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}$', $host);
}

/**
 * Refuse a server URL that would send the token in the clear: anything but
 * `https://`, except `http://` to a loopback host or with `allowInsecureHttp`.
 * The message leaves the URL out.
 *
 * @param cfg {Config} server and token
 * @throws {Error} kind "gotify" when the URL is refused
 */
func checkUrl(cfg as Config) {
    def lower as string init strings.lower($cfg.url);
    if (strings.startsWith($lower, "https://")) {
        return;
    }
    if (strings.startsWith($lower, "http://") and
        ($cfg.allowInsecureHttp or isLoopback($cfg.url[7..]))) {
        return;
    }
    throw Error{
        kind: "gotify",
        message: "gotify: the server URL needs https:// (http:// only with allowInsecureHttp)"
    };
}

/**
 * Message extras. A zero `Extras` adds nothing.
 *
 * @field markdown {bool} render the body as markdown
 * @field clickUrl {string} URL opened on tap; "" for none
 */
export def struct Extras {
    markdown as bool,
    clickUrl as string
};

/**
 * The form body of a plain push.
 *
 * @param title {string} notification title
 * @param message {string} notification body
 * @param priority {int} Gotify priority
 * @return {string} `title=...&message=...&priority=...`, form-encoded
 */
func formBody(title as string, message as string, priority as int) {
    def body as string init "title=" + uri.encodeForm($title);
    $body = $body + "&message=" + uri.encodeForm($message);
    return $body + "&priority={$priority}";
}

/**
 * Send a notification as a form POST to `<url>/message`.
 *
 * @param cfg {Config} server and token
 * @param title {string} notification title
 * @param message {string} notification body
 * @param priority {int} Gotify priority, 0 lowest
 * @return {http.Response} 2xx on success; a bad token is a 4xx response, not an error
 * @throws {Error} kind "gotify" when the URL is not `https://` and plain `http://` is not allowed
 */
export func push(cfg as Config, title as string, message as string, priority as int) {
    checkUrl($cfg);
    def headers as map of string to string init {"X-Gotify-Key": $cfg.token};
    def body as string init formBody($title, $message, $priority);
    return http.post($cfg.url + "/message", "application/x-www-form-urlencoded", $body, $headers);
}

/**
 * Whether an `Extras` sets anything.
 *
 * @param extras {Extras} the extras to check
 * @return {bool} true when markdown is on or a click URL is set
 */
func hasExtras(extras as Extras) {
    return $extras.markdown or len($extras.clickUrl) > 0;
}

/**
 * The Gotify `extras` object for the requested options, holding only the
 * keys that are set. `json.set` does not create parents, so each nested map
 * is set before its child.
 *
 * @param extras {Extras} the options
 * @return {json.Value} the `extras` object
 */
func buildExtras(extras as Extras) {
    def x as json.Value init json.map();
    if ($extras.markdown) {
        $x = json.set($x, "/client::display", json.map());
        $x = json.set($x, "/client::display/contentType", "text/markdown");
    }
    if (len($extras.clickUrl) > 0) {
        $x = json.set($x, "/client::notification", json.map());
        $x = json.set($x, "/client::notification/click", json.map());
        $x = json.set($x, "/client::notification/click/url", $extras.clickUrl);
    }
    return $x;
}

/**
 * The JSON body of a push with extras; `extras` is left out when none is set.
 *
 * @param title {string} notification title
 * @param message {string} notification body
 * @param priority {int} Gotify priority
 * @param extras {Extras} the extras to attach
 * @return {string} the encoded JSON object
 */
func jsonBody(title as string, message as string, priority as int, extras as Extras) {
    def payload as json.Value init json.map();
    $payload = json.set($payload, "/title", $title);
    $payload = json.set($payload, "/message", $message);
    $payload = json.set($payload, "/priority", $priority);
    if (hasExtras($extras)) {
        $payload = json.set($payload, "/extras", buildExtras($extras));
    }
    return json.encode($payload);
}

/**
 * Send a notification with extras. Extras are a nested object, so this posts
 * JSON instead of a form.
 *
 * @param cfg {Config} server and token
 * @param title {string} notification title
 * @param message {string} notification body
 * @param priority {int} Gotify priority, 0 lowest
 * @param extras {Extras} the extras to attach; a zero `Extras` sends none
 * @return {http.Response} 2xx on success; a bad token is a 4xx response, not an error
 * @throws {Error} kind "gotify" when the URL is not `https://` and plain `http://` is not allowed
 */
export func pushExtras(
    cfg as Config,
    title as string,
    message as string,
    priority as int,
    extras as Extras) {
    checkUrl($cfg);
    def headers as map of string to string init {"X-Gotify-Key": $cfg.token};
    def body as string init jsonBody($title, $message, $priority, $extras);
    return http.post($cfg.url + "/message", "application/json", $body, $headers);
}

/**
 * Send a notification whose body renders as markdown:
 * `pushExtras` with `Extras{markdown: true}`.
 *
 * @param cfg {Config} server and token
 * @param title {string} notification title
 * @param message {string} markdown body
 * @param priority {int} Gotify priority, 0 lowest
 * @return {http.Response} 2xx on success; a bad token is a 4xx response, not an error
 */
export func pushMarkdown(cfg as Config, title as string, message as string, priority as int) {
    return pushExtras($cfg, $title, $message, $priority, Extras{markdown: true, clickUrl: ""});
}

/**
 * Send a notification that opens `clickUrl` when tapped:
 * `pushExtras` with `Extras{clickUrl: clickUrl}`.
 *
 * @param cfg {Config} server and token
 * @param title {string} notification title
 * @param message {string} notification body
 * @param priority {int} Gotify priority, 0 lowest
 * @param clickUrl {string} URL to open on tap
 * @return {http.Response} 2xx on success; a bad token is a 4xx response, not an error
 */
export func pushWith(
    cfg as Config,
    title as string,
    message as string,
    priority as int,
    clickUrl as string) {
    return pushExtras(
        $cfg,
        $title,
        $message,
        $priority,
        Extras{markdown: false, clickUrl: $clickUrl});
}
