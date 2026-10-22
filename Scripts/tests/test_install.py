import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile


SCRIPTS = Path(__file__).resolve().parents[1]


class ReleaseInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.tag = "v1.2.3-beta.1"
        self.archive = self.root / "nest-macos.artifactbundle.zip"
        binary = self.root / "nest"
        binary.write_text(
            '#!/bin/bash\n'
            'printf "%s\\n" "$@" > "$INSTALL_ARGS"\n'
            'exit "${INSTALL_EXIT_CODE:-0}"\n'
        )
        binary.chmod(0o755)
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.write(binary, f"nest.artifactbundle/nest-{self.tag}-macos/bin/nest")
        self.checksum = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.installer = self.root / "install.sh"
        self.generate()

        self.mock_bin = self.root / "bin"
        self.mock_bin.mkdir()
        self.write_mock(
            "curl",
            'if [ "$#" -eq 2 ]; then\n'
            '  printf "%s\\n" "$2" > "$INSTALLER_URL_LOG"\n'
            '  cat "$FIXTURE_INSTALLER"\n'
            '  exit "${INSTALLER_CURL_EXIT_CODE:-0}"\n'
            'fi\n'
            'printf "%s\\n" "$4" > "$CURL_URL"\n'
            'printf "%s\\n" "$3" > "$DOWNLOAD_PATH_LOG"\n'
            'if [ "${CURL_EXIT_CODE:-0}" -ne 0 ]; then exit "$CURL_EXIT_CODE"; fi\n'
            'cp "$FIXTURE_ZIP" "$3"\n',
        )
        self.write_mock(
            "unzip",
            'touch "$UNZIP_CALLED"\n'
            'if [ "${UNZIP_EXIT_CODE:-0}" -ne 0 ]; then exit "$UNZIP_EXIT_CODE"; fi\n'
            'exec /usr/bin/unzip "$@"\n',
        )
        self.work_directory = self.root / "temporary files"
        self.work_directory.mkdir()
        self.caller_directory = self.root / "caller"
        self.caller_directory.mkdir()
        self.environment = {
            **os.environ,
            "PATH": f"{self.mock_bin}:{os.environ['PATH']}",
            "TMPDIR": str(self.work_directory),
            "FIXTURE_ZIP": str(self.archive),
            "FIXTURE_INSTALLER": str(self.installer),
            "INSTALLER_URL_LOG": str(self.root / "installer-url"),
            "CURL_URL": str(self.root / "curl-url"),
            "DOWNLOAD_PATH_LOG": str(self.root / "download-path"),
            "UNZIP_CALLED": str(self.root / "unzip-called"),
            "INSTALL_ARGS": str(self.root / "install-args"),
        }

    def generate(self, tag=None, archive=None):
        return subprocess.run(
            ["/bin/bash", str(SCRIPTS / "generate-install-script.sh"),
             self.tag if tag is None else tag,
             str(self.archive if archive is None else archive), str(self.installer)],
            check=tag is None and archive is None,
            capture_output=True, text=True,
        )

    def write_mock(self, name, body):
        path = self.mock_bin / name
        path.write_text("#!/bin/bash\nset -eu\n" + body)
        path.chmod(0o755)

    def run_installer(self, *, legacy=False, **environment):
        script = SCRIPTS / "install.sh" if legacy else self.installer
        result = subprocess.run(
            ["/bin/bash"], input=script.read_text(), cwd=self.caller_directory,
            env={**self.environment, **environment}, capture_output=True, text=True,
        )
        self.assertEqual(list(self.work_directory.iterdir()), [])
        return result

    def test_verified_release_installs_with_pinned_tag_and_checksum(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            (self.root / "curl-url").read_text().strip(),
            f"https://github.com/mtj0928/nest/releases/download/{self.tag}/{self.archive.name}",
        )
        self.assertEqual(
            (self.root / "install-args").read_text().splitlines(),
            ["install", "mtj0928/nest", self.tag, "--checksum", self.checksum],
        )
        self.assertIn("nest was installed", result.stdout)
        self.assertNotIn("Warning:", result.stderr)

    def test_install_preserves_existing_files_in_caller_directory(self):
        caller_archive = self.caller_directory / self.archive.name
        extracted_directory = self.caller_directory / "extracted_files"
        extracted_directory.mkdir()
        existing_file = extracted_directory / "keep"
        caller_archive.write_text("keep archive")
        existing_file.write_text("keep extracted files")

        for legacy in (False, True):
            with self.subTest(legacy=legacy):
                result = self.run_installer(legacy=legacy)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(caller_archive.read_text(), "keep archive")
                self.assertEqual(existing_file.read_text(), "keep extracted files")
                download_path = Path((self.root / "download-path").read_text().strip())
                self.assertEqual(download_path.parent.parent, self.work_directory)

    def test_install_does_not_follow_symlinks_in_caller_directory(self):
        archive_target = self.root / "existing-file"
        archive_target.write_text("keep file")
        caller_archive = self.caller_directory / self.archive.name
        caller_archive.symlink_to(archive_target)
        directory_target = self.root / "existing-directory"
        directory_target.mkdir()
        existing_file = directory_target / "keep"
        existing_file.write_text("keep directory")
        extracted_directory = self.caller_directory / "extracted_files"
        extracted_directory.symlink_to(directory_target, target_is_directory=True)

        for legacy in (False, True):
            with self.subTest(legacy=legacy):
                result = self.run_installer(legacy=legacy)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(caller_archive.is_symlink())
                self.assertTrue(extracted_directory.is_symlink())
                self.assertEqual(archive_target.read_text(), "keep file")
                self.assertEqual(existing_file.read_text(), "keep directory")
                self.assertEqual(list(directory_target.iterdir()), [existing_file])

    def test_legacy_url_warns_and_runs_verified_release_installer(self):
        result = self.run_installer(legacy=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        installer_url = "https://github.com/mtj0928/nest/releases/latest/download/install.sh"
        self.assertEqual((self.root / "installer-url").read_text().strip(), installer_url)
        self.assertIn("Warning:", result.stderr)
        self.assertIn(f"curl -fsSL {installer_url} | bash", result.stderr)
        self.assertIn("nest was installed", result.stdout)
        self.assertEqual(
            (self.root / "install-args").read_text().splitlines(),
            ["install", "mtj0928/nest", self.tag, "--checksum", self.checksum],
        )

    def test_legacy_url_verifies_checksum(self):
        with self.archive.open("ab") as archive:
            archive.write(b"tampered")
        result = self.run_installer(legacy=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Checksum mismatch", result.stderr)
        self.assertFalse((self.root / "unzip-called").exists())
        self.assertFalse((self.root / "install-args").exists())

    def test_legacy_download_failure_does_not_execute_partial_script(self):
        result = self.run_installer(legacy=True, INSTALLER_CURL_EXIT_CODE="22")
        self.assertEqual(result.returncode, 22)
        self.assertFalse((self.root / "curl-url").exists())
        self.assertFalse((self.root / "install-args").exists())

    def test_legacy_url_propagates_release_installer_failure(self):
        result = self.run_installer(legacy=True, INSTALL_EXIT_CODE="42")
        self.assertEqual(result.returncode, 42)
        self.assertNotIn("nest was installed", result.stdout)

    def test_checksum_mismatch_stops_before_extraction(self):
        with self.archive.open("ab") as archive:
            archive.write(b"tampered")
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Checksum mismatch", result.stderr)
        self.assertFalse((self.root / "unzip-called").exists())
        self.assertFalse((self.root / "install-args").exists())

    def test_failed_download_stops_before_extraction(self):
        result = self.run_installer(CURL_EXIT_CODE="22")
        self.assertEqual(result.returncode, 22)
        self.assertFalse((self.root / "unzip-called").exists())
        self.assertFalse((self.root / "install-args").exists())

    def test_failed_install_does_not_report_success(self):
        result = self.run_installer(INSTALL_EXIT_CODE="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("nest was installed", result.stdout)

    def test_failed_extraction_stops_before_install(self):
        result = self.run_installer(UNZIP_EXIT_CODE="9")
        self.assertEqual(result.returncode, 9)
        self.assertFalse((self.root / "install-args").exists())
        self.assertNotIn("nest was installed", result.stdout)

    def test_template_cannot_install_without_release_values(self):
        self.installer.write_text((SCRIPTS / "install.sh.template").read_text())
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "curl-url").exists())

    def test_generator_requires_tag_and_archive(self):
        self.assertNotEqual(self.generate(tag="").returncode, 0)
        self.assertNotEqual(self.generate(archive=self.root / "missing.zip").returncode, 0)

    def test_generator_quotes_tag_as_data(self):
        tag = 'v1.2.3-$(touch "unexpected")&test'
        self.assertEqual(self.generate(tag=tag).returncode, 0)
        result = self.run_installer(CURL_EXIT_CODE="22")
        self.assertEqual(result.returncode, 22)
        self.assertFalse((self.caller_directory / "unexpected").exists())
        self.assertIn(f"/releases/download/{tag}/", (self.root / "curl-url").read_text())


if __name__ == "__main__":
    unittest.main()
