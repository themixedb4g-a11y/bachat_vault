import os
import requests
from bs4 import BeautifulSoup
from lxml import html
import re
from supabase import create_client
from datetime import datetime
import pytz
import urllib3

# Suppress SSL Warnings for UBL/MUFAP
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- 1. CONNECTION PATH FOR GITHUB ---
# This reads the keys from the GitHub Secrets you will set up in your repo settings
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ Connection Error: SUPABASE_URL or SUPABASE_KEY is missing from environment.")
    # In a local environment, you can fallback to hardcoded strings for testing:
    # SUPABASE_URL = "YOUR_URL"
    # SUPABASE_KEY = "YOUR_KEY"
else:
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("🚀 Connection Path established successfully!")

headers = {'User-Agent': 'Mozilla/5.0'}

def is_valid_date(date_str, ticker_logic):
    """
    Returns True if the date is valid based on the fund's logic.
    Absolute logic = No weekends, No forward dates.
    """
    dt = datetime.strptime(date_str, '%Y-%m-%d').date()
    today_pk = datetime.now(pytz.timezone('Asia/Karachi')).date()

    # Rule 1: Never allow a future date
    if dt > today_pk:
        return False

    # Rule 2: If logic is 'Absolute', skip Sat (5) and Sun (6)
    if ticker_logic == 'Absolute':
        if dt.weekday() >= 5:
            return False
            
    return True

# --- TASK A: PSX INDICES ---
def sync_psx_indices():
    print("📈 Task A: Syncing PSX Indices...")
    try:
        response = requests.get("https://dps.psx.com.pk", headers=headers, timeout=20)
        tree = html.fromstring(response.content)
        raw_date_text = tree.xpath("//div[@class='market-status']//span/text() | //div[@class='stats_item'][1]/div[@class='stats_value']/text()")
        web_date = None
        for item in raw_date_text:
            match = re.search(r'[A-Z][a-z]{2}\s\d{2},\s\d{4}', item)
            if match:
                web_date = datetime.strptime(match.group(), '%b %d, %Y').strftime('%Y-%m-%d')
                break
        if not web_date: web_date = datetime.now(pytz.timezone('Asia/Karachi')).strftime('%Y-%m-%d')

        for ticker, xp_idx in [('KSE100', 1), ('KMI30', 5)]:
            xpath = f"//*[@id='indicesTabs']/div[2]/div[{xp_idx}]/h1"
            result = tree.xpath(xpath)
            if result:
                val = float(result[0].text_content().strip().replace(',', '').split(' ')[0])
                supabase.table("benchmarks").delete().eq("ticker", ticker).eq("validity_date", web_date).execute()
                supabase.table("benchmarks").insert({"ticker": ticker, "value": val, "validity_date": web_date, "source": "PSX"}).execute()
                print(f"   ✅ {ticker} ({web_date}): {val}")
    except Exception as e: print(f"   ❌ PSX Index Error: {e}")

# --- TASK B: GOLD 24K ---
def sync_gold_rates():
    print("\n💰 Task B: Syncing Gold Rates...")
    try:
        response = requests.get("https://gold.pk/gold-rates-pakistan.php", headers=headers, timeout=15)
        soup = BeautifulSoup(response.text, 'html.parser')
        gold_el = soup.find('p', class_='goldratehome')
        if gold_el:
            val = float(re.search(r'(\d+\.\d+|\d+)', gold_el.text.replace('Rs.', '').replace(',', '')).group(1))
            if val > 1000000: val = float(str(int(val))[:6])
            today_pk = datetime.now(pytz.timezone('Asia/Karachi')).strftime('%Y-%m-%d')
            supabase.table("benchmarks").delete().eq("ticker", "GOLD_24K").eq("validity_date", today_pk).execute()
            supabase.table("benchmarks").insert({"ticker": "GOLD_24K", "value": val, "validity_date": today_pk, "source": "Gold.pk"}).execute()
            print(f"   ✅ Gold 24K: {val}")
    except Exception as e: print(f"   ❌ Gold Error: {e}")

# --- TASK C: PSX ETFs ---
def sync_psx_etfs():
    print("\n📊 Task C: Syncing PSX ETFs...")
    etfs = ["JSGBETF", "JSMFETF", "MIIETF", "MZNPETF", "ACIETF", "NBPGETF", "NITGETF", "UBLPETF", "HBLTETF"]
    for ticker in etfs:
        if ticker == "HBLTETF":
            print(f"   ℹ️ Skipping {ticker} for MUFAP update.")
            continue
        try:
            soup = BeautifulSoup(requests.get(f"https://dps.psx.com.pk/etf/{ticker}", headers=headers).text, 'html.parser')
            price = float(re.findall(r'\d+\.\d+', soup.find('div', class_='quote__price').text)[0])
            date_match = re.search(r'[A-Z][a-z]{2}\s\d{2},\s\d{4}', soup.find('div', class_='quote__date').text).group()
            web_date = datetime.strptime(date_match, '%b %d, %Y').strftime('%Y-%m-%d')
            supabase.table("daily_nav").delete().eq("ticker", ticker).eq("validity_date", web_date).execute()
            supabase.table("daily_nav").insert({"ticker": ticker, "nav": price, "validity_date": web_date, "source": "PSX"}).execute()
            print(f"   ✅ ETF {ticker} ({web_date}): {price}")
        except: continue

