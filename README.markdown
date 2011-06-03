scripts to migrate trac to github.

trac is in a sqlite db, which should make this doable


# Format Conversion #

I wish this was simpler.

trac uses "wiki format" which is mostly the same across several
wikis. Notably, moinmoin, and wikimedia. Pandoc has a somewhat out of
date branch with moinmoin support. 

So, install the moinmoin branch of pandoc, and go. The corner cases
may not work, but it's probably a little cleaner than raw. (Note that
this requires some monkeying with the dependencies)

----

We don't have a large or complex bug database, and we don't think we
care much about the past, so this is a pretty lightweight converter. 

ticket initial data (and metadata?) is in the tickets table
ticket updates are in the ticket_change table.

# Psuedo code #

For each ticket

  get all updates
  
  push ticket & updates into GH (either en mass or piecemeal)
  
  set final status and tags
  
end



Some interesting prior art:

 * https://code.launchpad.net/trac-launchpad-migrator
 * https://github.com/seven1m/trac_wiki_to_github
