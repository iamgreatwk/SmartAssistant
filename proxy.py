#!/usr/bin/env python3
"""AI 调试代理 - 转发请求绕过 CORS"""
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import json, urllib.request, urllib.error, sys

PORT = 8765

def _get_target(handler):
    """从查询参数 ?target=URL 获取目标地址"""
    qs = parse_qs(urlparse(handler.path).query)
    return qs.get('target', [''])[0] or handler.headers.get('Proxy-Target', '')

class Proxy(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type,Authorization,Proxy-Target')
        self.end_headers()

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else b'{}'
        api_key = self.headers.get('Authorization', '')
        target_url = _get_target(self)

        if not target_url:
            self._error(400, '缺少 target 参数 (?target=URL)')
            return

        req = urllib.request.Request(target_url, data=body,
            headers={'Content-Type': 'application/json', 'Authorization': api_key},
            method='POST')
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
                self.send_response(resp.status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(e.read())

    def do_GET(self):
        api_key = self.headers.get('Authorization', '')
        target_url = _get_target(self)

        if not target_url:
            self._error(400, '缺少 target 参数 (?target=URL)')
            return

        req = urllib.request.Request(target_url,
            headers={'Authorization': api_key}, method='GET')
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = resp.read()
                self.send_response(resp.status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(e.read())

    def _error(self, code, msg):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps({'error': msg}).encode())

    def log_message(self, fmt, *args):
        print(f'[{self.log_date_time_string()}] {args[0]}')

if __name__ == '__main__':
    print(f'代理启动: http://localhost:{PORT}')
    print(f'在 HTML 中勾选 "代理" 即可')
    HTTPServer(('0.0.0.0', PORT), Proxy).serve_forever()
