"""Python/JVM images with explicit architecture inputs and native OCI indexes."""

load("@pythons_hub//:versions.bzl", "MINOR_MAPPING")
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_image_index", "oci_load", "oci_push")
load("@rules_distroless//apt/private:deb_postfix.bzl", "deb_postfix")
load("@rules_distroless//distroless:defs.bzl", "flatten")
load("@rules_pkg//pkg:mappings.bzl", "pkg_attributes", "pkg_files", "pkg_mklink")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

def _runtime_files_impl(ctx):
    stdlib = "lib/python" + ctx.attr.python_version + "/"
    site = stdlib + "site-packages/"
    retained = []
    for file in ctx.attr.src[DefaultInfo].files.to_list():
        prefix = "../" + file.owner.workspace_name + "/"
        if not file.short_path.startswith(prefix):
            fail("Unexpected interpreter file path: " + file.short_path)
        path = file.short_path[len(prefix):]
        if path in ["bin/pip", "bin/pip3", "bin/pip" + ctx.attr.python_version]:
            continue
        if path.startswith(stdlib + "ensurepip/"):
            continue
        if path.startswith(site):
            package = path[len(site):].split("/")[0]
            if package in ["pip", "setuptools", "pkg_resources", "_distutils_hack", "distutils-precedence.pth"]:
                continue
            if package.endswith(".dist-info") and (package.startswith("pip-") or package.startswith("setuptools-")):
                continue
        retained.append(file)
    return [DefaultInfo(files = depset(retained))]

_runtime_files = rule(
    implementation = _runtime_files_impl,
    attrs = {
        "src": attr.label(mandatory = True),
        "python_version": attr.string(mandatory = True),
    },
)

def runtime_layers(arch):
    """Package the Debian shared libraries and the selected Temurin archive."""
    flatten(
        name = "runtime_libraries_flat_" + arch,
        tars = ["@debian13_runtime_libraries//{}/{}".format(package, arch) for package in [
            "libc6",
            "libjpeg62-turbo",
            "liblcms2-2",
            "libnss3",
            "libpcsclite1",
            "libssl3t64",
            "libstdc++6",
            "libtinfo6",
            "zlib1g",
        ]],
        deduplicate = True,
    )
    # Debian 13 is merged-/usr.
    deb_postfix(
        name = "runtime_libraries_" + arch,
        mergedusr = True,
        outs = ["runtime_libraries_" + arch + ".tar.gz"],
        srcs = [":runtime_libraries_flat_" + arch],
    )
    java_layer(arch, "21")
    java_layer(arch, "25")

def java_layer(arch, java):
    suffix = java + "_" + arch
    java_home = "usr/lib/jvm/java-{}-openjdk-{}".format(java, arch)
    native.genrule(
        name = "java_layer_" + suffix,
        srcs = ["@temurin_" + suffix + "//:jre.tar.gz"],
        outs = ["java_layer_" + suffix + ".tar.gz"],
        cmd = '$(location :package_temurin) "$<" "$@" ' + java_home,
        tools = [":package_temurin"],
    )
    pkg_mklink(
        name = "java_" + suffix,
        link_name = "usr/bin/java",
        target = "../" + java_home.removeprefix("usr/") + "/bin/java",
    )
    pkg_tar(
        name = "metadata_layer_" + suffix,
        srcs = [":app_dir", ":certs_dir", ":java_" + suffix],
    )

