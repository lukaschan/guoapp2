import argparse
import hashlib
import json
import os
import platform
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

from app_build import BuildVariant, add_variant_argument

root = Path(__file__).resolve().parents[1]


def run(arguments, **kwargs):
    subprocess.run([str(item) for item in arguments], cwd=kwargs.pop('cwd', root), check=True, **kwargs)


def build_core(variant):
    if platform.system() != 'Darwin':
        raise SystemExit('macOS 构建需要 macOS 和完整 Xcode。')
    subprocess.run([sys.executable, str(root / 'scripts' / 'apply_fork_overlay.py')], check=True)
    go = shutil.which('go')
    if not go:
        raise SystemExit('请安装 Go 1.24.1 或更新版本。')
    environment = os.environ.copy()
    environment.setdefault('GOPROXY', 'https://goproxy.cn,direct')
    environment.setdefault('GOSUMDB', 'off')
    environment['CGO_ENABLED'] = '1'
    environment['GOTOOLCHAIN'] = os.environ.get('GOTOOLCHAIN', 'auto')
    sdk_path = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
    compiler = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--find', 'clang'], text=True).strip()
    build_root = root / 'upstream' / 'native' / 'build' / 'macos'
    headers = build_root / 'Headers'
    headers.mkdir(parents=True, exist_ok=True)
    libraries = []
    for architecture, triple in [('arm64', 'arm64-apple-macos12.0'), ('amd64', 'x86_64-apple-macos12.0')]:
        directory = build_root / architecture
        directory.mkdir(parents=True, exist_ok=True)
        output = directory / 'libDuanjuCore.a'
        flags = shlex.join(['-isysroot', sdk_path, '-target', triple])
        build_env = environment | {
            'GOOS': 'darwin', 'GOARCH': architecture, 'CC': compiler,
            'CGO_CFLAGS': flags, 'CGO_LDFLAGS': flags,
        }
        run([go, 'build', '-trimpath', '-buildmode=c-archive', '-ldflags=' + variant.linker_flags,
             '-o', str(output), './bridge'], cwd=root / 'upstream' / 'native', env=build_env)
        libraries.append(output)
    universal = build_root / 'libDuanjuCore.a'
    run(['xcrun', 'lipo', '-create', *[str(library) for library in libraries], '-output', str(universal)])
    shutil.copy2(libraries[0].with_suffix('.h'), headers / 'DuanjuCore.h')
    framework = root / 'macos' / 'DuanjuCore' / 'DuanjuCore.xcframework'
    if framework.exists():
        shutil.rmtree(framework)
    run(['xcodebuild', '-create-xcframework', '-library', str(universal), '-headers', str(headers),
         '-output', str(framework)])


def package_path(name):
    config = root / '.dart_tool' / 'package_config.json'
    if not config.is_file():
        return None
    for package in json.loads(config.read_text())['packages']:
        if package['name'] == name:
            path = Path(package['rootUri'].removeprefix('file://'))
            return path if path.is_absolute() else (config.parent / path).resolve()
    return None


def repair_media_kit():
    package = package_path('media_kit_libs_macos_video')
    if package is None:
        return
    directory = package / 'macos'
    script = directory / 'create_framework_symlinks.sh'
    linked = directory / 'Frameworks' / '.symlinks' / 'mpv' / 'macos'
    if not script.is_file() or linked.exists():
        return
    script.write_bytes(script.read_bytes().replace(b'\r\n', b'\n'))
    (directory / 'Frameworks' / '.symlinks' / 'mpv').mkdir(parents=True, exist_ok=True)
    run(['sh', 'create_framework_symlinks.sh', 'Frameworks/Mpv.xcframework',
         'Frameworks/.symlinks/mpv'], cwd=directory)


def sign_application(application):
    flags = ['codesign', '--force', '--sign', '-']
    for framework in sorted((application / 'Contents' / 'Frameworks').glob('*')):
        run(flags + [str(framework)])
    entitlements = root / 'macos' / 'Runner' / 'Release.entitlements'
    run(flags + ['--entitlements', str(entitlements), str(application)])


