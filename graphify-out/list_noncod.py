import json
from pathlib import Path
detect = json.loads(Path('e:/Power Net Manager/PowerNet Staff App/graphify-out/.graphify_detect.json').read_text(encoding='utf-8'))
non_code = []
for k in ['document', 'paper', 'image']:
    v = detect.get('files', {}).get(k, [])
    if isinstance(v, list): non_code.extend(v)
print('\n'.join(non_code))
print(f'\nTotal non-code: {len(non_code)}')
