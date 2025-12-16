#!/usr/bin/env python3
"""
install-tool.py - download, verify, and install binary tools

usage:
    ./install-tool.py list                     # show available tools
    ./install-tool.py install zellij helix     # install specific tools
    ./install-tool.py install --all            # install all tools
    ./install-tool.py install --group base     # install tools in a group
"""

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional
from urllib.request import urlopen
from urllib.error import URLError


@dataclass
class Tool(ABC):
    """base class for installable tools."""
    name: str
    version: str
    sha256: str
    groups: list[str] = field(default_factory=list)
    post_install_message: Optional[str] = None
    
    @property
    @abstractmethod
    def url(self) -> str:
        """return the download url for this tool."""
        pass
    
    @abstractmethod
    def install(self, archive_path: Path, dest_dir: Path) -> list[str]:
        """
        install the tool from the downloaded archive.
        returns list of installed binary names.
        """
        pass
    
    def download_and_verify(self, dest_path: Path) -> None:
        """download the tool and verify its sha256 hash."""
        print(f"  downloading {self.name} v{self.version}...")
        
        try:
            with urlopen(self.url, timeout=60) as response:
                data = response.read()
        except URLError as e:
            raise RuntimeError(f"failed to download {self.url}: {e}")
        
        # verify hash
        actual_hash = hashlib.sha256(data).hexdigest()
        if actual_hash != self.sha256:
            raise RuntimeError(
                f"sha256 mismatch for {self.name}:\n"
                f"  expected: {self.sha256}\n"
                f"  actual:   {actual_hash}"
            )
        
        dest_path.write_bytes(data)
        print(f"  verified sha256: {self.sha256[:16]}...")


@dataclass
class TarGzTool(Tool):
    """tool distributed as a .tar.gz archive."""
    url_template: str = ""
    binaries: list[str] = field(default_factory=list)
    strip_components: int = 0
    
    @property
    def url(self) -> str:
        return self.url_template.format(version=self.version)
    
    def install(self, archive_path: Path, dest_dir: Path) -> list[str]:
        with tarfile.open(archive_path, "r:gz") as tar:
            return self._extract_binaries(tar, dest_dir)
    
    def _extract_binaries(self, tar: tarfile.TarFile, dest_dir: Path) -> list[str]:
        installed = []
        for member in tar.getmembers():
            if not member.isfile():
                continue
            
            # get the base name, stripping path components if needed
            parts = Path(member.name).parts
            if len(parts) <= self.strip_components:
                continue
            
            name = parts[-1]
            if self.binaries and name not in self.binaries:
                continue
            
            # extract to dest
            dest_path = dest_dir / name
            with tar.extractfile(member) as src:
                dest_path.write_bytes(src.read())
            dest_path.chmod(0o755)
            installed.append(name)
        
        return installed


@dataclass
class TarXzTool(TarGzTool):
    """tool distributed as a .tar.xz archive."""
    
    def install(self, archive_path: Path, dest_dir: Path) -> list[str]:
        with tarfile.open(archive_path, "r:xz") as tar:
            return self._extract_binaries(tar, dest_dir)


@dataclass
class HelixTool(TarXzTool):
    """helix editor - extracts binary and runtime to ~/.config/helix/runtime."""
    
    def install(self, archive_path: Path, dest_dir: Path) -> list[str]:
        installed = []
        runtime_dir = Path.home() / ".config" / "helix" / "runtime"
        
        with tarfile.open(archive_path, "r:xz") as tar:
            for member in tar.getmembers():
                parts = Path(member.name).parts
                if len(parts) < 2:
                    continue
                
                # extract hx binary
                if member.isfile() and parts[-1] == "hx":
                    dest_path = dest_dir / "hx"
                    with tar.extractfile(member) as src:
                        dest_path.write_bytes(src.read())
                    dest_path.chmod(0o755)
                    installed.append("hx")
                
                # extract runtime directory
                elif "runtime" in parts:
                    idx = parts.index("runtime")
                    rel_path = Path(*parts[idx + 1:])  # path relative to runtime/
                    if not rel_path.parts:
                        continue
                    dest_path = runtime_dir / rel_path
                    
                    if member.isdir():
                        dest_path.mkdir(parents=True, exist_ok=True)
                    elif member.isfile():
                        dest_path.parent.mkdir(parents=True, exist_ok=True)
                        with tar.extractfile(member) as src:
                            dest_path.write_bytes(src.read())
        
        return installed


