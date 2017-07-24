## Danboorus

This is a multitenant version of Danbooru. It allows users to setup
their own Danbooru instance online without having to manually install 
the software on a server. It is forked from the original Danbooru 
project but has a few important differences:

### Major

* There is no mandatory moderation process. All uploads are uploaded
as approved by default.
* Consequently, there are no approval or unlimited upload roles.
* Janitors are not supported. Only moderators and above have approval privileges.
* Super voters are not supported.
* User similarity reports are not supported.
* The admin dashboard is not supported.
* The counts API is not supported.
* API keys are not supported.
* Missed and popular search reports are not supported.
* Posts can be flagged but there is no concept of appeals.
* IQDB is not supported (currently).
* The legacy API is not supported.
* Post replacements are not supported.
* The following content is banned: children, lolita, pre-teen, snuff, scat, mutilation, bestiality, and rape. This is because the payment processor bans this material.

### Minor

* The tag correction system is not supported.
* 