#!/usr/bin/env python3
"""
Generate Pony Unicode General Category range tables from UnicodeData.txt.

Downloads UnicodeData.txt from the Unicode Consortium and generates
json/_unicode_categories.pony with sorted codepoint range tables for
the 29 General Categories used by RFC 9485 (I-Regexp).

Usage:
  python3 gen_unicode_tables.py > ../../json/_unicode_categories.pony

To update for a new Unicode version, change UNICODE_VERSION below.
"""

import sys
import urllib.request
from collections import defaultdict

UNICODE_VERSION = "16.0.0"
UCD_URL = (
    f"https://www.unicode.org/Public/{UNICODE_VERSION}/ucd/UnicodeData.txt"
)


def download_ucd():
    """Download UnicodeData.txt and return its lines."""
    print(f"Downloading {UCD_URL}...", file=sys.stderr)
    with urllib.request.urlopen(UCD_URL) as resp:
        return resp.read().decode("utf-8").splitlines()


def parse_ucd(lines):
    """Parse UnicodeData.txt into per-category codepoint sets."""
    categories = defaultdict(list)
    range_start = None

    for line in lines:
        line = line.strip()
        if not line:
            continue
        fields = line.split(';')
        cp = int(fields[0], 16)
        name = fields[1]
        cat = fields[2]

        # Handle range entries like "<CJK Ideograph, First>" / "Last>"
        if name.endswith(', First>'):
            range_start = cp
            continue
        elif name.endswith(', Last>'):
            if range_start is not None:
                categories[cat].append((range_start, cp))
                range_start = None
            continue

        categories[cat].append((cp, cp))
        range_start = None

    return categories


def merge_ranges(points):
    """Merge sorted (start, end) pairs into non-overlapping ranges."""
    if not points:
        return []
    sorted_pts = sorted(points)
    merged = [sorted_pts[0]]
    for start, end in sorted_pts[1:]:
        prev_start, prev_end = merged[-1]
        if start <= prev_end + 1:
            merged[-1] = (prev_start, max(prev_end, end))
        else:
            merged.append((start, end))
    return merged


def format_ranges(ranges, indent="    "):
    """Format ranges as Pony array literal lines."""
    lines = []
    for i, (start, end) in enumerate(ranges):
        suffix = "" if i == len(ranges) - 1 else ""
        lines.append(f"{indent}(0x{start:04X}, 0x{end:04X}){suffix}")
    return "\n".join(lines)


# The 29 subcategories defined by RFC 9485
# (Cs/surrogates excluded — not valid Unicode scalar values)
SUBCATEGORIES = [
    "Lu", "Ll", "Lt", "Lm", "Lo",
    "Mn", "Mc", "Me",
    "Nd", "Nl", "No",
    "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po",
    "Zl", "Zp", "Zs",
    "Sm", "Sc", "Sk", "So",
    "Cc", "Cf", "Cn", "Co",
]

MAJOR_CATEGORIES = {
    "L": ["Lu", "Ll", "Lt", "Lm", "Lo"],
    "M": ["Mn", "Mc", "Me"],
    "N": ["Nd", "Nl", "No"],
    "P": ["Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po"],
    "Z": ["Zl", "Zp", "Zs"],
    "S": ["Sm", "Sc", "Sk", "So"],
    "C": ["Cc", "Cf", "Cn", "Co"],
}


def compute_cn(categories):
    """Compute Cn (unassigned) as complement of all assigned categories."""
    assigned = []
    for cat, ranges in categories.items():
        if cat != 'Cn':
            assigned.extend(ranges)
    assigned_merged = merge_ranges(assigned)

    # Cn = valid Unicode scalar values NOT in any assigned category
    # Valid: 0x0000-0xD7FF, 0xE000-0x10FFFF (excluding surrogates)
    cn_ranges = []
    prev_end = -1
    for start, end in assigned_merged:
        if start > prev_end + 1:
            gap_start = prev_end + 1
            gap_end = start - 1
            if gap_start <= 0xD7FF and gap_end >= 0xD800:
                if gap_start <= 0xD7FF:
                    cn_ranges.append((gap_start, min(gap_end, 0xD7FF)))
                if gap_end >= 0xE000:
                    cn_ranges.append((max(gap_start, 0xE000), gap_end))
            elif gap_start >= 0xD800 and gap_end <= 0xDFFF:
                pass
            else:
                cn_ranges.append((gap_start, gap_end))
        prev_end = end

    if prev_end < 0x10FFFF:
        gap_start = prev_end + 1
        gap_end = 0x10FFFF
        if gap_start <= 0xD7FF and gap_end >= 0xD800:
            cn_ranges.append((gap_start, 0xD7FF))
            cn_ranges.append((0xE000, gap_end))
        elif gap_start >= 0xD800 and gap_end <= 0xDFFF:
            pass
        elif gap_start >= 0xE000:
            cn_ranges.append((gap_start, gap_end))
        else:
            cn_ranges.append((gap_start, gap_end))

    return cn_ranges


