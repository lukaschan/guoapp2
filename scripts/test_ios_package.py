import unittest

from app_build import BuildVariant
from build_ios import ios_artifact_name


class IosPackageTests(unittest.TestCase):
    def test_signed_artifacts_keep_ipa_extension(self):
        self.assertEqual(
            ios_artifact_name(BuildVariant(), '0.2.11+17', signed=True),
            'hongguojian-0.2.11+17-ios.ipa',
        )
        self.assertEqual(
            ios_artifact_name(BuildVariant(True), '0.2.11+17', signed=True),
            'zhenguojian-0.2.11+17-ios.ipa',
        )

    def test_unsigned_app_archives_are_zip_files(self):
        self.assertEqual(
            ios_artifact_name(BuildVariant(), '0.2.11+17', signed=False),
            'hongguojian-0.2.11+17-ios-unsigned-app.zip',
        )


if __name__ == '__main__':
    unittest.main()
