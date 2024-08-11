# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html), insofar as
I understand how Elixir uses it.

## [Unreleased]

### Added

- `Lens2.Lenses.Keyword` lens makers
- Lenses for `BiMap` now also handle `BiMultiMap`.
- `defmakerp` and `deflensp`
– Because [TypedStructLens](https://hexdocs.pm/typed_struct_lens/readme.html) has a
  hardcoded dependency on Lens 1, I had to make a copy to alias. 

### Changed
- `Lens.Lenses.BiMap` changed to `Lens.Lenses.Bi` because it now handles both
  types of maps in the [`BiMap`](https://hexdocs.pm/bimap/readme.html) package.

### Fixed

- Various documentation glitches


## [0.1.0] - 2024-08-07

Initial version.

