#!/usr/bin/env python3
"""
Alternative parser for locally downloaded Morning and Evening content.
This script can parse content from various sources including:
- CCEL HTML files
- Plain text files
- Manually copied content
"""

import json
import re
from bs4 import BeautifulSoup
import os
import sys

def extract_day_number(date_str):
    """Extract day number (1-365) from date string like 'January 1'."""
    months = {
        'january': 1, 'february': 2, 'march': 3, 'april': 4,
        'may': 5, 'june': 6, 'july': 7, 'august': 8,
        'september': 9, 'october': 10, 'november': 11, 'december': 12
    }
    days_per_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    
    match = re.match(r'(\w+)\s+(\d+)', date_str, re.IGNORECASE)
    if match:
        month_name = match.group(1).lower()
        day = int(match.group(2))
        
        if month_name in months:
            month_num = months[month_name]
            day_number = sum(days_per_month[:month_num-1]) + day
            return day_number
    
    return 1

def get_month_name(day_number):
    """Get month name from day number (1-365)."""
    months = ['January', 'February', 'March', 'April', 'May', 'June',
              'July', 'August', 'September', 'October', 'November', 'December']
    days_per_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    
    day = day_number
    for i, days in enumerate(days_per_month):
        if day <= days:
            return months[i]
        day -= days
    return 'December'

def get_day_of_month(day_number):
    """Get day of month from day number (1-365)."""
    days_per_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    
    day = day_number
    for days in days_per_month:
        if day <= days:
            return day
        day -= days
    return day

def parse_content_file(filepath):
    """Parse a content file (HTML or text)."""
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    is_html = '<html' in content.lower() or '<body' in content.lower()
    
    if is_html:
        return parse_html_content(content)
    else:
        return parse_text_content(content)

def parse_html_content(content):
    """Parse HTML content."""
    soup = BeautifulSoup(content, 'html.parser')
    
    # Remove script, style, nav, header, footer
    for tag in soup(["script", "style", "nav", "header", "footer", "link", "meta"]):
        tag.decompose()
    
    # Get text content
    text = soup.get_text(separator='\n')
    return parse_text_content(text)

def parse_text_content(text):
    """Parse plain text content."""
    devotions = []
    
    # Patterns for matching dates with morning/evening
    # Handle multiple formats:
    # - "Morning, January 1" and "January 1, Morning"
    # - "January 1 AM" and "January 1 PM"
    morning_date_pattern = re.compile(
        r'Morning[\s,]+((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)',
        re.IGNORECASE
    )
    evening_date_pattern = re.compile(
        r'Evening[\s,]+((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)',
        re.IGNORECASE
    )
    date_morning_pattern = re.compile(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)[\s.,—\-]*Morning',
        re.IGNORECASE
    )
    date_evening_pattern = re.compile(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)[\s.,—\-]*Evening',
        re.IGNORECASE
    )
    # AM/PM format: "January 1 AM" or "January 1 PM"
    date_am_pattern = re.compile(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)\s+AM',
        re.IGNORECASE
    )
    date_pm_pattern = re.compile(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)\s+PM',
        re.IGNORECASE
    )
    
    lines = text.split('\n')
    current_day = None
    current_type = None
    current_content = []
    last_date = None
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        if not line or len(line) < 3:
            i += 1
            continue
        
        # Check for morning (try all formats: "Morning, January 1", "January 1, Morning", "January 1 AM")
        morning_match = morning_date_pattern.search(line) or date_morning_pattern.search(line) or date_am_pattern.search(line)
        if morning_match:
            if current_day is not None and current_content:
                devotions.append(create_devotion(current_day, current_type, current_content))
            
            date_str = morning_match.group(1)
            current_day = extract_day_number(date_str)
            current_type = 'morning'
            current_content = []
            last_date = date_str
            i += 1
            continue
        
        # Check for evening (try all formats: "Evening, January 1", "January 1, Evening", "January 1 PM")
        evening_match = evening_date_pattern.search(line) or date_evening_pattern.search(line) or date_pm_pattern.search(line)
        if evening_match:
            if current_day is not None and current_content:
                devotions.append(create_devotion(current_day, current_type, current_content))
            
            date_str = evening_match.group(1)
            current_day = extract_day_number(date_str)
            current_type = 'evening'
            current_content = []
            last_date = date_str
            i += 1
            continue
        
        # Collect content
        if current_day is not None:
            # Skip separator lines (lines with only underscores, dashes, or whitespace)
            if re.match(r'^[_\-\s]+$', line):
                # Don't add separator lines, but don't stop collection either
                i += 1
                continue
            
            # Skip very short lines and navigation text, but keep meaningful content
            # Allow lines with at least 3 characters (to catch short but important lines like "year!")
            if len(line) >= 3 and not re.match(r'^(Page|Chapter|CCEL|Table of Contents)', line, re.IGNORECASE):
                # Check if this line should be combined with the previous line
                # (if previous line doesn't end with sentence-ending punctuation and this line doesn't start with capital or quote)
                if (current_content and 
                    not re.search(r'[.!?]$', current_content[-1].strip()) and
                    not re.match(r'^[A-Z"\'\(]', line.strip()) and
                    not line.strip().startswith('"') and
                    len(line.strip()) > 0):
                    # Combine with previous line (it's likely a wrapped line)
                    current_content[-1] = current_content[-1].rstrip() + ' ' + line.strip()
                else:
                    current_content.append(line)
        
        i += 1
    
    # Add last devotion
    if current_day is not None and current_content:
        devotions.append(create_devotion(current_day, current_type, current_content))
    
    return devotions

