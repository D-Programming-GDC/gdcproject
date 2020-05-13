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

// This file serves the downloads page.

module gdcproject.archive;

import vibe.d;
import gdcproject.render;

string renderArchivePage(string path)
{
  import std.array : appender;
  import std.algorithm : sort;
  import std.path : buildPath, pathSplitter;

  auto content = appender!string();

  void appendFileOrDirectory(string parent, string name,
                             string prefix, string suffix,
                             bool is_directory = true)
  {
    content ~= prefix;
    content ~= `<a href="/`;
    content ~= buildPath(parent, name);
    content ~= (is_directory) ? `/">` : `">`;
    content ~= (parent) ? name : `[root]`;
    content ~= `</a>`;
    content ~= suffix;
    content ~= "\n";
  }

  // Build the parent directory listings.
  auto splitPaths = pathSplitter(path);
  string parent = null;
  content ~= `<h4>`;
  foreach (base; splitPaths)
  {
    appendFileOrDirectory(parent, base, null, "&nbsp;");
    parent = buildPath(parent, base);
  }
  content ~= "</h4>\n";

  // Build the subdirectory and file listings.
  string[] subdirs;
  string[] files;
  listDirectory(path, (fi) {
    if (fi.name[0] != '.')
    {
      if (fi.isDirectory)
        subdirs ~= fi.name;
      else
        files ~= fi.name;
    }
    return true;
  });

  content ~= "Subdirectories:<br>\n<ul>\n";
  foreach (subdir; subdirs.sort!("a > b"))
    appendFileOrDirectory(path, subdir, "<li>", "</li>");
  content ~= "</ul>\n";

  content ~= "Files:<br>\n<ul>";
  foreach (file; files.sort!("a > b"))
    appendFileOrDirectory(path, file, "<li>", "</li>", false);
  content ~= "</ul>\n";

  return content.data;
}

void serveArchivePage(HTTPServerRequest req, HTTPServerResponse res)
{
  scope(failure) return;

  import std.file : isDir;

  string path = req.requestURL[1 .. $];
  if (!path.isDir)
    return serveStaticFiles("./")(req, res);

  // Build up the content.
  auto content = appender!string();
  content ~= readHeader();
  content ~= renderArchivePage(path);
  content ~= readFooter();

  // Send the page data to the client.
  res.writeBody(content.data, "text/html; charset=UTF-8");
}
