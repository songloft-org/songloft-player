"""Check resolved JNI bindings against release DEX declarations."""

import contextlib
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "check-android-preferences-jni.py"
SPEC = importlib.util.spec_from_file_location("preferences_jni", SCRIPT)
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)
BRIDGE = "io.flutter.plugins.sharedpreferences.SharedPreferencesApiRegistrar"
OLD_SIGNATURE = (
    "(Ljava/lang/String;Ljava/util/List;Lkotlin/coroutines/Continuation;)"
    "Ljava/lang/Object;"
)
CURRENT_SIGNATURE = (
    "(Ljava/lang/String;[BLkotlin/coroutines/Continuation;)Ljava/lang/Object;"
)


class PreferencesJniTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.binding = self.root / "plugin/lib/src/messages.g.jni.dart"
        self.binding.parent.mkdir(parents=True)
        self.config = self.root / "package_config.json"
        self.config.write_text(
            json.dumps(
                {
                    "packages": [
                        {
                            "name": "shared_preferences_android",
                            "rootUri": "plugin/",
                        }
                    ]
                }
            )
        )

    def check(
        self,
        binding_signature,
        dex_signature,
        *,
        missing_class=None,
        missing_member=None,
        binding_source=None,
    ):
        if binding_source is None:
            binding_source = (
                "static final _id_getAll = "
                "SharedPreferencesApiRegistrar._class.instanceMethodId(\n"
                "  r'getAll',\n"
                f"  r'{binding_signature}',\n"
                ");\n"
            )
        self.binding.write_text(binding_source)

        def analyze(command, **kwargs):
            class_name = command[4]
            if class_name == missing_class:
                return subprocess.CompletedProcess(command, 1, "", "Class not found")
            declarations = {
                BRIDGE: [f".method public final getAll{dex_signature}"],
                "kotlin.coroutines.Continuation": [
                    ".method public abstract resumeWith(Ljava/lang/Object;)V",
                ],
                "kotlin.coroutines.intrinsics.CoroutineSingletons": [
                    (
                        ".field public static final COROUTINE_SUSPENDED:"
                        "Lkotlin/coroutines/intrinsics/CoroutineSingletons;"
                    ),
                ],
                "kotlin.coroutines.intrinsics.IntrinsicsKt__IntrinsicsKt": [
                    ".method public static final getCOROUTINE_SUSPENDED()Ljava/lang/Object;",
                ],
                "kotlin.Result": [".field private final value:Ljava/lang/Object;"],
                "kotlin.Result$Failure": [
                    ".field public final exception:Ljava/lang/Throwable;",
                    ".method public constructor <init>(Ljava/lang/Throwable;)V",
                ],
                "kotlin.Unit": [".field public static final INSTANCE:Lkotlin/Unit;"],
            }.get(class_name, [])
            output = "\n".join(
                [
                    ".class public L" + class_name.replace(".", "/") + ";",
                    *(line for line in declarations if line != missing_member),
                ]
            )
            return subprocess.CompletedProcess(command, 0, output, "")

        with (
            patch.object(
                sys,
                "argv",
                [
                    str(SCRIPT),
                    str(self.root / "release.apk"),
                    "--apkanalyzer",
                    "analyzer",
                    "--package-config",
                    str(self.config),
                ],
            ),
            patch.object(CHECKER.subprocess, "run", side_effect=analyze) as runner,
        ):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                CHECKER.main()
            return output.getvalue(), runner.call_count

    def test_legacy_jni_signature(self):
        output, calls = self.check(OLD_SIGNATURE, OLD_SIGNATURE)
        self.assertIn("verified", output)
        self.assertEqual(calls, 8)

    def test_current_jni_signature_uses_encoded_byte_array(self):
        output, calls = self.check(CURRENT_SIGNATURE, CURRENT_SIGNATURE)
        self.assertIn("verified", output)
        self.assertEqual(calls, 8)

    def test_old_apk_cannot_satisfy_current_dart_binding(self):
        with self.assertRaisesRegex(SystemExit, "Broken JNI runtime descriptor"):
            self.check(CURRENT_SIGNATURE, OLD_SIGNATURE)

    def test_renamed_descriptor_is_rejected(self):
        with self.assertRaisesRegex(SystemExit, "Broken JNI runtime descriptor"):
            self.check(
                CURRENT_SIGNATURE,
                CURRENT_SIGNATURE.replace(
                    "Lkotlin/coroutines/Continuation;",
                    "La/b;",
                ),
            )

    def test_missing_kotlin_runtime_class_is_rejected(self):
        with self.assertRaisesRegex(SystemExit, "Missing JNI runtime class"):
            self.check(
                CURRENT_SIGNATURE,
                CURRENT_SIGNATURE,
                missing_class="kotlin.coroutines.intrinsics.CoroutineSingletons",
            )

    def test_missing_kotlin_runtime_member_is_rejected(self):
        with self.assertRaisesRegex(SystemExit, "Broken JNI runtime descriptor"):
            self.check(
                CURRENT_SIGNATURE,
                CURRENT_SIGNATURE,
                missing_member=".field public final exception:Ljava/lang/Throwable;",
            )

    def test_unrecognized_generated_binding_fails_closed(self):
        with self.assertRaisesRegex(SystemExit, "Cannot read.*getAll"):
            self.check(
                CURRENT_SIGNATURE,
                CURRENT_SIGNATURE,
                binding_source="// Unexpected generator output\n",
            )

    def test_legacy_channel_needs_no_analyzer(self):
        with (
            patch.object(
                sys,
                "argv",
                [
                    str(SCRIPT),
                    "release.apk",
                    "--package-config",
                    str(self.config),
                ],
            ),
            patch.object(CHECKER.subprocess, "run") as runner,
        ):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                CHECKER.main()
            self.assertIn("legacy channel", output.getvalue())
            runner.assert_not_called()


if __name__ == "__main__":
    unittest.main()