def python_layer(python_version, arch):
    """Package CPython once for the platform, shared by both Java majors."""
    suffix = python_version.replace(".", "_")
    name = "pyva_runtime_" + suffix + "_" + arch
    repo = "@cpython_" + suffix + "_" + arch
    executables = [
        "idle" + python_version,
        "pydoc" + python_version,
        "python" + python_version,
        "python" + python_version + "-config",
    ]
    links = {
        "python": "python" + python_version,
        "python3": "python" + python_version,
        "python3-config": "python" + python_version + "-config",
        "idle3": "idle" + python_version,
        "pydoc3": "pydoc" + python_version,
    }
    _runtime_files(
        name = name + "_runtime_files",
        src = repo + "//:files",
        python_version = python_version,
    )
    pkg_files(
        name = name + "_files",
        srcs = [":" + name + "_runtime_files"],
        excludes = [repo + "//:bin/" + path for path in executables + links.keys()],
        prefix = "usr",
        strip_prefix = "/",
    )
    pkg_files(
        name = name + "_executables",
        srcs = [repo + "//:bin/" + path for path in executables],
        attributes = pkg_attributes(mode = "0555"),
        prefix = "usr",
        strip_prefix = "/",
    )
    for link, target in links.items():
        pkg_mklink(
            name = name + "_" + link.replace("-", "_"),
            link_name = "usr/bin/" + link,
            target = target,
        )
    pkg_tar(
        name = name + "_python_layer",
        srcs = [":" + name + "_files", ":" + name + "_executables"] + [
            ":" + name + "_" + link.replace("-", "_")
            for link in links
        ],
    )

def runtime_image(python_version, arch, java = "21"):
    """Define a platform image and its separately tagged Docker loader."""
    root = "pyva_runtime_" + python_version.replace(".", "_")
    java_suffix = "" if java == "21" else "_java" + java
    local_tag = python_version + java_suffix.replace("_", "-")
    name = root + java_suffix + "_" + arch
    java_home = "/usr/lib/jvm/java-{}-openjdk-{}".format(java, arch)
    version = MINOR_MAPPING[python_version]
    tag = version + "-java" + java + "-debian13"
    metadata = {
        "org.opencontainers.image.title": "pyva-runtime",
        "org.opencontainers.image.description": "Distroless Debian 13 runtime with CPython " + version + " and Eclipse Temurin " + java + " for JPype.",
        "org.opencontainers.image.version": tag,
        "org.opencontainers.image.base.name": "gcr.io/distroless/static-debian13",
    }
    oci_image(
        name = name,
        base = "@distroless_static_debian13_linux_" + ("arm64_v8" if arch == "arm64" else arch),
        annotations = metadata,
        labels = metadata,
        entrypoint = ["/usr/bin/python3"],
        env = {
            "JAVA_HOME": java_home,
            "LD_LIBRARY_PATH": java_home + "/lib/server",
            "PATH": "/usr/bin:/bin",
            "PYTHONHOME": "/usr",
            "SSL_CERT_DIR": "/etc/certs",
        },
        tars = [
            ":runtime_libraries_" + arch,
            ":java_layer_" + java + "_" + arch,
            ":" + root + "_" + arch + "_python_layer",
            ":metadata_layer_" + java + "_" + arch,
        ],
        user = "65532:65532",
        workdir = "/app",
    )
    oci_load(
        name = name + "_load",
        image = ":" + name,
        repo_tags = ["pyva-runtime:" + local_tag + "-" + arch] + (
            ["pyva-runtime:" + local_tag, "pyva-runtime:" + tag] if arch == "amd64" else []
        ),
    )

def runtime_index(python_version, java = "21"):
    """Define the two-platform index and its legacy amd64 loader."""
    java_variant = "" if java == "21" else "java" + java
    root = "pyva_runtime_" + python_version.replace(".", "_") + ("_" + java_variant if java_variant else "")
    oci_image_index(
        name = root,
        images = [":" + root + "_amd64", ":" + root + "_arm64"],
    )
    oci_push(name = root + "_push", image = ":" + root)
    oci_load(
        name = root + "_load",
        image = ":" + root + "_amd64",
        repo_tags = [
            "pyva-runtime:" + python_version + ("-" + java_variant if java_variant else ""),
            "pyva-runtime:" + MINOR_MAPPING[python_version] + "-java" + java + "-debian13",
        ],
    )
