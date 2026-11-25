#!/usr/bin/env python3
"""Render the date and a Monday-first calendar through Waybar's standard tooltip."""

import calendar
from datetime import date
from html import escape
import json


def calendar_status(today):
    weeks = calendar.Calendar(firstweekday=calendar.MONDAY).monthdatescalendar(
        today.year, today.month
    )
    lines = [
        escape(f"{calendar.month_name[today.month]} {today.year}".center(23)),
        "Mo Tu We Th Fr Sa Su",
    ]
    for week in weeks:
        cells = []
        for day in week:
            cell = f"{day.day:2}" if day.month == today.month else "  "
            if day == today:
                cell = f"<span color='#ff6a00'><b><u>{cell}</u></b></span>"
            cells.append(cell)
        lines.append(" ".join(cells) + f"  {week[0].isocalendar().week:02}")

    heading = escape(today.strftime("%A, %d %B %Y"))
    return {
        "text": "󰃭 " + today.strftime("%a %d.%m"),
        "tooltip": f"<big>{heading}</big>\n<tt>" + "\n".join(lines) + "</tt>",
    }


if __name__ == "__main__":
    print(json.dumps(calendar_status(date.today()), ensure_ascii=False))
