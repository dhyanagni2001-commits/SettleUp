#!/usr/bin/env python3
"""Builds expense_categories.csv: expense titles -> ExpenseCategory raw values.

Titles are composed from per-category vocabularies (items, merchants, and
phrasing people actually type into a splitting app), with a fixed seed so the
CSV is reproducible. The hand-written evaluation set (SplitWiseCloneTests/evaluation.csv) is kept
separate and shares no templates with this generator.

    python3 TrainingData/generate_dataset.py
"""

import csv
import random
from pathlib import Path

random.seed(42)

# Labels must match ExpenseCategory raw values in DomainModels.swift.
VOCAB = {
    "Food & Drink": {
        "items": [
            "dinner", "lunch", "breakfast", "brunch", "coffee", "lattes", "pizza", "sushi", "tacos",
            "burgers", "ramen", "pho", "curry", "kebabs", "bbq", "drinks", "beers", "cocktails", "wine",
            "happy hour", "dessert", "ice cream", "bagels", "dim sum", "noodles", "pasta", "steak",
            "takeout", "delivery", "food truck", "snacks at the bar", "boba", "smoothies", "donuts",
            "fish and chips", "paella", "tapas", "pastries", "croissants", "late night food", "pub quiz drinks",
            "birthday dinner", "team lunch", "street food", "falafel", "poke bowls", "shawarma", "bento",
        ],
        "merchants": [
            "Starbucks", "Chipotle", "McDonald's", "Nando's", "Domino's", "Pret", "Shake Shack",
            "Dunkin", "Subway", "KFC", "Taco Bell", "Five Guys", "In-N-Out", "Panera", "Time Out Market",
            "the Italian place", "the Thai restaurant", "the pub", "the cafe", "the diner", "the brewery",
            "Uber Eats", "DoorDash", "Deliveroo", "Grubhub", "the sushi bar", "the rooftop bar",
        ],
    },
    "Transport": {
        "items": [
            "uber", "lyft", "taxi", "cab", "train tickets", "bus fare", "metro cards", "subway", "flight",
            "flights", "plane tickets", "airport shuttle", "car rental", "rental car", "gas", "fuel", "petrol",
            "parking", "tolls", "ferry", "bike rental", "scooters", "tram", "toll road", "highway tolls",
            "airport transfer", "baggage fees", "rideshare", "diesel", "ev charging", "parking garage",
            "valet", "boat ride", "night bus", "commuter rail", "car wash", "oil change", "tram passes",
        ],
        "merchants": [
            "Uber", "Lyft", "Bolt", "Amtrak", "Delta", "United", "Ryanair", "easyJet", "Southwest",
            "Hertz", "Avis", "Enterprise", "Shell", "Chevron", "BP", "Exxon", "Greyhound", "FlixBus",
            "Eurostar", "Trainline", "Lime", "the airport", "the station",
        ],
    },
    "Lodging": {
        "items": [
            "hotel", "airbnb", "hostel", "motel", "resort", "cabin", "villa", "apartment rental", "guesthouse",
            "b&b", "bed and breakfast", "campsite", "beach house", "lake house", "chalet", "lodge", "inn",
            "room", "suite", "accommodation", "stay", "booking", "vacation rental", "glamping", "cottage",
            "extra night", "late checkout", "resort fee", "cleaning fee", "security deposit", "rent",
        ],
        "merchants": [
            "Airbnb", "Booking.com", "Expedia", "Marriott", "Hilton", "Hyatt", "Holiday Inn", "VRBO",
            "Hostelworld", "Hotels.com", "the hotel", "the hostel", "Premier Inn", "Ibis",
        ],
    },
    "Entertainment": {
        "items": [
            "movie tickets", "cinema", "concert", "concert tickets", "show", "theatre", "musical", "comedy club",
            "museum", "museum tickets", "zoo", "aquarium", "bowling", "karaoke", "escape room", "mini golf",
            "arcade", "theme park", "festival passes", "gig", "club entry", "cover charge", "game tickets",
            "football tickets", "basketball game", "baseball tickets", "go karts", "laser tag", "spa day",
            "boat tour", "walking tour", "wine tasting", "ski passes", "lift tickets", "surf lessons",
            "netflix", "spotify", "disney plus", "video game", "board games", "pool table", "paintball",
        ],
        "merchants": [
            "AMC", "Regal", "Cineworld", "Ticketmaster", "Live Nation", "StubHub", "Eventbrite",
            "Disneyland", "Six Flags", "Universal Studios", "the stadium", "the arena", "the museum",
        ],
    },
    "Utilities": {
        "items": [
            "electricity", "electric bill", "power bill", "gas bill", "water bill", "internet", "wifi",
            "broadband", "phone bill", "mobile plan", "trash collection", "sewage", "heating", "utilities",
            "energy bill", "council tax", "hoa fees", "cable", "streaming bundle for the house",
            "fiber internet", "router rental", "water and sewer", "heating oil", "recycling service",
        ],
        "merchants": [
            "Comcast", "Xfinity", "AT&T", "Verizon", "T-Mobile", "Spectrum", "PG&E", "ConEd", "Duke Energy",
            "British Gas", "Octopus Energy", "Thames Water", "Vodafone", "BT",
        ],
    },
    "Groceries": {
        "items": [
            "groceries", "grocery run", "food shopping", "supermarket", "milk and eggs", "bread", "fruit",
            "vegetables", "produce", "meat", "chicken", "rice", "pasta and sauce", "cereal", "snacks for the house",
            "cleaning supplies", "toilet paper", "paper towels", "dish soap", "laundry detergent",
            "coffee beans", "bottled water", "drinks for the fridge", "bbq supplies", "breakfast stuff",
            "farmers market", "household supplies", "pantry restock", "frozen food", "cheese", "olive oil",
        ],
        "merchants": [
            "Costco", "Trader Joe's", "Whole Foods", "Walmart", "Target", "Kroger", "Safeway", "Aldi",
            "Lidl", "Tesco", "Sainsbury's", "Publix", "Wegmans", "Instacart", "the corner shop",
            "the supermarket", "Pingo Doce", "Carrefour",
        ],
    },
    "Other": {
        "items": [
            "gift", "birthday present", "wedding gift", "flowers", "card", "haircut", "laundry", "dry cleaning",
            "pharmacy", "medicine", "doctor copay", "vet bill", "pet food", "dog walker", "phone case",
            "charger", "office supplies", "printer ink", "stationery", "furniture", "ikea", "lamp", "tools",
            "donation", "charity", "insurance", "visa fees", "passport photos", "postage", "shipping",
            "souvenirs", "sunscreen", "umbrella", "luggage", "storage unit", "moving truck", "repairs",
            "locksmith", "plumber", "decorations", "party supplies", "balloons", "cake order", "gym membership",
            "yoga class", "textbooks", "course fee", "atm fee", "bank fee", "misc", "random stuff", "tip jar",
        ],
        "merchants": [
            "Amazon", "IKEA", "Home Depot", "CVS", "Walgreens", "Boots", "Etsy", "eBay", "Best Buy",
            "the post office", "the pharmacy", "the hardware store", "Apple Store",
        ],
    },
}


