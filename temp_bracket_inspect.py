from pathlib import Path
text = Path('lib/main.dart').read_text()
lines = text.splitlines()
start, end = 2912, 2945
chunk = '\n'.join(lines[start-1:end])
print('----- chunk -----')
print(chunk)
paren=0
bracket=0
for idx,ch in enumerate(chunk):
    if ch == '(':
        paren += 1
    elif ch == ')':
        paren -= 1
    if ch == '[':
        bracket += 1
    elif ch == ']':
        bracket -= 1
    if paren < 0:
        print('extra ) at', idx)
        paren = 0
    if bracket < 0:
        print('extra ] at', idx)
        bracket = 0
print('paren balance', paren)
print('bracket balance', bracket)
