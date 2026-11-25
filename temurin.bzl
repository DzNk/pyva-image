"""Download the pinned Temurin archive for one runtime platform."""

def _temurin_archive_impl(ctx):
    entry = json.decode(ctx.read(ctx.attr.manifest))[ctx.attr.java]["archives"][ctx.attr.arch]
    ctx.download(url = entry["url"], sha256 = entry["sha256"], output = "jre.tar.gz")
    ctx.file("BUILD.bazel", 'exports_files(["jre.tar.gz"])\n')

temurin_archive = repository_rule(
    implementation = _temurin_archive_impl,
    attrs = {
        "arch": attr.string(mandatory = True, values = ["amd64", "arm64"]),
        "java": attr.string(mandatory = True, values = ["21", "25"]),
        "manifest": attr.label(default = Label("//:java_runtime.json"), allow_single_file = True),
    },
)
