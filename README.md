# Price Tracker (Flutter)

A phone app that watches product pages and notifies you when an item goes **on sale**
or drops **at or below a price you choose**, comparing the same item across several
stores. Everything runs on the phone: no server or account needed.

- Add a product link and an optional target price
- **Compare stores**: track the same item at several stores; the app uses the lowest price
- **Find on other sites**: searches Amazon and Newegg for the same product, or paste a link from any store
- Android checks prices in the background about every 30 minutes; pull down on the list to check right away
- Phone notifications for alerts (naming the cheapest store), plus an alerts list in the app
- Price-history chart for every item
- A built-in **demo store** with three pretend shops so you can simulate a sale during a presentation

## Setup

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) and an Android
phone or emulator. Run `flutter doctor` to check your install. Android is already
configured (permissions, desugaring for notifications, Cronet for networking).

```bash
flutter pub get
flutter test
flutter run
```

The app asks for notification permission on first launch. Tap **Allow**.

**Building for Windows** additionally needs Windows **Developer Mode** turned on
(Settings → System → For developers), because Flutter plugins need symlink support.

## Demo script (for a presentation)

1. Tap **Track item**, tap the **Wireless Noise-Cancelling Headphones** chip, enter a
   target of `200`, and tap **Start tracking**. It shows $249.99, "Watching".
2. Open the item and tap **Find on other sites**. MegaMart and BargainBay appear; tap
   **Add** on both. **Compare stores** now marks BargainBay ($239.99) as **BEST**.
3. Tap the **storefront icon** on the home screen and set the headphones at **MegaMart**
   to `189.99`, then tap **Set**.
4. Go back and **pull down** on the list. The card turns green ("Below target"), a phone
   notification says the price is at MegaMart, and the bell icon shows a badge.
5. Tap the item to show the store comparison and the price-history chart with the dashed
   target line.

## Project structure

```
lib/
  main.dart                    app start, background-check setup
  theme.dart                   colors, shapes and component styles (light and dark)
  models.dart                  TrackedItem, Offer (one store), PricePoint, AlertEntry (saved as JSON)
  widgets.dart                 item card, status chip, store badge, sparkline chart
  logic/                       pure Dart, no Flutter, easy to unit test
    scraper.dart               finds the price in a page's HTML
    search.dart                reads store search results and matches products
    stores.dart                friendly store names from links
    checker.dart               decides whether to alert
    demo_store.dart            fake store pages for demos
    format.dart                money / time formatting
  services/
    price_service.dart         fetch -> extract -> best store -> decide -> save -> notify
    storage.dart               SharedPreferences storage
    notifier.dart              local notifications
    background.dart            periodic checks with workmanager (Android)
  screens/                     home, add-item sheet, item detail, find-on-other-sites
                               sheet, alerts, demo store
test/                          scraper, search, alert-logic and app tests
```

### How the price is found (`scraper.dart`)

1. **JSON-LD structured data**, which many stores publish for Google Shopping
2. **Meta tags** such as `product:price:amount`
3. **Known store layouts** (Amazon, Newegg) that publish no structured data
4. **HTML**: `itemprop="price"`, `data-price`, or an element whose class contains "price"

### Finding other stores (`search.dart`)

The app reads Amazon's and Newegg's search pages, then keeps results whose titles match
the item: they must share its model number, and accessories ("case for…") and used or
renewed listings are skipped. Matches are suggestions; you choose which to add.

### Alert rules (`checker.dart`)

An item triggers an alert when its best price across stores either:
- is **at or below your target**, or
- is **on sale**: at least 5% below the store's "was" price, or below the highest price
  the app has recorded for it.

It alerts once per deal, alerts again only if the price drops further, and resets when the
deal ends, so you don't get spammed.

## Known limitations (good for a write-up)

- **Big stores block automated requests.** Walmart, Target, eBay and Best Buy usually
  refuse them or load prices with JavaScript, so their links show "Couldn't load the page"
  or "Couldn't find a price". Amazon and Newegg work more often, but can also block for a
  while, especially after many requests. Requests go through Chrome's network stack
  (`cronet_http`) on Android, which helps. The robust fix is a store's official API
  (Best Buy and eBay have free ones) or a shopping-search API.
- **Only Amazon and Newegg are searched automatically.** Any other store can be added by
  pasting its link.
- **Background timing is up to the OS.** Android runs checks roughly every 30 minutes but
  may delay them to save battery. On iOS, background checks need extra Xcode setup, so the
  app checks when opened or refreshed.
- **Web isn't supported** for real stores: browsers block cross-site page downloads (CORS).

## Ideas to extend it

- Share-sheet support: share a product link from the browser straight into the app
- Use a store API (Best Buy / eBay) or a shopping-search API for more reliable search
- A settings screen for check frequency and the minimum sale percentage
- Sync across devices with Firebase
