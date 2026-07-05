# Impulse iOS SDK

Journey analytics for iOS. Instead of a flat event stream, Impulse records
**session-scoped user journeys**: the ordered path a user takes through your
app (screen A → screen B → scrolled 75% → left), the **dwell time** on each
screen, and the declared **outcome** (success / failure) of named flows.

The web dashboard aggregates these journeys to show where users succeed,
fail, or abandon — and customer support can open a user id and replay the
full flow of any session.

- iOS 15+, Swift 6, UIKit and SwiftUI
- Manual tracking by default; UIKit auto-capture (screens, taps, scroll
  depth) is strictly opt-in
- Offline-safe: steps are persisted to disk and uploaded in batches

## Installation

Add the package in Xcode (**File → Add Package Dependencies…**) or in
`Package.swift`:

```swift
.package(url: "https://github.com/your-org/impulse-ios-sdk", from: "0.2.0")
```

## Quick start

```swift
import ImpulseSDK

// In application(_:didFinishLaunchingWithOptions:) or your App init:
ImpulseSDK.configure(ImpulseConfiguration(
    apiKey: "YOUR_API_KEY",
    endpoint: URL(string: "https://ingest.yourdomain.com")!
))

// Associate journeys with your user id (for support lookups):
ImpulseSDK.identify(userId: "user-42")
```

By default nothing is captured automatically — you track journey steps
manually.

## Manual tracking (default)

```swift
// Screens — dwell time is measured between opened and closed:
ImpulseSDK.trackScreenOpened("ProductDetail", properties: ["product_id": "sku-1"])
ImpulseSDK.trackScreenClosed("ProductDetail")

// Actions:
ImpulseSDK.trackAction("add_to_cart", properties: ["product_id": "sku-1"])

// Scroll depth (0...1):
ImpulseSDK.trackScroll(depth: 0.75)

// Custom steps:
ImpulseSDK.track("coupon_applied", properties: ["code": "SUMMER"])
```

### SwiftUI

```swift
struct ProductDetailView: View {
    var body: some View {
        content
            .impulseTrackScreen("ProductDetail")
    }
}
```

## Journey outcomes

Journeys are how the dashboard separates successful flows from failed ones.
Declare the result of a named flow when you know it:

```swift
// Order placed:
ImpulseSDK.completeJourney("checkout", outcome: .success)

// Payment declined:
ImpulseSDK.completeJourney("checkout", outcome: .failure,
                           properties: ["reason": "card_declined"])
```

Sessions that contain steps of a flow but never receive an outcome are
treated as **abandoned** by the dashboard (e.g. entered checkout, scrolled,
left). Aggregating many sessions yields the common success path, the common
failure path, and the screens where users drop off — with per-screen dwell
time analytics.

## Auto-capture (opt-in, UIKit)

Enable exactly the signals you want:

```swift
ImpulseSDK.configure(ImpulseConfiguration(
    apiKey: "YOUR_API_KEY",
    endpoint: URL(string: "https://ingest.yourdomain.com")!,
    autoCapture: .all   // or [.screens], [.screens, .scrolls], …
))
```

| Option | Captures |
|---|---|
| `.screens` | Screen opens/closes via `viewDidAppear`/`viewDidDisappear`, with dwell time |
| `.actions` | Taps and value changes on `UIButton`, `UISwitch`, `UISlider`, `UISegmentedControl`, `UIBarButtonItem` |
| `.scrolls` | Scroll-depth milestones (25/50/75/100 %) on any `UIScrollView` |

Notes:

- System and container controllers (`UINavigationController`, tab bars,
  UIKit internals) are filtered out automatically.
- Give screens stable, readable names by conforming to `ImpulseTrackable`:

  ```swift
  class ProductDetailViewController: UIViewController, ImpulseTrackable {
      let screenName = "ProductDetail"
  }
  ```

- Set `autoCaptureOnlyTrackableScreens: true` to auto-capture only
  conforming controllers.
- Text fields and text views are never captured.

## Sessions

A journey is scoped to a session. Sessions rotate automatically after
`sessionTimeout` (default 30 min) of inactivity — typically while the app is
backgrounded. You can also manage them explicitly:

```swift
ImpulseSDK.sessionId          // current session id
ImpulseSDK.startNewSession()  // force a fresh journey
ImpulseSDK.reset()            // logout: clears user id, rotates anonymous id
ImpulseSDK.flush()            // upload queued steps now
ImpulseSDK.setEnabled(false)  // pause all tracking
```

## Configuration reference

```swift
ImpulseConfiguration(
    apiKey: String,
    endpoint: URL,                          // batches POSTed to {endpoint}/v1/journeys
    autoCapture: AutoCaptureOptions = [],   // off by default
    autoCaptureOnlyTrackableScreens: Bool = false,
    sessionTimeout: TimeInterval = 1800,    // seconds of inactivity
    flushInterval: TimeInterval = 30,       // upload cadence
    flushBatchSize: Int = 50,               // steps per request
    maxQueuedSteps: Int = 10_000,           // local queue cap
    logLevel: LogLevel = .warning
)
```

## Ingestion payload

Steps are uploaded as batches to `POST {endpoint}/v1/journeys` with headers
`X-Impulse-Api-Key` and `X-Impulse-SDK-Version`. Timestamps are epoch
milliseconds.

```json
{
  "batch_id": "…",
  "sent_at": 1783626000000,
  "sdk_version": "0.2.0",
  "platform": "ios",
  "anonymous_id": "…",
  "user_id": "user-42",
  "device": {
    "model": "iPhone17,3",
    "system_name": "iOS",
    "system_version": "19.2",
    "app_version": "3.1.0",
    "app_build": "412",
    "bundle_id": "com.example.app",
    "locale": "en_US"
  },
  "steps": [
    { "id": "…", "session_id": "S", "sequence": 1, "type": "session_start", "name": "session", "timestamp": 1783626000000, "properties": {} },
    { "id": "A1", "session_id": "S", "sequence": 2, "type": "screen_view", "name": "ProductDetail", "timestamp": 1783626001000, "properties": {} },
    { "id": "…", "session_id": "S", "sequence": 3, "type": "scroll", "name": "scroll", "timestamp": 1783626004000, "properties": { "depth": 0.75, "screen": "ProductDetail" } },
    { "id": "…", "session_id": "S", "sequence": 4, "type": "screen_exit", "name": "ProductDetail", "timestamp": 1783626009000, "screen_instance_id": "A1", "dwell_ms": 8000, "properties": {} },
    { "id": "…", "session_id": "S", "sequence": 5, "type": "outcome", "name": "checkout", "timestamp": 1783626010000, "properties": { "outcome": "failure", "reason": "card_declined" } }
  ]
}
```

Step semantics for the dashboard:

- `sequence` orders steps within a session; `session_id` groups a journey.
- Every screen visit is a `screen_view` plus a later `screen_exit` whose
  `screen_instance_id` references the view step and carries `dwell_ms`.
  A `screen_view` with no matching exit means the visit was cut short
  (app killed / crashed) — itself a useful signal.
- `outcome` steps carry `"outcome": "success" | "failure"`; a flow with
  steps but no outcome in the session is abandoned.
- `session_end` includes `duration_ms`; its absence means the session is
  still open or ended with the app.

Delivery is at-least-once: steps are removed from the device only after a
2xx response, so the backend should deduplicate by step `id`.

## Reliability & privacy

- Steps are persisted to disk immediately and survive app kills; uploads
  retry on transient failures and flush when the app backgrounds.
- No text input, view hierarchies, or screenshots are ever collected.
  Auto-captured action names come from control titles/accessibility labels.
