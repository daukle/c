# c

The C language plugin for daukle. It renders resolved modules into a CMake region as FetchContent_Declare and FetchContent_MakeAvailable calls followed by one target_link_libraries line, rewriting only the text between the daukle markers.

## Examples

- [`c-hello-executable`](examples/c-hello-executable): A managed C project.

## License

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