# --- TASK D: MUFAP SYNC ---
def sync_mufap_master():
    print("\n🏛️ Task D: Syncing MUFAP (Tab 3, 4, 5)...")
    
    # 1. PRE-FETCH DATA: Get Tickers and their Return Logic from Master Table
    res = supabase.table("master_funds").select("ticker, fund_id_mufap, return_logic").execute()
    
    # Map for ID -> Ticker
    id_map = {str(int(float(row['fund_id_mufap']))): row['ticker'] for row in res.data if row['fund_id_mufap']}
    # Map for Ticker -> Logic (New!)
    logic_map = {row['ticker']: row.get('return_logic', 'Absolute') for row in res.data}
    
    def get_mufap_rows(tab):
        url = f"https://www.mufap.com.pk/Industry/IndustryStatDaily?tab={tab}"
        return BeautifulSoup(requests.get(url, headers=headers, verify=False).text, 'html.parser').find_all('tr')

    # Tab 3: NAV (Apply Date Filter Here)
    for row in get_mufap_rows(3):
        cells = row.find_all('td')
        if len(cells) < 9: continue
        link = cells[2].find('a', href=True)
        if link:
            m_id = re.search(r'FundID=(\d+)', link['href']).group(1)
            ticker = id_map.get(m_id)
            if ticker:
                try:
                    dt_str = datetime.strptime(cells[8].text.strip().title(), '%b %d, %Y').strftime('%Y-%m-%d')
                    ticker_logic = logic_map.get(ticker, 'Absolute')
                    
                    # --- THE FILTER ---
                    if not is_valid_date(dt_str, ticker_logic):
                        continue # Skip weekends/future dates for Absolute funds
                    
                    val = float(cells[6].text.replace(',', ''))
                    supabase.table("daily_nav").upsert({"ticker": ticker, "nav": val, "validity_date": dt_str, "source": "MUFAP"}, on_conflict="ticker,validity_date").execute()
                except: continue

# --- TASK E: UBL AMC REFINED ---
def sync_ubl_amc_refined():
    print("\n🏦 Task E: Syncing UBL AMC (The Fail-Safe)...")
    url = "https://www.ublfunds.com.pk/resources-tools/fund-performance-tools/latest-fund-prices/"
    
    # 1. PRE-FETCH DATA
    res = supabase.table("master_funds").select("ticker, amc_website_name, return_logic").not_.is_("amc_website_name", "null").execute()
    ubl_map = {r['amc_website_name'].strip(): r['ticker'] for r in res.data}
    logic_map = {r['ticker']: r.get('return_logic', 'Absolute') for r in res.data}

    try:
        soup = BeautifulSoup(requests.get(url, headers=headers, verify=False).text, 'html.parser')
        
        # Part 1: Main Tables (Apply Date Filter Here)
        for table_id in ['conventional-mutual-fund-schemes', 'islamic-mutual-fund-schemes']:
            table = soup.find('table', id=table_id)
            if not table: continue
            for row in table.find_all('tr'):
                cells = row.find_all('td')
                if len(cells) >= 4:
                    ticker = ubl_map.get(cells[0].get_text(strip=True))
                    if ticker:
                        dt_str = datetime.strptime(cells[1].text.strip(), '%d-%b-%Y').strftime('%Y-%m-%d')
                        ticker_logic = logic_map.get(ticker, 'Absolute')
                        
                        # --- THE FILTER ---
                        if not is_valid_date(dt_str, ticker_logic):
                            continue # Skip
                        
                        nav = float(cells[3].text.replace(',', ''))
                        supabase.table("daily_nav").upsert({"ticker": ticker, "nav": nav, "validity_date": dt_str, "source": "AMC_Website"}, on_conflict="ticker,validity_date").execute()
    except Exception as e: print(f"   ❌ UBL Error: {e}")

# --- MASTER EXECUTION ---
def run_everything():
    start_time = datetime.now()
    sync_psx_indices()
    sync_gold_rates()
    sync_psx_etfs()
    sync_mufap_master()
    sync_ubl_amc_refined()
    print(f"\n🎉 ALL SYSTEMS UPDATED. Total Time: {datetime.now() - start_time}")

if __name__ == "__main__":
    run_everything()