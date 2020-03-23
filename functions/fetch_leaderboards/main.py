import base64
import logging
import math
from datetime import datetime

import requests
from google.cloud import datastore

logger = logging.getLogger(__name__)
client = datastore.Client()
session = requests.Session()
chunk_size = 480


def chunks(l, n):
    """Yield successive n-sized chunks from l."""
    for i in range(0, len(l), n):
        yield l[i : i + n]


def fetch_leaderboard(region):
    logger.info("Fetching leaderboard data for region=%(region)s", {"region": region})
    response = session.get(
        "https://www.dota2.com/webapi/ILeaderboard/GetDivisionLeaderboard/v0001",
        params={"division": region, "leaderboard": "0"},
    )
    response.raise_for_status()
    return response.json()


def create_entities(region, records, parent_key, date):
    partial_key = client.key("Record", parent=parent_key)
    for record in records:
        entity = datastore.Entity(key=partial_key)
        entity.update({"date": date, **record})
        yield entity


def save_snapshot(region, response):
    date = datetime.fromtimestamp(response["time_posted"]).isoformat()
    snapshot_key = client.key("Region", region, "Snapshot", date)
    leaderboard = response["leaderboard"]
    logger.info(
        "Saving snapshot data for region=%(region)s,date=%(date)s",
        {"region": region, "date": date},
    )
    with client.transaction():
        if client.get(snapshot_key):
            logger.warning(
                "Snapshot for region=%(region)s,date=%(date)s already exists",
                {"region": region, "date": date},
            )
            return
        snapshot = datastore.Entity(key=snapshot_key)
        snapshot["date"] = date
        client.put(snapshot)
    try:
        for i, chunk in enumerate(chunks(leaderboard, chunk_size), start=1):
            logger.debug(
                "Saving chunk %(num)d/%(total)d",
                {"num": i, "total": math.ceil(len(leaderboard) / chunk_size)},
            )
            with client.transaction():
                client.put_multi(create_entities(region, chunk, snapshot_key, date))
    except Exception:
        logger.error("Exception during save, rolling back", exc_info=True)
        delete_snapshot(snapshot_key)
        raise
    logger.info(
        "Saved snapshot data for region=%(region)s,date=%(date)s",
        {"region": region, "date": date},
    )


def delete_snapshot(snapshot_key):
    with client.transaction():
        client.delete(snapshot_key)
        query = client.query(kind="Record", ancestor=snapshot_key)
        query.keys_only()
        client.delete_multi(query.fetch())


def entrypoint(data, context):
    region = base64.b64decode(data["data"]).decode("utf-8")
    response = fetch_leaderboard(region)
    save_snapshot(region, response)
