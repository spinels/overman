# Overman (`ddollar/foreman` fork)

[![CI](https://github.com/spinels/overman/actions/workflows/ci.yml/badge.svg)](https://github.com/spinels/overman/actions/workflows/ci.yml)

Manage Procfile-based applications

## Installation

    $ gem install overman

Ruby users should take care _not_ to install foreman in their project's `Gemfile`. See this [wiki article](https://github.com/ddollar/foreman/wiki/Don't-Bundle-Foreman) for more details.

## Getting Started

- http://blog.daviddollar.org/2011/05/06/introducing-foreman.html

## Process lifecycle

`overman start` runs each command in a separate process group. On Unix, shutdown
sends SIGTERM to those groups and waits for them to exit, including descendants
that remain in the group after their immediate parent exits. Groups still running
after the shutdown timeout receive SIGKILL. Descendants that leave the group,
for example by calling `setsid`, are not tracked. On Windows, shutdown sends
SIGKILL immediately.

Groups that cannot be signaled due to permission errors are skipped with a warning.
On systems where zombie-only groups still appear alive, an ancestor that does not
reap orphaned processes can cause shutdown to wait the full timeout; use a reaping
init process when running in a container, such as Docker's `--init` option.

## Supported Ruby versions

See [ci.yml](.github/workflows/ci.yml) for a list of Ruby versions against which Foreman is tested.

## Documentation

- [man page](http://ddollar.github.io/foreman/)
- [wiki](https://github.com/ddollar/foreman/wiki)
- [changelog](https://github.com/ddollar/foreman/blob/main/Changelog.md)

## Ports

- [forego](https://github.com/ddollar/forego) - Go
- [node-foreman](https://github.com/strongloop/node-foreman) - Node.js
- [gaffer](https://github.com/jingweno/gaffer) - Java/JVM
- [goreman](https://github.com/mattn/goreman) - Go
- [honcho](https://github.com/nickstenning/honcho) - python
- [proclet](https://github.com/kazeburo/Proclet) - Perl
- [shoreman](https://github.com/chrismytton/shoreman) - shell
- [crank](https://github.com/arktisklada/crank) - Crystal
- [houseman](https://github.com/fujimura/houseman) - Haskell
- [spm](https://github.com/bytegust/spm) - Go

## Authors

#### Created and maintained by

David Dollar

#### Patches contributed by

[Contributor List](https://github.com/ddollar/foreman/contributors)

## License

Foreman is licensed under the MIT license.

See LICENSE for the full license text.
