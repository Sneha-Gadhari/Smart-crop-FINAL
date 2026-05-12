"""
Smart Crop DSS — FastAPI Backend  v5.0
Maharashtra-focused.
"""

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional
from contextlib import asynccontextmanager
import sqlite3, os, httpx, asyncio, math
from dotenv import load_dotenv
from datetime import datetime, timedelta

load_dotenv()

from services.weather_service   import WeatherService
from services.soil_classifier   import SoilClassifier
from services.crop_recommender  import CropRecommender
from services.disease_detector  import DiseaseDetector
from services.risk_engine       import RiskEngine, CROP_PROFILES, INPUT_COSTS, DEFAULT_INPUT_COST, MARKET_DATA
from services.pest_engine       import PestEngine

# ── Globals ───────────────────────────────────────────────────────────
weather_svc : WeatherService  = None
soil_clf    : SoilClassifier  = None
crop_rec    : CropRecommender = None
disease_det : DiseaseDetector = None
risk_eng    : RiskEngine      = None
pest_eng    : PestEngine      = None

DB_PATH          = "sightings.db"
DATA_GOV_API_KEY = os.getenv("DATA_GOV_API_KEY", "")

# ── In-process cache ─────────────────────────────────────────────────
_price_cache: dict = {}
_msp_cache  : dict = {}
_yield_cache: dict = {}
_CACHE_TTL = 86400  # 24 hours — preserves API rate limit

# ── Harvest days ──────────────────────────────────────────────────────
HARVEST_DAYS: dict[str, int] = {
    "rice": 120,       "wheat": 120,        "cotton": 180,
    "soybean": 100,    "soyabean": 100,     "maize": 100,
    "sugarcane": 365,  "groundnut": 130,    "banana": 300,
    "mango": 120,      "coconut": 365,      "pomegranate": 180,
    "grapes": 240,     "onion": 120,        "tomato": 80,
    "chickpea": 110,   "gram": 110,         "pigeonpeas": 180,
    "arhar/tur": 180,  "lentil": 110,       "orange": 300,
    "coffee": 365,     "jute": 120,         "mungbean": 65,
    "blackgram": 75,   "urad": 75,          "watermelon": 90,
    "muskmelon": 85,   "papaya": 240,       "mothbeans": 90,
    "kidneybeans": 90, "apple": 150,        "bajra": 80,
    "jowar": 110,      "ragi": 120,         "sunflower": 100,
    "sesamum": 80,     "safflower": 130,    "linseed": 120,
}

# ── Nearest Maharashtra APMC mandis per district ─────────────────────
DISTRICT_MANDI: dict[str, list[str]] = {
    "Nagpur"                   : ["Nagpur", "Wardha"],
    "Wardha"                   : ["Wardha", "Nagpur"],
    "Amravati"                 : ["Amravati", "Akola"],
    "Akola"                    : ["Akola", "Washim"],
    "Washim"                   : ["Washim", "Akola"],
    "Buldhana"                 : ["Buldhana", "Akola"],
    "Yavatmal"                 : ["Yavatmal", "Wardha"],
    "Chandrapur"               : ["Chandrapur", "Nagpur"],
    "Gadchiroli"               : ["Gadchiroli", "Chandrapur"],
    "Gondia"                   : ["Gondia", "Bhandara"],
    "Bhandara"                 : ["Bhandara", "Nagpur"],
    "Chhatrapati Sambhajinagar": ["Aurangabad", "Jalna"],
    "Dharashiv"                : ["Osmanabad", "Latur"],
    "Beed"                     : ["Beed", "Aurangabad"],
    "Hingoli"                  : ["Hingoli", "Nanded"],
    "Jalna"                    : ["Jalna", "Aurangabad"],
    "Latur"                    : ["Latur", "Osmanabad"],
    "Nanded"                   : ["Nanded", "Latur"],
    "Parbhani"                 : ["Parbhani", "Hingoli"],
    "Pune"                     : ["Pune", "Satara"],
    "Nashik"                   : ["Nashik", "Yeola"],
    "Ahilyanagar"              : ["Ahmednagar", "Kopargaon"],
    "Solapur"                  : ["Solapur", "Pandharpur"],
    "Satara"                   : ["Satara", "Karad"],
    "Sangli"                   : ["Sangli", "Miraj"],
    "Kolhapur"                 : ["Kolhapur", "Ichalkaranji"],
    "Raigad"                   : ["Alibag", "Panvel"],
    "Ratnagiri"                : ["Ratnagiri", "Chiplun"],
    "Sindhudurg"               : ["Sindhudurg", "Sawantwadi"],
    "Thane"                    : ["Thane", "Kalyan"],
    "Palghar"                  : ["Palghar", "Vasai"],
    "Mumbai suburban"          : ["Mumbai", "Vashi"],
    "Dhule"                    : ["Dhule", "Shirpur"],
    "Nandurbar"                : ["Nandurbar", "Shahada"],
    "Jalgaon"                  : ["Jalgaon", "Bhusawal"],
}

# ── Agmarknet commodity name map ──────────────────────────────────────
_COMMODITY_MAP: dict[str, str] = {
    "rice": "Rice",             "wheat": "Wheat",
    "cotton": "Cotton(Lint)",   "soybean": "Soybean",
    "soyabean": "Soybean",      "maize": "Maize",
    "sugarcane": "Sugarcane",   "groundnut": "Groundnut",
    "banana": "Banana",         "mango": "Mango",
    "coconut": "Coconut",       "pomegranate": "Pomegranate",
    "grapes": "Grapes",         "onion": "Onion",
    "tomato": "Tomato",         "chickpea": "Gram",
    "gram": "Gram",             "pigeonpeas": "Arhar(Tur/Red Gram)(Whole)",
    "arhar/tur": "Arhar(Tur/Red Gram)(Whole)",
    "lentil": "Lentil (Masur)(Whole)",
    "orange": "Orange",         "mungbean": "Moong(Green Gram)(Whole)",
    "blackgram": "Black Gram (Urd Beans)(Whole)",
    "urad": "Black Gram (Urd Beans)(Whole)",
    "watermelon": "Water Melon","muskmelon": "Musk Melon",
    "papaya": "Papaya",         "bajra": "Bajra(Pearl Millet/Cumbu)",
    "jowar": "Jowar(Sorghum)",  "sunflower": "Sunflower Seed",
    "ragi": "Ragi (Finger Millet/Nagli/Ragi)",
}

MARKET_PRICES_FALLBACK: dict[str, float] = {
    "rice": 2183,        "wheat": 2275,       "cotton": 6680,
    "soybean": 4600,     "soyabean": 4600,    "maize": 2090,
    "sugarcane": 3150,   "groundnut": 5550,   "banana": 1400,
    "mango": 3200,       "coconut": 2800,     "pomegranate": 8000,
    "grapes": 5500,      "onion": 1800,       "tomato": 2500,
    "chickpea": 5440,    "gram": 5440,        "pigeonpeas": 7000,
    "arhar/tur": 7000,   "lentil": 6425,      "orange": 3500,
    "coffee": 9000,      "jute": 4750,        "mungbean": 8558,
    "blackgram": 7400,   "urad": 7400,        "watermelon": 800,
    "muskmelon": 1200,   "papaya": 1500,      "mothbeans": 8558,
    "kidneybeans": 6000, "apple": 12000,      "bajra": 2500,
    "jowar": 2800,       "sunflower": 7280,   "ragi": 3000,
    "sesamum": 7830,     "safflower": 5800,
}

MSP_FALLBACK: dict[str, float] = {
    "rice": 2300,     "wheat": 2275,     "cotton": 7121,
    "soybean": 4892,  "soyabean": 4892,  "maize": 2225,
    "groundnut": 6783,"chickpea": 5440,  "gram": 5440,
    "pigeonpeas": 7000,"lentil": 6425,   "mungbean": 8682,
    "blackgram": 7400, "urad": 7400,     "sugarcane": 3400,
    "jute": 5335,     "sunflower": 7280, "bajra": 2625,
    "jowar": 3371,    "ragi": 4290,      "sesamum": 9267,
    "safflower": 5800,
}

IRRIGATION_YIELD_FACTOR = {"Full": 1.20, "Partial": 1.0, "None": 0.80}

