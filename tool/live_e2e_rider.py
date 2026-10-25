#!/usr/bin/env python3
"""The rider side of test/live/live_server_e2e_test.dart, as plain HTTP.

Books three rides on a running movera-server while the driver test drives
them, in step through files in STATE_DIR (the driver test writes `online`,
`accepted-<n>` and `done-<n>`):

  1. booked; the driver takes it from pickup to drop-off;
  2. booked; the rider cancels once the driver accepted;
  3. booked; the driver cancels before pickup; the rider then cancels it.

Run (server on 8080, zone Z001 with published pricing and dispatch):
  mkdir -p /tmp/e2e && python3 tool/live_e2e_rider.py http://127.0.0.1:8080 /tmp/e2e &
  MOVERA_E2E_BASE=http://127.0.0.1:8080 MOVERA_E2E_STATE=/tmp/e2e \\
    flutter test test/live/live_server_e2e_test.dart
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = sys.argv[1].rstrip("/") + "/api/v1"
STATE = sys.argv[2]
RIDER = os.environ.get("MOVERA_E2E_RIDER", "+46701740608")
# Norrmalm (zone Z001).
PICKUP = {"lat": 59.3320, "lng": 18.0660, "address": "Vasagatan 1, Stockholm"}
DROPOFF = {"lat": 59.3400, "lng": 18.0800, "address": "Kungsgatan 40, Stockholm"}


def call(method, path, body=None, token=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    req.add_header("X-Api-Version", "0.5")
    if method in ("POST", "PUT", "PATCH"):
        req.add_header("Idempotency-Key", uuid.uuid4().hex)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        return e.code, (json.loads(raw) if raw else None)


def wait(name, timeout=300):
    end = time.time() + timeout
    while not os.path.exists(os.path.join(STATE, name)):
        if time.time() > end:
            raise SystemExit(f"timed out waiting for {name}")
        time.sleep(0.3)
    return open(os.path.join(STATE, name)).read()


def sign_in():
    s, b = call("POST", "/auth/otp/request", {"phone": RIDER, "app": "rider"})
    assert s == 200, (s, b)
    s, b = call("POST", "/auth/otp/verify", {"phone": RIDER, "sessionId": b["sessionId"], "code": "1234"})
    assert s == 200, (s, b)
    return b["accessToken"]


def book(token, n):
    s, q = call("POST", "/quotes", {"pickup": PICKUP, "dropoff": DROPOFF, "stops": [], "categoryIds": ["economy"], "paymentMethod": "cash"}, token)
    assert s in (200, 201), q
    quote = q["quotes"][0]
    s, t = call("POST", "/trips", {"quoteId": quote["quoteId"], "categoryId": quote["categoryId"], "pickup": PICKUP, "dropoff": DROPOFF, "stops": [], "kind": "live", "paymentMethod": "cash"}, token)
    assert s == 201, t
    print(f"ride {n}: {t['tripId']} {t['status']}", flush=True)
    return t["tripId"]


def cancel(token, trip_id):
    s, t = call("GET", f"/trips/{trip_id}", token=token)
    s, c = call("POST", f"/trips/{trip_id}/cancel", {"expectedVersion": t["version"], "reasonCode": "plans_changed"}, token)
    assert s == 200, c
    return c["status"]


def main():
    token = sign_in()
    wait("online")
    t1 = book(token, 1)
    wait("done-1")
    s, t = call("GET", f"/trips/{t1}", token=token)
    print(f"ride 1 as the rider sees it: {t['status']}, fare {t.get('fare')}, payment {t.get('paymentStatus')}", flush=True)
    assert t["status"] == "completed", t
    t2 = book(token, 2)
    assert wait("accepted-2") == t2
    print(f"ride 2 rider cancel: {cancel(token, t2)}", flush=True)
    wait("done-2")
    t3 = book(token, 3)
    wait("done-3")
    s, t = call("GET", f"/trips/{t3}", token=token)
    print(f"ride 3 after the driver's cancel: {t['status']}", flush=True)
    print(f"ride 3 rider cancel: {cancel(token, t3)}", flush=True)
    print("RIDER OK", flush=True)


if __name__ == "__main__":
    main()
