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

// This file builds (and optionally caches) pages to be sent to the client.

module gdcproject.render;

import vibe.inet.path;
import vibe.core.file;
import vibe.db.redis.redis;

import gdcproject.downloads;

// Read and return as a string a dynamically loaded template from 'path'.
// If not found, the value of 'notfound' is used inplace of the file.
// The template is assumed to be in html format.

string readTemplate(string path, lazy string notfound)
{
  import std.array : appender;
  import std.algorithm : findSplit, strip;

  // Catch recursively included templates.
  static bool[string] rendering;

  if (rendering.get(path, false))
    return "<!-- RECURSIVE " ~ path ~ " -->";

  rendering[path] = true;
  scope(exit) rendering[path] = false;

  // Read and filter the contents for any sub-templates to include.
  string tmpl = readContentsOrNotFound(path, notfound);

  auto content = appender!string;
  content.reserve(tmpl.length);

  while (tmpl.length != 0)
  {
    // Split up as ['... content', '{{', 'template ...']
    auto s1 = findSplit(tmpl, "{{");
    // No match for '{{', reached end of template.
    if (s1[1].length == 0)
    {
      content ~= tmpl;
      break;
    }
    // Split up as ['... template', '}}', 'content...']
    auto s2 = findSplit(s1[2], "}}");
    // No match for '}}', write content unfiltered.
    if (s2[1].length == 0)
    {
      content ~= tmpl;
      break;
    }
    // Write content before '{{'
    content ~= s1[0];
    // Write contents of sub-template.
    string incpath = s2[0].strip(' ');
    content ~= readTemplate(incpath, "<!-- NOT FOUND " ~ incpath ~ " -->");
    // Still need to process content after '}}'
    tmpl = s2[2];
  }
  return content.data;
}

// Read and return as a string the (hard coded) header template.
// The template is assumed to be in html format.

string readHeader()
{
  return readTemplate("templates/header.inc", "<html><body>");
}

// Read and return as a string the (hard coded) footer template.
// The template is assumed to be in html format.

string readFooter()
{
  return readTemplate("templates/footer.inc", "</body></html>");
}

// Read return as a string the contents of the file from 'path'.

string readContents(string path)
{
  import std.file : read;
  return cast(string) read(path);
}

// Same as readContents, except returns 'notfound' on failure.

string readContentsOrNotFound(string path, lazy string notfound)
{
  scope(failure) return notfound;
  return readContents(path);
}

// Render the page contents to send to client.

string renderPage(string path, string function(string) read, bool nocache = false)
{
  import std.array : appender;
  import vibe.textfilter.markdown : filterMarkdown;

  // First attempt to get from cache.
  if (!nocache)
  {
    scope(failure) goto Lnocache;

    RedisClient rc = connectRedis("127.0.0.1");
    RedisDatabase rdb = rc.getDatabase(0);
    string content = rdb.get!string(path);
    rc.quit();

    if (content != null)
      return content;
  }
Lnocache:

  auto content = appender!string();
  content ~= readHeader();
  content ~= filterMarkdown(read(path));
  content ~= readFooter();

  return content.data;
}

// Watch the views directory, recompiling pages when a change occurs.
// Uses Redis as the database backend.

void waitForViewChanges()
{
  import core.thread : Thread;
  import core.time : seconds;
  scope(failure) return;

  DirectoryWatcher watcher = Path("views").watchDirectory(true);
  while (true)
  {
    DirectoryChange[] changes;
    if (watcher.readChanges(changes, 0.seconds))
    {
      RedisClient rc = connectRedis("127.0.0.1");
      RedisDatabase rdb = rc.getDatabase(0);

      foreach (change; changes)
      {
        string path = change.path.toNativeString();

        // Check if one of the downloads templates changed.
        // Don't handle delete signals.
        if ((path.length > 15 && path[$-15..$] == "/downloads.json")
            || (path.length > 19 && path[$-19..$] == "/downloads.mustache"))
        {
          path = (path[$-1] == 'n') ? path[0..$-5] : path[0..$-9];
          string content = renderPage(path, &renderOldDownloadsPage, true);
          rdb.set(path, content);
        }

        // Should be a markdown file.
        if (path.length <= 9 || path[$-3..$] != ".md")
          continue;

        // Add or remove pages on the fly.
        if (change.type == DirectoryChangeType.added
            || change.type == DirectoryChangeType.modified)
        {
          string content = renderPage(path, &readContents, true);
          rdb.set(path, content);
        }
        else if (DirectoryChangeType.removed)
          rdb.del(path);
      }
      rc.quit();
    }
    Thread.sleep(5.seconds);
  }
}

// Watch the templates directory, rebuilding all pages when a change occurs.

void waitForTemplateChanges()
{
  import core.thread : Thread;
  import core.time : seconds;
  scope(failure) return;

  DirectoryWatcher watcher = Path("templates").watchDirectory(false);
  while (true)
  {
    DirectoryChange[] changes;
    if (watcher.readChanges(changes, 0.seconds))
    {
      // Check the name of the file changed, only need to rebuild
      // if either the header or footer change.
      foreach (change; changes)
      {
        string path = change.path.toNativeString();
        if (path.length == 20
            && (path == "templates/header.inc" || path == "templates/footer.inc"))
        {
          buildCache();
          break;
        }
      }
    }
    Thread.sleep(5.seconds);
  }
}

// Render and cache all pages.  This is called on application start-up,
// and when a change occurs to a header/footer template.

void buildCache()
{
  import std.file : dirEntries, SpanMode;
  scope(failure) return;

  RedisClient rc = connectRedis("127.0.0.1");
  RedisDatabase rdb = rc.getDatabase(0);

  // Build all markdown pages.
  auto de = dirEntries("views", "*.md", SpanMode.depth, false);
  foreach (path; de)
  {
    string content = renderPage(path, &readContents, true);
    rdb.set(path, content);
  }

  // Build (historical) downloads page.
  de = dirEntries("views", "downloads.mustache", SpanMode.depth, false);
  foreach (path; de)
  {
    string downloadsPath = path[0..$-9];
    string content = renderPage(downloadsPath, &renderOldDownloadsPage, true);
    rdb.set(path, content);
  }

  rc.quit();
}
