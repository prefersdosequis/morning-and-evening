#!/usr/bin/env python3
"""
Script to fetch Morning and Evening devotions by following links from CCEL's TOC page.
This is a more comprehensive approach that follows individual devotion links.
"""

import requests
import json
import re
from bs4 import BeautifulSoup
import time

def extract_day_number(date_str):
    """Extract day number (1-365) from date string."""
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
            return sum(days_per_month[:month_num-1]) + day
    return None

def get_month_name(day_number):
    """Get month name from day number."""
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
    """Get day of month from day number."""
    days_per_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    day = day_number
    for days in days_per_month:
        if day <= days:
            return day
        day -= days
    return day

def fetch_devotion_page(url, base_url="https://www.ccel.org"):
    """Fetch a single devotion page."""
    try:
        if url.startswith('/'):
            url = base_url + url
        elif not url.startswith('http'):
            url = base_url + '/' + url
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        response = requests.get(url, headers=headers, timeout=15)
        if response.status_code == 200:
            return response.text
    except Exception as e:
        print(f"  Error fetching {url}: {e}")
    return None

def parse_devotion_page(html_content):
    """Extract devotion content from a single page."""
    soup = BeautifulSoup(html_content, 'html.parser')
    
    # Remove scripts, styles, navigation
    for tag in soup(["script", "style", "nav", "header", "footer"]):
        tag.decompose()
    
    # Try to find main content
    content_divs = soup.find_all(['div', 'p'], class_=re.compile(r'content|text|body|main', re.I))
    if not content_divs:
        # Fallback: get all paragraphs
        content_divs = soup.find_all('p')
    
    text_parts = []
    for div in content_divs:
        text = div.get_text(strip=True)
        if len(text) > 50:  # Substantial content
            text_parts.append(text)
    
    return '\n\n'.join(text_parts)

def main():
    print("Fetching Morning and Evening devotional from CCEL TOC...")
    print("=" * 60)
    
    toc_url = "https://www.ccel.org/ccel/spurgeon/morneve.toc.html"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    
    try:
        print(f"Fetching TOC from {toc_url}...")
        response = requests.get(toc_url, headers=headers, timeout=30)
        if response.status_code != 200:
            print(f"Error: Could not fetch TOC (status {response.status_code})")
            return
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Find all links that might be devotion pages
        # Look for links with dates or morning/evening in them
        links = soup.find_all('a', href=True)
        
        devotions = []
        devotion_links = []
        
        # Collect potential devotion links
        for link in links:
            href = link.get('href', '')
            text = link.get_text(strip=True)
            
            # Look for date patterns or morning/evening
            date_match = re.search(r'((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+)', text, re.IGNORECASE)
            morning_match = re.search(r'morning', text, re.IGNORECASE)
            evening_match = re.search(r'evening', text, re.IGNORECASE)
            
            if date_match or morning_match or evening_match:
                date_str = date_match.group(1) if date_match else None
                day_num = extract_day_number(date_str) if date_str else None
                dev_type = 'evening' if evening_match else 'morning' if morning_match else None
                
                if href and (day_num or dev_type):
                    devotion_links.append({
                        'url': href,
                        'date': date_str,
                        'day': day_num,
                        'type': dev_type,
                        'text': text
                    })
        
        print(f"Found {len(devotion_links)} potential devotion links")
        
        if not devotion_links:
            print("\nCould not find devotion links in TOC.")
            print("This method may not work with CCEL's current structure.")
            print("\nAlternative: Download the content manually and use parse_local_file.py")
            print("See GET_CONTENT.md for instructions.")
            return
        
        # Fetch a sample to test (first 10 links)
        print(f"\nTesting with first {min(10, len(devotion_links))} links...")
        for i, link_info in enumerate(devotion_links[:10]):
            print(f"  [{i+1}/{min(10, len(devotion_links))}] Fetching {link_info['text'][:50]}...")
            content = fetch_devotion_page(link_info['url'])
            
            if content:
                devotion_text = parse_devotion_page(content)
                if devotion_text and len(devotion_text) > 100:
                    day = link_info['day'] or 1
                    dev_type = link_info['type'] or 'morning'
                    
                    devotions.append({
                        "type": dev_type,
                        "day": day,
                        "title": f"{get_month_name(day)} {get_day_of_month(day)} - {dev_type.capitalize()}",
                        "content": devotion_text
                    })
                    print(f"    ✓ Successfully parsed ({len(devotion_text)} chars)")
                else:
                    print(f"    ✗ Content too short or empty")
            else:
                print(f"    ✗ Could not fetch content")
            
            time.sleep(0.5)  # Be polite to the server
        
        if devotions:
            print(f"\nSuccessfully fetched {len(devotions)} devotions")
            print("\nNote: This script only fetches a sample. To get all 730 devotions:")
            print("1. Download the full content file from CCEL manually")
            print("2. Use parse_local_file.py to parse it")
            print("See GET_CONTENT.md for detailed instructions.")
            
            # Save sample
            output_file = 'devotions_sample.json'
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(devotions, f, indent=2, ensure_ascii=False)
            print(f"\n✓ Saved sample to {output_file}")
        else:
            print("\nCould not fetch any devotions. The TOC structure may have changed.")
            print("Please use the manual download method (see GET_CONTENT.md)")
    
    except Exception as e:
        print(f"\nError: {e}")
        print("\nPlease use the manual download method:")
        print("1. Download content from https://www.ccel.org/ccel/spurgeon/morneve.html")
        print("2. Save as morneve.txt or morneve.html")
        print("3. Run: python3 parse_local_file.py morneve.txt")

if __name__ == '__main__':
    main()






