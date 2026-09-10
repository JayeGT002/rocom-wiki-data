import argparse, re, json, os, sys

BASE = os.path.dirname(os.path.abspath(__file__))
CAT = os.path.join(BASE, '..', 'wiki_modules', 'Pets', 'data', 'Catalog.lua')

def parse_catalog():
    txt = open(CAT, encoding='utf-8').read()
    body = re.sub(r'^\s*return\s*\{', '', txt, flags=re.S)
    pets = {}
    for blk in re.split(r',(?=pet_\d+=\{)', body):
        m = re.search(r'pet_(\d+)=\{(.*)', blk, re.S)
        if not m:
            continue
        pid = m.group(1); b = m.group(2)
        gstr = lambda name: (re.search(name + r'="([^"]*)"', b).group(1)
                             if re.search(name + r'="', b) else None)
        gnum = lambda name: (re.search(name + r'=(-?\d+)', b).group(1)
                             if re.search(name + r'=(-?\d+)\b', b) else None)
        num = gstr('number'); title = gstr('title')
        if num is None:
            continue
        # egg_group={6,9}
        eg = re.search(r'egg_group=\{([^}]*)\}', b)
        egg_group = [int(x) for x in eg.group(1).split(',')] if eg else []
        # egg_size={min=..,max=..}
        es = re.search(r'egg_size=\{(.*?)\}', b, re.S)
        egg_min = egg_max = None
        if es:
            emin = re.search(r'min=([\d.]+)', es.group(1)); emax = re.search(r'max=([\d.]+)', es.group(1))
            egg_min = float(emin.group(1)) if emin else None
            egg_max = float(emax.group(1)) if emax else None
        tm = re.search(r'types=\{(.*?)\}', b, re.S)
        types = [x.strip() for x in tm.group(1).replace('"','').split(',') if x.strip()] if tm else []
        pets[pid] = {
            'number': num.zfill(3), 'title': title, 'name': gstr('name'),
            'stage': int(gnum('stage') or 0),
            'starlight': int(gnum('starlight')) if gnum('starlight') is not None else None,
            'review_gold': int(gnum('review_gold')) if gnum('review_gold') is not None else None,
            'egg_group': egg_group,
            'egg_size': f'{egg_min}~{egg_max}',
            'height': gstr('height'), 'weight': gstr('weight'),
            'gender_ratio': gstr('gender_ratio'),
            'types': types,
            'category': gstr('class'),
            'stats': (re.search(r'stats=\{(.*?)\}', b, re.S).group(1) if re.search(r'stats=\{', b) else ''),
        }
    return pets

def primary_form(posts):
    # 同 number 下选无括号的基础形态
    base = [p for p in posts if p['title'] and '(' not in p['title']]
    return base[0] if base else posts[0]

def main():
    ap = argparse.ArgumentParser(description='本地查询 洛克王国世界WIKI Catalog 数据')
    ap.add_argument('q', nargs='+', help='图鉴编号 或 名称 或 pet_id 前缀')
    ap.add_argument('--all', action='store_true', help='显示同一编号所有形态')
    args = ap.parse_args()
    pets = parse_catalog()
    bynum = {}
    for p in pets.values():
        bynum.setdefault(p['number'], []).append(p)
    q = ' '.join(args.q).strip()
    results = []
    if q.isdigit():
        num = q.zfill(3)
        results = bynum.get(num, [])
        if not results:
            results = [p for p in pets.values() if p['number'] == q]
    elif q.lower().startswith('pet_'):
        results = [p for pid, p in pets.items() if pid == q.replace('pet_', '')]
    else:
        for p in pets.values():
            if p['title'] and q in p['title']:
                results.append(p)
    if not results:
        print('未找到: %s' % q)
        return
    shown = results if args.all else [primary_form(results)]
    EGG = {1:'未发现',2:'巨灵组',3:'两栖组',4:'昆虫组',5:'天空组',6:'动物组',7:'妖精组',8:'植物组',9:'拟人组',10:'软体组',11:'大地组',12:'魔力组',13:'海洋组',14:'飞龙组',15:'机械组'}
    for p in shown:
        eggs = '/'.join(EGG.get(e,'') for e in p['egg_group'])
        print(f"编号{p['number']} | {p['title']} | 阶段{p['stage']} | 星光值{p['starlight']} | 洛克贝{p['review_gold']} | 蛋组[{eggs}] | 蛋大小[{p['egg_size']}] | 属性{','.join(p['types'])} | 分类{p['category']}")

if __name__ == '__main__':
    main()