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
        'subtitle': '短剧视界 AltStore 订阅源',
        'description': ('短剧视界（guoapp2）的 AltStore 订阅源，版本随 GitHub '
                        'Release 自动更新，可用于 AltStore、SideStore 等兼容应用。'
                        '本源提供短剧视界版；全剧视界版 IPA 请到 GitHub Releases 手动下载。'),
        'iconURL': icon,
        'website': f'https://github.com/{slug}',
        'tintColor': TINT,
        'apps': [{
            'name': '短剧视界',
            'bundleIdentifier': 'com.duanju.duanjuApp',
            'developerName': 'lukaschan',
            'subtitle': '短剧聚合浏览与播放',
            'localizedDescription': '短剧视界：多站源短剧聚合浏览、搜索与在线播放。',
            'iconURL': icon,
            'tintColor': TINT,
            'versions': [],
        }],
    }


def main():
    pubspec = (root / 'pubspec.yaml').read_text()
    full_version = re.search(r'^version:\s*(\S+)', pubspec, re.M).group(1)
    version = full_version.split('+')[0]
    tag = f'v{version}'
    slug = repo_slug()
    release = json.loads(run('gh', 'release', 'view', tag, '--repo', slug,
                             '--json', 'assets,publishedAt'))
    ipa = next((a for a in release['assets']
                if a['name'].startswith('duanjushijie-')
                and a['name'].endswith('-ios-unsigned.ipa')), None)
    if ipa is None:
        raise SystemExit(f'{tag} 里找不到 duanjushijie 的 iOS IPA 资产')
    entry = {
        'version': version,
        'date': release['publishedAt'][:10],
        'localizedDescription': changelog_notes(version),
        'downloadURL': (f'https://github.com/{slug}/releases/download/'
                        f'{tag}/{ipa["name"]}'),
        'size': ipa['size'],
        'minOSVersion': MIN_OS,
    }
    if SOURCE_PATH.exists():
        source = json.loads(SOURCE_PATH.read_text())
    else:
        source = skeleton(slug)
    app = next((a for a in source.get('apps', [])
                if a.get('bundleIdentifier') == 'com.duanju.duanjuApp'), None)
    if app is None:
        source.setdefault('apps', []).append(skeleton(slug)['apps'][0])
        app = source['apps'][-1]
    versions = [entry] + [v for v in app.get('versions', [])
                          if v.get('version') != version]
    app['versions'] = versions[:MAX_VERSIONS]
    SOURCE_PATH.write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n')
    print(f'altstore.json 已更新到 {version}（{tag}，IPA {ipa["size"]} 字节）')


if __name__ == '__main__':
    sys.exit(main())
