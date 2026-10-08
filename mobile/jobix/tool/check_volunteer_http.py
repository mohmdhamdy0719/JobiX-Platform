"""Anonymous development API checks; never prints credentials or response rows."""
import json
import os
import urllib.error
import urllib.request
import uuid


def main():
    base = os.environ["JOBIX_DEV_SUPABASE_URL"].rstrip("/")
    if base != "https://lmouxhbjhtqdtiqijcee.supabase.co":
        raise RuntimeError("DEV_TARGET_GUARD_FAILED")
    headers = {"apikey": os.environ["JOBIX_DEV_SUPABASE_CLIENT_KEY"]}

    def denied(path, payload=None):
        request = urllib.request.Request(
            base + "/rest/v1/" + path,
            headers={**headers, "Content-Type": "application/json"},
            data=None if payload is None else json.dumps(payload).encode(),
        )
        try:
            with urllib.request.urlopen(request, timeout=20):
                raise RuntimeError("ANONYMOUS_ACCESS_UNEXPECTEDLY_ACCEPTED")
        except urllib.error.HTTPError as error:
            response = json.loads(error.read())
            if error.code not in (401, 403) or response.get("code") != "42501":
                raise RuntimeError("EXPECTED_PERMISSION_DENIAL_NOT_OBSERVED") from None

    denied("profile_volunteer_experiences?select=id&limit=1")
    denied("rpc/profile_mutate", {
        "command_key": str(uuid.uuid4()),
        "requested_profile": str(uuid.uuid4()),
        "expected_profile_version": 1,
        "mutation": {
            "type": "upsert_item", "section": "volunteer",
            "value": {
                "id": str(uuid.uuid4()), "organization": "Isolated denied request",
                "role": "Coordinator", "start_month": "2024-01", "is_current": True,
            },
        },
    })
    print("PASS: anonymous HTTP Volunteer reads and mutations denied (42501); no rows exposed or written.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("BLOCKED:", str(error) if type(error) is RuntimeError else type(error).__name__)
        raise SystemExit(1)
