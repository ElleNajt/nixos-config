#!/usr/bin/env python3

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

ANTHROPIC_API_BASE = "https://api.anthropic.com"
DUMMY_TOKENS = [
    "sk-ant-oat01-dummyDummyDummyDummyDummyDummyDummyDummyDummyDummyDummyDummyDummyDummyDummyDummyDummyDQ-DummyAA"
]

VERBOSE_LOGGING = False


class ClaudeAuthProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        if VERBOSE_LOGGING:
            sys.stderr.write(
                "%s - - [%s] %s\n"
                % (self.address_string(), self.log_date_time_string(), format % args)
            )

    def get_real_oauth_token(self):
        try:
            result = subprocess.run(
                ["get-claude-credentials.sh"],
                capture_output=True,
                text=True,
                timeout=10,
            )

            if result.returncode == 0 and result.stdout:
                creds = json.loads(result.stdout.strip())

                if "claudeAiOauth" in creds:
                    oauth_data = creds["claudeAiOauth"]

                    if "accessToken" in oauth_data:
                        return oauth_data["accessToken"]

        except json.JSONDecodeError:
            pass
        except Exception:
            pass

        return None

    def do_POST(self):
        self.handle_request("POST")

    def do_GET(self):
        self.handle_request("GET")

    def do_PUT(self):
        self.handle_request("PUT")

    def do_DELETE(self):
        self.handle_request("DELETE")

    def handle_request(self, method):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else b""
        real_token = self.get_real_oauth_token()

        if not real_token:
            self.send_error(500, "No credentials found")
            return

        url = f"{ANTHROPIC_API_BASE}{self.path}"
        headers = dict(self.headers)

        # Inject real credentials
        token_replaced = False
        for name, value in headers.items():
            if isinstance(value, str):
                for dummy in DUMMY_TOKENS:
                    if dummy in value:
                        value = value.replace(dummy, real_token)
                        token_replaced = True
                headers[name] = value

        if not token_replaced:
            self.send_error(500, "No dummy tokens found to replace")
            return

        # Fix headers
        headers.pop("Content-Length", None)
        headers.pop("Connection", None)
        headers["Host"] = "api.anthropic.com"

        try:
            req = urllib.request.Request(url, data=body, headers=headers, method=method)
            with urllib.request.urlopen(req, timeout=600) as resp:
                self.send_response(resp.code)
                for key, value in resp.headers.items():
                    if key.lower() not in ["connection", "transfer-encoding"]:
                        self.send_header(key, value)
                self.end_headers()
                self.wfile.write(resp.read())

        except urllib.error.HTTPError as e:
            # If we get a 401, try to refresh token with claude -p and retry once
            if e.code == 401:
                try:
                    subprocess.run(
                        ["claude", "-p", "hi claude, may you be happy"],
                        capture_output=True,
                        timeout=30,
                    )

                    # Get fresh token after refresh
                    fresh_token = self.get_real_oauth_token()
                    if fresh_token and fresh_token != real_token:
                        # Update headers with fresh token
                        for name, value in headers.items():
                            if isinstance(value, str):
                                for dummy in DUMMY_TOKENS:
                                    if real_token in value:
                                        value = value.replace(real_token, fresh_token)
                                headers[name] = value

                        # Retry request with fresh token
                        retry_req = urllib.request.Request(
                            url, data=body, headers=headers, method=method
                        )
                        with urllib.request.urlopen(
                            retry_req, timeout=600
                        ) as retry_resp:
                            self.send_response(retry_resp.code)
                            for key, value in retry_resp.headers.items():
                                if key.lower() not in [
                                    "connection",
                                    "transfer-encoding",
                                ]:
                                    self.send_header(key, value)
                            self.end_headers()
                            self.wfile.write(retry_resp.read())
                        return

                except Exception:
                    pass  # Fall through to original error handling

            # Original error handling for non-401 or failed retry
            error_body = e.read()
            error_headers = dict(e.headers) if hasattr(e, "headers") else {}

            self.send_response(e.code)
            for key, value in error_headers.items():
                if key.lower() not in ["connection", "transfer-encoding"]:
                    self.send_header(key, value)
            self.end_headers()
            self.wfile.write(error_body)

        except Exception as e:
            self.send_error(502, f"Bad Gateway: {str(e)}")


def main():
    global VERBOSE_LOGGING
    parser = argparse.ArgumentParser(description="Claude Authentication Proxy")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")
    args = parser.parse_args()

    VERBOSE_LOGGING = args.verbose

    try:
        server = HTTPServer(("0.0.0.0", args.port), ClaudeAuthProxyHandler)
        if VERBOSE_LOGGING:
            print(
                f"Proxy listening on port {args.port} (verbose mode)", file=sys.stderr
            )
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()
    except OSError:
        # Port likely in use - exit with error
        sys.exit(1)


if __name__ == "__main__":
    main()
