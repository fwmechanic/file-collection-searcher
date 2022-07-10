package Site;
use Strict;

# no code; contains semantic mappings of web dirs to filesys dirs

use constant CACHEDIR => "/cgi-app-cache/search-files";  # in lieu of config file or parameter support: these two dirs are OWNED and writable only by www-data

my $common_fsroot = '/var/www-filesearcher-data';  # contains symlinks to actual file trees

#
# As noted in README.md
#    * suffix variants: `2005.ext` might morph to either
#        * `2005.medtype.ext` generated by [Calibre](https://calibre-ebook.com/ ) when creating PDF from non-PDF, or
#        * `2005_cropped.ext` generated by [briss2](https://github.com/fwmechanic/briss2 ) when cropping a PDF.
# the vast majority of the time, a user will want to download the (cropped) pdf
# version of the ebook.  Since there are potentially many variants (formats and
# croppings) of the SAME book (in INCREASING order of preference:
#    * book.(djvu|azw3|chm|mobi|epub|pdf)
#    * book_cropped.pdf  (locally generated from book.pdf)
#    * book.medtype.pdf  (locally generated from book.(azw3|chm|mobi|epub))
#    * book.code.zip     (git repo(s) associated with book text)
# ) it would be helpful for these to collapse into a single line containing
# multiple links, with the best version ( being left-most (and the longest
# link).
#
# What I think this means is I want to determine the basename (book) and find
# all files having the same basename and compress them as above.
#
our @treelocns = (  # unfortunately necessary hardcoding of app filesys/webapp mappings
   # HACK ALERT: handler_search_keys call tree adds {matches} to these array entries!!!
   # align with /etc/nginx/sites-enabled/default (must edit as root)
   { isa=>'b', ft=>'f', cat=>'Books'      , webroot=>'/files/ebooks'       , fsroot=>$common_fsroot.'/ebooks'       },
   { isa=>'m', ft=>'d', cat=>'Music'      , webroot=>'/files/MP3'          , fsroot=>$common_fsroot.'/MP3'          },
 # { isa=>'m', ft=>'d', cat=>'Music'      , webroot=>'/files/MP3_extranea' , fsroot=>$common_fsroot.'/MP3_extranea' },
   { isa=>'a', ft=>'f', cat=>'Audiobooks' , webroot=>'/files/audiobooks'   , fsroot=>$common_fsroot.'/audiobooks'   },
   { isa=>'v', ft=>'d', cat=>'Videos'     , webroot=>'/files/Video'        , fsroot=>$common_fsroot.'/Video'        },
   );
