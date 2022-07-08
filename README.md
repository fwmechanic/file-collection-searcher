[unlike BitBucket, Github has no markdown TOC feature; Please fix this!](https://github.com/isaacs/github/issues/215)

# Description

This is a CGI-Perl project (created in 2017!) that performs a brute-force
filename-only-based search of a (media) file collection living in a set of
personal-server-local directory trees.

# Approach & Features

  * Search based only on filename content; a sidecar metadata database is not present.
  * Provides only Read (R in CRUD) services against the collection.  Collection dir trees are readonly.
  * Uses nginx + [fcgiwrap](https://www.nginx.com/resources/wiki/start/topics/examples/fcgiwrap/) ([github](https://github.com/gnosek/fcgiwrap)) to front the Perl-CGI script and serve all media artifacts.
  * Transforms user query parameter(s) into a Perl regex which is compared against each candidate filename in a (cached) list of filenames (output of `find` command) across multiple disjoint directory trees.
  * Uses `inotifywait` daemon output (file touching) to determine whether the cached list of filenames remains valid (else a find scan is performed to update the cache before searching).
  * Presents output in descending copyright-year order, sorted alphabetically within year, with different formats of the same title coalesced to save UI space.
  * New in 22.07: on-demand zip-file creation & downloading of entire MP3 albums! Only core Perl modules used (requires no optional/nondefault nginx modules).

# Missing Features

  * exclusion of otherwise-hits which match a term (might implement this, but so far its absence has not been painful enough).
  * Create/Update/Delete (CRD of CRUD) of the collection is performed out of band via network filesystem operations.
  * Search of media _content_ (EX: within books for e.g. matching words).

# Features Under Consideration
  * candidate enhanced-search features
     * "Resolve ER" (Early Release): "ER" ebooks are typically superseded months later by final releases (at which time the "ER" ebooks become superfluous and should be deleted or ignored).
        * separate CGI script to perform ER-retirement "analysis": for all ER files, find non-ER name-alikes.
     * "Show all hashtags": ranked by occurrence-count
     * "find possible (filename) dups"
  * candidate Update (file-rename) actions:
     * "add hashtag"
     * "rmv hashtag"
  * candidate offsite actions:
     * "Search-engine search"
     * "Amazon search"
  * API's for external `curl`+`jq` scripting
     * return metadata (size, SHA-sum) of all matches.

# Setup

## Unify content using symlinks

Create a dir containing symlinks to disparate content dirs:
```
mkdir /var/www-filesearcher-data
ln -s /mnt/smb/5t_a/data/audiobooks /var/www-filesearcher-data/audiobooks
ln -s /mnt/smb/5t_a/data/ebooks /var/www-filesearcher-data/ebooks
ln -s /mnt/smb/5t_a/data/Video /var/www-filesearcher-data/Video
ln -s /mnt/smb/pri/data/public/MP3 /var/www-filesearcher-data/MP3
ln -s /mnt/smb/pri/data/public/MP3_extranea /var/www-filesearcher-data/MP3_extranea
ls -l /var/www-filesearcher-data/
   ./
   ../
   audiobooks -> /mnt/smb/5t_a/data/audiobooks/
   ebooks -> /mnt/smb/5t_a/data/ebooks/
   MP3 -> /mnt/smb/pri/data/public/MP3/
   MP3_extranea -> /mnt/smb/pri/data/public/MP3_extranea/
   Video -> /mnt/smb/5t_a/data/Video/
```
This facilitates future shuffling of content as HDD volumes are migrated, etc.
## install nginx and CGI-related plumbing progs, configure nginx
On Ubuntu 20.04 (or later, presumably):
  * run `apt-get install nginx fcgiwrap libcgi-pm-perl`
  * set Nginx config (Ubuntu: `/etc/nginx/sites-enabled/default`) as follows
     * with `%repo_dir%` being replaced by the location of this repo
     * NB: **if you edit `/etc/nginx/sites-enabled/default`, must `systemctl reload nginx` for it to take effect!**
```
server {
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;
    server_name localhost;
    access_log off;
    error_log /var/log/nginx/error.log notice;

    location / {
        root %repo_dir%/;
        autoindex off;
        index index.html;
    }

    location /files {
        alias /var/www-filesearcher-data;  # dir containing symlinks to disparate content dirs, created above
        autoindex on;
        autoindex_exact_size off;
    }

    location ~ ^/cgi {
        # map /cgi/scriptname -> %repo_dir%/scriptname
        root %repo_dir%/;  # set $document_root for 'fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' in /etc/nginx/fastcgi.conf
        rewrite ^/cgi/(.*) /$1 break;  # rmv '/cgi/' prefix (rewrite directive has space-delimited params)

        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        include fastcgi_params;
    }
}

```
Run `nginx -t` to test config-file changes.

The above, in combination with the contents of this repo, creates from n
disjoint content trees on the server, `/mnt/smb/pri/data/public/ebooks` and
`/mnt/smb/pri/data/public/MP3`, two "static sub-sites", plus a third mapping
`%repo_dir%/index.html` at the site root.

`%repo_dir%/index.html` contains
links enabling manual browsing of the content "sub-sites" and a HTML form
which invokes a GET request to the CGI script `%repo_dir%/search-files`,
which responds with a search-result HTML representation containing links into
the aforementioned "static sub-sites" via which the user can download (and/or
read/listen to) content files.

### Assumptions & Coupling

The collection is organized by filename and directory name.  The filesystem names of the items in the collection are the single source of truth about them; there is NO external metadata collected/maintained/used by this facility (e.g. in a database).

There are a few ways I've organized these collections of files (or file-based
stuff) on my server (Ubuntu Linux exporting Samba shares to Windows clients),
depending on whether they're "1-file per thing" (ebook) or "many files per
thing" (music album, audiobook, etc.):

 * "1-file per thing": `treelocn/hier/archy/name.of.the.book.2005.ext`
     * `treelocn`: rootdir of the content tree.
     * `hier/archy/`: my attempt to categorize (and shard) manually.
     * `name.of.the.book`: a reasonably faithful facsimile of the thing's published name.
     * `2005`: copyright year
     * `.ext`: extension which signals content-type
     * suffix variants: `2005.ext` might morph to either
         * `2005.medtype.ext` generated by [Calibre](https://calibre-ebook.com/ ) when creating PDF from non-PDF, or
         * `2005_cropped.ext` generated by [briss2](https://github.com/fwmechanic/briss2 ) when cropping a PDF.

 * "music album": `treelocn/artist/artist-2005-name.of.the.album [DlxEd] @320/`
     * `treelocn`: as above (but a different location -> different content tree)
     * `artist/`: optional; created when # of albums of artist exceeds an arbitrary threshold.
     * `artist-2005-name.of.the.album [DlxEd] @320/`: '@320' signifies MP3 encoding bitrate.

Other name conventions are coming into use for other types of media.  The names are of significance to this facility for the following reasons:
  * copyright year needs to be extracted for search-result presentation (sorting).
  * disambiguation of file format descriptor vs. file title, allowing different-format files of the same title to be compressed for search-result presentation.

### site-specific config in this repo

As this is a "one off" project (only one instance deployed worldwide), as of 22.07 I've moved all the site-specific Perl stuff into `Site.pm`:
 * `@Site::treelocns` a list of structs (hashrefs) with each list element describing one subtree of the collection.
 * [constant] `Site::CACHEDIR` where per-collection-subtree inotifywait output files and zipdown tempdirs are instantiated.

## Helpful Sources
  * [SO::nginx-static-file-serving-confusion-with-root-alias]( https://stackoverflow.com/questions/10631933/nginx-static-file-serving-confusion-with-root-alias)
  * [github::CGI-bash project]( https://github.com/ruudud/cgi)

# Backstory

I collect ebooks, audiobooks, instructional videos and music MP3's.  As with the WWW itself, the quantity of artifacts I have accumulated mandates an associated search facility to allow the collection to be leveraged.

Searching: since I have collected far more ebooks than albums, years ago I
developed a 100%-Windows-client-based ebook search program (written using a
self-built (Win32-only) version of Lua 5.1 with a few custom libraries added)
that, PER QUERY, created (by scanning a Samba share) a list of candidate
files under "treelocn", then performing string searching on the list of
candidate files.

This "worked OK" (IOW, was "better than nothing") for many years, but (a) didn't scale
well as my ebook collection's size increased: the performance of a Windows client
scanning a dir tree hosted on a Linux/Samba server was poor at best, and (b) its
use required the presence of the search program on the client, which made it
useless to anyone but me.

A recent performance optimization was to have the server periodically run `find`
to create a file containing the candidate file list in the root of the treelocn
subtree (its local filesystem; this takes less than 100mS for a treelocn
containing 40K+ files), which the client (now written in Git for Windows Perl)
reads in lieu of performing its own much slower scan of the Samba server.  This
improved search performance massively, but of course did nothing to make this
file-collection-search functionality (and the file collection itself) accessible
to all (W)LAN clients.

The latest evolution (embodied in the content of this repo) is to roll all
of this into a (server-side) CGI Perl script; the server-side `find` command
is now executed only when the "find cache" (embodied as a file containing
`find`'s output) is expired (by use of `inotifywait` daemons; details
below).  This is hooked into an nginx web-server instance, which also serves
the collection files via search-result links and offers a crude interactive
"dir tree browser" (using nginx autoindex mode).

The idea that I'm using CGI-Perl in a new-in-2017 project will probably
_appall_ anyone who reads this, but: I am not a "web developer" (so I didn't
start this project having a "pet web framework" or a desire to add a new "pet
web framework" notch in my belt), and more saliently, _I don't like
frameworks_ (in fact I prefer to avoid them at all costs: I don't want more
code, more bugs, more inexplicable/magical behavior (which may change in the
next framework release (i.e. `apt-get upgrade`))).  Using the Perl 5 CGI
module (which has, between Ubuntu 14.04 and 18.04, been banished from Perl5's
stdlib) is about as far as I'm willing to go in this direction.

As noted above, the earlier (client) versions of this software were written
in Lua, then Perl 5 (which I've used for decades), and with a very recent
attempt to use go/golang (1.9.2) having been abandoned due to poor
performance related to string searching[1] vs. my Perl implementation), I
have chosen to stick with mainstream single-purpose external components
(nginx), obsolescent technologies (CGI) and a frequently denigrated but
"tried and true" "mature" language (Perl 5).  Hey, I could've used TCL
(naaaw)!

[1] golang's regexes != perlre and in particular my Perl implementation takes
advantage of the perlre-specific `(?=...)` construct which allows creation of a
single regex that checks for matches of ALL word/frag matches occurring in any
order in the target string.  To achieve the same end in golang I had to create a
slice of regexes, one per word/frag, and loop over this slice until the first
miss is encountered, _for each candidate filename_, resulting in the search
process taking > 10x longer vs.  Perl (yes I was amazed; go authorities
explain this as a consequence of go losing out to C and go not implementing
the same flavor of regex as Perl).

*Update 20190530*: performance of the find command imploded when run on
circa 60K file-count dir tree: > 25 seconds to immediately re-run a search
(_on a spinning HDD_ with a hot dir cache): my guess is the dir info for 60K
files overflows some Linux filesystem/directory cache.

After suffering with this situation for too long, I hacked up the following:

 * Created a shell script `modifylog` that runs `inotifywait -r -m $dir` ($dir contains 60+K files),
   logging only _modifying_ events to file `$dir/modify.log`.
    * for now, `modifylog` must be invoked _manually_ each time the server is rebooted.
 * Because the user which `search-files` runs as (www-data) does not have write access to the dir containing `search-files`, and because that user does not have a /home/ dir, a dedicated directory for this user to write find-cache files must be created.
    * Created dirs `/cgi-app-cache/search-files` and gave user www-data exclusive write access to these.
 * Modified `search-files` script to write its (per dir tree) `find` output to `/cgi-app-cache/search-files/$dir-leafname`
 * Modified `search-files` script to read `find` output from `/cgi-app-cache/search-files/$dir-leafname`.
 * Modified `search-files` script to run `find` (overwriting `/cgi-app-cache/search-files/$dir-leafname`) iff mtime of file `$dir/modify.log` is newer than mtime of `/cgi-app-cache/search-files/$dir-leafname`.

This brings performance back down to the 300mS range; not awesome, but massively better than 25,000mS!

## Benchmarking

| Date | # of files | ms | server | OS |
| ---- | -------- |  --- | ----- | ----- |
| 20.07 |  85295  |  210 | TS140 i3-4130 16GB RAM | Ubuntu 14.04(!) |
| 20.10 |  90202  |  170 | TS140 i3-4130 16GB RAM | Ubuntu 20.04 |
| 22.01 | 113265  |  233 | TS140 i3-4130 16GB RAM | Ubuntu 20.04 |
| 22.06 | 121936  |  241 | TS140 i3-4130 16GB RAM | Ubuntu 20.04 |

# Future performance-related directions

Performance per above benchmark results is adequate and stable, but I still
hope for better.  The lazy approach (which I'm currently taking) is to await
the arrival of pending upgrades:

 * Ubuntu 22.04.1 (2022/08/04)
 * a new server (PC hardware): my TS140 with i3-4130 is getting long in the
   tooth.  However it'll be critical to find a replacement that provides a
   significant single-core performance improvement:
    * this CGI program is single-threaded, and my investigation of Perl's
      threads and its other concurrent work related facilities left me
      decidedly unenthused.
 * even more RAM to maximize the presence of media-storage directory (tree)
   in the OS filesystem cache (reducing the runtime of `find`) and provide
   headroom for inotify kernel data, all as the sizeof my media storage
   disk volumes continues its inexorable growth.

The obvious traditional approach which I have till now eschewed (storing the
`find` output, indexed by all component words, in some sort of database and
querying the database for matches) is something I've been thinking about
periodically.  I've not taken action due to

 * not wanting to add the complexity of syncing two sources of truth (filesystem content, database).
    * mapping each filesystem modification event into an INSERT/REPLACE/DELETE DB op in anything approaching real time seems like a gigantic hassle.
    * the cruder approach of completely deleting the database and refreshing it in its entirety from a full `find` output, just seems, well, crude.
       * getting more specific, the idea of using Perl's DBD::SQLite to write/read a character and word-indexed SQLite db file in lieu of the current text file (containing raw `find` output).
 * the current solution looks for not only isolated words but strings (within a word); indexing all word-substrings within a sequence of words strikes me as crazy.