def generate_pony(categories):
    """Generate the Pony source file to stdout."""
    merged_cats = {}
    for cat in SUBCATEGORIES:
        if cat in categories:
            merged_cats[cat] = merge_ranges(categories[cat])
        else:
            merged_cats[cat] = []

    print(f'// Unicode General Category range tables.')
    print(f'// Generated from Unicode Character Database {UNICODE_VERSION}.')
    print(f'// Source: {UCD_URL}')
    print('//')
    print('// Each subcategory primitive returns sorted, non-overlapping (start, end)')
    print('// codepoint ranges (inclusive). Major categories (L, M, N, etc.) are')
    print('// computed by merging subcategory ranges at lookup time.')
    print('//')
    print(f'// Regenerate: cd tools/gen-unicode-tables && python3 gen_unicode_tables.py > ../../json/_unicode_categories.pony')
    print()

    for cat in SUBCATEGORIES:
        ranges = merged_cats[cat]
        print(f'primitive _UnicodeCategory{cat}')
        print(f'  fun ranges(): Array[(U32, U32)] val =>')
        if not ranges:
            print(f'    []')
        else:
            print(f'    [')
            print(format_ranges(ranges, "      "))
            print(f'    ]')
        print()

    print('primitive _RangeOps')
    print('  """Utilities for working with sorted (start, end) codepoint range arrays."""')
    print()
    print('  fun merge(input: Array[(U32, U32)] ref): Array[(U32, U32)] val =>')
    print('    """')
    print('    Sort and merge overlapping/adjacent ranges. Consumes input, returns val.')
    print('    """')
    print('    // Sort by start codepoint (insertion sort — range arrays are small)')
    print('    var i: USize = 1')
    print('    while i < input.size() do')
    print('      var j = i')
    print('      while j > 0 do')
    print('        try')
    print('          (let a_start, _) = input(j - 1)?')
    print('          (let b_start, _) = input(j)?')
    print('          if a_start > b_start then')
    print('            let tmp = input(j - 1)?')
    print('            input(j - 1)? = input(j)?')
    print('            input(j)? = tmp')
    print('          else')
    print('            break')
    print('          end')
    print('        end')
    print('        j = j - 1')
    print('      end')
    print('      i = i + 1')
    print('    end')
    print('    // Merge overlapping/adjacent')
    print('    let result = recover iso Array[(U32, U32)] end')
    print('    try')
    print('      (var cur_start, var cur_end) = input(0)?')
    print('      var k: USize = 1')
    print('      while k < input.size() do')
    print('        (let next_start, let next_end) = input(k)?')
    print('        if next_start <= (cur_end + 1) then')
    print('          cur_end = cur_end.max(next_end)')
    print('        else')
    print('          result.push((cur_start, cur_end))')
    print('          cur_start = next_start')
    print('          cur_end = next_end')
    print('        end')
    print('        k = k + 1')
    print('      end')
    print('      result.push((cur_start, cur_end))')
    print('    end')
    print('    consume result')
    print()
    print('  fun union(')
    print('    a: Array[(U32, U32)] val,')
    print('    b: Array[(U32, U32)] val)')
    print('    : Array[(U32, U32)] val')
    print('  =>')
    print('    """Merge two sorted range arrays into one sorted, merged array."""')
    print('    let combined = Array[(U32, U32)](a.size() + b.size())')
    print('    for r in a.values() do combined.push(r) end')
    print('    for r in b.values() do combined.push(r) end')
    print('    merge(combined)')
    print()

    print('primitive _UnicodeCategories')
    print('  """')
    print('  Look up Unicode General Category range tables by abbreviation.')
    print('  Subcategories (e.g., "Lu", "Nd") return precomputed ranges.')
    print('  Major categories (e.g., "L", "N") merge subcategory ranges.')
    print('  Raises on unknown category name.')
    print('  """')
    print()
    print('  fun apply(name: String): Array[(U32, U32)] val ? =>')
    print('    match name')

    for cat in SUBCATEGORIES:
        print(f'    | "{cat}" => _UnicodeCategory{cat}.ranges()')

    for major, subs in MAJOR_CATEGORIES.items():
        parts = [f'_UnicodeCategory{s}.ranges()' for s in subs]
        print(f'    | "{major}" =>')
        expr = parts[0]
        for part in parts[1:]:
            expr = f'_RangeOps.union({expr}, {part})'
        print(f'      {expr}')

    print('    else')
    print('      error')
    print('    end')


def main():
    lines = download_ucd()
    categories = parse_ucd(lines)
    categories['Cn'] = compute_cn(categories)
    generate_pony(categories)
    print(
        f"Generated tables for {len(SUBCATEGORIES)} subcategories "
        f"from Unicode {UNICODE_VERSION}.",
        file=sys.stderr,
    )


if __name__ == '__main__':
    main()
