#!/usr/bin/env python3
"""Classify an abuse-test base URL as local, private or refuse.

Usage: check_target.py <base-url> [--deny HOST[:PORT] ...]
       check_target.py --self-test

  --deny  production (or otherwise forbidden) hosts found in recon. A base URL
          whose host, or any address it resolves to, matches one is refused.
          Without a port the whole host is refused.
Prefer IP-literal base URLs (http://127.0.0.1:PORT): then the address checked
is exactly the address the probes connect to.

Prints "<class> <host> <ip ...>" (or "refuse <url> (<reason>)") and exits:
   0  local    loopback, or a container network on this host
  10  private  LAN/private address; allowed only if the user approved it as a dev host
  20  refuse   public, unresolvable, production-looking, on the deny list,
               or not a bare base URL
Any other exit code is an error: treat it as refuse.
"""
import ipaddress
import re
import shutil
import socket
import subprocess
import sys

LOCAL, PRIVATE, REFUSE = 0, 10, 20
BASE_URL = re.compile(
    r"^(?:https?|wss?)://(\[[0-9A-Fa-f:.]+\]|[A-Za-z0-9.-]+)(?::(\d{1,5}))?/?$")
PROD_NAME = re.compile(r"(^|[.-])(prod|production|live)([.-]|$)|^www\.", re.I)
# Container/VM bridges only: docker0, Docker user networks (br-<12 hex>),
# podman, libvirt and LXC defaults. A generic "br-lan"/"br0" bridging a
# physical NIC must NOT count, or the whole LAN would classify as local.
BRIDGE_IFACE = re.compile(r"^(docker\d+|br-[0-9a-f]{12}|podman\d+|cni-podman\d+|virbr\d+|lxcbr\d+)$")
DEFAULT_PORTS = {"http": 80, "ws": 80, "https": 443, "wss": 443}
CGNAT = ipaddress.ip_network("100.64.0.0/10")


