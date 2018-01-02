[unlike BitBucket, Github has no markdown TOC feature; Please fix this!](https://github.com/isaacs/github/issues/215)

# Description

This is CGI-Perl project (created in 2017!) that performs a brute-force filename-based
search of a file collection living in a local directory tree.  Results sorted
first by descending copyright year, then alphabetically.  I created it to search for
files on "the family server" (which is mostly _my_ server, but I hope this tool
will remove this exclusivity).

# Setup

On Ubuntu 14.04 (or later, presumably):
  * run `apt-get install nginx fcgiwrap`
  * set Nginx config (Ubuntu: `/etc/nginx/sites-enabled/default`) with the location of this repo replacing %repo_dir%:
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
    location /files/ebooks {
        alias /mnt/smb/pri/data/public/ebooks;
        autoindex on;
        autoindex_exact_size off;
    }
    location /files/mp3 {
        alias /mnt/smb/pri/data/public/MP3;
        autoindex on;
        autoindex_exact_size off;
    }
    location ~ ^/cgi {
        root %repo_dir%/;
        rewrite ^/cgi/(.*) /$1 break;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;  # ubuntu-/fcgiwrap-specific
        fastcgi_param SCRIPT_FILENAME %repo_dir%/search-files;
        include fastcgi_params;
    }
}
```

## Helpful Sources
  * [SO::nginx-static-file-serving-confusion-with-root-alias]( https://stackoverflow.com/questions/10631933/nginx-static-file-serving-confusion-with-root-alias)
  * [github::CGI-bash project]( https://github.com/ruudud/cgi)

# Backstory

I collect ebooks and digital music.

There seem to be two ways I've manually organized files (or file-based
stuff) on my server (Ubuntu Linux exporting Samba shares to Windows clients),
depending on whether they're "1-file per thing" (ebook) or "many files per
thing" (music album, audiobook, etc.):

 * "1-file per thing": treelocn/hier/archy/name.of.the.book.2005.ext
     * treelocn: root of the dir tree
     * hier/archy/: my attempt to categorize manually (and shard)
     * name.of.the.book: a reasonably faithful facsimle of the thing's published name
     * 2005: the date of publication
     * .ext: extension which signals content-type

 * "music album": "treelocn/artist/artist-2005-name.of.the.album [DlxEd] @320/"
     * treelocn: as above
     * artist/: optional; appears when # of albums of artist exceeds an arbitrary thld
     * "artist-2005-name.of.the.album [DlxEd] @320/": self-explanatory?

Searching: since I have far more ebooks than albums, years ago I developed a
100%-Windows-client-based ebook search program (written using a self-built
(Win32-only) version of Lua 5.1 with a few custom libraries added) that, PER
QUERY, created (by scanning a Samba share) a list of candidate files under
"treelocn", then performing string searching on the list of candidate files.

This worked "OK" ("better than nothing") for many years, but (a) didn't scale
well as my ebook collection's size increased: the performance of a Windows client
scanning a dir tree hosted on a Linux/Samba server was poor at best, and (b) its
use required the presence of the search program on the client, which made it
useless to anyone but me; other (W)LAN clients were blocked from accessing this
content.

A recent performance optimization was to have the server periodically run `find`
to create a file containing the candidate file list in the root of the treelocn
subtree (its local filesystem; this takes less than 100mS for a treelocn
containing 40K+ files), which the client (now written in Git for Windows Perl)
reads in lieu of performing its own much slower scan of the Samba server.  This
improved search performance massively, but of course did nothing to make this
file-collection-search functionality (and the file collection itself) accessible
to all (W)LAN clients.

The latest evolution (embodied in the content of this repo) is to roll all of
this into a (server-side) CGI Perl script; the server-side `find` command is now
executed _on each search request_ (this is of course not performance optimal at
scale, but provides an avg response time of 120mS which I deem acceptable (`use
CGI;` added about 10mS to this); optimization will follow if necessary).  This is
hooked into an nginx web-server instance, which also serves the collection files
via search-result links and "browse mode" (using nginx autoindex mode).

The idea that I'm using CGI-Perl in a new-in-2017 project will probably
_appall_ anyone who reads this, but: I am not a "web developer" (so I didn't
start this project having a "pet web framework" or a desire to add a new "pet
web framework" notch in my belt), and more saliently, _I don't like
frameworks_ (in fact I prefer to avoid them at all costs: I don't want more
code, more bugs, more inexplicable/magical behavior (which may change in the
next framework release (i.e. `apt-get upgrade`))).  Using the Perl 5 CGI
module is about as far as I'm willing to go in this direction.

As noted above, the earlier (client) versions of this software were written in
Lua, then Perl 5 (which I've used, off and on, for decades), and with a very
recent attempt to use go/golang (1.9.2) having been abandoned due to poor
performance related to string searching (since golang's regexes are incompatible
with Perl regexes and in particular the '(?=...)' construct which is used above
to construct a single regex that checks for matches of ALL word/frag matches
occurring in any order in the target string, in golang you're forced to
explicitly loop over a slice of regexes (one per word/frag), resulting in the
search process taking > 10x longer (yes I was amazed) vs. my Perl
implementation), I have chosen to stick with popular necessary external
components (nginx), obsolescent technologies (CGI) and a frequently denigrated
but "tried and true" "mature" language (Perl 5).  Hey, I could've used TCL
(naaaw)!
