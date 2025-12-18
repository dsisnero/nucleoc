# Nucleoc - Fuzzy Matcher for Crystal

[![CI](https://github.com/dsisnero/nucleoc/actions/workflows/ci.yml/badge.svg)](https://github.com/dsisnero/nucleoc/actions/workflows/ci.yml)
[![GitHub license](https://img.shields.io/github/license/dsisnero/nucleoc)](https://github.com/dsisnero/nucleoc/blob/main/LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/dsisnero/nucleoc)](https://github.com/dsisnero/nucleoc/releases)
[![Crystal Shards](https://img.shields.io/badge/crystal-shards-blue)](https://crystal-lang.org)

Nucleoc is a Crystal port of the [nucleo](https://github.com/helix-editor/nucleo) fuzzy matcher from Rust.
It provides high-performance fuzzy matching algorithms for text search and filtering.

## Status

⚠️ **Early Development** - This is an early port of the Rust nucleo library. Currently only basic exact matching is implemented. The full fuzzy matching functionality is under development.

## Features

- [x] Exact string matching
- [x] Case-sensitive and case-insensitive matching
- [x] Configurable scoring parameters
- [ ] Fuzzy matching (in progress)
- [ ] Substring matching
- [ ] Prefix/Postfix matching
- [ ] Pattern parsing
- [ ] Unicode normalization
- [ ] High-performance optimizations

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     nucleoc:
       github: dsisnero/nucleoc
   ```

2. Run `shards install`

## Usage

```crystal
require "nucleoc"

# Create a matcher with default configuration
matcher = Nucleoc::Matcher.new

# Exact matching
if score = matcher.exact_match("hello world", "hello world")
  puts "Match found with score: #{score}"
end

# Case insensitive matching (default)
matcher.exact_match("Hello", "hello") # => 0 (match)

# Case sensitive matching
config = Nucleoc::Config.new(ignore_case: false)
matcher = Nucleoc::Matcher.new(config)
matcher.exact_match("Hello", "hello") # => nil (no match)

# Matching with indices
indices = [] of UInt32
if score = matcher.exact_indices("crystal", "crystal", indices)
  puts "Match indices: #{indices}"
end
```

## Configuration

```crystal
# Default configuration
config = Nucleoc::Config::DEFAULT

# Custom configuration
config = Nucleoc::Config.new(
  ignore_case: false,
  normalize: true,
  prefer_prefix: false,
  delimiter_chars: "/,:;|"
)

# Configure for file path matching
config = Nucleoc::Config::DEFAULT.match_paths
```

## Development Status

This project is actively being developed to port the full functionality from the Rust nucleo library. The current implementation includes:

1. **Basic structure** - Config, Matcher, character classification
2. **Exact matching** - Simple exact string matching
3. **Character utilities** - ASCII/Unicode character classification

Coming soon:

1. Fuzzy matching algorithms
2. Substring matching
3. Pattern parsing
4. Performance optimizations

## Development

### Prerequisites
- Crystal 1.18.2 or later
- Git

### Setup
```bash
git clone https://github.com/dsisnero/nucleoc.git
cd nucleoc
shards install
```

### Running Tests
```bash
crystal spec
```

### Code Quality
```bash
# Format code
crystal tool format src/ spec/

# Run linter
ameba
```

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer

See the full list of [contributors](https://github.com/dsisnero/nucleoc/contributors) who participated in this project.

## Acknowledgments

- Based on the [nucleo](https://github.com/helix-editor/nucleo) Rust library by Pascal Kuthe and the Helix editor team
- Inspired by fzf and skim fuzzy matching algorithms
- Uses [CML](https://github.com/dsisnero/cml) for concurrent ML patterns

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
