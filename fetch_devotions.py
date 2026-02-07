#!/usr/bin/env python3
"""
Script to fetch and parse Charles Spurgeon's Morning and Evening devotional
from CCEL (Christian Classics Ethereal Library) and convert it to JSON format.
"""

import requests
import json
import re
from bs4 import BeautifulSoup
from datetime import datetime
import time

def fetch_ccel_content():
    """Fetch the devotional content from CCEL."""
    # CCEL has the content available in multiple formats
    # Try the single HTML file first (1.4 MB file mentioned in CCEL)
    
    urls = [
        "https://www.ccel.org/s/spurgeon/morn_eve/morn_eve.html",  # Single HTML file
        "https://www.ccel.org/ccel/spurgeon/morneve.html",  # HTML version
        "https://www.ccel.org/ccel/spurgeon/morneve.txt",  # Plain text version (may redirect)
    ]
    
    for url in urls:
        try:
            print(f"Attempting to fetch from {url}...")
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
            response = requests.get(url, headers=headers, timeout=60, allow_redirects=True)
            if response.status_code == 200:
                content = response.text
                # Check if it's actually HTML (not a redirect page)
                if '<html' in content.lower() or '<body' in content.lower():
                    print(f"Successfully fetched HTML content from {url} ({len(content)} chars)")
                    return content, True
                elif len(content) > 10000:  # Substantial text content
                    print(f"Successfully fetched text content from {url} ({len(content)} chars)")
                    return content, False
        except Exception as e:
            print(f"Error fetching from {url}: {e}")
            continue
    
    return None, False

def parse_plain_text(content):
    """Parse plain text format."""
    devotions = []
    
    # Pattern to match date headers with morning/evening
    date_morning_pattern = re.compile(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)[\s.,—\-]*(?:Morning|MORNING)',
        re.IGNORECASE
    )
    date_evening_pattern = re.compile(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)[\s.,—\-]*(?:Evening|EVENING)',
        re.IGNORECASE
    )
    date_pattern = re.compile(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)',
        re.IGNORECASE
    )
    
    lines = content.split('\n')
    current_day = None
    current_type = None
    current_content = []
    last_date = None
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        if not line:
            i += 1
            continue
        
        # Check for morning pattern
        morning_match = date_morning_pattern.search(line)
        if morning_match:
            # Save previous devotion if exists
            if current_day is not None and current_content:
                devotions.append({
                    "type": current_type,
                    "day": current_day,
                    "title": f"{get_month_name(current_day)} {get_day_of_month(current_day)} - {current_type.capitalize()}",
                    "content": '\n\n'.join(current_content).strip()
                })
            
            date_str = morning_match.group(1)
            current_day = extract_day_number(date_str)
            current_type = 'morning'
            current_content = []
            last_date = date_str
            i += 1
            continue
        
        # Check for evening pattern
        evening_match = date_evening_pattern.search(line)
        if evening_match:
            # Save previous devotion if exists
            if current_day is not None and current_content:
                devotions.append({
                    "type": current_type,
                    "day": current_day,
                    "title": f"{get_month_name(current_day)} {get_day_of_month(current_day)} - {current_type.capitalize()}",
                    "content": '\n\n'.join(current_content).strip()
                })
            
            date_str = evening_match.group(1)
            current_day = extract_day_number(date_str)
            current_type = 'evening'
            current_content = []
            last_date = date_str
            i += 1
            continue
        
        # Check for date pattern (without explicit label)
        date_match = date_pattern.search(line)
        if date_match:
            date_str = date_match.group(1)
            if date_str != last_date:
                # Save previous devotion if exists
                if current_day is not None and current_content:
                    devotions.append({
                        "type": current_type or 'morning',
                        "day": current_day,
                        "title": f"{get_month_name(current_day)} {get_day_of_month(current_day)} - {(current_type or 'morning').capitalize()}",
                        "content": '\n\n'.join(current_content).strip()
                    })
                
                current_day = extract_day_number(date_str)
                # Infer type from context
                if 'evening' in line.lower():
                    current_type = 'evening'
                elif 'morning' in line.lower():
                    current_type = 'morning'
                elif current_type is None:
                    current_type = 'morning'
                current_content = []
                last_date = date_str
        
        # Collect content
        if current_day is not None and len(line) > 5:
            current_content.append(line)
        
        i += 1
    
    # Add last devotion
    if current_day is not None and current_content:
        devotions.append({
            "type": current_type or 'morning',
            "day": current_day,
            "title": f"{get_month_name(current_day)} {get_day_of_month(current_day)} - {(current_type or 'morning').capitalize()}",
            "content": '\n\n'.join(current_content).strip()
        })
    
    return devotions