def verify_application(application):
    info = plistlib.loads((application / 'Contents' / 'Info.plist').read_bytes())
    executable = application / 'Contents' / 'MacOS' / info['CFBundleExecutable']
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise SystemExit('macOS 包缺少可执行文件。')
    architectures = subprocess.run(['lipo', '-info', str(executable)], capture_output=True, text=True).stdout
    if 'arm64' not in architectures or 'x86_64' not in architectures:
        raise SystemExit('macOS 包应同时包含 arm64 和 x86_64：' + architectures.strip())
    symbols = subprocess.run(['nm', '-gU', str(executable)], capture_output=True, text=True).stdout
    for symbol in ['_DuanjuRequest', '_DuanjuFree']:
        if symbol not in symbols:
            raise SystemExit('macOS 包缺少 FFI 入口：' + symbol)
    frameworks = application / 'Contents' / 'Frameworks'
    present = sorted(entry.name for entry in frameworks.glob('*')) if frameworks.is_dir() else []
    for required in ['App.framework', 'FlutterMacOS.framework', 'Mpv.framework', 'ffmpegkit.framework']:
        if required not in present:
            raise SystemExit('macOS 包缺少框架：' + required + '；现有框架：' + ', '.join(present))


def build_dmg(variant, application, target):
    staging = root / 'build' / 'macos-dmg'
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    staged = staging / f'{variant.name}.app'
    shutil.copytree(application, staged, symlinks=True)
    plist_path = staged / 'Contents' / 'Info.plist'
    info = plistlib.loads(plist_path.read_bytes())
    info['CFBundleDisplayName'] = variant.name
    info['CFBundleName'] = variant.name
    info['CFBundleIdentifier'] = variant.macos_bundle_id
    plist_path.write_bytes(plistlib.dumps(info))
    sign_application(staged)
    verify_application(staged)
    os.symlink('/Applications', staging / 'Applications')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.unlink(missing_ok=True)
    run(['hdiutil', 'create', '-volname', variant.name, '-srcfolder', str(staging), '-ov',
         '-fs', 'HFS+', '-format', 'UDZO', '-imagekey', 'zlib-level=9', str(target)])
    mount = root / 'build' / 'macos-dmg-mount'
    if mount.exists():
        shutil.rmtree(mount)
    mount.mkdir(parents=True)
    try:
        run(['hdiutil', 'attach', str(target), '-nobrowse', '-readonly', '-mountpoint', str(mount)])
        if not (mount / f'{variant.name}.app').is_dir():
            raise SystemExit('dmg 里缺少应用：' + variant.name)
        if not (mount / 'Applications').is_symlink():
            raise SystemExit('dmg 里缺少 Applications 快捷方式。')
    finally:
        subprocess.run(['hdiutil', 'detach', str(mount)], capture_output=True)


def main():
    parser = argparse.ArgumentParser(description='构建短剧视界 / 全剧视界 macOS 核心和应用')
    parser.add_argument('--core-only', action='store_true')
    add_variant_argument(parser)
    options = parser.parse_args()
    variant = BuildVariant(options.all_sources)
    build_core(variant)
    if options.core_only:
        return
    flutter = shutil.which('flutter')
    if not flutter or not shutil.which('pod'):
        raise SystemExit('请安装 Flutter 和 CocoaPods。')
    run([flutter, 'pub', 'get', '--enforce-lockfile'])
    run(['pod', 'install'], cwd=root / 'macos')
    repair_media_kit()
    run([flutter, 'build', 'macos', '--release', '--no-pub', *variant.flutter_arguments])
    applications = sorted((root / 'build' / 'macos' / 'Build' / 'Products' / 'Release').glob('*.app'))
    if not applications:
        raise SystemExit('未生成 macOS 应用。')
    version = re.search(r'^version:\s*(\S+)', (root / 'pubspec.yaml').read_text(), re.MULTILINE).group(1)
    output = root / 'dist' / 'macos'
    target = output / f'{variant.slug}-{version}-macos-universal.dmg'
    build_dmg(variant, applications[0], target)
    checksums = []
    for artifact in sorted(output.glob(f'*-{version}-macos-universal.dmg')):
        digest = hashlib.sha256()
        with artifact.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
        checksums.append(f'{digest.hexdigest()}  {artifact.name}')
        print(artifact)
    (output / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n', encoding='ascii')


if __name__ == '__main__':
    main()
