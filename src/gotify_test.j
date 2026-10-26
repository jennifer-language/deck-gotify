# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * White-box tests for gotify: jennifer test src/gotify_test.j
 *
 * The body builders are tested directly. The pushes go to an `httpd` server
 * on a loopback port, which answers one request like Gotify does and hands
 * back what it received.
 */
use convert;
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
        body: convert.stringFromBytes(httpd.body($req), "utf-8")
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
    def g as Config init Config{url: "http://" + httpd.address($srv), token: "secret-token"};
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
    def g as Config init Config{url: "http://" + httpd.address($srv), token: "wrong"};
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
    def g as Config init Config{url: "http://" + httpd.address($srv), token: "secret-token"};
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
    def g as Config init Config{url: "http://" + httpd.address($srv), token: "secret-token"};
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
    def g as Config init Config{url: "http://" + httpd.address($srv), token: "secret-token"};
    def r as http.Response init pushExtras($g, "T", "M", 1, Extras{markdown: false, clickUrl: ""});
    def seen as Seen init task.wait($t);
    httpd.shutdown($srv);
    testing.assertEqual($r.status, 200);
    testing.assertEqual($seen.contentType, "application/json");
    testing.assertEqual(json.has(json.decode($seen.body), "/extras"), false);
}
