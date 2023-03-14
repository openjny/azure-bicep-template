# /usr/bin/env python3
import re
import argparse
from pathlib import Path


def generate_module_content(name: str) -> str:
    return f"""// {name}.bicep

@description('Region to deploy')
param location string = resourceGroup().location

@description('{name} name suffix (e.g. "{name}-<suffix>")')
param nameSuffix string

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
    parser = argparse.ArgumentParser(description="Ceate a new module")
    parser.add_argument("category", help="Resource category (e.g. network)")
    parser.add_argument("name", help="Resource name (e.g. vpngw)")
    args = parser.parse_args()

    # module category/name
    category = normalized_name(args.category)
    name = normalized_name(args.name)

    # directory
    root_path = Path(__file__).resolve().parent
    moduel_path = root_path / category / f"{name}.bicep"
    testfile_path = root_path / category / "tests" / f"{name}.test.bicep"

    # set up directories
    (root_path / category / "tests").mkdir(parents=True, exist_ok=True)

    # write files
    with moduel_path.open("w", encoding="utf-8") as f:
        f.write(generate_module_content(name))

    with testfile_path.open("w", encoding="utf-8") as f:
        f.write(generate_testfile_content(name))


if __name__ == "__main__":
    main()
