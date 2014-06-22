// Copyright (C) 2014  Iain Buclaw

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
// - Read files once and re-use in memory until they change content.
// - Make all (hard coded) components configurable.
// - Add support for /news, which would be a dynamic blog-style set
//   of content pages.
// - Load testing, identify vulnerabilities, etc...

module gdcproject;

import vibe.d;

// Read and return as a string the (hard coded) header template.
// The template is assumed to be in html format.

string readHeader()
{
  import std.file : read;
  scope(failure) return "<html><body>";
  return cast(string) read("templates/header.inc");
}

// Read and return as a string the (hard coded) footer template.
// The template is assumed to be in html format.

string readFooter()
{
  import std.file : read;
  scope(failure) return "</body></hmtl>";
  return cast(string) read("templates/footer.inc");
}

// Handle any kind of GET request on the server.

void handleRequest(HTTPServerRequest req, HTTPServerResponse res)
{
  import std.array : appender;
  import std.file : read;
  import std.string : chomp;
  scope(failure) return;

  // Forward style, images and downloads to the static files
  // handler provided by vibe.d
  string requestURL = chomp(req.requestURL, "/");

  // Content for styles and images found in one place.
  if ((requestURL.length >= 7 && requestURL[0..7] == "/style/")
      || (requestURL.length >= 8 && requestURL[0..8] == "/images/"))
    return serveStaticFiles("static/")(req, res);

  // Downloads are kept to the /downloads directory.
  if (requestURL.length >= 11 && requestURL[0..11] == "/downloads/")
    return serveStaticFiles("downloads/")(req, res);

  // The downloads page itself is generated outside this server.
  if (requestURL == "/downloads")
    return serveStaticFile("downloads/index.html")(req, res);

  // Not a requesting a static file, look for a markdown script instead.
  // This is done by translating the request into a file path, and running
  // its contents through the markdown filter, if the file exists.
  string requestPath;
  if (requestURL.length == 0)
    requestPath = "views/index.md";
  else
    requestPath = "views" ~ requestURL ~ ".md";

  // Build up the content.
  auto content = appender!string();
  content ~= readHeader();
  content ~= filterMarkdown(cast(string)read(requestPath));
  content ~= readFooter();

  // Send the page data to the client.
  res.writeBody(content.data, "text/html; charset=UTF-8");
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
  // Set (hard coded) server settings.
  auto settings = new HTTPServerSettings;
  settings.port = 8080;
  settings.bindAddresses = ["::1", "127.0.0.1"];
  settings.errorPageHandler = toDelegate(&handleError);

  // Start listening.
  // Catch all GET requests and push them through our main handler.
  listenHTTP(settings, toDelegate(&handleRequest));
}

