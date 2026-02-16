# Tools

Code generation and maintenance tools for json-ng. These are development-time utilities, not part of the library itself.

## gen-unicode-tables

Generates `json/_unicode_categories.pony` from the Unicode Character Database. The generated file contains sorted codepoint range tables for the 29 Unicode General Categories used by the I-Regexp engine (RFC 9485).

```bash
cd tools/gen-unicode-tables
python3 gen_unicode_tables.py > ../../json/_unicode_categories.pony
```

The script downloads `UnicodeData.txt` from the Unicode Consortium automatically. To update for a new Unicode version, change `UNICODE_VERSION` at the top of the script.

Currently targets Unicode 16.0.