def bridge_networks():
    """CIDRs of container bridge interfaces on this host (Linux only)."""
    if not shutil.which("ip"):
        return []
    try:
        out = subprocess.run(["ip", "-o", "addr"], capture_output=True,
                             text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    nets = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 4 and BRIDGE_IFACE.match(parts[1].split("@")[0]) \
                and parts[2] in ("inet", "inet6"):
            net = ipaddress.ip_interface(parts[3]).network
            if not net.is_link_local:  # fe80::/10 exists on every link, including the LAN
                nets.append(net)
    return nets


def classify_ip(ip, bridges):
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped:
        ip = ip.ipv4_mapped
    if ip.is_loopback or ip.is_unspecified:
        return LOCAL
    if any(ip.version == n.version and ip in n for n in bridges):
        return LOCAL
    if ip.is_private or ip.is_link_local or (ip.version == 4 and ip in CGNAT):
        return PRIVATE
    return REFUSE


def resolve(host):
    return sorted({ai[4][0].split("%")[0] for ai in socket.getaddrinfo(host, None)})


def norm_ip(text):
    ip = ipaddress.ip_address(text)
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped:
        ip = ip.ipv4_mapped
    return ip


def parse_deny(entry):
    """HOST, HOST:PORT, [V6], [V6]:PORT or a bare IPv6 address -> (host, port|None)."""
    entry = entry.strip()
    m = re.match(r"^\[([0-9A-Fa-f:.]+)\](?::(\d{1,5}))?$", entry)
    if m:
        return m.group(1), int(m.group(2)) if m.group(2) else None
    if entry.count(":") > 1:  # unbracketed IPv6: no port
        return entry, None
    m = re.match(r"^([A-Za-z0-9.-]+)(?::(\d{1,5}))?$", entry)
    if m:
        return m.group(1), int(m.group(2)) if m.group(2) else None
    raise ValueError(f"bad --deny entry: {entry!r}")


def denied(host, port, ips, deny):
    """port is the effective (int) port of the target."""
    target_ips = {norm_ip(i) for i in ips}
    for entry in deny:
        d_host, d_port = parse_deny(entry)
        if d_port is not None and d_port != port:
            continue
        if d_host.lower().rstrip(".") == host.lower().rstrip("."):
            return True
        try:
            if {norm_ip(i) for i in resolve(d_host)} & target_ips:
                return True
        except socket.gaierror:
            # Unresolvable deny entry: be safe if it names this host at all.
            if d_host.lower() in host.lower():
                return True
    return False


def classify(url, bridges=None, deny=()):
    m = BASE_URL.match(url)
    if not m:
        return REFUSE, f"refuse {url} (not a bare base URL: scheme://host[:port] only)"
    scheme = url.split("://", 1)[0].lower()
    host, port_text = m.group(1).strip("[]"), m.group(2)
    port = int(port_text) if port_text else DEFAULT_PORTS[scheme]
    if not 0 < port < 65536 or (port_text and port_text != str(port)):
        return REFUSE, f"refuse {url} (bad port: no leading zeros, 1-65535)"
    if PROD_NAME.search(host):
        return REFUSE, f"refuse {host} (looks like production)"
    try:
        ips = resolve(host)
    except socket.gaierror:
        return REFUSE, f"refuse {host} (unresolvable)"
    try:
        is_denied = denied(host, port, ips, deny)
    except ValueError as e:
        return REFUSE, f"refuse {host} ({e})"
    if is_denied:
        return REFUSE, f"refuse {host} (on the deny list: production or forbidden)"
    bridges = bridge_networks() if bridges is None else bridges
    worst = max(classify_ip(ipaddress.ip_address(i), bridges) for i in ips)
    name = {LOCAL: "local", PRIVATE: "private", REFUSE: "refuse"}[worst]
    return worst, f"{name} {host} {' '.join(ips)}"


def self_test():
    bridges = [ipaddress.ip_network("172.17.0.0/16")]
    cases = [
        ("http://localhost:3000", LOCAL), ("http://127.0.0.1:8080/", LOCAL),
        ("http://[::1]:5000", LOCAL), ("http://127.1", LOCAL),
        ("http://172.17.0.2:80", LOCAL), ("http://172.18.0.2", PRIVATE),
        ("http://192.168.1.10:8000", PRIVATE), ("http://100.64.0.1", PRIVATE),
        ("http://[::ffff:127.0.0.1]", LOCAL), ("http://8.8.8.8", REFUSE),
        ("http://evil.example?x=@localhost", REFUSE), ("http://evil.example#@localhost", REFUSE),
        ("http://example.com\\@localhost", REFUSE), ("http://user@localhost", REFUSE),
        ("http://localhost/api", REFUSE), ("ftp://localhost", REFUSE),
        ("http://prod-db.local", REFUSE), ("http://nonexistent.invalid", REFUSE),
        ("http://localhost:99999", REFUSE), ("", REFUSE),
    ]
    deny = ["192.168.1.200:18080", "127.0.0.1:8920", "192.168.1.201:80", "fd00::5"]
    cases += [
        ("http://127.0.0.1:08920", REFUSE), ("http://[::ffff:127.0.0.1]:8920", REFUSE),
        ("http://[::ffff:192.168.1.200]:18080", REFUSE), ("http://192.168.1.201", REFUSE),
        ("http://192.168.1.201:80", REFUSE), ("http://[fd00::5]:3000", REFUSE),
        ("https://192.168.1.201", PRIVATE),
        ("http://192.168.1.200:18080", REFUSE), ("http://192.168.1.200:9999", PRIVATE),
        ("http://127.0.0.1:8920", REFUSE), ("http://localhost:8920", REFUSE),
        ("http://127.0.0.1:18765", LOCAL),
    ]
    failed = 0
    for url, want in cases:
        got, msg = classify(url, bridges, deny)
        ok = got == want
        failed += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {url!r:40} -> {msg}")
    print(f"{len(cases) - failed}/{len(cases)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["--self-test"]:
        sys.exit(self_test())
    deny = []
    if "--deny" in args:
        i = args.index("--deny")
        deny, args = args[i + 1:], args[:i]
    if len(args) != 1 or (not deny and "--deny" in sys.argv):
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)
    code, message = classify(args[0], deny=deny)
    print(message)
    sys.exit(code)
