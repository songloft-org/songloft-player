#!/usr/bin/env python3
"""按子串在 uiautomator dump 里找节点并点击。

比 runner/ui.py 的全匹配正则宽松：Flutter 的语义节点常把邻近文字合并进同一个
content-desc（如「曲库\n2 首」），`^曲库$` 因此匹配不到，而它明明在屏幕上。

用法: tapx.py SERIAL <substr> [--pick first|last|widest] [--dump NAME] [--list]
"""
import re
import subprocess
import sys
import xml.etree.ElementTree as ET


def dump(serial):
    subprocess.run(['adb', '-s', serial, 'shell', 'uiautomator', 'dump', '/sdcard/tapx.xml'],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return subprocess.check_output(['adb', '-s', serial, 'exec-out', 'cat', '/sdcard/tapx.xml'])


def bounds(node):
    m = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.attrib.get('bounds', ''))
    return tuple(map(int, m.groups())) if m else None


def nodes(raw):
    try:
        root = ET.fromstring(raw)
    except ET.ParseError:
        return []
    out = []
    for n in root.iter('node'):
        b = bounds(n)
        if not b:
            continue
        txt = (n.attrib.get('text') or '') + '|' + (n.attrib.get('content-desc') or '')
        out.append((b, txt, n.attrib.get('class', '')))
    return out


def main():
    serial = sys.argv[1]
    raw = dump(serial)
    all_nodes = nodes(raw)

    if '--list' in sys.argv:
        for b, txt, cls in all_nodes:
            if txt.strip('|'):
                print(f'{b} {cls.split(".")[-1]:12s} {txt[:90]!r}')
        return

    needle = sys.argv[2]
    pick = 'first'
    if '--pick' in sys.argv:
        pick = sys.argv[sys.argv.index('--pick') + 1]

    hits = [(b, txt) for b, txt, _ in all_nodes
            if needle in txt and b[2] - b[0] > 8 and b[3] - b[1] > 8]
    if not hits:
        print(f'NOT FOUND: {needle!r}', file=sys.stderr)
        sys.exit(2)

    if pick == 'last':
        hits.sort(key=lambda x: x[0][1])
        target = hits[-1]
    elif pick == 'widest':
        hits.sort(key=lambda x: (x[0][2] - x[0][0]) * (x[0][3] - x[0][1]))
        target = hits[-1]
    else:
        hits.sort(key=lambda x: x[0][1])
        target = hits[0]

    b, txt = target
    cx, cy = (b[0] + b[2]) // 2, (b[1] + b[3]) // 2
    print(f'tap ({cx},{cy}) <- {txt[:60]!r} bounds={b}')
    subprocess.run(['adb', '-s', serial, 'shell', 'input', 'tap', str(cx), str(cy)])


if __name__ == '__main__':
    main()
