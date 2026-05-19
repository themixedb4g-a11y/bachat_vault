import requests
from bs4 import BeautifulSoup
import urllib3

# Suppress SSL warnings for the test
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# The exact AUM URL for April 2026
url = "https://www.mufap.com.pk/Industry/IndustryStatMonthly?tab=1&datefrom=2026-04"
print(f"🔍 Fetching URL: {url}\n")

# Connect as a normal browser
headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
response = requests.get(url, headers=headers, verify=False, timeout=15)
soup = BeautifulSoup(response.text, "lxml")

rows = soup.find_all("tr")
print(f"Total rows found on page: {len(rows)}\n")

# Print the exact column index mapping for the first 3 actual data rows
data_row_count = 0
for i, row in enumerate(rows):
    cells = row.find_all("td")

    # Only look at rows that actually have data cells
    if len(cells) > 0:
        print(f"--- Data Row {data_row_count + 1} (Found {len(cells)} columns) ---")
        for col_index, cell in enumerate(cells):
            print(f"  Index {col_index}: {cell.get_text(strip=True)}")
        print("-" * 40)

        data_row_count += 1

        # Stop after showing 3 funds
        if data_row_count >= 3:
            break
