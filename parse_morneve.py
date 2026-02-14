#!/usr/bin/env python3
"""
Parse morneve.txt and convert to devotions.json format
"""

import json
import re
from datetime import datetime

def parse_morneve_file(filename):
    """Parse morneve.txt and return list of devotion dictionaries"""
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    devotions = []
    lines = content.split('\n')
    
    i = 0
    day_counter = 1  # Track sequential day number
    
    # Month names for date parsing
    months = {
        'January': 1, 'February': 2, 'March': 3, 'April': 4, 'May': 5, 'June': 6,
        'July': 7, 'August': 8, 'September': 9, 'October': 10, 'November': 11, 'December': 12
    }
    
    while i < len(lines):
        line = lines[i].strip()
        
        # Look for "Morning, Month Day" or "Evening, Month Day" pattern
        morning_match = re.match(r'Morning,\s+(\w+)\s+(\d+)', line)
        evening_match = re.match(r'Evening,\s+(\w+)\s+(\d+)', line)
        
        if morning_match or evening_match:
            match = morning_match or evening_match
            month_name = match.group(1)
            day_num = int(match.group(2))
            dev_type = 'morning' if morning_match else 'evening'
            
            # Skip "Go To" line if present
            i += 1
            while i < len(lines) and ('Go To' in lines[i] or re.match(r'^\s*\[\d+\]', lines[i])):
                i += 1
            
            # Get scripture verse (usually in quotes on next line)
            scripture = ""
            scripture_ref = ""
            i += 1
            if i < len(lines):
                # Look for quoted scripture verse
                verse_line = lines[i].strip()
                if verse_line.startswith('"') or verse_line.startswith("'"):
                    scripture = verse_line.strip('"\'')
                    i += 1
                    # Next line should be the reference
                    if i < len(lines):
                        ref_line = lines[i].strip()
                        # Check if it looks like a Bible reference (contains numbers and colons)
                        if re.search(r'\d+:\d+', ref_line):
                            scripture_ref = ref_line
                            i += 1
            
            # Collect body text until we hit the next devotion or separator
            body_lines = []
            while i < len(lines):
                current_line = lines[i].strip()
                
                # Stop if we hit the next devotion
                if re.match(r'(Morning|Evening),\s+\w+\s+\d+', current_line):
                    break
                
                # Stop if we hit a separator line (usually underscores)
                if current_line.startswith('___'):
                    i += 1
                    break
                
                # Skip empty lines at start
                if not body_lines and not current_line:
                    i += 1
                    continue
                
                # Skip "Go To" links and reference numbers
                if 'Go To' in current_line or re.match(r'^\s*\[\d+\]', current_line):
                    i += 1
                    continue
                
                # Add non-empty lines to body
                if current_line:
                    body_lines.append(current_line)
                
                i += 1
            
            # Clean up body lines - remove any remaining "Go To" references
            cleaned_body = []
            for line in body_lines:
                # Remove reference numbers like [153]
                line = re.sub(r'\[\d+\]', '', line).strip()
                # Skip "Go To" lines
                if 'Go To' in line or not line:
                    continue
                cleaned_body.append(line)
            
            # Combine scripture and body
            if scripture and scripture_ref:
                full_content = f'"{scripture}"\n{scripture_ref}\n\n' + '\n\n'.join(cleaned_body)
            elif scripture_ref:
                full_content = f'{scripture_ref}\n\n' + '\n\n'.join(cleaned_body)
            elif scripture:
                full_content = f'"{scripture}"\n\n' + '\n\n'.join(cleaned_body)
            else:
                full_content = '\n\n'.join(cleaned_body)
            
            # Create title
            title = f"{month_name} {day_num} - {'Morning' if dev_type == 'morning' else 'Evening'}"
            
            # Calculate day number (sequential from Jan 1 Morning = 1)
            day = day_counter
            if dev_type == 'evening':
                # Evening is same day number, morning increments
                day_counter += 1
            
            devotion = {
                'type': dev_type,
                'day': day,
                'title': title,
                'content': full_content.strip()
            }
            
            devotions.append(devotion)
            continue
        
        i += 1
    
    return devotions

def main():
    print("Parsing morneve.txt...")
    devotions = parse_morneve_file('morneve.txt')
    print(f"Found {len(devotions)} devotions")
    
    # Write to JSON file
    output_file = 'assets/devotions.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(devotions, f, indent=2, ensure_ascii=False)
    
    print(f"Saved to {output_file}")
    
    # Show sample
    if devotions:
        print("\nSample devotion:")
        sample = devotions[0]
        print(f"  Type: {sample['type']}")
        print(f"  Title: {sample['title']}")
        print(f"  Content preview: {sample['content'][:100]}...")
        
        # Find February 15 Evening
        feb15_eve = next((d for d in devotions if 'February 15' in d['title'] and d['type'] == 'evening'), None)
        if feb15_eve:
            print("\nFebruary 15 Evening content length:", len(feb15_eve['content']))
            print("First 200 chars:", feb15_eve['content'][:200])

if __name__ == '__main__':
    main()

