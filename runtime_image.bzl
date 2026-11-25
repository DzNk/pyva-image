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

def python_layer(python_version, arch, cpu_variant = ""):
    """Package CPython once for the platform, shared by both Java majors."""
    suffix = python_version.replace(".", "_")
    selection = arch + ("_" + cpu_variant if cpu_variant else "")
    name = "pyva_runtime_" + suffix + "_" + selection
    repo = "@cpython_" + suffix + "_" + selection
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

def runtime_image(python_version, arch, cpu_variant = "", java = "21"):
    """Define a platform image and its separately tagged Docker loader."""
    if cpu_variant and (cpu_variant not in ["v2", "v3"] or arch != "amd64" or java != "21"):
        fail("CPU variants require amd64, Java 21, and v2 or v3")
    selection = arch + ("_" + cpu_variant if cpu_variant else "")
    root = "pyva_runtime_" + python_version.replace(".", "_")
    java_suffix = "" if java == "21" else "_java" + java
    local_tag = python_version + java_suffix.replace("_", "-")
    name = root + java_suffix + "_" + selection
    java_home = "/usr/lib/jvm/java-{}-openjdk-{}".format(java, arch)
    version = MINOR_MAPPING[python_version]
    tag = version + "-java" + java + "-debian13"
    metadata = {
        "org.opencontainers.image.title": "pyva-runtime",
        "org.opencontainers.image.description": "Distroless Debian 13 runtime with CPython " + version + " and Eclipse Temurin " + java + " for JPype.",
        "org.opencontainers.image.version": tag,
        "org.opencontainers.image.base.name": "gcr.io/distroless/static-debian13",
    }
    if cpu_variant:
        metadata["io.pyva.cpu.variant"] = cpu_variant
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
            ":" + root + "_" + selection + "_python_layer",
            ":metadata_layer_" + java + "_" + arch,
        ],
        user = "65532:65532",
        workdir = "/app",
    )
    oci_load(
        name = name + "_load",
        image = ":" + name,
        repo_tags = ["pyva-runtime:" + local_tag + "-" + selection.replace("_", "-")] + (
            ["pyva-runtime:" + local_tag, "pyva-runtime:" + tag] if arch == "amd64" and not cpu_variant else []
        ),
    )

def runtime_index(python_version, cpu_variant = "", java = "21"):
    """Publish the default pair or one explicit CPU image; release.sh sets tags."""
    if cpu_variant not in ["", "v2", "v3"]:
        fail("CPU variant must be v2 or v3")
    java_variant = "" if java == "21" else "java" + java
    root = "pyva_runtime_" + python_version.replace(".", "_") + ("_" + java_variant if java_variant else "")
    name = root + ("_amd64_" + cpu_variant + "_index" if cpu_variant else "")
    oci_image_index(
        name = name,
        images = [":" + root + "_amd64_" + cpu_variant] if cpu_variant else [":" + root + "_amd64", ":" + root + "_arm64"],
    )
    oci_push(name = name + "_push", image = ":" + name)
    if not cpu_variant:
        oci_load(
            name = name + "_load",
            image = ":" + name + "_amd64",
            repo_tags = [
                "pyva-runtime:" + python_version + ("-" + java_variant if java_variant else ""),
                "pyva-runtime:" + MINOR_MAPPING[python_version] + "-java" + java + "-debian13",
            ],
        )
