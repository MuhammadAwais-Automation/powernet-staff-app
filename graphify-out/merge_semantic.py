import json, glob
from pathlib import Path

chunks = sorted(glob.glob('e:/Power Net Manager/PowerNet Staff App/graphify-out/.graphify_chunk_*.json'))
all_nodes, all_edges, all_hyperedges = [], [], []
for c in chunks:
    d = json.loads(Path(c).read_text(encoding='utf-8'))
    all_nodes += d.get('nodes', [])
    all_edges += d.get('edges', [])
    all_hyperedges += d.get('hyperedges', [])
print(f'Chunks merged: {len(chunks)}, nodes: {len(all_nodes)}, edges: {len(all_edges)}')

ast = json.loads(Path('e:/Power Net Manager/PowerNet Staff App/graphify-out/.graphify_ast.json').read_text(encoding='utf-8'))
seen = {n['id'] for n in ast['nodes']}
merged_nodes = list(ast['nodes'])
for n in all_nodes:
    if n['id'] not in seen:
        merged_nodes.append(n)
        seen.add(n['id'])

merged = {
    'nodes': merged_nodes,
    'edges': ast['edges'] + all_edges,
    'hyperedges': all_hyperedges,
    'input_tokens': 0,
    'output_tokens': 0,
}
Path('e:/Power Net Manager/PowerNet Staff App/graphify-out/.graphify_extract.json').write_text(
    json.dumps(merged, indent=2, ensure_ascii=False), encoding='utf-8')
print(f'Final extract: {len(merged_nodes)} nodes, {len(merged["edges"])} edges')
