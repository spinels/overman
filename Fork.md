# Fork history

Overman fixes processes being orphaned during shutdown, originally observed
with JRuby, by starting commands in separate process groups and signaling
the whole group. This remains the fork's main difference from Foreman 0.90.0.

## September 2026: descendants surviving their parent

The original process-group change still allowed descendants that ignored
SIGTERM to survive when their immediate parent exited. Overman removed that
parent from its running list and could finish shutdown before sending SIGKILL
to the remaining group, as reported in
[issue #2](https://github.com/spinels/overman/issues/2).

Overman 0.88.3 addresses this in
[PR #11](https://github.com/spinels/overman/pull/11). It tracks process groups
separately from immediate children, retaining them until they disappear or
the shutdown timeout expires. It reaps exited children before checking group
liveness and rechecks before escalating to SIGKILL. A vanished group no longer
prevents signaling later groups; permission failures produce a warning.

The separate process-group bookkeeping also exposed an output race: buffered
lines read after a child and its group were removed could lose their process
label. [PR #13](https://github.com/spinels/overman/pull/13) keeps each output
reader associated with its process name until EOF so late output remains
correctly attributed.

This applies to descendants that remain in the managed process group.
Processes that leave it, for example through `setsid`, are not tracked.
Zombie-only groups can still cause a full timeout when their ancestor does
not reap them. See [Process lifecycle](README.md#process-lifecycle) for platform
details and container guidance.

## July 2025: upstream takes a different dependency path

Foreman's 0.89 and 0.90 releases changed areas Overman had maintained locally.
These changes have not been imported into Overman 0.88.2.

Upstream replaced vendored Thor with a runtime dependency:

* [3c48caf](https://github.com/ddollar/foreman/commit/3c48caf): unbundle Thor and upgrade to 1.4.0.
* [77c8cb6](https://github.com/ddollar/foreman/commit/77c8cb6): make the CLI options override public for the newer Thor.
* [f577772](https://github.com/ddollar/foreman/commit/f577772): explicitly enable exit on failure.
* [ab36d9c](https://github.com/ddollar/foreman/commit/ab36d9c): declare Thor as a runtime dependency in the gemspec.

Overman retained vendored Thor and support for Ruby 2.3.8 and newer.
Adopting the Thor upgrade
requires considering these commits together and deciding the supported Ruby
versions.

For Bluepill, upstream [ef92565](https://github.com/ddollar/foreman/commit/ef92565)
made generated hash formatting independent of Ruby's `Hash#inspect` output.
Overman continues to use `Hash#inspect`; the generated Ruby remains valid,
but its whitespace varies with the Ruby version.

Upstream [a022c65](https://github.com/ddollar/foreman/commit/a022c65) removed
`ostruct` by deleting the deprecated exporter methods for `port`, `template`,
and `engine.procfile`. Overman retained that interface using `ProcessStruct`.
Importing this removal would change compatibility for custom exporters.

Foreman 0.90.0 still lacked Overman's process-group spawning and signaling.

## February 2025: upstream import and Ruby compatibility

On February 7, [1bd5e00](https://github.com/spinels/overman/commit/1bd5e00)
imported Foreman's April 2024 changes while retaining Overman's process-group
behavior.

Runtime compatibility changes included:

* [c784aa2](https://github.com/spinels/overman/commit/c784aa2): backport a Thor change to avoid loading `reline` through `readline`.
* [5d60599](https://github.com/spinels/overman/commit/5d60599): declare Ruby 2.3.8 as the minimum supported version.

On February 13, [098ec08](https://github.com/spinels/overman/commit/098ec08)
reverted an incorrect replacement of `OpenStruct` with `Struct` that had
shipped in 0.88.1. [96002f8](https://github.com/spinels/overman/commit/96002f8)
then introduced a reusable `ProcessStruct`, removing the `ostruct` dependency
while preserving the deprecated exporter interface. Overman 0.88.2 includes this fix.

## October 2022: process-group shutdown

The fork began on October 28, 2022. Foreman could leave child processes
running after shutdown when a command was launched through an intermediate
shell, as observed with JRuby's handling of working directories.

[PR #1](https://github.com/spinels/overman/pull/1)
([65af5e7](https://github.com/spinels/overman/commit/65af5e7)) added separate
process groups when spawning commands and changed signal forwarding to
address the groups. These changes live in `lib/foreman/process.rb` and
`lib/foreman/engine.rb` and should be preserved when importing upstream work.

The gem and executable were renamed to `overman` in
[3289ff2](https://github.com/spinels/overman/commit/3289ff2).
