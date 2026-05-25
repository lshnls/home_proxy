#!/usr/bin/env python3
"""Unbound Prometheus exporter.

Подключается к удалённому unbound через unbound-control (TLS),
парсит вывод stats_noreset и отдаёт метрики на /metrics.
"""
import os
import socket
import subprocess
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from prometheus_client import Gauge, Counter, generate_latest, CollectorRegistry

UNBOUND_HOST = os.environ.get("UNBOUND_HOST", "unbound")
UNBOUND_PORT = os.environ.get("UNBOUND_PORT", "8953")
UNBOUND_CONF = os.environ.get("UNBOUND_CONF", "/etc/unbound/unbound.conf")
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "9167"))

# Регистр для метрик unbound (без default-метрик python)
registry = CollectorRegistry()

# Основные счётчики
m_queries = Gauge('unbound_queries_total', 'Total number of queries received', ['thread'], registry=registry)
m_cachehits = Gauge('unbound_cache_hits_total', 'Cache hits', ['thread'], registry=registry)
m_cachemiss = Gauge('unbound_cache_misses_total', 'Cache misses', ['thread'], registry=registry)
m_prefetch = Gauge('unbound_prefetch_total', 'Prefetched DNS records', ['thread'], registry=registry)
m_recursivereplies = Gauge('unbound_recursive_replies_total', 'Recursive replies sent', ['thread'], registry=registry)
m_expired = Gauge('unbound_expired_total', 'Replies served from expired cache', ['thread'], registry=registry)
m_dnscrypt_crypted = Gauge('unbound_dnscrypt_crypted_total', 'DNSCrypt crypted queries', ['thread'], registry=registry)

m_tcp = Gauge('unbound_queries_tcp_total', 'Number of TCP queries', ['thread'], registry=registry)
m_tcpout = Gauge('unbound_queries_tcpout_total', 'Number of outgoing TCP queries', ['thread'], registry=registry)
m_udpout = Gauge('unbound_queries_udpout_total', 'Number of outgoing UDP queries', ['thread'], registry=registry)
m_tls = Gauge('unbound_queries_tls_total', 'Number of TLS queries', ['thread'], registry=registry)
m_https = Gauge('unbound_queries_https_total', 'Number of HTTPS queries', ['thread'], registry=registry)
m_ipv6 = Gauge('unbound_queries_ipv6_total', 'Number of IPv6 queries', ['thread'], registry=registry)

m_reqlist_avg = Gauge('unbound_request_list_avg', 'Average request list size', ['thread'], registry=registry)
m_reqlist_max = Gauge('unbound_request_list_max', 'Max request list size', ['thread'], registry=registry)
m_reqlist_current = Gauge('unbound_request_list_current', 'Current request list size', ['thread'], registry=registry)
m_reqlist_exceeded = Gauge('unbound_request_list_exceeded_total', 'Times request list size exceeded limit', ['thread'], registry=registry)
m_reqlist_overwritten = Gauge('unbound_request_list_overwritten_total', 'Times request list overwritten', ['thread'], registry=registry)

m_recursion_avg = Gauge('unbound_recursion_time_avg', 'Average recursion time seconds', ['thread'], registry=registry)
m_recursion_median = Gauge('unbound_recursion_time_median', 'Median recursion time seconds', ['thread'], registry=registry)

# Total stats
m_total_queries = Gauge('unbound_total_queries', 'Total queries (all threads)', registry=registry)
m_total_cachehits = Gauge('unbound_total_cache_hits', 'Total cache hits (all threads)', registry=registry)
m_total_cachemiss = Gauge('unbound_total_cache_misses', 'Total cache misses (all threads)', registry=registry)
m_total_recursivereplies = Gauge('unbound_total_recursive_replies', 'Total recursive replies', registry=registry)

# Cache sizes
m_msg_cache_count = Gauge('unbound_msg_cache_count', 'Messages in msg cache', registry=registry)
m_rrset_cache_count = Gauge('unbound_rrset_cache_count', 'RRsets in rrset cache', registry=registry)
m_infra_cache_count = Gauge('unbound_infra_cache_count', 'Items in infrastructure cache', registry=registry)
m_key_cache_count = Gauge('unbound_key_cache_count', 'Items in DNSSEC key cache', registry=registry)
m_dnscrypt_shared_secret_cache_count = Gauge('unbound_dnscrypt_shared_secret_cache_count', 'DNSCrypt shared secret cache count', registry=registry)
m_dnscrypt_nonce_cache_count = Gauge('unbound_dnscrypt_nonce_cache_count', 'DNSCrypt nonce cache count', registry=registry)