def create_devotion(day, dev_type, content_lines):
    """Create a devotion dictionary."""
    content = '\n\n'.join(content_lines).strip()
    # Clean up content - remove excessive whitespace
    content = re.sub(r'\n{3,}', '\n\n', content)
    
    return {
        "type": dev_type or 'morning',
        "day": day,
        "title": f"{get_month_name(day)} {get_day_of_month(day)} - {(dev_type or 'morning').capitalize()}",
        "content": content
    }

def organize_devotions(devotions):
    """Organize devotions into alternating morning/evening pattern."""
    by_day = {}
    for dev in devotions:
        day = dev.get('day', 1)
        if day not in by_day:
            by_day[day] = {}
        by_day[day][dev['type']] = dev
    
    organized = []
    for day in sorted(by_day.keys()):
        if 'morning' in by_day[day]:
            organized.append(by_day[day]['morning'])
        if 'evening' in by_day[day]:
            organized.append(by_day[day]['evening'])
    
    return organized

def main():
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        # Try common filenames
        possible_files = [
            'morneve.html',
            'morneve.txt',
            'morning_and_evening.html',
            'morning_and_evening.txt',
            'spurgeon_morneve.html',
            'spurgeon_morneve.txt'
        ]
        
        filepath = None
        for f in possible_files:
            if os.path.exists(f):
                filepath = f
                break
        
        if not filepath:
            print("Usage: python3 parse_local_file.py <filepath>")
            print("\nOr place one of these files in the current directory:")
            for f in possible_files:
                print(f"  - {f}")
            print("\nThe file can be HTML or plain text format.")
            return
    
    if not os.path.exists(filepath):
        print(f"Error: File '{filepath}' not found.")
        return
    
    print(f"Parsing {filepath}...")
    devotions = parse_content_file(filepath)
    
    if not devotions:
        print("Warning: No devotions found. The file format may be different.")
        print("Please ensure the file contains date headers like 'January 1, Morning' or 'January 1, Evening'")
        return
    
    print(f"Found {len(devotions)} devotions")
    
    organized = organize_devotions(devotions)
    print(f"Organized into {len(organized)} entries")
    
    output_file = 'devotions.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(organized, f, indent=2, ensure_ascii=False)
    
    print(f"\n✓ Successfully saved to {output_file}")
    print(f"  The app is now ready to use!")

if __name__ == '__main__':
    main()