@dataclass
class ZipTool(Tool):
    """tool distributed as a .zip archive."""
    url_template: str = ""
    binaries: list[str] = field(default_factory=list)
    strip_components: int = 0
    
    @property
    def url(self) -> str:
        return self.url_template.format(version=self.version)
    
    def install(self, archive_path: Path, dest_dir: Path) -> list[str]:
        installed = []
        with zipfile.ZipFile(archive_path, "r") as zf:
            for info in zf.infolist():
                if info.is_dir():
                    continue
                
                parts = Path(info.filename).parts
                if len(parts) <= self.strip_components:
                    continue
                
                name = parts[-1]
                if self.binaries and name not in self.binaries:
                    continue
                
                dest_path = dest_dir / name
                dest_path.write_bytes(zf.read(info.filename))
                dest_path.chmod(0o755)
                installed.append(name)
        
        return installed


@dataclass
class BinaryTool(Tool):
    """tool distributed as a raw binary."""
    url_template: str = ""
    binary_name: str = ""
    
    @property
    def url(self) -> str:
        return self.url_template.format(version=self.version)
    
    def install(self, archive_path: Path, dest_dir: Path) -> list[str]:
        dest_path = dest_dir / (self.binary_name or self.name)
        shutil.copy2(archive_path, dest_path)
        dest_path.chmod(0o755)
        return [dest_path.name]


# tool registry
TOOLS: dict[str, Tool] = {
    "zellij": TarGzTool(
        name="zellij",
        version="0.43.0",
        sha256="00070e052a86e3072dbd626cc0a0295106e7ed74c42871ba38185d4ebbcae58a",
        url_template="https://github.com/zellij-org/zellij/releases/download/v{version}/zellij-x86_64-unknown-linux-musl.tar.gz",
        binaries=["zellij"],
        groups=["base"],
    ),
    "helix": HelixTool(
        name="helix",
        version="25.07.1",
        sha256="3f08e63ecd388fff657ad39722f88bb03dcf326f1f2da2700d99e1dc40ab2e8b",
        url_template="https://github.com/helix-editor/helix/releases/download/{version}/helix-{version}-x86_64-linux.tar.xz",
        binaries=["hx"],
        strip_components=1,
        groups=["base"],
    ),
    "yazi": ZipTool(
        name="yazi",
        version="25.5.31",
        sha256="a2fdc9c35719fa72d94820893eb2fedd93fd1c418c2cf568702643526c358f7a",
        url_template="https://github.com/sxyazi/yazi/releases/download/v{version}/yazi-x86_64-unknown-linux-musl.zip",
        binaries=["yazi"],
        strip_components=1,
        groups=["base"],
    ),
    "starship": TarGzTool(
        name="starship",
        version="1.24.1",
        sha256="44a729c34aea5b0451fba49108cdc5ef6b1ae68db65e7623cc244a52efcd23d1",
        url_template="https://github.com/starship/starship/releases/download/v{version}/starship-x86_64-unknown-linux-musl.tar.gz",
        binaries=["starship"],
        groups=["base"],
    ),
    "uv": TarGzTool(
        name="uv",
        version="0.5.11",
        sha256="5b77978bc8ded7e1b6ddb6d6a3e52f684bcc07c6d9be11d7b4fc3c1c23f4458f",
        url_template="https://github.com/astral-sh/uv/releases/download/{version}/uv-x86_64-unknown-linux-musl.tar.gz",
        binaries=["uv", "uvx"],
        strip_components=1,
        groups=["base"],
    ),
    "kubectl": BinaryTool(
        name="kubectl",
        version="1.34.3",
        sha256="ab60ca5f0fd60c1eb81b52909e67060e3ba0bd27e55a8ac147cbc2172ff14212",
        url_template="https://dl.k8s.io/release/v{version}/bin/linux/amd64/kubectl",
        binary_name="kubectl",
        groups=["k8s"],
    ),
    "talosctl": BinaryTool(
        name="talosctl",
        version="1.9.1",
        sha256="3dbc86618394db080a3465143c1bc45aefd4e299fc3f7e1429e93c255cf9c555",
        url_template="https://github.com/siderolabs/talos/releases/download/v{version}/talosctl-linux-amd64",
        binary_name="talosctl",
        groups=["k8s"],
    ),
    "cilium": TarGzTool(
        name="cilium",
        version="0.18.9",
        sha256="15978aaf82373b0682aa87ab217848b3fb6e3cd80adad365d34696fe92543923",
        url_template="https://github.com/cilium/cilium-cli/releases/download/v{version}/cilium-linux-amd64.tar.gz",
        binaries=["cilium"],
        groups=["k8s"],
    ),
    "kubectl-cnpg": TarGzTool(
        name="kubectl-cnpg",
        version="1.28.0",
        sha256="d39f8623ff4de6bc7a3013e596b808432ae50773ddac56efe04e9ded2205bbf1",
        url_template="https://github.com/cloudnative-pg/cloudnative-pg/releases/download/v{version}/kubectl-cnpg_{version}_linux_x86_64.tar.gz",
        binaries=["kubectl-cnpg"],
        groups=["k8s"],
    ),
    "direnv": BinaryTool(
        name="direnv",
        version="2.35.0",
        sha256="55c294f4376397c68b1f659f049fb104dc2ecd0fcb15a15949d7f748e3f70b66",
        url_template="https://github.com/direnv/direnv/releases/download/v{version}/direnv.linux-amd64",
        binary_name="direnv",
        groups=["base"],
        post_install_message="add 'eval \"$(direnv hook bash)\"' to your .bashrc",
    ),
    "just": TarGzTool(
        name="just",
        version="1.40.0",
        sha256="181b91d0ceebe8a57723fb648ed2ce1a44d849438ce2e658339df4f8db5f1263",
        url_template="https://github.com/casey/just/releases/download/{version}/just-{version}-x86_64-unknown-linux-musl.tar.gz",
        binaries=["just"],
        groups=["base"],
    ),
}


