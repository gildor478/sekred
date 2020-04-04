# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog], and this project adheres to [Semantic Versioning].

[Keep a Changelog]: https://keepachangelog.com/en/1.0.0/
[Semantic Versioning]: https://semver.org/spec/v2.0.0.html

## [0.2.3] - 2020-04-05
* Use dispakan.

## [0.2.2] - 2018-05-05
* Compile to native when possible.
* Fix problems with Bytes/String.
* Stop deploying Debian archive.

## [0.2.1] - 2015-04-1
* Add a subcommand "exists" to test existence of a domain.

## [0.2.0] - 2013-10-23
* Drop the need of a sticky bit:
  * domain are now stored in separate directory for each user
  * before a user can use sekred, administrator must "enable" the user

* Implement a test suite, using OUnit v0.2.
