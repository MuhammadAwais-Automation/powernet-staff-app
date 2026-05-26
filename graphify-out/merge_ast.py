import json
from pathlib import Path

ast = json.loads(Path('e:/Power Net Manager/PowerNet Staff App/graphify-out/.graphify_ast.json').read_text(encoding='utf-8'))
# No semantic — empty
merged = {
    'nodes': ast['nodes'],
    'edges': ast['edges'],
    'hyperedges': [],
    'input_tokens': 0,
    'output_tokens': 0,
}
Path('e:/Power Net Manager/PowerNet Staff App/graphify-out/.graphify_extract.json').write_text(
    json.dumps(merged, indent=2, ensure_ascii=False), encoding='utf-8')
print(f'Flutter extract: {len(merged["nodes"])} nodes, {len(merged["edges"])} edges')
