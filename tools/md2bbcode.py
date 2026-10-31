"""Convert README.md to Nexus BBCode (headings, bold/italic, links, lists; tables -> lists, since Nexus has no tables)."""
import re, sys

def inline(s):
    s = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'[url=\2]\1[/url]', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'[b]\1[/b]', s)
    s = re.sub(r'(?<![*\w])\*([^*]+)\*(?![*\w])', r'[i]\1[/i]', s)
    return re.sub(r'`([^`]+)`', r'\1', s)

def table(rows):
    # Nexus BBCode has no tables (a [code] block broke links and wrapped badly), so each row becomes
    # a list item: "[b]first cell[/b]: second cell - third cell ...". The header row is dropped.
    cells = [[c.strip() for c in r.strip().strip('|').split('|')] for r in rows if not re.match(r'^\|[-:| ]+\|$', r.strip())]
    items = []
    for r in cells[1:]:
        first = re.sub(r'\*\*', '', r[0])
        rest = [inline(c) for c in r[1:] if c]
        items.append('[*][b]' + inline(first) + '[/b]' + (': ' + ' - '.join(rest) if rest else ''))
    return '[list]\n' + '\n'.join(items) + '\n[/list]'

def convert(md):
    out, para, items, kind = [], [], [], None

    def flush_para():
        if para: out.append(inline(' '.join(para))); para.clear()

    def flush_list():
        nonlocal kind
        if items:
            out.append('[list=1]' if kind == 'ol' else '[list]')
            out.extend('[*]' + inline(it) for it in items)
            out.append('[/list]')
            items.clear()
        kind = None

    lines = md.splitlines()
    i = 0
    while i < len(lines):
        l = lines[i]
        if l.startswith('<p'):
            i += 1; continue
        if l.startswith('|'):
            flush_para(); flush_list()
            block = []
            while i < len(lines) and lines[i].startswith('|'):
                block.append(lines[i]); i += 1
            out.append(table(block)); continue
        m = re.match(r'^(\s*)(-|\d+\.)\s+(.*)', l)
        if m:
            flush_para()
            if m.group(1) and items:            # sub-item: keep it inside the current item
                items[-1] += '\n    - ' + m.group(3)
            else:
                k = 'ol' if m.group(2)[0].isdigit() else 'ul'
                if kind and k != kind: flush_list()
                kind = k
                items.append(m.group(3))
            i += 1; continue
        if items and l.startswith('  ') and l.strip():  # wrapped list line
            items[-1] += ' ' + l.strip(); i += 1; continue
        if not l.strip():
            flush_para(); flush_list(); out.append(''); i += 1; continue
        flush_list()
        if l.startswith('#'):
            flush_para()
            level = len(l) - len(l.lstrip('#'))
            text = inline(l.lstrip('#').strip())
            out.append({1: '[size=6][b]%s[/b][/size]', 2: '[line]\n[size=5][b]%s[/b][/size]'}.get(level, '[size=4][b]%s[/b][/size]') % text)
        elif re.match(r'^\*\*[^*]+:\*\*', l) and para:  # "**Update:** ..." starts a new line
            flush_para(); para.append(l)
        else:
            para.append(l.strip())
        i += 1
    flush_para(); flush_list()
    return re.sub(r'\n{3,}', '\n\n', '\n'.join(out)).strip() + '\n'

if __name__ == '__main__':
    open(sys.argv[2], 'w', encoding='utf-8').write(convert(open(sys.argv[1], encoding='utf-8').read()))
