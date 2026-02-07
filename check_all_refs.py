import json
import re

def check_devotion(title, content):
    """Check if a devotion has duplicate scripture references"""
    # Find the first scripture reference pattern
    verse_ref_pattern = r'((?:\d+\s+)?[A-Z][a-zA-Z]+(?:\s+of\s+[A-Z][a-zA-Z]+)?\s+\d+:\d+)'
    
    # Find all references
    all_refs = re.findall(verse_ref_pattern, content)
    
    if len(all_refs) == 0:
        return None, []
    
    # Get the first reference (should be the one after the verse)
    first_ref = all_refs[0]
    
    # Count how many times this reference appears
    count = all_refs.count(first_ref)
    
    if count > 1:
        # Find all positions
        positions = []
        for m in re.finditer(re.escape(first_ref), content):
            start = max(0, m.start() - 50)
            end = min(len(content), m.end() + 50)
            context = content[start:end].replace('\n', ' ')
            positions.append((m.start(), m.end(), context))
        return first_ref, positions
    
    return None, []

with open('assets/devotions.json', 'r') as f:
    data = json.load(f)

issues = []

for item in data:
    title = item.get('title', '')
    content = item.get('content', '')
    
    ref, positions = check_devotion(title, content)
    if ref:
        issues.append({
            'title': title,
            'reference': ref,
            'count': len(positions),
            'positions': positions
        })

print(f'Found {len(issues)} devotions with duplicate scripture references:\n')
for issue in issues:
    print(f"{issue['title']}: '{issue['reference']}' appears {issue['count']} times")
    for i, (start, end, context) in enumerate(issue['positions']):
        print(f"  {i+1}. Position {start}-{end}: ...{context}...")
    print()