def parse_html(content):
    """Parse HTML format from CCEL."""
    devotions = []
    soup = BeautifulSoup(content, 'html.parser')
    
    # Remove script and style elements
    for script in soup(["script", "style", "nav", "header", "footer"]):
        script.decompose()
    
    # Try to find the main content area
    main_content = soup.find('body') or soup
    
    # Get all text, preserving some structure
    text_content = main_content.get_text(separator='\n', strip=True)
    
    # Pattern to match date headers with morning/evening
    # Examples: "January 1. Morning", "January 1, Morning", "January 1 — Morning"
    date_morning_pattern = re.compile(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)[\s.,—\-]*(?:Morning|MORNING)',
        re.IGNORECASE
    )
    date_evening_pattern = re.compile(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)[\s.,—\-]*(?:Evening|EVENING)',
        re.IGNORECASE
    )
    
    # Also try patterns without explicit morning/evening labels
    date_pattern = re.compile(
        r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)',
        re.IGNORECASE
    )
    
    lines = text_content.split('\n')
    current_day = None
    current_type = None
    current_content = []
    day_number = 0
    last_date = None
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        if not line:
            i += 1
            continue
        
        # Check for morning pattern
        morning_match = date_morning_pattern.search(line)
        if morning_match:
            # Save previous devotion
            if current_day is not None and current_content:
                devotions.append({
                    "type": current_type,
                    "day": current_day,
                    "title": f"{get_month_name(current_day)} {get_day_of_month(current_day)} - {current_type.capitalize()}",
                    "content": '\n\n'.join(current_content).strip()
                })
            
            # Extract date and calculate day number
            date_str = morning_match.group(1)
            day_number = extract_day_number(date_str)
            current_day = day_number
            current_type = 'morning'
            current_content = []
            last_date = date_str
            i += 1
            continue
        
        # Check for evening pattern
        evening_match = date_evening_pattern.search(line)
        if evening_match:
            # Save previous devotion
            if current_day is not None and current_content:
                devotions.append({
                    "type": current_type,
                    "day": current_day,
                    "title": f"{get_month_name(current_day)} {get_day_of_month(current_day)} - {current_type.capitalize()}",
                    "content": '\n\n'.join(current_content).strip()
                })
            
            # Extract date and calculate day number
            date_str = evening_match.group(1)
            day_number = extract_day_number(date_str)
            current_day = day_number
            current_type = 'evening'
            current_content = []
            last_date = date_str
            i += 1
            continue
        
        # Check for date pattern (without morning/evening label)
        date_match = date_pattern.search(line)
        if date_match:
            date_str = date_match.group(1)
            # Only process if it's a new date
            if date_str != last_date:
                # Save previous devotion
                if current_day is not None and current_content:
                    devotions.append({
                        "type": current_type or 'morning',
                        "day": current_day,
                        "title": f"{get_month_name(current_day)} {get_day_of_month(current_day)} - {(current_type or 'morning').capitalize()}",
                        "content": '\n\n'.join(current_content).strip()
                    })
                
                day_number = extract_day_number(date_str)
                current_day = day_number
                # Try to infer type from context
                if 'evening' in line.lower():
                    current_type = 'evening'
                elif 'morning' in line.lower():
                    current_type = 'morning'
                elif current_type is None:
                    current_type = 'morning'  # Default
                current_content = []
                last_date = date_str
        
        # Collect content (skip very short lines that are likely headers/navigation)
        if current_day is not None and len(line) > 10:
            # Skip lines that look like navigation or headers
            if not re.match(r'^(Page|Chapter|Table of Contents|CCEL|Christian Classics)', line, re.IGNORECASE):
                current_content.append(line)
        
        i += 1
    
    # Add last devotion
    if current_day is not None and current_content:
        devotions.append({
            "type": current_type or 'morning',
            "day": current_day,
            "title": f"{get_month_name(current_day)} {get_day_of_month(current_day)} - {(current_type or 'morning').capitalize()}",
            "content": '\n\n'.join(current_content).strip()
        })
    
    return devotions

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
    
    return 1  # Default to day 1 if parsing fails

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

def organize_devotions(devotions):
    """Organize devotions into alternating morning/evening pattern."""
    # Group by day
    by_day = {}
    for dev in devotions:
        day = dev.get('day', 1)
        if day not in by_day:
            by_day[day] = {}
        by_day[day][dev['type']] = dev
    
    # Create alternating list: morning, evening, morning, evening...
    organized = []
    for day in sorted(by_day.keys()):
        if 'morning' in by_day[day]:
            organized.append(by_day[day]['morning'])
        if 'evening' in by_day[day]:
            organized.append(by_day[day]['evening'])
    
    return organized

def main():
    print("Fetching Morning and Evening devotional content from CCEL...")
    print("=" * 60)
    
    content, is_html = fetch_ccel_content()
    
    if not content:
        print("\nError: Could not fetch content from CCEL.")
        print("You may need to:")
        print("1. Check your internet connection")
        print("2. Download the content manually from https://www.ccel.org/ccel/spurgeon/morneve.html")
        print("3. Save it as 'morneve.txt' or 'morneve.html' in this directory")
        print("4. Run this script again")
        return
    
    print(f"\nParsing {'HTML' if is_html else 'plain text'} content...")
    
    if is_html:
        devotions = parse_html(content)
    else:
        devotions = parse_plain_text(content)
    
    if not devotions:
        print("Warning: Could not parse devotions from content.")
        print("The content structure may be different than expected.")
        print(f"Content preview (first 500 chars):\n{content[:500]}")
        return
    
    print(f"Found {len(devotions)} devotions")
    
    # Organize into alternating pattern
    organized = organize_devotions(devotions)
    
    print(f"Organized into {len(organized)} entries (morning/evening alternating)")
    
    # Save to JSON
    output_file = 'devotions.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(organized, f, indent=2, ensure_ascii=False)
    
    print(f"\n✓ Successfully saved {len(organized)} devotions to {output_file}")
    print(f"  The app is now ready to use with the full devotional content!")

if __name__ == '__main__':
    main()

