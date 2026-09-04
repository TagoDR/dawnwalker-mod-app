cmake_minimum_required(VERSION 3.22)
project(DawnwalkerNativeMods)

# RE-UE4SS is cloned as a sibling directory here (see README.md) — not
# vendored into this repo, gitignored.
add_subdirectory(RE-UE4SS)
add_subdirectory(DawnwalkerNativeFix)
