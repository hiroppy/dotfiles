import json
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

import worktree_cleanup


class ProcessTests(unittest.TestCase):
    def blockers(self, references, executable, returncode=0, stderr=""):
        responses = [
            subprocess.CompletedProcess([], returncode, references, stderr),
            subprocess.CompletedProcess([], 0, executable + "\n", ""),
        ]
        with patch.object(worktree_cleanup.subprocess, "run", side_effect=responses):
            return worktree_cleanup.process_blockers(Path("/worktree"))

    def test_shared_mount_read_references_do_not_block(self):
        self.assertEqual(
            [],
            self.blockers(
                "p123\nf5\nar\nn/worktree/a\nf6\nar\nn/worktree\nf*001\nar\nn/worktree/b\n",
                worktree_cleanup.SHARED_MOUNT_PROCESS,
            ),
        )

    def test_vm_writes_cwd_and_unknown_access_still_block(self):
        for reference in ("f5\naw", "f5\nau", "fcwd\nar", "f5"):
            reference += "\nn/worktree/x"
            with self.subTest(reference=reference):
                self.assertEqual(
                    ["active_processes"],
                    self.blockers(
                        "p123\n" + reference + "\n",
                        worktree_cleanup.SHARED_MOUNT_PROCESS,
                    ),
                )

    def test_docker_vm_write_references_require_mount_check(self):
        references = (
            "p123\nf6\nau\nn/Users/dev/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw\n"
            "f*10\naw\nn/worktree/emulator.log\n"
        )
        with patch.object(worktree_cleanup, "docker_desktop_mounts_worktree") as mounts:
            for mounted in (False, True):
                mounts.return_value = mounted
                self.assertEqual(
                    ["active_processes"] if mounted else [],
                    self.blockers(references, worktree_cleanup.SHARED_MOUNT_PROCESS),
                )
            self.assertEqual(2, mounts.call_count)

    def test_desktop_checks_containers_and_local_volume_devices(self):
        cases = (
            ("/host_mnt/worktree/firebase", "", True),
            ("/", "", True),
            ("/worktree-sibling", "/run/host_mnt/worktree/data", True),
            ("/worktree-sibling", "/elsewhere", False),
        )
        for source, device, expected in cases:
            responses = (
                "Docker Desktop",
                "container-id",
                "volume-name",
                json.dumps([{"Mounts": [{"Source": source}]}]),
                json.dumps([{"Options": {"device": device}}]),
            )
            with self.subTest(source=source, device=device), patch.object(
                Path, "is_socket", return_value=True
            ), patch.object(
                worktree_cleanup.subprocess,
                "run",
                side_effect=[subprocess.CompletedProcess([], 0, value) for value in responses],
            ) as run:
                self.assertEqual(
                    expected, worktree_cleanup.docker_desktop_mounts_worktree(Path("/worktree"))
                )
                self.assertIn("--all", run.call_args_list[1].args[0])

    def test_desktop_inspection_failure_keeps_worktree(self):
        with patch.object(Path, "is_socket", return_value=True), patch.object(
            worktree_cleanup.subprocess,
            "run",
            side_effect=subprocess.TimeoutExpired("docker", 10),
        ):
            self.assertTrue(worktree_cleanup.docker_desktop_mounts_worktree(Path("/worktree")))

    def test_application_read_reference_is_still_active(self):
        for executable in (
            "/usr/bin/node",
            worktree_cleanup.SHARED_MOUNT_PROCESS + "-other",
        ):
            with self.subTest(executable=executable):
                self.assertEqual(
                    ["active_processes"], self.blockers("p123\nf5\nar\nn/worktree/x\n", executable)
                )

    def test_mixed_vm_and_application_is_not_exempt(self):
        with patch.object(
            worktree_cleanup.subprocess,
            "run",
            side_effect=[
                subprocess.CompletedProcess([], 0, "p123\nf5\nar\nn/worktree/x\np124\nf6\nar\nn/worktree/y\n", ""),
                subprocess.CompletedProcess(
                    [], 0, worktree_cleanup.SHARED_MOUNT_PROCESS, ""
                ),
                subprocess.CompletedProcess([], 0, "/usr/bin/node", ""),
            ],
        ):
            self.assertEqual(
                ["active_processes"],
                worktree_cleanup.process_blockers(Path("/worktree")),
            )

    def test_failed_or_malformed_observations_remain_unknown(self):
        for output, code, error in (
            ("", 1, ""),
            ("p123\nf5\nar\n", 1, "permission denied"),
            ("f5\nar\n", 0, ""),
            ("123\n", 0, ""),
            ("p123\nn/worktree/x\n", 0, ""),
        ):
            with self.subTest(output=output, code=code, error=error):
                expected = [] if not output and not error else ["process_state_unknown"]
                self.assertEqual(
                    expected,
                    self.blockers(
                        output, worktree_cleanup.SHARED_MOUNT_PROCESS, code, error
                    ),
                )

    def test_files_outside_worktree_are_ignored(self):
        with patch.object(
            worktree_cleanup.subprocess,
            "run",
            return_value=subprocess.CompletedProcess(
                [], 0, "p123\nfcwd\nar\nn/other\nf5\naw\nn/worktree-sibling/x\n", ""
            ),
        ) as run:
            self.assertEqual([], worktree_cleanup.process_blockers(Path("/worktree")))
        self.assertEqual(1, run.call_count)

    def test_unreadable_name_is_unknown(self):
        with patch.object(
            worktree_cleanup.subprocess,
            "run",
            return_value=subprocess.CompletedProcess(
                [], 0, "p123\nfcwd\nar\nn/ (readlink: Permission denied)\n", ""
            ),
        ):
            self.assertEqual(
                ["process_state_unknown"],
                worktree_cleanup.process_blockers(Path("/worktree")),
            )

    def test_non_ascii_worktree_is_unknown_without_scanning(self):
        with patch.object(worktree_cleanup.subprocess, "run") as run:
            self.assertEqual(
                ["process_state_unknown"],
                worktree_cleanup.process_blockers(Path("/作業")),
            )
        run.assert_not_called()

    def test_process_identity_failure_is_unknown(self):
        with patch.object(
            worktree_cleanup.subprocess,
            "run",
            side_effect=[
                subprocess.CompletedProcess([], 0, "p123\nf5\nar\nn/worktree/x\n", ""),
                subprocess.CompletedProcess([], 1, "", ""),
            ],
        ):
            self.assertEqual(
                ["process_state_unknown"],
                worktree_cleanup.process_blockers(Path("/worktree")),
            )


if __name__ == "__main__":
    unittest.main()
