#!/usr/bin/env python3
"""Verify the release DEX descriptor that shared_preferences' JNI code calls."""

import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--apkanalyzer")
    parser.add_argument(
        "--package-config", type=Path, default=Path(".dart_tool/package_config.json")
    )
    args = parser.parse_args()

    config = args.package_config.resolve()
    packages = json.loads(config.read_text())["packages"]
    plugin = next(p for p in packages if p["name"] == "shared_preferences_android")
    uri = urljoin(config.as_uri(), plugin["rootUri"])
    root = Path(unquote(urlparse(uri).path))
    binding = root / "lib/src/messages.g.jni.dart"
    if not binding.exists():
        print("SharedPreferences uses the legacy channel; no JNI descriptor to check.")
        return

    # Pigeon may change the bridge's argument encoding between plugin releases.
    # Compare the APK to the binding that this build actually compiles, rather
    # than accepting a historical descriptor (which can also hide an old APK).
    get_all = re.search(
        r"SharedPreferencesApiRegistrar\._class\.instanceMethodId\(\s*"
        r"r?'getAll',\s*r?'(\([^'\n]+)',?\s*\)",
        binding.read_text(encoding="utf-8"),
    )
    if not get_all:
        raise SystemExit(
            "Cannot read SharedPreferences getAll JNI descriptor: " + str(binding)
        )
    get_all_descriptor = "getAll" + get_all.group(1)

    analyzer = args.apkanalyzer or shutil.which("apkanalyzer")
    if not analyzer:
        for key in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
            sdk = os.environ.get(key)
            if sdk:
                candidate = Path(sdk) / "cmdline-tools/latest/bin/apkanalyzer"
                if candidate.is_file():
                    analyzer = str(candidate)
                    break
    if not analyzer:
        parser.error("apkanalyzer is required (Android SDK command-line tools)")

    # Names and descriptors used by shared_preferences and package:jni's
    # lib/src/kotlin.dart. Checking only getAll misses runtime helper lookups.
    requirements = {
        "io.flutter.plugins.sharedpreferences.SharedPreferencesApiRegistrar": [
            ("method", get_all_descriptor),
        ],
        "kotlin.coroutines.Continuation": [
            ("method", "resumeWith(Ljava/lang/Object;)V"),
        ],
        "kotlin.coroutines.intrinsics.CoroutineSingletons": [
            (
                "field",
                (
                    "COROUTINE_SUSPENDED:"
                    "Lkotlin/coroutines/intrinsics/CoroutineSingletons;"
                ),
            ),
        ],
        "kotlin.coroutines.intrinsics.IntrinsicsKt": [],
        "kotlin.coroutines.intrinsics.IntrinsicsKt__IntrinsicsKt": [
            ("method", "getCOROUTINE_SUSPENDED()Ljava/lang/Object;"),
        ],
        "kotlin.Result": [("field", "value:Ljava/lang/Object;")],
        "kotlin.Result$Failure": [
            ("field", "exception:Ljava/lang/Throwable;"),
            ("method", "<init>(Ljava/lang/Throwable;)V"),
        ],
        "kotlin.Unit": [("field", "INSTANCE:Lkotlin/Unit;")],
    }
    for class_name, members in requirements.items():
        result = subprocess.run(
            [analyzer, "dex", "code", "--class", class_name, str(args.apk.resolve())],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0 or ".class " not in result.stdout:
            raise SystemExit("Missing JNI runtime class in release APK: " + class_name)
        for kind, descriptor in members:
            pattern = r"^\." + kind + r" [^\n]* " + re.escape(descriptor) + r"$"
            if not re.search(pattern, result.stdout, re.MULTILINE):
                raise SystemExit(
                    "Broken JNI runtime descriptor in release APK: "
                    + class_name
                    + "."
                    + descriptor
                    + ". Check release ProGuard keep rules."
                )
    print("SharedPreferences JNI bridge and Kotlin runtime verified in release APK.")


if __name__ == "__main__":
    main()
