# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * White-box tests for gotify: jennifer test src/gotify_test.j
 *
 * The body builders are tested directly. The pushes go to an `httpd` server
 * on a loopback port, which answers one request like Gotify does and hands
 * back what it received.
 */
use encoding;
use httpd;
use task;
use testing;

/** One request as the fake server saw it. */
def struct Seen {
    method as string,
    path as string,
    key as string,
    contentType as string,
    body as string
};

/**
 * Answer one request: 401 unless the key is "secret-token", else 200 with
 * `{"id": 1}`.
 *
 * @param srv {httpd.Server} the listening server
 * @return {Seen} the request
 */
func answerOne(srv as httpd.Server) {
    def req as httpd.Request init httpd.accept($srv);
    def seen as Seen init Seen{
        method: httpd.method($req),
        path: httpd.path($req),
        key: httpd.header($req, "X-Gotify-Key"),
        contentType: httpd.header($req, "Content-Type"),
        body: encoding.decode("utf-8", httpd.body($req))
    };
    if ($seen.key == "secret-token") {
        httpd.respond($req, 200, '{"id": 1}');
    } else {
        httpd.respond($req, 401, '{"error": "Unauthorized"}');
    }
    return $seen;
}

func testFormBody() {
    testing.assertEqual(formBody("Hi there", "a&b", 5), "title=Hi+there&message=a%26b&priority=5");
}

func testJsonBodyWithoutExtras() {
    def e as Extras init Extras{markdown: false, clickUrl: ""};
    def doc as json.Value init json.decode(jsonBody("Deploy", "build 1234 is live", 5, $e));
    testing.assertEqual(json.asString($doc, "/title"), "Deploy");
    testing.assertEqual(json.asString($doc, "/message"), "build 1234 is live");
    testing.assertEqual(json.asInt($doc, "/priority"), 5);
    testing.assertEqual(json.has($doc, "/extras"), false);
}

func testJsonBodyMarkdown() {
    def e as Extras init Extras{markdown: true, clickUrl: ""};
    def doc as json.Value init json.decode(jsonBody("T", "M", 5, $e));
    def ct as string init json.asString($doc, "/extras/client::display/contentType");
    testing.assertEqual($ct, "text/markdown");
    testing.assertEqual(json.has($doc, "/extras/client::notification"), false);
}

func testJsonBodyClick() {
    def e as Extras init Extras{markdown: false, clickUrl: "https://x.example/go"};
    def doc as json.Value init json.decode(jsonBody("T", "M", 4, $e));
    testing.assertEqual(
        json.asString($doc, "/extras/client::notification/click/url"),
        "https://x.example/go");
    testing.assertEqual(json.has($doc, "/extras/client::display"), false);
}

func testJsonBodyBoth() {
    def e as Extras init Extras{markdown: true, clickUrl: "https://x.example/go"};
    def doc as json.Value init json.decode(jsonBody("Deploy", "done", 8, $e));
    def ct as string init json.asString($doc, "/extras/client::display/contentType");
    testing.assertEqual($ct, "text/markdown");
    testing.assertEqual(
        json.asString($doc, "/extras/client::notification/click/url"),
        "https://x.example/go");
}

func testPushPostsTheForm() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def g as Config init Config{
        url: "http://" + httpd.address($srv),
        token: "secret-token",
        allowInsecureHttp: false
    };
    def r as http.Response init push($g, "Deploy", "build 1234 & up", 5);
    def seen as Seen init task.wait($t);
    httpd.shutdown($srv);
    testing.assertEqual($r.status, 200);
    testing.assertEqual($seen.method, "POST");
    testing.assertEqual($seen.path, "/message");
    testing.assertEqual($seen.key, "secret-token");
    testing.assertEqual($seen.contentType, "application/x-www-form-urlencoded");
    testing.assertEqual($seen.body, "title=Deploy&message=build+1234+%26+up&priority=5");
}

func testBadTokenIsAResponse() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def g as Config init Config{
        url: "http://" + httpd.address($srv),
        token: "wrong",
        allowInsecureHttp: false
    };
    def r as http.Response init push($g, "X", "Y", 1);
    task.wait($t);
    httpd.shutdown($srv);
    testing.assertEqual($r.status, 401);
}

