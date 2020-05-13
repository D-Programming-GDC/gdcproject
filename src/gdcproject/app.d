// Copyright (C) 2014-2020  Iain Buclaw

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

// Architecture:
//-----------------------------------------------------------------------------
//   One of the main selling features of vibe.d is that it supports
//   Compile-time "Diet" templates for fast dynamic page loading.
//   It achieves this speed by compiling the templates down to native
//   machine code, meaning that if you wish to make changes to a page,
//   then you must rebuild the entire site.  Another limitation is that
//   given the more pages you wish to add to a site, the more memory
//   it will consume to build, and the longer it will take to compile.

//   On this server, given that all pages are static text, we instead
//   avoid the use of diet templating and bundle in our own templating
//   system using raw HTML for the header/footer components, and
//   markdown for the main bodies.
//-----------------------------------------------------------------------------
//   It functions in the following way:
//   -  Receives a request object for GET /foobar
//   -  Translates /foobar into a path of where the markdown file
//      is expected to be.
//        '/'         => /views/index.md
//        '/foo'      => /views/foo.md
//        '/foo/bar/' => /views/foo/bar.md
//   -  Checks if the translated path exists as a file and proceeds
//      to render the page in the topdown order of:
//      - Template header (templates/header.inc)
//      - Markdown script (views/foobar.md)
//      - Template footer (templates/footer.inc)
//   -  Sends the built page back to the response object.
//-----------------------------------------------------------------------------
//   The benefit of this being that templates can be loaded onto the
//   server dynamically and without requiring a restart of the entire
//   service to make a change.
//   As of writing, the memory consumption and build time was > 50%
//   reduction in comparison to using Diet templates to compile *only*
//   four pages in CTFE.

//   The only time when a site rebuild would be required is for fixing
//   any of the todo listed items below.
//-----------------------------------------------------------------------------
// TODO:
// - Add in server-side logging facilities.
// - Make all (hard coded) components configurable.
// - Add support for /news, which would be a dynamic blog-style set
//   of content pages.
// - Load testing, identify vulnerabilities, etc...

module gdcproject.app;

import vibe.d;

import gdcproject.archive;
import gdcproject.downloads;
import gdcproject.render;

// Handle any kind of GET request on the server.
// The paths /style, /images and /archive are forwarded to the
// static files handler provided by vibe.d
// All other paths are translated a file path, and if it exists,
// loading and running its contents through the markdown filter.

void handleRequest(HTTPServerRequest req, HTTPServerResponse res)
{
  import std.string : chomp;
  import std.file : exists;
  scope(failure) return;

  string requestURL = chomp(req.requestURL, "/");

  if ((requestURL.length >= 4 && requestURL[0..4] == "/js/")
      || (requestURL.length >= 7 && requestURL[0..7] == "/style/")
      || (requestURL.length >= 8 && requestURL[0..8] == "/images/"))
    return serveStaticFiles("static/")(req, res);

  if (requestURL.length == 8 && requestURL == "/archive"
      || requestURL.length >= 9 && requestURL[0..9] == "/archive/")
    return serveArchivePage(req, res);

  // Render download page from template
  if (requestURL.length >= 10 && requestURL[$-10..$] == "/downloads")
  {
    string downloadsPath = "views" ~ requestURL ~ ".mustache";
    if (downloadsPath.exists)
      return serveOldDownloadsPage(downloadsPath[0..$-9], res);
  }

  // Not a requesting a static file, look for the markdown script instead.
  string requestPath;
  if (requestURL.length == 0)
    requestPath = "views/index.md";
  else
    requestPath = "views" ~ requestURL ~ ".md";

  // Build up the content.
  string content = renderPage(requestPath, &readContents);

  // Send the page data to the client.
  res.writeBody(content, "text/html; charset=UTF-8");
}

// Handle an error on the server.

void handleError(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error)
{
  import std.array : appender;
  import std.conv : to;

  // Build up the content.
  auto content = appender!string();
  content ~= readHeader();
  content ~= "<h3>HTTP Error</h3>\n";
  content ~= "<p>Code: " ~ to!string(error.code) ~ "</p>\n";
  content ~= "<p>Description: " ~ error.message ~ "</p>\n";
  content ~= readFooter();

  // Send the error data to the client.
  res.writeBody(content.data, "text/html; charset=UTF-8");
}


shared static this()
{
  import core.thread : Thread;

  // Set (hard coded) server settings.
  auto settings = new HTTPServerSettings;
  settings.port = 8080;
  settings.bindAddresses = ["::1", "127.0.0.1"];
  settings.errorPageHandler = toDelegate(&handleError);

  // Load all pages into cache.
  buildCache();

  // Start the watcher task on template files.
  static Thread templateWatcher = null;
  if (templateWatcher is null)
  {
    templateWatcher = new Thread(&waitForTemplateChanges);
    templateWatcher.isDaemon(true);
    templateWatcher.start();
  }

  // Start the watcher task on individual pages.
  static Thread pageWatcher = null;
  if (pageWatcher is null)
  {
    pageWatcher = new Thread(&waitForViewChanges);
    pageWatcher.isDaemon(true);
    pageWatcher.start();
  }

  // Start listening.
  // Catch all GET requests and push them through our main handler.
  listenHTTP(settings, toDelegate(&handleRequest));
}

