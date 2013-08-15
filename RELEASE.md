`mixlib-authorization` Releases
===============================

PSYCH!

We no longer create official "releases" of this library, though
we did in the past (which accounts for the `release` branch and
various tags).  Now, whatever is on `master` is the "current release",
and consumers of the library control which version they use based on
`Gemfile.lock` contents.  This is analogous to how we manage our
various Erlang libraries (e.g., see the use of the `rebar_lock_deps`
plugin for `erchef` and `oc_erchef`).

If you have something that's ready to merge to master, go ahead and do
it, and adjust the client application's `Gemfile.lock` file as
appropriate.