# Memory
m_mem_cache_rrset = Gauge('unbound_memory_caches_rrset_bytes', 'Memory used by rrset cache', registry=registry)
m_mem_cache_message = Gauge('unbound_memory_caches_message_bytes', 'Memory used by message cache', registry=registry)
m_mem_cache_dnscrypt_shared_secret = Gauge('unbound_memory_caches_dnscrypt_shared_secret_bytes', 'Memory used by dnscrypt shared secret cache', registry=registry)
m_mem_cache_dnscrypt_nonce = Gauge('unbound_memory_caches_dnscrypt_nonce_bytes', 'Memory used by dnscrypt nonce cache', registry=registry)
m_mem_mod_iterator = Gauge('unbound_memory_modules_iterator_bytes', 'Memory used by iterator module', registry=registry)
m_mem_mod_validator = Gauge('unbound_memory_modules_validator_bytes', 'Memory used by validator module', registry=registry)
m_mem_mod_respip = Gauge('unbound_memory_modules_respip_bytes', 'Memory used by respip module', registry=registry)
m_mem_streamwait = Gauge('unbound_memory_streamwait_bytes', 'Memory used by tcp stream waits', registry=registry)

# Uptime
m_time_up = Gauge('unbound_time_up_seconds', 'Uptime of unbound in seconds', registry=registry)

# Answer rcodes
m_answer_rcode = Gauge('unbound_answer_rcodes_total', 'Answers by rcode', ['rcode'], registry=registry)
# Query types
m_query_type = Gauge('unbound_query_types_total', 'Queries by type', ['type'], registry=registry)
# Query classes
m_query_class = Gauge('unbound_query_classes_total', 'Queries by class', ['class'], registry=registry)
# Query opcodes
m_query_opcode = Gauge('unbound_query_opcodes_total', 'Queries by opcode', ['opcode'], registry=registry)
# Query flags
m_query_flags = Gauge('unbound_query_flags_total', 'Queries by flag', ['flag'], registry=registry)

# Scrape duration
m_scrape_duration = Gauge('unbound_scrape_duration_seconds', 'Last scrape duration', registry=registry)
m_scrape_success = Gauge('unbound_scrape_success', '1 if last scrape was successful', registry=registry)


