import os
import re

lcov_file = os.path.join(os.path.dirname(__file__), '..', 'coverage', 'lcov.info')

if not os.path.exists(lcov_file):
    print("lcov.info not found!")
    exit(1)

file_coverage = {}
current_file = None
lines_found = 0
lines_hit = 0

with open(lcov_file, 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if line.startswith('SF:'):
            current_file = line[3:].replace('\\', '/')
            lines_found = 0
            lines_hit = 0
        elif line.startswith('DA:'):
            parts = line[3:].split(',')
            if len(parts) == 2:
                count = int(parts[1])
                lines_found += 1
                if count > 0:
                    lines_hit += 1
        elif line == 'end_of_record':
            if current_file:
                file_coverage[current_file] = (lines_hit, lines_found)
            current_file = None

categories = {
    'bloc_cubit': [r'/presentation/bloc/', r'/presentation/cubit/'],
    'repository': [r'/data/repositories/', r'/domain/repositories/'],
    'core_services': [r'/core/services/'],
}

def analyze_category(name, patterns):
    total_hit = 0
    total_found = 0
    files = []
    for f, (hit, found) in file_coverage.items():
        if any(re.search(p, f) for p in patterns):
            pct = (hit / found * 100) if found > 0 else 100.0
            files.append((f, hit, found, pct))
            total_hit += hit
            total_found += found
    total_pct = (total_hit / total_found * 100) if total_found > 0 else 100.0
    return name, total_hit, total_found, total_pct, files

print(f"{'Category':<20} | {'Lines Hit':<10} | {'Total Lines':<12} | {'Coverage %':<10}")
print("-" * 60)
for cat_name, patterns in categories.items():
    name, hit, found, pct, files = analyze_category(cat_name, patterns)
    print(f"{name:<20} | {hit:<10} | {found:<12} | {pct:<9.2f}%")

print("\n--- Detailed Files below 70% in Target Categories ---")
for cat_name, patterns in categories.items():
    _, _, _, _, files = analyze_category(cat_name, patterns)
    for f, hit, found, pct in sorted(files, key=lambda x: x[3]):
        if pct < 70.0 and found > 0:
            print(f"[{cat_name}] {pct:6.2f}% ({hit}/{found}) - {f}")

