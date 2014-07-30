// Copyright (C) 2014  Iain Buclaw
// Written by Johannes Pfau

// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 3.0 of the License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.

// You should have received a copy of the GNU Lesser General Public
// License along with this program; if not, see
// <http://www.gnu.org/licenses/lgpl-3.0.txt>.

// The gdcproject website powered by vibe.d

// This file serves the downloads page.

module gdcproject.downloads;

import vibe.d;
import gdcproject.render;

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

string renderDownloadsPage(string path)
{
  import mustache;

  alias MustacheEngine!(string) Mustache;
  Mustache engine;
  auto context = new Mustache.Context();
  Host[] hosts;

  auto jsonData = readContents(path ~ ".json");
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
  return engine.render(path, context);
}

void serveDownloadsPage(HTTPServerRequest req, HTTPServerResponse res)
{
  scope(failure) return;

  // Build up the content.
  string content = renderPage("views/downloads", &renderDownloadsPage);

  // Send the page data to the client.
  res.writeBody(content, "text/html; charset=UTF-8");
}

