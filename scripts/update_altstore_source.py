import json
import re
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
SOURCE_PATH = root / 'altstore.json'
MAX_VERSIONS = 5
TINT = '#DF1428'
MIN_OS = '15.1'
EDITIONS = [
    {
        'slug': 'duanjushijie',
        'name': '短剧视界',
        'bundleIdentifier': 'com.duanju.duanjuApp',
        'subtitle': '仅红果站源',
        'localizedDescription': '短剧视界：以红果为主的短剧聚合浏览、搜索与在线播放。',
    },
    {
        'slug': 'quanjushijie',
        'name': '全剧视界',
        'bundleIdentifier': 'com.duanju.duanjuApp.quanjushijie',
        'subtitle': '全站源版，共 11 个站源',
        'localizedDescription': '全剧视界：包含全部 11 个站源的短剧聚合浏览、搜索与在线播放。',
    },
]


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def repo_slug():
    remote = run('git', '-C', str(root), 'remote', 'get-url', 'origin').strip()
    m = re.search(r'github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?$', remote)
    if not m:
        raise SystemExit('无法从 origin 推断 GitHub 仓库')
    return f'{m.group(1)}/{m.group(2)}'


def changelog_notes(version):
    text = (root / 'CHANGELOG.md').read_text()
    m = re.search(rf'^## {re.escape(version)}(?:\+\d+)?\s*\n(.*?)(?=^## |\Z)',
                  text, re.S | re.M)
    return m.group(1).strip() if m else ''


def skeleton(slug):
    icon = (f'https://raw.githubusercontent.com/{slug}'
            '/refs/heads/main/assets/app_icon_master.png')
    return {
        'name': 'guoapp2',
        'subtitle': '短剧视界 / 全剧视界 AltStore 订阅源',
        'description': ('短剧视界 / 全剧视界（guoapp2）的 AltStore 订阅源，版本随 '
                        'GitHub Release 自动更新，可用于 AltStore、SideStore 等兼容应用。'
                        '两版可同时安装（全剧视界自 1.0.15 起使用独立 bundle ID）。'),
        'iconURL': icon,
        'website': f'https://github.com/{slug}',
        'tintColor': TINT,
        'apps': [{
            'name': edition['name'],
            'bundleIdentifier': edition['bundleIdentifier'],
            'developerName': 'lukaschan',
            'subtitle': edition['subtitle'],
            'localizedDescription': edition['localizedDescription'],
            'iconURL': icon,
            'tintColor': TINT,
            'versions': [],
        } for edition in EDITIONS],
    }


def main():
    pubspec = (root / 'pubspec.yaml').read_text()
    full_version = re.search(r'^version:\s*(\S+)', pubspec, re.M).group(1)
    version = full_version.split('+')[0]
    tag = f'v{version}'
    slug = repo_slug()
    release = json.loads(run('gh', 'release', 'view', tag, '--repo', slug,
                             '--json', 'assets,publishedAt'))
    existing = {}
    if SOURCE_PATH.exists():
        old = json.loads(SOURCE_PATH.read_text())
        for app in old.get('apps', []):
            existing[app.get('bundleIdentifier')] = app.get('versions', [])
    source = skeleton(slug)
    notes = changelog_notes(version)
    for app, edition in zip(source['apps'], EDITIONS):
        ipa = next((a for a in release['assets']
                    if a['name'].startswith(edition['slug'] + '-')
                    and a['name'].endswith('-ios-unsigned.ipa')), None)
        if ipa is None:
            raise SystemExit(f'{tag} 里找不到 {edition["slug"]} 的 iOS IPA 资产')
        entry = {
            'version': version,
            'date': release['publishedAt'][:10],
            'localizedDescription': notes,
            'downloadURL': (f'https://github.com/{slug}/releases/download/'
                            f'{tag}/{ipa["name"]}'),
            'size': ipa['size'],
            'minOSVersion': MIN_OS,
        }
        versions = [entry] + [v for v in existing.get(edition['bundleIdentifier'], [])
                              if v.get('version') != version]
        app['versions'] = versions[:MAX_VERSIONS]
        print(f'{edition["name"]} 已更新到 {version}（IPA {ipa["size"]} 字节）')
    SOURCE_PATH.write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n')
    print(f'altstore.json 已按 {tag} 重新生成')


if __name__ == '__main__':
    sys.exit(main())
