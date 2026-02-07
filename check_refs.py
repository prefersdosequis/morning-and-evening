import json
import re

with open('assets/devotions.json', 'r') as f:
    data = json.load(f)

item = [d for d in data if d.get('title') == 'February 9 - Morning'][0]
content = item['content']

# Find all occurrences of the reference
refs = re.findall(r'2 Samuel 5:23', content)
print(f'Found {len(refs)} occurrences of "2 Samuel 5:23"')
print('\nPositions:')
for i, m in enumerate(re.finditer(r'2 Samuel 5:23', content)):
    start = max(0, m.start() - 50)
    end = min(len(content), m.end() + 50)
    context = content[start:end].replace('\n', ' ')
    print(f'{i+1}. Position {m.start()}-{m.end()}: ...{context}...')

