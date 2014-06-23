module gdcproject.downloads;

import vibe.d;
import gdcproject.app;

struct Download
{
  string[] multilib;
  string target, dmdFE, runtime, gcc, gdcRev, buildDate, url, comment, runtimeLink;
}

struct DownloadSet
{
  string name, comment, targetHeader;
  Download[] downloads;
}

struct Host
{
  string name, triplet, archiveURL, comment;
  DownloadSet[] sets;
}

void renderDownloadPage(HTTPServerRequest req, HTTPServerResponse res)
{
  import mustache;
  import std.file : read;
  scope(failure) return;

  alias MustacheEngine!(string) Mustache;
  Mustache engine;
  auto context = new Mustache.Context();
  Host[] hosts;

  auto jsonData = cast(string)read("views/downloads.json");
  deserializeJson(hosts, parseJson(jsonData));

  foreach(host; hosts)
  {
    auto hostCtx = context.addSubContext("Host");
    hostCtx["name"] = host.name;
    hostCtx["triplet"] = host.triplet;
    hostCtx["archiveURL"] = host.archiveURL;
    hostCtx["comment"] = host.comment;

    foreach(dlSet; host.sets)
    {
      auto setCtx = hostCtx.addSubContext("DownloadSet");
      setCtx["name"] = dlSet.name;
      setCtx["comment"] = dlSet.comment;
      setCtx["targetHeader"] = dlSet.targetHeader;

      foreach(i, dl; dlSet.downloads)
      {
        auto dlCtx = setCtx.addSubContext("DownloadEntry");
        dlCtx["target"] = dl.target;
        dlCtx["dmdFE"] = dl.dmdFE;
        dlCtx["runtime"] = dl.runtime;
        dlCtx["gcc"] = dl.gcc;
        dlCtx["gdcRev"] = dl.gdcRev[0..10];
        dlCtx["buildDate"] = dl.buildDate;
        dlCtx["url"] = dl.url;
        dlCtx["comment"] = dl.comment;
        dlCtx["runtimeLink"] = dl.runtimeLink;
        dlCtx["multilib"] = dl.multilib.join("<br>");
      }
    }
  }

  engine.level = Mustache.CacheLevel.no;
  string mdbody = engine.render("views/downloads", context);

  auto content = appender!string();
  content ~= readHeader();
  content ~= filterMarkdown(mdbody);
  content ~= readFooter();

  // Send the page data to the client.
  res.writeBody(content.data, "text/html; charset=UTF-8");
}
