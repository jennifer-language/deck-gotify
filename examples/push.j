#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * Push a notification: GOTIFY_URL=... GOTIFY_TOKEN=... jennifer run examples/push.j
 *
 * Without both variables it prints a hint and pushes nothing; when the server
 * cannot be reached it prints the error.
 */

use io;
use os;

import "http.j" as http;
import "../src/gotify.j" as gotify;

def url as string init os.getEnv("GOTIFY_URL");
def token as string init os.getEnv("GOTIFY_TOKEN");

if (len($url) == 0 or len($token) == 0) {
    io.printf("set GOTIFY_URL and GOTIFY_TOKEN to push a notification\n");
} else {
    def g as gotify.Config init gotify.Config{url: $url, token: $token};
    try {
        def r as http.Response init gotify.push($g, "Jennifer", "Hello from @jennifer/gotify", 5);
        io.printf("push -> %d %s\n", $r.status, $r.statusText);
        def m as http.Response init gotify.pushWith(
            $g,
            "Jennifer",
            "Tap to open the docs",
            5,
            "https://jennifer-language.github.io/deck-gotify/");
        io.printf("pushWith -> %d %s\n", $m.status, $m.statusText);
    } catch (e) {
        io.printf("no Gotify server at %s (%s)\n", $url, $e.message);
    }
}
