#!/usr/bin/env python3
"""Wake up the Streamlit app at https://ordered.streamlit.app/.

Streamlit Community Cloud puts apps to sleep after a period of inactivity
and shows a "Yes, get this app back up!" button in their place. This script
opens the app and clicks that button if it's there; if the app is already
awake, it does nothing.

Requires: pip install playwright && playwright install chromium

Intended to run daily on weekday mornings via cron, e.g.:
    0 6 * * 1-5 /usr/bin/python3 /path/to/wake_ordered_app.py >> /var/log/wake_ordered_app.log 2>&1
"""

import sys

from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
from playwright.sync_api import sync_playwright

APP_URL = "https://ordered.streamlit.app/"
BUTTON_NAME = "get this app back up"
NAV_TIMEOUT_MS = 30_000
BUTTON_TIMEOUT_MS = 15_000


def find_wake_button(page):
    """Try a couple of locator strategies, in case the button isn't exposed
    with an accessible role in every Streamlit build."""
    candidates = [
        page.get_by_role("button", name=BUTTON_NAME),
        page.get_by_text(BUTTON_NAME, exact=False),
    ]
    for locator in candidates:
        try:
            locator.first.wait_for(state="visible", timeout=BUTTON_TIMEOUT_MS)
            return locator.first
        except PlaywrightTimeoutError:
            continue
    return None


def wake_app() -> None:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        try:
            page.goto(APP_URL, timeout=NAV_TIMEOUT_MS, wait_until="networkidle")
            button = find_wake_button(page)
            if button is None:
                print("No wake-up button found -- app is likely already running.")
                return
            button.click()
            print("App was asleep -- clicked 'Yes, get this app back up!'")
        finally:
            browser.close()


if __name__ == "__main__":
    wake_app()
    sys.exit(0)