YIELD_BENCHMARKS: dict[str, dict] = {
    "rice": dict(low=900, high=1600),     "wheat": dict(low=1000, high=1800),
    "cotton": dict(low=200, high=500),    "soybean": dict(low=600, high=1100),
    "soyabean": dict(low=600, high=1100), "maize": dict(low=900, high=1700),
    "sugarcane": dict(low=20000, high=40000),
    "groundnut": dict(low=500, high=900), "banana": dict(low=7000, high=15000),
    "mango": dict(low=2000, high=6000),   "coconut": dict(low=3000, high=8000),
    "pomegranate": dict(low=3000, high=8000),
    "grapes": dict(low=4000, high=10000), "onion": dict(low=5000, high=12000),
    "tomato": dict(low=6000, high=15000), "chickpea": dict(low=350, high=700),
    "gram": dict(low=350, high=700),      "pigeonpeas": dict(low=400, high=800),
    "arhar/tur": dict(low=400, high=800), "lentil": dict(low=300, high=600),
    "orange": dict(low=2500, high=6000),  "coffee": dict(low=300, high=700),
    "jute": dict(low=1500, high=2800),    "mungbean": dict(low=200, high=450),
    "blackgram": dict(low=200, high=450), "urad": dict(low=200, high=450),
    "watermelon": dict(low=8000, high=18000),
    "muskmelon": dict(low=4000, high=10000),
    "papaya": dict(low=8000, high=20000), "bajra": dict(low=700, high=1400),
    "jowar": dict(low=800, high=1500),    "sunflower": dict(low=400, high=800),
    "ragi": dict(low=600, high=1200),
}

# ══════════════════════════════════════════════════════════════════════
#  District geographic coordinates (lat, lon) for proximity sorting
#  Used to rank mandi results: selected district first, then nearest.
# ══════════════════════════════════════════════════════════════════════

DISTRICT_COORDS: dict[str, tuple[float, float]] = {
    "Nagpur"                   : (21.15, 79.09),
    "Wardha"                   : (20.75, 78.60),
    "Amravati"                 : (20.93, 77.75),
    "Akola"                    : (20.71, 77.00),
    "Washim"                   : (20.11, 77.13),
    "Buldhana"                 : (20.53, 76.18),
    "Yavatmal"                 : (20.39, 78.12),
    "Chandrapur"               : (19.96, 79.30),
    "Gadchiroli"               : (20.18, 80.00),
    "Gondia"                   : (21.46, 80.20),
    "Bhandara"                 : (21.17, 79.65),
    "Chhatrapati Sambhajinagar": (19.88, 75.32),
    "Dharashiv"                : (18.18, 76.04),
    "Beed"                     : (18.99, 75.76),
    "Hingoli"                  : (19.72, 77.15),
    "Jalna"                    : (19.84, 75.88),
    "Latur"                    : (18.40, 76.56),
    "Nanded"                   : (19.15, 77.32),
    "Parbhani"                 : (19.27, 76.77),
    "Pune"                     : (18.52, 73.86),
    "Nashik"                   : (20.00, 73.79),
    "Ahilyanagar"              : (19.09, 74.74),
    "Solapur"                  : (17.68, 75.91),
    "Satara"                   : (17.68, 74.00),
    "Sangli"                   : (16.86, 74.57),
    "Kolhapur"                 : (16.70, 74.24),
    "Raigad"                   : (18.52, 73.18),
    "Ratnagiri"                : (16.99, 73.30),
    "Sindhudurg"               : (16.35, 73.57),
    "Thane"                    : (19.22, 72.97),
    "Palghar"                  : (19.70, 72.77),
    "Mumbai suburban"          : (19.08, 72.88),
    "Dhule"                    : (20.90, 74.78),
    "Nandurbar"                : (21.37, 74.24),
    "Jalgaon"                  : (21.01, 75.57),
}

# ── Mandi name → district mapping for proximity-based sorting ─────────
# Maps known Agmarknet mandi/market names to their Maharashtra district.
# Add more entries here as new mandis appear in API responses.
MANDI_TO_DISTRICT: dict[str, str] = {
    # Vidarbha
    "nagpur"       : "Nagpur",        "wardha"        : "Wardha",
    "amravati"     : "Amravati",      "akola"         : "Akola",
    "washim"       : "Washim",        "buldhana"      : "Buldhana",
    "yavatmal"     : "Yavatmal",      "chandrapur"    : "Chandrapur",
    "gadchiroli"   : "Gadchiroli",    "gondia"        : "Gondia",
    "bhandara"     : "Bhandara",
    # Marathwada
    "aurangabad"   : "Chhatrapati Sambhajinagar",
    "chhatrapati sambhajinagar": "Chhatrapati Sambhajinagar",
    "osmanabad"    : "Dharashiv",     "latur"         : "Latur",
    "beed"         : "Beed",          "hingoli"       : "Hingoli",
    "jalna"        : "Jalna",         "nanded"        : "Nanded",
    "parbhani"     : "Parbhani",
    # Western Maharashtra
    "pune"         : "Pune",          "nashik"        : "Nashik",
    "yeola"        : "Nashik",        "ahmednagar"    : "Ahilyanagar",
    "kopargaon"    : "Ahilyanagar",   "solapur"       : "Solapur",
    "pandharpur"   : "Solapur",       "satara"        : "Satara",
    "karad"        : "Satara",        "sangli"        : "Sangli",
    "miraj"        : "Sangli",        "kolhapur"      : "Kolhapur",
    "ichalkaranji" : "Kolhapur",
    # Konkan
    "alibag"       : "Raigad",        "panvel"        : "Raigad",
    "ratnagiri"    : "Ratnagiri",     "chiplun"       : "Ratnagiri",
    "sindhudurg"   : "Sindhudurg",    "sawantwadi"    : "Sindhudurg",
    "thane"        : "Thane",         "kalyan"        : "Thane",
    "palghar"      : "Palghar",       "vasai"         : "Palghar",
    "mumbai"       : "Mumbai suburban", "vashi"       : "Mumbai suburban",
    # Northern Maharashtra
    "dhule"        : "Dhule",         "shirpur"       : "Dhule",
    "nandurbar"    : "Nandurbar",     "shahada"       : "Nandurbar",
    "jalgaon"      : "Jalgaon",       "bhusawal"      : "Jalgaon",
}


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Returns approximate distance in km between two lat/lon points."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(dlon / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _district_coords(district: str) -> Optional[tuple[float, float]]:
    """Case-insensitive lookup of district coordinates."""
    for key, coords in DISTRICT_COORDS.items():
        if key.lower() == district.lower():
            return coords
    return None


def _mandi_distance_km(mandi_name: str, origin_coords: tuple[float, float]) -> float:
    """
    Returns distance in km from origin to the district that owns this mandi.
    Returns 0.0 if the mandi is in the origin district itself.
    Returns a large number (9999) if the mandi district is unknown.
    """
    mandi_key = mandi_name.lower().strip()
    district  = MANDI_TO_DISTRICT.get(mandi_key)

    # Fuzzy match: try if the mandi name contains a known district key
    if not district:
        for key, d in MANDI_TO_DISTRICT.items():
            if key in mandi_key or mandi_key in key:
                district = d
                break

    if not district:
        return 9999.0

    coords = _district_coords(district)
    if not coords:
        return 9999.0

    return _haversine_km(origin_coords[0], origin_coords[1], coords[0], coords[1])


def _sort_mandis_by_proximity(
    records: list[dict],
    selected_district: str,
) -> list[dict]:
    """
    Sorts a list of mandi price records so that:
      1. Records from the selected district's own mandis appear first.
      2. Remaining records are ordered by geographic proximity (nearest first).
      3. Within each proximity tier, records are sorted by modal_price descending.

    Each record must have a 'mandi' key (the mandi/market name string).
    """
    origin = _district_coords(selected_district)
    if not origin:
        # District not found in coordinates map — return as-is sorted by price
        return sorted(records, key=lambda r: r.get("modal_price", 0), reverse=True)

    # Own mandis for the selected district (from DISTRICT_MANDI)
    own_mandis: set[str] = set()
    for key, mandis in DISTRICT_MANDI.items():
        if key.lower() == selected_district.lower():
            own_mandis = {m.lower() for m in mandis}
            break

    def _sort_key(rec: dict):
        mandi_lc  = rec.get("mandi", "").lower()
        is_own    = mandi_lc in own_mandis or any(
            own.lower() in mandi_lc for own in own_mandis
        )
        dist_km   = 0.0 if is_own else _mandi_distance_km(rec.get("mandi", ""), origin)
        price_inv = -rec.get("modal_price", 0)   # secondary: higher price first
        return (0 if is_own else 1, dist_km, price_inv)

    return sorted(records, key=_sort_key)


