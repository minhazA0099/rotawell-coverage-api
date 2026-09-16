"""Build and release metadata, exposed at /version for traceability.

The commit and build time are baked into the image when CI builds it. The release version
is configuration supplied when an already-tested image is promoted, so promotion never
needs a rebuild.
"""

import os


def build_info() -> dict[str, str]:
    return {
        "version": os.environ.get("APP_VERSION", "unreleased"),
        "commit": os.environ.get("GIT_SHA", "unknown"),
        "built": os.environ.get("BUILD_DATE", "unknown"),
    }