def fetch_stats():
    """Запускает unbound-control stats_noreset и возвращает dict ключ=значение."""
    # unbound-control требует IP-адрес в опции -s, поэтому резолвим имя
    try:
        ip = socket.gethostbyname(UNBOUND_HOST)
    except socket.gaierror as e:
        raise RuntimeError(f"DNS resolve failed for {UNBOUND_HOST}: {e}")
    cmd = [
        "unbound-control",
        "-c", UNBOUND_CONF,
        "-s", f"{ip}@{UNBOUND_PORT}",
        "stats_noreset",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    if result.returncode != 0:
        raise RuntimeError(f"unbound-control failed: {result.stderr.strip()}")
    stats = {}
    for line in result.stdout.strip().split('\n'):
        if '=' in line:
            k, v = line.split('=', 1)
            stats[k.strip()] = v.strip()
    return stats


def _to_float(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def update_metrics():
    start = time.time()
    try:
        stats = fetch_stats()
        m_scrape_success.set(1)
    except Exception as e:
        print(f"[exporter] scrape error: {e}", flush=True)
        m_scrape_success.set(0)
        m_scrape_duration.set(time.time() - start)
        return

    # Per-thread метрики
    threads = set()
    for key in stats:
        if key.startswith('thread') and '.' in key:
            t = key.split('.', 1)[0]
            if t != 'thread':
                threads.add(t)

    for t in threads:
        m_queries.labels(thread=t).set(_to_float(stats.get(f'{t}.num.queries', 0)))
        m_cachehits.labels(thread=t).set(_to_float(stats.get(f'{t}.num.cachehits', 0)))
        m_cachemiss.labels(thread=t).set(_to_float(stats.get(f'{t}.num.cachemiss', 0)))
        m_prefetch.labels(thread=t).set(_to_float(stats.get(f'{t}.num.prefetch', 0)))
        m_recursivereplies.labels(thread=t).set(_to_float(stats.get(f'{t}.num.recursivereplies', 0)))
        m_expired.labels(thread=t).set(_to_float(stats.get(f'{t}.num.expired', 0)))
        m_dnscrypt_crypted.labels(thread=t).set(_to_float(stats.get(f'{t}.num.dnscrypt.crypted', 0)))
        m_tcp.labels(thread=t).set(_to_float(stats.get(f'{t}.num.tcp', 0)))
        m_tcpout.labels(thread=t).set(_to_float(stats.get(f'{t}.num.tcpout', 0)))
        m_udpout.labels(thread=t).set(_to_float(stats.get(f'{t}.num.udpout', 0)))
        m_tls.labels(thread=t).set(_to_float(stats.get(f'{t}.num.tls', 0)))
        m_https.labels(thread=t).set(_to_float(stats.get(f'{t}.num.https', 0)))
        m_ipv6.labels(thread=t).set(_to_float(stats.get(f'{t}.num.query.ipv6', 0)))
        m_reqlist_avg.labels(thread=t).set(_to_float(stats.get(f'{t}.requestlist.avg', 0)))
        m_reqlist_max.labels(thread=t).set(_to_float(stats.get(f'{t}.requestlist.max', 0)))
        m_reqlist_current.labels(thread=t).set(_to_float(stats.get(f'{t}.requestlist.current.all', 0)))
        m_reqlist_exceeded.labels(thread=t).set(_to_float(stats.get(f'{t}.requestlist.exceeded', 0)))
        m_reqlist_overwritten.labels(thread=t).set(_to_float(stats.get(f'{t}.requestlist.overwritten', 0)))
        m_recursion_avg.labels(thread=t).set(_to_float(stats.get(f'{t}.recursion.time.avg', 0)))
        m_recursion_median.labels(thread=t).set(_to_float(stats.get(f'{t}.recursion.time.median', 0)))

    # Totals
    m_total_queries.set(_to_float(stats.get('total.num.queries', 0)))
    m_total_cachehits.set(_to_float(stats.get('total.num.cachehits', 0)))
    m_total_cachemiss.set(_to_float(stats.get('total.num.cachemiss', 0)))
    m_total_recursivereplies.set(_to_float(stats.get('total.num.recursivereplies', 0)))

    # Caches
    m_msg_cache_count.set(_to_float(stats.get('msg.cache.count', 0)))
    m_rrset_cache_count.set(_to_float(stats.get('rrset.cache.count', 0)))
    m_infra_cache_count.set(_to_float(stats.get('infra.cache.count', 0)))
    m_key_cache_count.set(_to_float(stats.get('key.cache.count', 0)))
    m_dnscrypt_shared_secret_cache_count.set(_to_float(stats.get('dnscrypt_shared_secret.cache.count', 0)))
    m_dnscrypt_nonce_cache_count.set(_to_float(stats.get('dnscrypt_nonce.cache.count', 0)))

    # Memory
    m_mem_cache_rrset.set(_to_float(stats.get('mem.cache.rrset', 0)))
    m_mem_cache_message.set(_to_float(stats.get('mem.cache.message', 0)))
    m_mem_cache_dnscrypt_shared_secret.set(_to_float(stats.get('mem.cache.dnscrypt_shared_secret', 0)))
    m_mem_cache_dnscrypt_nonce.set(_to_float(stats.get('mem.cache.dnscrypt_nonce', 0)))
    m_mem_mod_iterator.set(_to_float(stats.get('mem.mod.iterator', 0)))
    m_mem_mod_validator.set(_to_float(stats.get('mem.mod.validator', 0)))
    m_mem_mod_respip.set(_to_float(stats.get('mem.mod.respip', 0)))
    m_mem_streamwait.set(_to_float(stats.get('mem.streamwait', 0)))

    # Uptime
    m_time_up.set(_to_float(stats.get('time.up', 0)))

    # Сбросим динамические лейблы (rcode/type/class) перед обновлением
    m_answer_rcode.clear()
    m_query_type.clear()
    m_query_class.clear()
    m_query_opcode.clear()
    m_query_flags.clear()

    for k, v in stats.items():
        if k.startswith('num.answer.rcode.'):
            m_answer_rcode.labels(rcode=k.split('.')[-1]).set(_to_float(v))
        elif k.startswith('num.query.type.'):
            m_query_type.labels(type=k.split('.')[-1]).set(_to_float(v))
        elif k.startswith('num.query.class.'):
            m_query_class.labels(**{'class': k.split('.')[-1]}).set(_to_float(v))
        elif k.startswith('num.query.opcode.'):
            m_query_opcode.labels(opcode=k.split('.')[-1]).set(_to_float(v))
        elif k.startswith('num.query.flags.'):
            m_query_flags.labels(flag=k.split('.')[-1]).set(_to_float(v))

    m_scrape_duration.set(time.time() - start)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            update_metrics()
            output = generate_latest(registry)
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.send_header("Content-Length", str(len(output)))
            self.end_headers()
            self.wfile.write(output)
        elif self.path == "/" or self.path == "/health":
            body = b"unbound-exporter ok\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Тихие логи доступа
        return


if __name__ == "__main__":
    print(f"[exporter] starting on :{LISTEN_PORT}, target={UNBOUND_HOST}:{UNBOUND_PORT}", flush=True)
    HTTPServer(("0.0.0.0", LISTEN_PORT), Handler).serve_forever()
