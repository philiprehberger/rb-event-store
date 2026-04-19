# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-04-18

### Added
- `Store#clear(stream = nil)` — removes events and snapshot for a stream, or everything when no stream is passed; subscribers remain registered; clearing all resets the global position

## [0.2.3] - 2026-04-08

### Changed
- Align gemspec summary with README description.

## [0.2.2] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.0] - 2026-03-27

### Added
- Event querying with `#query(stream:, type:, after:, before:, limit:)` for filtered reads
- Event snapshots via `#snapshot(stream, state)` to save aggregate state at a version
- Snapshot-based loading via `#load_from_snapshot(stream)` to rebuild from snapshot + newer events
- Stream replay via `#replay(stream, from_version:)` to re-emit events to subscribers
- Global replay via `#replay_all(from_position:)` across all streams
- Stream version tracking via `#version(stream)` returning event count
- Global position tracking for cross-stream event ordering
- Timestamp metadata on all events for time-based querying
- Support section with LinkedIn and packages badges in README
- All 8 standard badges in README

## [0.1.1] - 2026-03-22

### Changed
- Expanded test suite to 30+ examples covering edge cases, error paths, and boundary conditions

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Named stream support for event organization
- Append and read operations for individual streams
- Read all events across all streams
- Subscriber notifications on event append
- State projections with reduce-style accumulation
- Thread-safe operations with mutex synchronization
