# /usr/bin/env python3
import re
import argparse
from pathlib import Path


def generate_module_content(name: str) -> str:
    return f"""// {name}.bicep

@description('Region to deploy')
param location string = resourceGroup().location

// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Resources
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------
"""


def generate_testfile_content(name: str) -> str:
    return f"""// {name}.test.bicep

param location string = resourceGroup().location
param envName string = 'mod-{name}'
"""


def normalized_name(name: str) -> str:
    s = name.strip().lower()
    s = s.replace("_", "-")
    s = re.sub(r"\s+", "-", s)
    return s


def main():
    parser = argparse.ArgumentParser(description="A script to create a new module")
    parser.add_argument("name", help="The name of a new module")
    args = parser.parse_args()

    # module name
    name = normalized_name(args.name)

    # create folders
    root_path = Path(__file__).resolve().parent
    (root_path / name / "test").mkdir(parents=True, exist_ok=True)

    # write files
    moduel_path = root_path / name / f"{name}.bicep"
    with moduel_path.open("w", encoding="utf-8") as f:
        f.write(generate_module_content(name))

    testfile_path = root_path / name / "test" / "main.test.bicep"
    with testfile_path.open("w", encoding="utf-8") as f:
        f.write(generate_testfile_content(name))


if __name__ == "__main__":
    main()
