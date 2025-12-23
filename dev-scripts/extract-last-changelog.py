#!/usr/bin/env python3

import xml.etree.ElementTree as ET


def description_node_to_markdown(description: ET.Element) -> str:
    result = ""
    for node in description:
        tag = node.tag
        if tag == "p":
            result += str(node.text) + "\n"
        elif tag == "ul":
            for item in node:
                result += "- " + str(item.text) + "\n"
        else:
            continue
        result += "\n"

    return result.strip()


def print_all_releases() -> None:
    root = ET.parse("./data/com.github.Darazaki.Spedread.appdata.xml.in").getroot()
    releases = root.findall("./releases/release")
    descriptions = root.findall("./releases/release/description")
    assert len(releases) == len(descriptions)

    for release, description in zip(releases, descriptions):
        md = description_node_to_markdown(description)
        md = "\n".join("    " + line for line in md.splitlines())
        print(str(release.get("version")) + ":", md, sep="\n", end="\n\n")


def print_last_release() -> None:
    root = ET.parse("./data/com.github.Darazaki.Spedread.appdata.xml.in").getroot()
    release = root.find("./releases/release")
    assert release is not None

    version = release.get("version")
    date = release.get("date")
    assert version is not None and date is not None

    description_xpath = f'./releases/release[@version="{version}"]/description'
    description = root.find(description_xpath)
    assert description is not None

    print("<!--", version, "@", date, "-->")
    print(description_node_to_markdown(description))


if __name__ == "__main__":
    print_last_release()
