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
BRIDGE_IFACES = ("docker", "br-", "veth", "virbr", "podman", "cni", "lxc")
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
        if len(parts) >= 4 and parts[1].startswith(BRIDGE_IFACES) and parts[2] in ("inet", "inet6"):
            nets.append(ipaddress.ip_interface(parts[3]).network)
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


def denied(host, port, ips, deny):
    for entry in deny:
        m = re.match(r"^\[?([^\]]+?)\]?(?::(\d+))?$", entry.strip())
        if not m:
            continue
        d_host, d_port = m.group(1), m.group(2)
        if d_port and d_port != (port or ""):
            continue
        if d_host.lower() == host.lower():
            return True
        try:
            if set(resolve(d_host)) & set(ips):
                return True
        except socket.gaierror:
            pass
    return False


def classify(url, bridges=None, deny=()):
    m = BASE_URL.match(url)
    if not m:
        return REFUSE, f"refuse {url} (not a bare base URL: scheme://host[:port] only)"
    host, port = m.group(1).strip("[]"), m.group(2)
    if port and not 0 < int(port) < 65536:
        return REFUSE, f"refuse {url} (bad port)"
    if PROD_NAME.search(host):
        return REFUSE, f"refuse {host} (looks like production)"
    try:
        ips = resolve(host)
    except socket.gaierror:
        return REFUSE, f"refuse {host} (unresolvable)"
    if denied(host, port, ips, deny):
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
    deny = ["192.168.1.200:18080", "127.0.0.1:8920"]
    cases += [
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
