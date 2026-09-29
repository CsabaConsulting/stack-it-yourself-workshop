"""Local tools: plain Python functions that run inside the agent process.

In Step 5 compare their spans with the MCP tools, which run in a different process.
"""

from datetime import datetime
from zoneinfo import ZoneInfo

CITIES = {
    "san jose": "America/Los_Angeles",
    "seattle": "America/Los_Angeles",
    "new york": "America/New_York",
    "london": "Europe/London",
    "paris": "Europe/Paris",
    "tokyo": "Asia/Tokyo",
    "sydney": "Australia/Sydney",
    "utc": "UTC",
}


def current_time(city: str = "San Jose") -> str:
    """Get the current local date and time in a city.

    Args:
        city: One of San Jose, Seattle, New York, London, Paris, Tokyo, Sydney or UTC.
    """
    zone = CITIES.get(city.strip().lower())
    if zone is None:
        return f"Unknown city {city!r}. Known cities: {', '.join(c.title() for c in CITIES)}."
    return datetime.now(ZoneInfo(zone)).strftime(f"%A %d %B %Y, %H:%M in {city.title()}")


LOCAL_TOOLS = [current_time]
