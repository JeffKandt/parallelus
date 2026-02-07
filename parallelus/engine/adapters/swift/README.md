# Swift Adapter

This adapter provides Swift-specific tooling integration for the Interruptus Agent Process.

## Requirements

- Swift 5.0+ (installed via [swift.org](https://swift.org/download/))
- Swift Package Manager (included with Swift)
- SwiftLint (optional, install with `brew install swiftlint`)
- SwiftFormat (optional, install with `brew install swiftformat`)

## Features

- **Environment Setup**: Validates Swift installation and resolves dependencies
- **Linting**: Runs SwiftLint for code style checks
- **Formatting**: Runs SwiftFormat for code formatting
- **Testing**: Executes tests using Swift Package Manager

## Project Structure

The adapter expects a standard Swift Package Manager structure:

```
Project/
├── Package.swift          # Package manifest
├── Sources/               # Source code
│   └── ProjectName/
│       └── ProjectName.swift
├── Tests/                 # Test code
│   └── ProjectNameTests/
│       └── ProjectNameTests.swift
└── README.md
```

## Configuration

The adapter reads its commands from `parallelus/engine/agentrc` so teams can tailor tooling without editing the scripts:

- `SWIFT_LINT_CMD`: lint command (default: `swiftlint lint --quiet`)
- `SWIFT_FORMAT_CMD`: format command (default: `swiftformat --quiet .`)
- `SWIFT_TEST_CMD`: test command (default: `swift test --quiet`)

Each helper script shells out via these variables. Override them in `parallelus/engine/agentrc` (or export them in the environment) to plug in custom tasks such as Danger checks, xcbeautify, or multi-target builds.

## Usage

The adapter is automatically used when `LANG_ADAPTERS` includes `swift` in `parallelus/engine/agentrc`:

```bash
# In parallelus/engine/agentrc
LANG_ADAPTERS="swift"

# Then use the standard agent process commands
make lint      # Runs SwiftLint
make format    # Runs SwiftFormat  
make test      # Runs Swift tests
make ci        # Runs lint + test + smoke suite
```

## Integration with Agent Process

The Swift adapter integrates seamlessly with the agent process workflow:

1. **Bootstrap**: Creates Swift package structure
2. **Development**: Provides linting, formatting, and testing
3. **CI**: Runs all checks before merge
4. **Documentation**: Generates documentation using DocC

## Troubleshooting

### Swift Not Found
```bash
# Install Swift on macOS
brew install swift

# Or download from swift.org
```

### SwiftLint Not Found
```bash
# Install SwiftLint
brew install swiftlint
```

### SwiftFormat Not Found
```bash
# Install SwiftFormat
brew install swiftformat
```

### Package Resolution Issues
```bash
# Clean and resolve dependencies
swift package clean
swift package resolve
```
