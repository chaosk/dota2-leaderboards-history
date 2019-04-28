import logging

from flask import jsonify
from google.cloud import datastore

logger = logging.getLogger(__name__)
client = datastore.Client()


def records_for_snapshot(region, date, limit=100, cursor=None):
    query = client.query(
        kind="Record",
        ancestor=client.key("Region", region, "Snapshot", date),
        order=["rank"],
    )
    query.projection = ["rank", "name"]
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

    date = request.args.get("date")
    region = request.args.get("region")
    cursor = request.args.get("cursor")
    try:
        limit = int(request.args.get("limit"))
    except (TypeError, ValueError):
        limit = 100

    if not region:
        response = jsonify({"region": [{"code": "required"}]})
        response.status_code = 422
        return response

    if not date:
        response = jsonify({"date": [{"code": "required"}]})
        response.status_code = 422
        return response

    records, next_cursor = records_for_snapshot(region, date, limit=limit, cursor=cursor)
    response = jsonify(
        {
            "next_cursor": next_cursor,
            "items": [
                {
                    "rank": record["rank"],
                    "name": record["name"],
                }
                for record in records
            ],
        }
    )
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response