func testPushExtrasPostsJson() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def g as Config init Config{
        url: "http://" + httpd.address($srv),
        token: "secret-token",
        allowInsecureHttp: false
    };
    def r as http.Response init pushWith($g, "Deploy", "done", 8, "https://x.example/go");
    def seen as Seen init task.wait($t);
    httpd.shutdown($srv);
    testing.assertEqual($r.status, 200);
    testing.assertEqual($seen.path, "/message");
    testing.assertEqual($seen.contentType, "application/json");
    def doc as json.Value init json.decode($seen.body);
    testing.assertEqual(json.asInt($doc, "/priority"), 8);
    testing.assertEqual(
        json.asString($doc, "/extras/client::notification/click/url"),
        "https://x.example/go");
}

func testPushMarkdownSetsTheContentType() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def g as Config init Config{
        url: "http://" + httpd.address($srv),
        token: "secret-token",
        allowInsecureHttp: false
    };
    def r as http.Response init pushMarkdown($g, "Report", "# Done", 5);
    def seen as Seen init task.wait($t);
    httpd.shutdown($srv);
    testing.assertEqual($r.status, 200);
    def doc as json.Value init json.decode($seen.body);
    testing.assertEqual(json.asString($doc, "/message"), "# Done");
    def ct as string init json.asString($doc, "/extras/client::display/contentType");
    testing.assertEqual($ct, "text/markdown");
    testing.assertEqual(json.has($doc, "/extras/client::notification"), false);
}

func testPushExtrasWithZeroExtrasSendsNone() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def g as Config init Config{
        url: "http://" + httpd.address($srv),
        token: "secret-token",
        allowInsecureHttp: false
    };
    def r as http.Response init pushExtras($g, "T", "M", 1, Extras{markdown: false, clickUrl: ""});
    def seen as Seen init task.wait($t);
    httpd.shutdown($srv);
    testing.assertEqual($r.status, 200);
    testing.assertEqual($seen.contentType, "application/json");
    testing.assertEqual(json.has(json.decode($seen.body), "/extras"), false);
}

/**
 * The kind a push to `url` throws, or "" when it is not refused. A refused
 * URL throws before any connection, so the hosts need not exist.
 *
 * @param url {string} the server URL
 * @param insecure {bool} the `allowInsecureHttp` setting
 * @return {string} the error kind, "" when `checkUrl` passes
 */
func refusal(url as string, insecure as bool) {
    try {
        checkUrl(Config{url: $url, token: "secret-token", allowInsecureHttp: $insecure});
    } catch (e) {
        return $e.kind;
    }
    return "";
}

func testPlainHttpToALanHostIsRefused() {
    for (def url in [
        "http://192.168.1.10:8080",
        "HTTP://unraid.local",
        "http://localhost.example.com",
        "http://127.0.0.1@evil.example",
        "http://127.0.0.1.evil.example",
        "http://128.0.0.1",
        "http://127.0.0.256",
        "http://[::2]",
        "htps://push.example.com",
        "push.example.com",
        ""
    ]) {
        testing.assertEqual(refusal($url, false), "gotify");
    }
}

func testHttpsAndLoopbackAreAllowed() {
    for (def url in [
        "https://push.example.com",
        "HTTPS://push.example.com",
        "http://127.0.0.1:8080",
        "http://127.1.2.3",
        "http://localhost",
        "http://LOCALHOST:80/gotify",
        "http://user:pass@127.0.0.1",
        "http://[::1]:9"
    ]) {
        testing.assertEqual(refusal($url, false), "");
    }
}

func testAllowInsecureHttpOptsIn() {
    testing.assertEqual(refusal("http://192.168.1.10:8080", true), "");
    testing.assertEqual(refusal("http://tower.lan", true), "");
    # The opt-in is for plain http only; another scheme is still refused.
    testing.assertEqual(refusal("ftp://192.168.1.10", true), "gotify");
}

func testPushRefusesPlainHttpBeforeSending() {
    def g as Config init Config{
        url: "http://gotify.invalid",
        token: "secret-token",
        allowInsecureHttp: false
    };
    def kinds as list of string;
    try {
        push($g, "T", "M", 1);
    } catch (e) {
        $kinds[] = $e.kind;
    }
    try {
        pushExtras($g, "T", "M", 1, Extras{markdown: true, clickUrl: ""});
    } catch (e) {
        $kinds[] = $e.kind;
    }
    testing.assertEqual($kinds, ["gotify", "gotify"]);
}