def list_tools() -> None:
    """print available tools."""
    print("available tools:\n")
    
    # group by groups
    by_group: dict[str, list[Tool]] = {}
    for tool in TOOLS.values():
        for group in tool.groups or ["other"]:
            by_group.setdefault(group, []).append(tool)
    
    for group, tools in sorted(by_group.items()):
        print(f"  [{group}]")
        for tool in tools:
            print(f"    {tool.name:15} v{tool.version}")
        print()


def install_tools(
    names: list[str],
    dest_dir: Path,
    use_sudo: bool = False,
) -> bool:
    """install the specified tools. returns True on success."""
    success = True
    
    for name in names:
        tool = TOOLS.get(name)
        if not tool:
            print(f"error: unknown tool '{name}'", file=sys.stderr)
            success = False
            continue
        
        print(f"installing {tool.name} v{tool.version}...")
        
        try:
            with tempfile.NamedTemporaryFile(delete=False) as tmp:
                tmp_path = Path(tmp.name)
            
            tool.download_and_verify(tmp_path)
            
            # install to temp dir first, then move with sudo if needed
            with tempfile.TemporaryDirectory() as tmp_dir:
                tmp_dest = Path(tmp_dir)
                installed = tool.install(tmp_path, tmp_dest)
                
                for bin_name in installed:
                    src = tmp_dest / bin_name
                    dst = dest_dir / bin_name
                    
                    if use_sudo:
                        subprocess.run(
                            ["sudo", "cp", str(src), str(dst)],
                            check=True,
                        )
                        subprocess.run(
                            ["sudo", "chmod", "755", str(dst)],
                            check=True,
                        )
                    else:
                        shutil.copy2(src, dst)
                        dst.chmod(0o755)
                    
                    print(f"  installed {bin_name} -> {dst}")
            
            tmp_path.unlink(missing_ok=True)
            
            if tool.post_install_message:
                msg = tool.post_install_message.format(version=tool.version)
                print(f"  note: {msg}")
            
            print(f"  done\n")
            
        except Exception as e:
            print(f"  error: {e}\n", file=sys.stderr)
            success = False
    
    return success


def main() -> int:
    parser = argparse.ArgumentParser(
        description="download, verify, and install binary tools"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # list command
    subparsers.add_parser("list", help="list available tools")
    
    # install command
    install_parser = subparsers.add_parser("install", help="install tools")
    install_parser.add_argument(
        "tools",
        nargs="*",
        help="tool names to install",
    )
    install_parser.add_argument(
        "--all",
        action="store_true",
        help="install all tools",
    )
    install_parser.add_argument(
        "--group",
        action="append",
        dest="groups",
        help="install all tools in group(s)",
    )
    install_parser.add_argument(
        "--dest",
        type=Path,
        default=Path("/usr/local/bin"),
        help="destination directory (default: /usr/local/bin)",
    )
    install_parser.add_argument(
        "--sudo",
        action="store_true",
        help="use sudo for installation",
    )
    
    args = parser.parse_args()
    
    if args.command == "list":
        list_tools()
        return 0
    
    elif args.command == "install":
        tools_to_install: list[str] = []
        
        if args.all:
            tools_to_install = list(TOOLS.keys())
        elif args.groups:
            for tool in TOOLS.values():
                if any(g in tool.groups for g in args.groups):
                    tools_to_install.append(tool.name)
        else:
            tools_to_install = args.tools
        
        if not tools_to_install:
            print("error: no tools specified", file=sys.stderr)
            return 1
        
        # check dest dir
        if not args.dest.exists():
            print(f"error: destination {args.dest} does not exist", file=sys.stderr)
            return 1
        
        success = install_tools(
            tools_to_install,
            args.dest,
            use_sudo=args.sudo,
        )
        return 0 if success else 1
    
    return 1


if __name__ == "__main__":
    sys.exit(main())