# ══════════════════════════════════════════════════════════════════════
#  DB + lifespan
# ══════════════════════════════════════════════════════════════════════

def _init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS sightings (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            district TEXT    NOT NULL,
            crop     TEXT    NOT NULL,
            pest     TEXT    NOT NULL,
            severity TEXT    NOT NULL,
            ts       DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit(); conn.close()
    print("✅ DB initialised")


@asynccontextmanager
async def lifespan(app: FastAPI):
    global weather_svc, soil_clf, crop_rec, disease_det, risk_eng, pest_eng
    print("🌱 Starting SmartCrop backend v5...")
    _init_db()
    weather_svc = WeatherService(os.getenv("OPENWEATHER_API_KEY", ""))
    soil_clf    = SoilClassifier()
    crop_rec    = CropRecommender(os.getenv("HF_API_TOKEN", ""))
    disease_det = DiseaseDetector(os.getenv("HF_API_TOKEN", ""))
    risk_eng    = RiskEngine()
    pest_eng    = PestEngine()
    asyncio.create_task(_warm_msp_cache())
    print("✅ All services ready.")
    yield


app = FastAPI(title="Smart Crop DSS", version="5.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


# ══════════════════════════════════════════════════════════════════════
#  Agmarknet helpers
# ══════════════════════════════════════════════════════════════════════

_AGMARKNET_URL = "https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070"

# In-memory store for the full Maharashtra bulk fetch result
# { date_str -> [parsed_record, ...] }
_bulk_cache: dict = {}
_bulk_cache_lock = asyncio.Lock()


def _yesterday_str() -> str:
    """Returns real yesterday's date as dd/Mon/yyyy e.g. 18/Apr/2026"""
    return (datetime.now() - timedelta(days=1)).strftime("%d/%b/%Y")


def _safe_float(val) -> Optional[float]:
    try:
        return float(str(val).replace(",", "").strip())
    except (TypeError, ValueError):
        return None


def _parse_record(rec: dict) -> Optional[dict]:
    """
    Parse one Agmarknet record.
    The API returns lowercase keys: modal_price, min_price, max_price,
    arrival_date, market, commodity, variety — NOT Title_Case.
    """
    modal = _safe_float(rec.get("modal_price"))
    if not modal or modal <= 0:
        return None
    return {
        "mandi"        : rec.get("market", "Maharashtra APMC"),
        "commodity"    : rec.get("commodity", ""),
        "variety"      : rec.get("variety", "Common"),
        "grade"        : rec.get("grade", ""),
        "district"     : rec.get("district", ""),
        "min_price"    : _safe_float(rec.get("min_price")) or round(modal * 0.75),
        "modal_price"  : modal,
        "max_price"    : _safe_float(rec.get("max_price")) or round(modal * 1.25),
        "arrival_date" : rec.get("arrival_date", ""),
    }


async def _fetch_maharashtra_all(date_str: str) -> list[dict]:
    """
    Fetches ALL Maharashtra mandi data for a given date in one go —
    paginating through the results (limit 500 per page, up to 5 pages).
    Returns a flat list of parsed records.
    No commodity filter — we take everything the API gives us.
    """
    if not DATA_GOV_API_KEY:
        return []

    cache_key = f"bulk:{date_str}"
    cached = _bulk_cache.get(cache_key)
    if cached is not None:
        return cached

    all_records: list[dict] = []
    PAGE_LIMIT = 500
    MAX_PAGES  = 5      # safety cap — 5 × 500 = 2500 records max per date

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        for page in range(MAX_PAGES):
            params = {
                "api-key"         : DATA_GOV_API_KEY,
                "format"          : "json",
                "limit"           : str(PAGE_LIMIT),
                "offset"          : str(page * PAGE_LIMIT),
                "filters[state.keyword]": "Maharashtra",
                "filters[arrival_date]" : date_str,
            }
            for attempt in range(3):
                try:
                    r = await client.get(_AGMARKNET_URL, params=params)
                    if r.status_code == 429:
                        wait = 2.0 * (attempt + 1)
                        print(f"⏳ 429 on bulk fetch — waiting {wait:.0f}s...")
                        await asyncio.sleep(wait)
                        continue
                    r.raise_for_status()
                    body = r.json()
                    break
                except Exception as e:
                    print(f"⚠️  Bulk fetch error page {page}: {e}")
                    body = {}
                    break

            records = body.get("records", [])
            for rec in records:
                parsed = _parse_record(rec)
                if parsed:
                    all_records.append(parsed)

            # Stop paginating if we got fewer records than the page limit
            total_available = int(body.get("total", 0))
            fetched_so_far  = (page + 1) * PAGE_LIMIT
            print(f"📦 Bulk page {page+1}: {len(records)} records | total available: {total_available}")
            if fetched_so_far >= total_available or len(records) < PAGE_LIMIT:
                break

    print(f"✅ Bulk fetch {date_str}: {len(all_records)} Maharashtra records total")
    _bulk_cache[cache_key] = all_records
    return all_records


async def _get_fresh_maharashtra_data() -> tuple[list[dict], str]:
    """
    Tries today and the last 7 days until we find a date with records.
    Returns (records, date_str_used).
    """
    async with _bulk_cache_lock:
        for days_back in range(0, 7):
            date_str = (datetime.now() - timedelta(days=days_back)).strftime("%d/%m/%Y")
            records = await _fetch_maharashtra_all(date_str)
            if records:
                return records, date_str
    return [], _yesterday_str()


async def _fetch_mandi_prices(crop_key: str, district: str) -> Optional[dict]:
    """
    Fetches prices for a specific crop by filtering the bulk Maharashtra data locally.
    No per-crop API call — uses the shared bulk fetch.
    The returned `all_mandis` list is sorted by proximity to `district`.
    """
    if not DATA_GOV_API_KEY:
        return None

    cache_key = f"mandi:{district.lower()}:{crop_key}"
    cached = _price_cache.get(cache_key)
    if cached and (datetime.now() - cached["_ts"]).seconds < _CACHE_TTL:
        return {k: v for k, v in cached.items() if k != "_ts"}

    commodity = _COMMODITY_MAP.get(crop_key)
    if not commodity:
        return None

    all_records, date_used = await _get_fresh_maharashtra_data()
    if not all_records:
        return None

    # Filter by commodity name (case-insensitive)
    commodity_lower = commodity.lower()
    matches = [r for r in all_records if r["commodity"].lower() == commodity_lower]

    if not matches:
        print(f"⚠️  No records for commodity '{commodity}' in Maharashtra data — using fallback")
        return None

    # Sort all matches by proximity to the requested district
    sorted_matches = _sort_mandis_by_proximity(matches, district)

    # Best price is the top result after proximity sort (own district first,
    # then nearest), falling back to highest modal price if no local data
    best = sorted_matches[0]

    result = {
        "mandi_name"  : best["mandi"],
        "commodity"   : commodity,
        "variety"     : best["variety"],
        "min_price"   : best["min_price"],
        "modal_price" : best["modal_price"],
        "max_price"   : best["max_price"],
        "arrival_date": best["arrival_date"] or date_used,
        "all_mandis"  : sorted_matches[:5],   # top-5, proximity-sorted
        "source"      : "agmarknet_live",
        "_ts"         : datetime.now(),
    }
    _price_cache[cache_key] = result
    print(f"✅ Live: {crop_key} @ {district} = ₹{best['modal_price']} ({best['mandi']}) on {best['arrival_date']}")
    return {k: v for k, v in result.items() if k != "_ts"}


async def _fetch_agmarknet_modal(crop_key: str) -> Optional[float]:
    """Gets a single modal price for a crop, using the shared bulk cache."""
    cache_key = f"modal:{crop_key}"
    cached = _price_cache.get(cache_key)
    if cached and (datetime.now() - cached["_ts"]).seconds < _CACHE_TTL:
        return cached.get("price")

    commodity = _COMMODITY_MAP.get(crop_key)
    if not commodity or not DATA_GOV_API_KEY:
        return None

    all_records, _ = await _get_fresh_maharashtra_data()
    if not all_records:
        return None

    commodity_lower = commodity.lower()
    prices = [r["modal_price"] for r in all_records if r["commodity"].lower() == commodity_lower]
    if not prices:
        return None

    avg = sum(prices) / len(prices)
    _price_cache[cache_key] = {"price": avg, "_ts": datetime.now()}
    return avg


_MSP_RESOURCE = "35be93cd-ab6f-4fdd-859a-e1d2f04b8571"
_MSP_COMMODITY_MAP = {
    "rice": "Paddy (Common)",   "wheat": "Wheat",
    "cotton": "Cotton (Medium Staple)", "soybean": "Soybean (Yellow)",
    "soyabean": "Soybean (Yellow)",     "maize": "Maize",
    "groundnut": "Groundnut",  "chickpea": "Gram",  "gram": "Gram",
    "pigeonpeas": "Arhar/Tur", "lentil": "Masur (Lentil)",
    "mungbean": "Moong",       "blackgram": "Urad", "urad": "Urad",
    "sugarcane": "Sugarcane (FRP)", "bajra": "Bajra",
    "jowar": "Jowar (Hybrid)", "sunflower": "Sunflower Seed",
}


async def _warm_msp_cache():
    _msp_cache.update({
        "rice": 2369, "wheat": 2425, "maize": 2225,
        "bajra": 2625, "jowar": 3371, "ragi": 4886,
        "soybean": 4892, "soyabean": 4892,
        "groundnut": 6783, "sunflower": 7280,
        "cotton": 7121, "chickpea": 5440, "gram": 5440,
        "pigeonpeas": 7550, "arhar/tur": 7550,
        "mungbean": 8682, "blackgram": 7400, "urad": 7400,
        "sugarcane": 3400, "sesamum": 9267,
        "lentil": 6700, "jute": 5335,
    })
    print(f"✅ MSP cache: {len(_msp_cache)} crops loaded (2025-26 official rates)")


# ══════════════════════════════════════════════════════════════════════
#  Pydantic schemas
# ══════════════════════════════════════════════════════════════════════

class CropRequest(BaseModel):
    N          : float = Field(..., ge=0, le=145)
    P          : float = Field(..., ge=0, le=145)
    K          : float = Field(..., ge=0, le=210)
    temperature: float = Field(..., ge=0, le=50)
    humidity   : float = Field(..., ge=0, le=100)
    ph         : float = Field(..., ge=0, le=14)
    rainfall   : float = Field(..., ge=0, le=3000)
    season     : str   = "Kharif"
    irrigation : str   = "Partial"
    land_acres : float = Field(1.0, ge=0.1, le=1000)
    budget     : Optional[float] = Field(None, ge=0)
    district   : Optional[str]   = None
    w_npk      : float = Field(0.4, ge=0.0, le=1.0)
    top_n      : int   = Field(5, ge=1, le=10)


class SightingRequest(BaseModel):
    district: str
    crop    : str
    pest    : str
    severity: str


# ══════════════════════════════════════════════════════════════════════
#  Endpoints
# ══════════════════════════════════════════════════════════════════════

@app.get("/health")
def health():
    return {
        "status"        : "ok",
        "version"       : "5.0.0",
        "soil_model"    : soil_clf.source,
        "crop_model"    : crop_rec.source,
        "disease_model" : disease_det.source,
        "data_gov_key"  : "configured" if DATA_GOV_API_KEY else "missing",
        "msp_cached"    : len(_msp_cache),
    }


@app.get("/weather/{district}")
async def get_weather(district: str):
    return await weather_svc.fetch(district)


@app.get("/district-defaults/{district}")
def district_defaults(district: str):
    d = DISTRICT_DATA.get(district)
    if not d:
        raise HTTPException(404, f"No data for district: {district}")
    return d


# ── FIX: Relaxed content-type check for soil image upload ─────────────
# Some Android/iOS devices send 'application/octet-stream' instead of
# 'image/jpeg'. We now validate by actually attempting to open the image
# with Pillow rather than relying solely on the MIME type header.
@app.post("/analyze-soil-image")
async def analyze_soil(file: UploadFile = File(...)):
    data = await file.read()

    # Validate minimum size first
    if len(data) < 1000:
        raise HTTPException(400, "Image appears empty or corrupt")

    # Try to validate as image using Pillow — much more reliable than MIME type
    try:
        from PIL import Image as PILImage
        import io
        img = PILImage.open(io.BytesIO(data))
        img.verify()  # raises if not a valid image
    except Exception:
        # Only reject if it truly cannot be opened as an image
        ct = file.content_type or ""
        # Allow octet-stream through since many mobile clients send this
        # for camera images
        if ct and not ct.startswith("image/") and ct not in (
            "application/octet-stream", "binary/octet-stream", ""
        ):
            raise HTTPException(400, "Must be an image file")

    return soil_clf.classify(data)


@app.post("/recommend-crops")
async def recommend_crops(req: CropRequest):
    candidates = crop_rec.recommend(
        req.N, req.P, req.K,
        req.temperature, req.humidity,
        req.ph, req.rainfall,
        district = req.district or "",
        season   = req.season,
        w_npk    = req.w_npk,
        top_n    = min(req.top_n * 2, 10),
    )

    async def _enrich(c: dict) -> dict:
        name     = c["crop_name"]
        crop_key = name.lower()
        risk   = risk_eng.score(name, req.season, req.temperature,
                                req.humidity, req.rainfall, req.land_acres, req.budget)
        afford = risk_eng.affordability(name, req.land_acres, req.budget)
        yield_d = _yield_estimate(name, req.land_acres, req.irrigation)
        market  = _market_info(name)
        live_price = await _fetch_agmarknet_modal(crop_key)
        if live_price:
            price = live_price
            source = "live"
        else:
            import random
            base_price = MARKET_PRICES_FALLBACK.get(crop_key, 3000)
            fluctuation = random.randint(-150, 150)
            price = base_price + fluctuation
            source = "simulated"

        today     = datetime.now().strftime("%d/%b/%Y")
        yesterday = _yesterday_str()
        confidence = "High" if source == "live" else "Medium"

        revenue    = _revenue_from_price(name, req.land_acres, req.irrigation, price)
        mandi = await _fetch_mandi_prices(crop_key, req.district or "Pune")
        if mandi is None:
            fp = MARKET_PRICES_FALLBACK.get(crop_key)
            if fp:
                mandi = {
                    "mandi_name"  : f"{req.district or 'Maharashtra'} APMC",
                    "commodity"   : name,
                    "variety"     : "Common",
                    "min_price"   : round(fp * 0.75),
                    "modal_price" : fp,
                    "max_price"   : round(fp * 1.25),
                    "arrival_date": yesterday,
                    "all_mandis"  : [],
                    "source"      : "simulated",
                }
        harvest_days = HARVEST_DAYS.get(crop_key, 120)
        return {
            **c,
            "risk_score"          : risk["total"],
            "risk_level"          : risk["level"],
            "risk_breakdown"      : risk["breakdown"],
            "affordability"       : afford,
            "harvest_days"        : harvest_days,
            "mandi_prices"        : mandi,
            "explanation"         : _explain(name, req),
            "market_signal"       : market,
            "yield_estimate"      : yield_d,
            "revenue_estimate"    : revenue,
            "input_cost_estimate" : _input_cost_str(name, req.land_acres),
            "price_info": {
                "price"     : round(price, 2),
                "date"      : yesterday,
                "source"    : source,
                "confidence": confidence,
            },
        }

    enriched = list(await asyncio.gather(*[_enrich(c) for c in candidates]))

    def _composite(crop: dict) -> float:
        ai_conf    = float(crop["confidence"])
        risk_inv   = 100.0 - float(crop["risk_score"])
        af         = crop["affordability"]
        if af["budget_ratio"] is None:
            budget_fit = 75.0
        else:
            r = af["budget_ratio"]
            if r < 0.50:   budget_fit = 100.0
            elif r < 0.85: budget_fit = 85.0
            elif r < 1.00: budget_fit = 70.0
            elif r < 1.20: budget_fit = 35.0
            else:          budget_fit = 10.0
        return ai_conf * 0.40 + risk_inv * 0.35 + budget_fit * 0.25

    ranked = sorted(enriched, key=_composite, reverse=True)[: req.top_n]
    for i, crop in enumerate(ranked):
        crop["rank"]            = i + 1
        crop["composite_score"] = round(_composite(crop), 1)

    weather = await weather_svc.fetch_or_use(req.temperature, req.humidity, req.rainfall)
    return {"crops": ranked, "total": len(ranked), "weather": weather}


@app.get("/mandi-prices/{district}/{crop}")
async def mandi_prices(district: str, crop: str):
    live = await _fetch_mandi_prices(crop.lower(), district)
    if live:
        return live
    fp = MARKET_PRICES_FALLBACK.get(crop.lower())
    if not fp:
        raise HTTPException(404, f"No price data for {crop}")
    return {
        "mandi_name"  : f"{district} APMC",
        "commodity"   : crop.title(),
        "variety"     : "Common",
        "min_price"   : round(fp * 0.75),
        "modal_price" : fp,
        "max_price"   : round(fp * 1.25),
        "arrival_date": _yesterday_str(),
        "all_mandis"  : [],
        "source"      : "simulated",
    }


# ── Bulk mandi prices for Flutter MandiPricesScreen ──────────────────
_POPULAR_CROPS = [
    "rice", "wheat", "maize", "cotton", "soybean", "onion",
    "tomato", "sugarcane", "groundnut", "jowar", "bajra",
    "chickpea", "pigeonpeas", "mungbean", "blackgram",
    "pomegranate", "grapes", "banana", "mango", "orange",
]

@app.get("/mandi-prices-bulk/{district}")
async def mandi_prices_bulk(district: str):
    """
    Returns live mandi prices for all popular crops in a district.

    Sorting logic:
      - For each crop, the primary mandi shown is the one closest to `district`
        (own district first, then nearest neighbours by haversine distance).
      - The `all_mandis` list within each crop entry is also proximity-sorted.
      - The final crop list is sorted by modal_price descending (prices stay
        comparable regardless of which mandi is chosen as primary).

    All crops share a single bulk Maharashtra API fetch (paginated),
    so this endpoint only makes ~1-5 API calls total regardless of
    how many crops are requested.

    Response: { "prices": [...], "district": "...", "source": "...",
                "sort_note": "Sorted by proximity to <district>" }
    """
    yesterday = _yesterday_str()

    # One shared bulk fetch for all crops — results are cached 24h
    all_mh_records, date_used = await _get_fresh_maharashtra_data()

    # Build a commodity -> [records] lookup from the bulk data
    commodity_index: dict[str, list[dict]] = {}
    for rec in all_mh_records:
        key = rec["commodity"].lower()
        commodity_index.setdefault(key, []).append(rec)

    prices     = []
    live_count = 0

    for crop in _POPULAR_CROPS:
        commodity = _COMMODITY_MAP.get(crop)
        if commodity:
            matches = commodity_index.get(commodity.lower(), [])
        else:
            matches = []

        if matches:
            # Sort matches by proximity to the requested district
            sorted_matches = _sort_mandis_by_proximity(matches, district)
            best           = sorted_matches[0]   # nearest/own district first
            live_count    += 1
            prices.append({
                "crop"        : crop.title(),
                "mandi"       : best["mandi"],
                "min_price"   : best["min_price"],
                "modal_price" : best["modal_price"],
                "max_price"   : best["max_price"],
                "arrival_date": best["arrival_date"] or date_used,
                "variety"     : best["variety"],
                "all_mandis"  : sorted_matches[:5],   # proximity-sorted top-5
                "source"      : "agmarknet_live",
                "unit"        : "quintal",
            })
        else:
            # Fallback with real date
            fp = MARKET_PRICES_FALLBACK.get(crop)
            if fp:
                prices.append({
                    "crop"        : crop.title(),
                    "mandi"       : f"{district} APMC",
                    "min_price"   : round(fp * 0.75),
                    "modal_price" : fp,
                    "max_price"   : round(fp * 1.25),
                    "arrival_date": yesterday,
                    "source"      : "simulated",
                    "unit"        : "quintal",
                })

    # Sort final list: live entries by modal_price desc, then simulated
    prices.sort(key=lambda x: (0 if x["source"] == "agmarknet_live" else 1,
                               -x["modal_price"]))

    return {
        "prices"    : prices,
        "district"  : district,
        "total"     : len(prices),
        "live_count": live_count,
        "source"    : "agmarknet_live" if live_count > 0 else "static_fallback",
        "fetched_at": datetime.now().isoformat(),
        "sort_note" : f"Mandis sorted by proximity to {district}",
    }


@app.get("/mandi-prices-all")
async def mandi_prices_all(district: Optional[str] = None):
    """
    Returns EVERY commodity available from Agmarknet Maharashtra today.

    Optional query param: ?district=Pune
    When provided, results are sorted so the selected district's mandis
    appear first, followed by nearest districts in order.
    Without district param, results are sorted by modal_price descending.

    Flutter can use this to show a complete live market screen.
    """
    all_records, date_used = await _get_fresh_maharashtra_data()
    yesterday = _yesterday_str()

    if not all_records:
        return {
            "prices"    : [],
            "total"     : 0,
            "live_count": 0,
            "source"    : "no_data",
            "fetched_at": datetime.now().isoformat(),
        }

    # Deduplicate: keep highest modal price per commodity+market combo
    seen: dict[str, dict] = {}
    for rec in all_records:
        key = f"{rec['commodity'].lower()}|{rec['mandi'].lower()}"
        if key not in seen or rec["modal_price"] > seen[key]["modal_price"]:
            seen[key] = rec

    prices = []
    for rec in seen.values():
        prices.append({
            "crop"        : rec["commodity"],
            "mandi"       : rec["mandi"],
            "district"    : rec.get("district", ""),
            "variety"     : rec.get("variety", "Common"),
            "grade"       : rec.get("grade", ""),
            "min_price"   : rec["min_price"],
            "modal_price" : rec["modal_price"],
            "max_price"   : rec["max_price"],
            "arrival_date": rec["arrival_date"] or date_used,
            "source"      : "agmarknet_live",
            "unit"        : "quintal",
        })

    if district:
        # Proximity sort: selected district mandis first, then nearest
        prices = _sort_mandis_by_proximity(prices, district)
        sort_note = f"Sorted by proximity to {district}"
    else:
        prices.sort(key=lambda x: x["modal_price"], reverse=True)
        sort_note = "Sorted by modal price (no district specified)"

    return {
        "prices"    : prices,
        "total"     : len(prices),
        "live_count": len(prices),
        "date_used" : date_used,
        "source"    : "agmarknet_live",
        "fetched_at": datetime.now().isoformat(),
        "sort_note" : sort_note,
    }


@app.post("/diagnose-crop-image")
async def diagnose(
    file     : UploadFile = File(...),
    crop_name: str        = Form("Unknown"),
):
    return await disease_det.diagnose(await file.read(), crop_name)


@app.get("/pest-alerts/{district}/{crop}")
async def pest_alerts(district: str, crop: str, season: str = "Kharif"):
    weather  = await weather_svc.fetch(district)
    w_alerts = pest_eng.weather_alerts(crop, weather, season)
    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute(
        """SELECT pest, severity, COUNT(*) as cnt FROM sightings
           WHERE LOWER(district)=LOWER(?) AND LOWER(crop)=LOWER(?)
             AND ts > datetime('now','-7 days')
           GROUP BY pest, severity ORDER BY cnt DESC""",
        (district, crop),
    ).fetchall()
    conn.close()
    c_alerts = [{
        "pest_name"      : pest,
        "crop"           : crop,
        "severity"       : sev,
        "alert_type"     : "community",
        "report_count"   : cnt,
        "trigger_reason" : f"{cnt} farmer(s) in {district} reported {pest} in last 7 days",
        "action"         : pest_eng.action(pest),
        "organic"        : pest_eng.organic(pest),
        "days_until_peak": 3,
        "time_posted"    : "Recent",
    } for (pest, sev, cnt) in rows]
    return {"alerts": w_alerts + c_alerts, "district": district, "crop": crop}


@app.post("/report-sighting")
def report_sighting(req: SightingRequest):
    if not req.pest.strip():
        raise HTTPException(400, "Pest name required")
    if req.severity.upper() not in ("LOW", "MEDIUM", "HIGH"):
        raise HTTPException(400, "Severity must be LOW, MEDIUM, or HIGH")
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "INSERT INTO sightings (district, crop, pest, severity) VALUES (?,?,?,?)",
        (req.district.strip(), req.crop.strip(), req.pest.strip(), req.severity.upper()),
    )
    conn.commit()
    n = conn.execute(
        "SELECT COUNT(*) FROM sightings WHERE LOWER(district)=LOWER(?) AND LOWER(crop)=LOWER(?)",
        (req.district, req.crop),
    ).fetchone()[0]
    conn.close()
    return {"success": True, "message": "Sighting recorded", "farmers_alerted": n}


@app.get("/crop-recommender-meta")
def crop_recommender_meta():
    return {"districts": crop_rec.districts, "seasons": crop_rec.seasons, "source": crop_rec.source}


@app.get("/market-prices/{crop}")
async def get_market_price(crop: str):
    live = await _fetch_agmarknet_modal(crop.lower())
    if live:
        return {"crop": crop, "price": live, "source": "agmarknet_live", "unit": "₹/quintal"}
    fb = MARKET_PRICES_FALLBACK.get(crop.lower())
    return {"crop": crop, "price": fb, "source": "static_fallback", "unit": "₹/quintal"}


# ══════════════════════════════════════════════════════════════════════
#  Helper functions
# ══════════════════════════════════════════════════════════════════════

def _yield_estimate(crop: str, land: float, irrigation: str) -> str:
    d = YIELD_BENCHMARKS.get(crop.lower())
    if not d:
        return "Data not available"
    f  = IRRIGATION_YIELD_FACTOR.get(irrigation, 1.0)
    lo = int(d["low"]  * land * f)
    hi = int(d["high"] * land * f)
    if d["high"] > 5000:
        return f"{lo/1000:.1f}–{hi/1000:.1f} tonnes"
    return f"{lo}–{hi} kg  ({lo//100}–{hi//100} qtl)"


def _revenue_from_price(crop: str, land: float, irrigation: str, price: float) -> str:
    d = YIELD_BENCHMARKS.get(crop.lower())
    if not d:
        return "N/A"
    f     = IRRIGATION_YIELD_FACTOR.get(irrigation, 1.0)
    lo_kg = d["low"]  * land * f
    hi_kg = d["high"] * land * f
    return f"Rs.{int(lo_kg/100*price):,} - Rs.{int(hi_kg/100*price):,}"


def _input_cost_str(crop: str, land: float) -> str:
    d = INPUT_COSTS.get(crop.lower(), DEFAULT_INPUT_COST)
    return f"Rs.{int(d['total'] * land):,}"


def _market_info(crop: str) -> dict:
    crop_key = crop.lower()
    mkt      = MARKET_DATA.get(crop_key)
    msp      = _msp_cache.get(crop_key) or MSP_FALLBACK.get(crop_key)
    if mkt:
        trend, demand, oversupply, _ = mkt
    else:
        trend, demand, oversupply = "STABLE", "MEDIUM", False
    return {
        "price_trend"    : trend,
        "demand_level"   : demand,
        "oversupply_risk": oversupply,
        "msp_price"      : msp or MARKET_PRICES_FALLBACK.get(crop_key),
    }


def _explain(crop: str, req: CropRequest) -> list[str]:
    """
    Generates real data-driven explanation points using actual user inputs
    vs crop profile ideal ranges — every sentence references real numbers.
    """
    pts  = []
    prof = CROP_PROFILES.get(crop.lower(), {})
    tlo, thi = prof.get("temp", (20, 33))
    rlo, rhi = prof.get("rain", (400, 1200))
    plo, phi = prof.get("ph",   (6.0, 7.5))
    seasons  = prof.get("seasons", [])

    # ── Nitrogen ──────────────────────────────────────────────────────
    if req.N >= 80:
        pts.append(f"High nitrogen ({req.N:.0f} mg/kg) supports the vigorous vegetative growth {crop} needs")
    elif req.N >= 55:
        pts.append(f"Nitrogen at {req.N:.0f} mg/kg is adequate for {crop}; a split urea dose at tillering will boost yield")
    else:
        pts.append(f"Low nitrogen ({req.N:.0f} mg/kg)  -  apply 50 kg urea/acre before sowing {crop}")

    # ── Phosphorus ────────────────────────────────────────────────────
    if req.P >= 50:
        pts.append(f"Phosphorus ({req.P:.0f} mg/kg) is sufficient for strong root development in {crop}")
    elif req.P >= 30:
        pts.append(f"Phosphorus is moderate ({req.P:.0f} mg/kg); add 20 kg SSP/acre for better root establishment")
    else:
        pts.append(f"Low phosphorus ({req.P:.0f} mg/kg)  -  apply DAP before transplanting {crop}")

    # ── Potassium ─────────────────────────────────────────────────────
    if req.K >= 80:
        pts.append(f"Potassium ({req.K:.0f} mg/kg) supports disease resistance and grain filling in {crop}")
    else:
        pts.append(f"Potassium is low ({req.K:.0f} mg/kg)  -  apply MOP (muriate of potash) to improve {crop} quality")

    # ── Temperature ───────────────────────────────────────────────────
    if tlo <= req.temperature <= thi:
        pts.append(f"Current temperature {req.temperature:.0f} deg C is within the ideal {tlo}-{thi} deg C range for {crop}")
    elif req.temperature < tlo:
        pts.append(f"Temperature {req.temperature:.0f} deg C is below ideal ({tlo} deg C min)  -  sow after temperatures rise or use mulching")
    else:
        pts.append(f"Temperature {req.temperature:.0f} deg C is above ideal ({thi} deg C max)  -  ensure shade/irrigation to protect {crop}")

    # ── Rainfall ──────────────────────────────────────────────────────
    if rlo <= req.rainfall <= rhi:
        pts.append(f"Rainfall {req.rainfall:.0f} mm fits {crop}'s requirement of {rlo}-{rhi} mm  -  natural moisture should suffice")
    elif req.rainfall < rlo:
        deficit = rlo - req.rainfall
        pts.append(f"Rainfall {req.rainfall:.0f} mm is {deficit:.0f} mm short of {crop}'s minimum  -  drip or sprinkler irrigation required")
    else:
        excess = req.rainfall - rhi
        pts.append(f"Rainfall {req.rainfall:.0f} mm exceeds {crop}'s range by {excess:.0f} mm  -  raised beds and drainage channels recommended")

    # ── pH ────────────────────────────────────────────────────────────
    if plo <= req.ph <= phi:
        pts.append(f"Soil pH {req.ph:.1f} is ideal for {crop} (optimal: {plo}-{phi})")
    elif req.ph < plo:
        pts.append(f"Acidic pH {req.ph:.1f}  -  apply lime at 2 q/acre to bring soil to {crop}'s ideal range ({plo}-{phi})")
    else:
        pts.append(f"Alkaline pH {req.ph:.1f}  -  apply gypsum or sulphur to lower pH toward {crop}'s ideal ({plo}-{phi})")

    # ── Season ────────────────────────────────────────────────────────
    if not seasons or req.season in seasons:
        pts.append(f"{req.season} is one of the optimal seasons for {crop} in Maharashtra")
    else:
        pts.append(f"{crop} grows best in {'/'.join(seasons)}  -  in {req.season} monitor closely and adjust irrigation")

    # ── Irrigation ────────────────────────────────────────────────────
    if req.irrigation == "Full":
        pts.append(f"Full irrigation gives {crop} a 20% yield advantage  -  use drip for water efficiency")
    elif req.irrigation == "Partial":
        pts.append(f"Partial irrigation is sufficient for {crop} given the current rainfall; supplement during dry spells")
    else:
        pts.append(f"{crop} can survive rainfed conditions but yield will be 20% lower  -  consider micro-irrigation")

    return pts[:6]

DISTRICT_DATA: dict[str, dict] = {
    # ── Vidarbha ─────────────────────────────────────────────────────
    "Nagpur": dict(
        region="Vidarbha", typical_soil_type="Black Soil",
        npk_range=dict(N_low=60,N_high=85,P_low=50,P_high=80,K_low=80,K_high=130),
        avg_ph_range=dict(low=7.0,high=8.5), avg_annual_rainfall_mm=1034,
        primary_season="Kharif", weather_city="Nagpur",
        common_crops=["Cotton","Soybean","Orange","Wheat","Pigeonpeas"],
    ),
    "Wardha": dict(
        region="Vidarbha", typical_soil_type="Black Soil",
        npk_range=dict(N_low=55,N_high=80,P_low=45,P_high=75,K_low=75,K_high=120),
        avg_ph_range=dict(low=7.0,high=8.5), avg_annual_rainfall_mm=920,
        primary_season="Kharif", weather_city="Wardha",
        common_crops=["Cotton","Soybean","Wheat","Pigeonpeas"],
    ),
    "Amravati": dict(
        region="Vidarbha", typical_soil_type="Black Soil",
        npk_range=dict(N_low=55,N_high=80,P_low=45,P_high=75,K_low=75,K_high=120),
        avg_ph_range=dict(low=7.0,high=8.5), avg_annual_rainfall_mm=870,
        primary_season="Kharif", weather_city="Amravati",
        common_crops=["Cotton","Soybean","Orange","Pigeonpeas"],
    ),
    "Akola": dict(
        region="Vidarbha", typical_soil_type="Black Soil",
        npk_range=dict(N_low=55,N_high=78,P_low=48,P_high=75,K_low=78,K_high=118),
        avg_ph_range=dict(low=7.2,high=8.6), avg_annual_rainfall_mm=790,
        primary_season="Kharif", weather_city="Akola",
        common_crops=["Cotton","Soybean","Wheat","Pigeonpeas"],
    ),
    "Washim": dict(
        region="Vidarbha", typical_soil_type="Black Soil",
        npk_range=dict(N_low=52,N_high=75,P_low=44,P_high=70,K_low=72,K_high=115),
        avg_ph_range=dict(low=7.2,high=8.5), avg_annual_rainfall_mm=760,
        primary_season="Kharif", weather_city="Washim",
        common_crops=["Cotton","Soybean","Pigeonpeas","Mungbean"],
    ),
    "Buldhana": dict(
        region="Vidarbha", typical_soil_type="Black Soil",
        npk_range=dict(N_low=52,N_high=78,P_low=46,P_high=72,K_low=74,K_high=116),
        avg_ph_range=dict(low=7.0,high=8.5), avg_annual_rainfall_mm=800,
        primary_season="Kharif", weather_city="Buldhana",
        common_crops=["Cotton","Soybean","Wheat","Orange"],
    ),
    "Yavatmal": dict(
        region="Vidarbha", typical_soil_type="Black Soil",
        npk_range=dict(N_low=58,N_high=82,P_low=48,P_high=76,K_low=76,K_high=122),
        avg_ph_range=dict(low=7.0,high=8.4), avg_annual_rainfall_mm=920,
        primary_season="Kharif", weather_city="Yavatmal",
        common_crops=["Cotton","Soybean","Pigeonpeas","Wheat"],
    ),
    "Chandrapur": dict(
        region="Vidarbha", typical_soil_type="Red Soil",
        npk_range=dict(N_low=40,N_high=65,P_low=25,P_high=50,K_low=55,K_high=90),
        avg_ph_range=dict(low=6.0,high=7.5), avg_annual_rainfall_mm=1250,
        primary_season="Kharif", weather_city="Chandrapur",
        common_crops=["Rice","Cotton","Soybean","Maize"],
    ),
    "Gadchiroli": dict(
        region="Vidarbha", typical_soil_type="Red Soil",
        npk_range=dict(N_low=35,N_high=60,P_low=20,P_high=45,K_low=50,K_high=85),
        avg_ph_range=dict(low=5.5,high=7.0), avg_annual_rainfall_mm=1500,
        primary_season="Kharif", weather_city="Gadchiroli",
        common_crops=["Rice","Maize","Sorghum"],
    ),
    "Gondia": dict(
        region="Vidarbha", typical_soil_type="Alluvial Soil",
        npk_range=dict(N_low=65,N_high=95,P_low=38,P_high=65,K_low=80,K_high=125),
        avg_ph_range=dict(low=6.5,high=7.8), avg_annual_rainfall_mm=1350,
        primary_season="Kharif", weather_city="Gondia",
        common_crops=["Rice","Wheat","Soybean"],
    ),
    "Bhandara": dict(
        region="Vidarbha", typical_soil_type="Alluvial Soil",
        npk_range=dict(N_low=68,N_high=98,P_low=40,P_high=68,K_low=82,K_high=128),
        avg_ph_range=dict(low=6.5,high=7.8), avg_annual_rainfall_mm=1320,
        primary_season="Kharif", weather_city="Bhandara",
        common_crops=["Rice","Wheat","Maize","Soybean"],
    ),
    "Chhatrapati Sambhajinagar": dict(
        region="Marathwada", typical_soil_type="Black Soil",
        npk_range=dict(N_low=50,N_high=75,P_low=40,P_high=68,K_low=70,K_high=110),
        avg_ph_range=dict(low=7.2,high=8.6), avg_annual_rainfall_mm=710,
        primary_season="Kharif", weather_city="Aurangabad",
        common_crops=["Cotton","Soybean","Sugarcane","Pigeonpeas","Wheat"],
    ),
    "Dharashiv": dict(
        region="Marathwada", typical_soil_type="Black Soil",
        npk_range=dict(N_low=48,N_high=72,P_low=38,P_high=65,K_low=68,K_high=108),
        avg_ph_range=dict(low=7.2,high=8.6), avg_annual_rainfall_mm=670,
        primary_season="Kharif", weather_city="Osmanabad",
        common_crops=["Soybean","Pigeonpeas","Cotton","Sugarcane"],
    ),
    "Beed": dict(
        region="Marathwada", typical_soil_type="Black Soil",
        npk_range=dict(N_low=48,N_high=73,P_low=40,P_high=66,K_low=68,K_high=108),
        avg_ph_range=dict(low=7.2,high=8.6), avg_annual_rainfall_mm=680,
        primary_season="Kharif", weather_city="Beed",
        common_crops=["Sugarcane","Cotton","Soybean","Pomegranate"],
    ),
    "Hingoli": dict(
        region="Marathwada", typical_soil_type="Black Soil",
        npk_range=dict(N_low=50,N_high=74,P_low=42,P_high=68,K_low=70,K_high=112),
        avg_ph_range=dict(low=7.0,high=8.4), avg_annual_rainfall_mm=830,
        primary_season="Kharif", weather_city="Hingoli",
        common_crops=["Soybean","Cotton","Pigeonpeas","Wheat"],
    ),
    "Jalna": dict(
        region="Marathwada", typical_soil_type="Black Soil",
        npk_range=dict(N_low=50,N_high=74,P_low=42,P_high=68,K_low=70,K_high=110),
        avg_ph_range=dict(low=7.2,high=8.5), avg_annual_rainfall_mm=720,
        primary_season="Kharif", weather_city="Jalna",
        common_crops=["Cotton","Soybean","Mungbean","Wheat"],
    ),
    "Latur": dict(
        region="Marathwada", typical_soil_type="Black Soil",
        npk_range=dict(N_low=48,N_high=72,P_low=40,P_high=66,K_low=66,K_high=106),
        avg_ph_range=dict(low=7.2,high=8.6), avg_annual_rainfall_mm=680,
        primary_season="Kharif", weather_city="Latur",
        common_crops=["Soybean","Pigeonpeas","Sugarcane","Cotton"],
    ),
    "Nanded": dict(
        region="Marathwada", typical_soil_type="Black Soil",
        npk_range=dict(N_low=52,N_high=76,P_low=44,P_high=70,K_low=72,K_high=112),
        avg_ph_range=dict(low=7.0,high=8.5), avg_annual_rainfall_mm=860,
        primary_season="Kharif", weather_city="Nanded",
        common_crops=["Soybean","Cotton","Sugarcane","Banana"],
    ),
    "Parbhani": dict(
        region="Marathwada", typical_soil_type="Black Soil",
        npk_range=dict(N_low=50,N_high=74,P_low=42,P_high=68,K_low=70,K_high=110),
        avg_ph_range=dict(low=7.2,high=8.6), avg_annual_rainfall_mm=760,
        primary_season="Kharif", weather_city="Parbhani",
        common_crops=["Soybean","Cotton","Pigeonpeas","Wheat"],
    ),
    "Pune": dict(
        region="Western Maharashtra", typical_soil_type="Black Soil",
        npk_range=dict(N_low=55,N_high=80,P_low=40,P_high=70,K_low=70,K_high=115),
        avg_ph_range=dict(low=6.5,high=8.0), avg_annual_rainfall_mm=725,
        primary_season="Kharif", weather_city="Pune",
        common_crops=["Sugarcane","Grapes","Onion","Wheat","Tomato"],
    ),
    "Nashik": dict(
        region="Northern Maharashtra", typical_soil_type="Red Soil",
        npk_range=dict(N_low=30,N_high=55,P_low=18,P_high=40,K_low=48,K_high=82),
        avg_ph_range=dict(low=5.8,high=7.2), avg_annual_rainfall_mm=680,
        primary_season="Kharif", weather_city="Nashik",
        common_crops=["Grapes","Onion","Tomato","Wheat","Maize"],
    ),
    "Ahilyanagar": dict(
        region="Western Maharashtra", typical_soil_type="Black Soil",
        npk_range=dict(N_low=52,N_high=78,P_low=42,P_high=68,K_low=72,K_high=112),
        avg_ph_range=dict(low=6.8,high=8.2), avg_annual_rainfall_mm=590,
        primary_season="Kharif", weather_city="Ahmednagar",
        common_crops=["Sugarcane","Onion","Cotton","Pomegranate"],
    ),
    "Solapur": dict(
        region="Western Maharashtra", typical_soil_type="Black Soil",
        npk_range=dict(N_low=45,N_high=70,P_low=38,P_high=62,K_low=65,K_high=105),
        avg_ph_range=dict(low=7.0,high=8.5), avg_annual_rainfall_mm=540,
        primary_season="Kharif", weather_city="Solapur",
        common_crops=["Pomegranate","Sugarcane","Onion","Sorghum"],
    ),
    "Satara": dict(
        region="Western Maharashtra", typical_soil_type="Loamy Soil",
        npk_range=dict(N_low=60,N_high=88,P_low=42,P_high=70,K_low=75,K_high=118),
        avg_ph_range=dict(low=6.2,high=7.8), avg_annual_rainfall_mm=780,
        primary_season="Kharif", weather_city="Satara",
        common_crops=["Sugarcane","Onion","Wheat","Maize","Tomato"],
    ),
    "Sangli": dict(
        region="Western Maharashtra", typical_soil_type="Black Soil",
        npk_range=dict(N_low=55,N_high=82,P_low=42,P_high=70,K_low=72,K_high=115),
        avg_ph_range=dict(low=7.0,high=8.2), avg_annual_rainfall_mm=520,
        primary_season="Kharif", weather_city="Sangli",
        common_crops=["Sugarcane","Grapes","Turmeric","Onion","Sorghum"],
    ),
    "Kolhapur": dict(
        region="Western Maharashtra", typical_soil_type="Loamy Soil",
        npk_range=dict(N_low=65,N_high=95,P_low=45,P_high=75,K_low=80,K_high=128),
        avg_ph_range=dict(low=5.8,high=7.5), avg_annual_rainfall_mm=1100,
        primary_season="Kharif", weather_city="Kolhapur",
        common_crops=["Sugarcane","Rice","Groundnut","Soybean"],
    ),
    "Raigad": dict(
        region="Konkan", typical_soil_type="Laterite Soil",
        npk_range=dict(N_low=22,N_high=45,P_low=12,P_high=28,K_low=35,K_high=65),
        avg_ph_range=dict(low=5.0,high=6.5), avg_annual_rainfall_mm=2500,
        primary_season="Kharif", weather_city="Alibaug",
        common_crops=["Rice","Coconut","Mango","Cashew","Banana"],
    ),
    "Ratnagiri": dict(
        region="Konkan", typical_soil_type="Laterite Soil",
        npk_range=dict(N_low=20,N_high=42,P_low=10,P_high=25,K_low=32,K_high=60),
        avg_ph_range=dict(low=5.0,high=6.5), avg_annual_rainfall_mm=3000,
        primary_season="Kharif", weather_city="Ratnagiri",
        common_crops=["Alphonso Mango","Cashew","Coconut","Rice"],
    ),
    "Sindhudurg": dict(
        region="Konkan", typical_soil_type="Laterite Soil",
        npk_range=dict(N_low=20,N_high=42,P_low=10,P_high=26,K_low=33,K_high=62),
        avg_ph_range=dict(low=5.0,high=6.5), avg_annual_rainfall_mm=3200,
        primary_season="Kharif", weather_city="Sindhudurg",
        common_crops=["Coconut","Cashew","Rice","Mango"],
    ),
    "Thane": dict(
        region="Konkan", typical_soil_type="Laterite Soil",
        npk_range=dict(N_low=25,N_high=48,P_low=12,P_high=30,K_low=38,K_high=68),
        avg_ph_range=dict(low=5.2,high=6.8), avg_annual_rainfall_mm=2600,
        primary_season="Kharif", weather_city="Thane",
        common_crops=["Rice","Maize","Vegetables","Coconut"],
    ),
    "Palghar": dict(
        region="Konkan", typical_soil_type="Laterite Soil",
        npk_range=dict(N_low=22,N_high=46,P_low=11,P_high=28,K_low=36,K_high=66),
        avg_ph_range=dict(low=5.2,high=6.8), avg_annual_rainfall_mm=2800,
        primary_season="Kharif", weather_city="Palghar",
        common_crops=["Rice","Vegetables","Banana","Coconut"],
    ),
    "Mumbai suburban": dict(
        region="Konkan", typical_soil_type="Laterite Soil",
        npk_range=dict(N_low=20,N_high=40,P_low=10,P_high=25,K_low=30,K_high=58),
        avg_ph_range=dict(low=5.0,high=6.5), avg_annual_rainfall_mm=2400,
        primary_season="Kharif", weather_city="Mumbai",
        common_crops=["Vegetables","Rice"],
    ),
    "Dhule": dict(
        region="Northern Maharashtra", typical_soil_type="Red Soil",
        npk_range=dict(N_low=25,N_high=50,P_low=15,P_high=35,K_low=42,K_high=75),
        avg_ph_range=dict(low=6.5,high=8.0), avg_annual_rainfall_mm=575,
        primary_season="Kharif", weather_city="Dhule",
        common_crops=["Maize","Cotton","Onion","Wheat","Groundnut"],
    ),
    "Nandurbar": dict(
        region="Northern Maharashtra", typical_soil_type="Red Soil",
        npk_range=dict(N_low=25,N_high=48,P_low=14,P_high=32,K_low=40,K_high=72),
        avg_ph_range=dict(low=6.0,high=7.8), avg_annual_rainfall_mm=900,
        primary_season="Kharif", weather_city="Nandurbar",
        common_crops=["Maize","Cotton","Sorghum","Banana"],
    ),
    "Jalgaon": dict(
        region="Northern Maharashtra", typical_soil_type="Black Soil",
        npk_range=dict(N_low=55,N_high=80,P_low=44,P_high=72,K_low=74,K_high=118),
        avg_ph_range=dict(low=7.0,high=8.4), avg_annual_rainfall_mm=680,
        primary_season="Kharif", weather_city="Jalgaon",
        common_crops=["Banana","Cotton","Maize","Wheat","Onion"],
    ),
}