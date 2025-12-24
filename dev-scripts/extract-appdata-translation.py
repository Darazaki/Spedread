#!/usr/bin/env python3


def normalize_whitespace(text: str) -> str:
    """
    Normalize whitespace in a string.

    Args:
        text: Input string

    Returns:
        String with trimmed whitespace, all whitespace converted to spaces,
        and consecutive spaces collapsed to single spaces
    """
    import re

    text = text.strip()
    text = re.sub(r"\s+", " ", text)
    return text


def extract_summary_description(xml_file_path: str) -> list[tuple[str, str, int]]:
    """
    Extract text from 'summary' or 'description' nodes in an XML file,
    including all text from their subnodes.

    Args:
        xml_file_path: Path to the XML file

    Returns:
        List of tuples containing (node_name, text_content, line_number)
    """
    from xml.parsers import expat

    class LineNumberingParser:
        """Parser that tracks line numbers for elements."""

        def __init__(self):
            self.results = []
            self.element_stack = []
            self.parser = expat.ParserCreate()

            # Set up parser callbacks
            self.parser.StartElementHandler = self.start_element
            self.parser.EndElementHandler = self.end_element
            self.parser.CharacterDataHandler = self.char_data

        def start_element(self, name, attrs):
            """Called when an opening tag is encountered."""
            elem_info = {
                "tag": name,
                "attribs": attrs,
                "line": self.parser.CurrentLineNumber,
                "texts": [],
                "children_data": [],  # List of (text, line_number, tag) tuples
            }

            self.element_stack.append(elem_info)

        def end_element(self, name):
            """Called when a closing tag is encountered."""
            elem_info = self.element_stack.pop()

            # Combine direct text from this element only and normalize it
            direct_text = "".join(elem_info["texts"])
            direct_text = normalize_whitespace(direct_text)

            # Check if this is a summary or description element
            if name in ("summary", "description"):
                # Check if translatable attribute is set to "no"
                if elem_info["attribs"].get("translatable") == "no":
                    if self.element_stack:
                        # Pass all data up to parent
                        if direct_text:
                            self.element_stack[-1]["children_data"].append(
                                (direct_text, elem_info["line"], name)
                            )
                        self.element_stack[-1]["children_data"].extend(
                            elem_info["children_data"]
                        )
                    return

                # Output direct text with this element's line number
                if direct_text:
                    self.results.append((name, direct_text, elem_info["line"]))

                # Output all children data with their respective line numbers
                for text, line_num, _ in elem_info["children_data"]:
                    self.results.append((name, text, line_num))
            else:
                # For non-summary/description elements, combine text and pass up
                combined_text = direct_text
                if elem_info["children_data"]:
                    # Combine direct text with children text
                    children_texts = [direct_text] if direct_text else []
                    children_texts.extend([t for t, _, _ in elem_info["children_data"]])
                    combined_text = " ".join(children_texts)
                    combined_text = normalize_whitespace(combined_text)

                if self.element_stack and combined_text:
                    self.element_stack[-1]["children_data"].append(
                        (combined_text, elem_info["line"], name)
                    )

        def char_data(self, data):
            """Called when text content is encountered."""
            if self.element_stack:
                self.element_stack[-1]["texts"].append(data)

        def parse_file(self, file_path):
            """Parse the XML file."""
            with open(file_path, "rb") as f:
                self.parser.ParseFile(f)
            return self.results

    # Create parser and parse file
    parser = LineNumberingParser()
    results = parser.parse_file(xml_file_path)

    # Sort by line number
    results.sort(key=lambda x: x[2])
    return results


def write_po_file(
    input_filename: str,
    output_filename: str,
    extracted_data: list[tuple[str, str, int]],
) -> None:
    """
    Write extracted text to a .po translation file.

    Args:
        input_filename: Original XML filename (used in comments)
        output_filename: Output .po file path
        extracted_data: List of tuples (node_name, text, line_number) from extract_summary_description
    """

    def wrap_comment_line(
        prefix: str, locations: list[str], max_length=80
    ) -> list[str]:
        """
        Wrap location comments to not exceed max_length characters.
        Returns a list of comment lines.
        """
        lines = []
        current_line = prefix

        for location in locations:
            # Check if adding this location would exceed the character limit
            test_line = (
                current_line + (" " if current_line != prefix else "") + location
            )
            if len(test_line) > max_length and current_line != prefix:
                # Save current line and start a new one
                lines.append(current_line)
                current_line = prefix + location
            else:
                if current_line != prefix:
                    current_line += " "
                current_line += location

        if current_line != prefix:
            lines.append(current_line)

        return lines

    def wrap_msgid(text: str, max_length=80) -> list[str]:
        """
        Wrap msgid text to not exceed max_length characters per line.
        Returns a list of lines.
        """
        # Escape special characters
        escaped_text = (
            text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        )

        # If it fits on one line, return simple format
        if len(f'msgid "{escaped_text}"') <= max_length:
            return [f'msgid "{escaped_text}"']

        # Otherwise, split into multiple lines
        lines = ['msgid ""']
        words = escaped_text.split(" ")
        current_line = ""

        for word in words:
            # Check if adding this word would exceed the limit
            test_line = current_line + (" " if current_line else "") + word
            if len(f'"{test_line}"') > max_length - 1 and current_line:
                # Save current line and start a new one
                lines.append(f'"{current_line} "')
                current_line = word
            else:
                if current_line:
                    current_line += " "
                current_line += word

        if current_line:
            lines.append(f'"{current_line}"')

        return lines

    # Group texts by their content to combine line number references
    text_to_lines = {}
    for _, text, line_num in extracted_data:
        if text not in text_to_lines:
            text_to_lines[text] = []
        text_to_lines[text].append(line_num)

    with open(output_filename, "w", encoding="utf-8") as f:
        # Write each entry sorted by smallest line number
        for text, line_numbers in sorted(
            text_to_lines.items(), key=lambda x: min(x[1])
        ):
            # Write location comments with wrapping
            locations = [f"{input_filename}:{line}" for line in sorted(line_numbers)]
            comment_lines = wrap_comment_line("#: ", locations)
            for comment_line in comment_lines:
                f.write(f"{comment_line}\n")

            # Write msgid with wrapping
            msgid_lines = wrap_msgid(text)
            for msgid_line in msgid_lines:
                f.write(f"{msgid_line}\n")

            # Write empty msgstr
            f.write('msgstr ""\n\n')


if __name__ == "__main__":
    APPDATA_FILENAME = "./data/com.github.Darazaki.Spedread.appdata.xml.in"
    results = extract_summary_description(APPDATA_FILENAME)
    write_po_file(APPDATA_FILENAME, "appdata.po", results)
