import os
import plistlib
import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

from app_build import BuildVariant
from build_ios import ios_artifact_name, package_unsigned_ipa


class IosPackageTests(unittest.TestCase):
    def test_signed_artifacts_keep_ipa_extension(self):
        self.assertEqual(
            ios_artifact_name(BuildVariant(), '0.2.11+17', signed=True),
            'duanjushijie-0.2.11+17-ios.ipa',
        )
        self.assertEqual(
            ios_artifact_name(BuildVariant(True), '0.2.11+17', signed=True),
            'quanjushijie-0.2.11+17-ios.ipa',
        )

    def test_unsigned_artifacts_keep_ipa_extension(self):
        self.assertEqual(
            ios_artifact_name(BuildVariant(), '0.2.11+17', signed=False),
            'duanjushijie-0.2.11+17-ios-unsigned.ipa',
        )

    def test_unsigned_ipa_contains_payload_and_frameworks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            application = root / 'Runner.app'
            framework = application / 'Frameworks' / 'Fixture.framework'
            framework.mkdir(parents=True)
            (application / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'Runner'}))
            executable = application / 'Runner'
            executable.write_bytes(b'synthetic executable')
            executable.chmod(0o755)
            (framework / 'Fixture').write_bytes(b'synthetic framework')
            if os.name != 'nt':
                (framework / 'Current').symlink_to('Fixture')
            destination = root / 'unsigned.ipa'
            package_unsigned_ipa(application, destination)
            with zipfile.ZipFile(destination) as archive:
                self.assertIsNone(archive.testzip())
                self.assertEqual(archive.read('Payload/Runner.app/Runner'), executable.read_bytes())
                self.assertEqual(archive.read('Payload/Runner.app/Frameworks/Fixture.framework/Fixture'),
                                 b'synthetic framework')
                self.assertTrue(all(name.startswith('Payload/Runner.app/') for name in archive.namelist()))
                if os.name != 'nt':
                    self.assertTrue(stat.S_IXUSR & (archive.getinfo('Payload/Runner.app/Runner').external_attr >> 16))
                    link = archive.getinfo('Payload/Runner.app/Frameworks/Fixture.framework/Current')
                    self.assertTrue(stat.S_ISLNK(link.external_attr >> 16))
                    self.assertEqual(archive.read(link), b'Fixture')

    def test_unsigned_ipa_rewrites_bundle_id_when_requested(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            application = root / 'Runner.app'
            application.mkdir()
            (application / 'Info.plist').write_bytes(plistlib.dumps(
                {'CFBundleExecutable': 'Runner',
                 'CFBundleIdentifier': 'com.duanju.duanjuApp'}))
            (application / 'Runner').write_bytes(b'synthetic executable')
            destination = root / 'unsigned.ipa'
            package_unsigned_ipa(application, destination,
                                 BuildVariant(True).ios_bundle_id)
            with zipfile.ZipFile(destination) as archive:
                info = plistlib.loads(archive.read('Payload/Runner.app/Info.plist'))
            self.assertEqual(info['CFBundleIdentifier'],
                             'com.duanju.duanjuApp.quanjushijie')
            self.assertEqual(
                plistlib.loads((application / 'Info.plist').read_bytes())['CFBundleIdentifier'],
                'com.duanju.duanjuApp.quanjushijie')

    def test_incomplete_application_is_not_packaged(self):
        with tempfile.TemporaryDirectory() as temporary:
            application = Path(temporary) / 'Runner.app'
            application.mkdir()
            (application / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'Runner'}))
            destination = Path(temporary) / 'unsigned.ipa'
            with self.assertRaisesRegex(ValueError, '主程序'):
                package_unsigned_ipa(application, destination)
            self.assertFalse(destination.exists())


if __name__ == '__main__':
    unittest.main()
