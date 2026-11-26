# Runs inside tools/gen_openapi.py in name order with its globals (rule 25 split). v0.18.169 (owner 2026-11-26 "Route in
# driver !!": the driver's offer card draws the real Google route): Offer.routePolyline, the trip's stored Google polyline,
# only on an open offer (contract.json#offerRouteLine).
_ORL = C["offerRouteLine"]
_V169 = "v0.18.169 (contract.json#offerRouteLine): "
_O169 = S["Offer"]["properties"]
assert "routePolyline" not in _O169, "Offer.routePolyline exists before v0.18.169"
_O169["routePolyline"] = s(_V169 + _ORL["offer"] + " " + _ORL["calls"] + " " + _ORL["driver"], minLength=1)
