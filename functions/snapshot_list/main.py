import logging

from flask import jsonify
from google.cloud import datastore

logger = logging.getLogger(__name__)
client = datastore.Client()


def snapshots_for_region(region, limit=30, cursor=None):
    query = client.query(
        kind="Snapshot",
        ancestor=client.key("Region", region),
        order=["-date"],
    )
    query.keys_only()
    query_iterator = query.fetch(limit=limit, start_cursor=cursor)
    page = next(query_iterator.pages)
    next_cursor = (
        query_iterator.next_page_token.decode("utf-8")
        if query_iterator.next_page_token
        else None
    )
    return page, next_cursor


def entrypoint(request):
    if request.method == "OPTIONS":
        headers = {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Max-Age": "3600",
        }
        return ("", 204, headers)

    region = request.args.get("region")
    cursor = request.args.get("cursor")

    if not region:
        response = jsonify({"region": [{"code": "required"}]})
        response.status_code = 422
        return response

    snapshots, next_cursor = snapshots_for_region(region, cursor=cursor)
    response = jsonify(
        {
            "next_cursor": next_cursor,
            "items": [
                {
                    "date": snapshot.key.name,
                }
                for snapshot in snapshots
            ],
        }
    )
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response
