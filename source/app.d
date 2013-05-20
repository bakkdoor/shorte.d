import std.stdio, std.digest.sha, std.conv, std.exception;
import vibe.d;

alias string ShortID;
alias string URL;

struct URLInfo
{
    ShortID id;
    URL     url;
    uint    redirects;
}

URLInfo[ShortID] urls;

URLInfo lookup(ShortID id)
{
    if(id in urls) {
        return urls[id];
    }
    throw new Exception("Invalid ID");
}

ShortID shortened(URL url)
{
    auto sha = toHexString(sha1Of(url));
    return to!string(sha[0..16]);
}

ShortID addUrl(URL url)
{
    string id = shortened(url);
    if(id !in urls)
        urls[id] = URLInfo(id, url, 0);
    return id;
}

void updateInfo(URLInfo info)
{
    urls[info.id] = info;
}

// http handlers

void index(HTTPServerRequest req, HTTPServerResponse res)
{
    res.writeBody("Hello!", "text/html");
}

void redirectToUrl(HTTPServerRequest req, HTTPServerResponse res)
{
    auto urlInfo = lookup(req.params["id"]);

    writeln("Redirecting ID: "~urlInfo.id~" to URL: "~urlInfo.url);

    urlInfo.redirects++;
    updateInfo(urlInfo);

    res.redirect(urlInfo.url);
}

void shortenUrl(HTTPServerRequest req, HTTPServerResponse res)
{
    auto url = req.query["url"];
    auto id  = addUrl(url);

    writeln("Shortening: "~url~" to ID: "~id);

    switch(req.method) {
        case HTTPMethod.GET:
            res.writeBody(`{ "id": "`~id~`", "url": "`~url~`" }`, "text/json");
            break;
        case HTTPMethod.POST:
            res.redirect("/info/" ~ id);
            break;
        default:
            throw new Exception("Invalid request type.");
    }
}

void showUrlInfo(HTTPServerRequest req, HTTPServerResponse res)
{
    auto id = req.params["id"];
    auto urlInfo = lookup(id);

    res.writeBody(`{ "id": "`~id~`", "url": "`~urlInfo.url~`", "redirects": `~to!string(urlInfo.redirects)~" }" , "text/json");
}

shared static this()
{
    auto router = new URLRouter;

    router.get("/", &index)
          .get("/shorten/", &shortenUrl)
          .get("/info/:id", &showUrlInfo)
          .get("/:id", &redirectToUrl)
          ;

    auto settings = new HTTPServerSettings;
    settings.port = 3000;

    listenHTTP(settings, router);
}