# Shared by every category so filler words ("for the group", "tonight") carry
# no signal; only the items and merchants tell categories apart.
TEMPLATES = [
    "{item}", "{item}", "{item}", "{item} at {merchant}", "{merchant}", "{merchant} {item}",
    "{item} for everyone", "{item} for the group", "{item} tonight", "{item} on saturday",
    "{item} for the trip", "{item} split", "{item} for the flat", "{item} this week",
    "{item} with friends", "our {item}", "{item} from {merchant}", "{merchant} order",
]


def variations(title: str) -> list[str]:
    """How people actually type: casing, a trailing amount or emoji, small typos."""
    out = {title, title.lower(), title.title(), title.capitalize()}
    if random.random() < 0.3:
        out.add(f"{title} ${random.randint(5, 400)}")
    if random.random() < 0.15 and len(title) > 5:
        i = random.randrange(1, len(title) - 1)
        out.add(title[:i] + title[i + 1:])  # dropped letter
    return sorted(out)


def build() -> list[tuple[str, str]]:
    rows = set()
    for label, vocab in VOCAB.items():
        titles = set()
        for template in TEMPLATES:
            for _ in range(25):
                item = random.choice(vocab["items"])
                merchant = random.choice(vocab["merchants"])
                titles.add(template.format(item=item, merchant=merchant).strip())
        for title in titles:
            for variant in variations(title):
                rows.add((variant, label))
    rows = sorted(rows)
    random.shuffle(rows)
    return rows


if __name__ == "__main__":
    rows = build()
    path = Path(__file__).with_name("expense_categories.csv")
    with path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["text", "label"])
        writer.writerows(rows)
    counts = {}
    for _, label in rows:
        counts[label] = counts.get(label, 0) + 1
    print(f"wrote {len(rows)} rows to {path.name}: {counts}")
