## Fastly Deprecation Notice

This repository is no longer used. Source code to build fst-unbound
is fetched directly from vendor releases now.

## Unbound README
* ./configure && make && make install
* You can use libevent if you want. libevent is useful when using 
  many (10000) outgoing ports. By default max 256 ports are opened at
  the same time and the builtin alternative is equally capable and a 
  little faster.
* More detailed README, README.svn, README.tests in doc directory
* manual pages can be found in doc directory, and are installed, unbound(8).
* example configuration file doc/example.conf

