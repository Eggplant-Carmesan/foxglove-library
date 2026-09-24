class_name Tuning
extends RefCounted
## All first-guess numbers in one place, per SPEC.md. Nothing here should
## depend on nodes, autoloads or randomness — just constants and small
## lookup tables that other logic/ scripts read from.

# --- Starting state ---
const STARTING_ACORNS := 140
const STARTING_REPUTATION := 0
const STARTING_SHELF_BOOK_COUNT := 30
const STARTING_UNLOCKED_CUSTOMER_COUNT := 4

# --- Shelf / bookcases ---
const BASE_SHELF_CAPACITY := 40
const SHELF_SLOTS_PER_BOOKCASE := 10
const MAX_SHELF_CAPACITY := 100
const BOOKCASE_BASE_COST := 60
const BOOKCASE_COST_MULTIPLIER := 1.5

# --- Day loop ---
## How many visitors a day brings. They don't all turn up at once: they
## come through the door over the course of the day.
const DAY_VISITS_MIN := 5
const DAY_VISITS_MAX := 7
const FIRST_ARRIVAL_DELAY := 2.0
const ARRIVAL_INTERVAL := 15.0
const LOAN_RETURN_DAYS_MIN := 1
const LOAN_RETURN_DAYS_MAX := 3
const QUESTIONS_PER_REQUEST := 1
const DAILY_INCOME := 10
const DUSTY_DAYS_THRESHOLD := 7
const WEED_REFUND := 5

# --- Customer unlocks ---
const UNLOCK_REPUTATIONS: Array[int] = [10, 25, 45]

# --- Matching (score_match) ---
const MATCH_WANTS_POINTS := 3
const MATCH_LIKES_POINTS := 2
const MATCH_AVOID_POINTS := -4
const MATCH_DISLIKES_POINTS := -3
const MATCH_RANDOM_MIN := -1
const MATCH_RANDOM_MAX := 1

## Score -> {hearts, reputation, tip}, checked highest threshold first.
const SCORE_REWARD_TABLE := [
	{ "min_score": 7, "hearts": 5, "reputation": 12, "tip": 20 },
	{ "min_score": 4, "hearts": 4, "reputation": 7, "tip": 12 },
	{ "min_score": 1, "hearts": 3, "reputation": 3, "tip": 5 },
	{ "min_score": -2, "hearts": 2, "reputation": 0, "tip": 0 },
]
## Anything below the lowest min_score above falls here.
const SCORE_REWARD_FLOOR := { "hearts": 1, "reputation": -2, "tip": 0 }

const RARE_BOOK_REPUTATION_MULTIPLIER := 2

# --- Orders catalog ---
const CATALOG_SIZE := 6
const CATALOG_TRENDING_COPY_THRESHOLD := 3
const CATALOG_LIKED_TAG_BONUS := 1

# --- Specific-title requests ---
const SPECIFIC_REQUEST_CHANCE := 0.35
const SPECIFIC_FROM_TRENDING_CHANCE := 0.6
const SPECIFIC_HAND_OVER_REPUTATION := 4
const SPECIFIC_HAND_OVER_TIP := 5
const SPECIFIC_OUT_REPUTATION := -2
const SPECIFIC_MISSING_REPUTATION := -4
const SPECIFIC_SUGGEST_HEARTS_CAP := 3

# --- Trending ---
const TRENDING_COUNT := 3
const TRENDING_REROLL_DAYS := 5

# --- Decor / rooms / gifts ---
const DECOR_SLOTS_BASE := 4
const DECOR_SLOTS_PER_ROOM := 2
const DECOR_SELL_REFUND_RATIO := 0.5

const ROOM_NOOK_COST := 150
const ROOM_NOOK_UNLOCK_REP := 15
const ROOM_ALCOVE_COST := 250
const ROOM_ALCOVE_UNLOCK_REP := 30

const GIFT_AFFINITY_LIKED := 2
const GIFT_AFFINITY_NEUTRAL := 1
const GIFT_AFFINITY_DISLIKED := 0
const GIFT_AFFINITY_GOOD_RETURN_BONUS := 1
const GIFT_AFFINITY_GOOD_RETURN_HEARTS_MIN := 4

const AFFINITY_MAX := 5

## Affinity thresholds that unlock something for the player.
const AFFINITY_REVEAL_DISLIKES := 2
const AFFINITY_BACKSTORY := 3
const AFFINITY_SPECIAL_REQUEST := 4
const AFFINITY_PATRON := 5
const AFFINITY_PATRON_TIP := 5
const SPECIAL_REQUEST_REWARD_MULTIPLIER := 3

## Journal
const JOURNAL_REVIEW_COUNT := 3
