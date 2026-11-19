# Google Play listing and forms

Everything to paste into Play Console for SpendSheet, written from what the
app does at this commit. Check it again if a feature changes.

## Store listing

**App name** (30 characters at most)

```
SpendSheet
```

**Short description** (80 characters at most)

```
Track spending on your phone. Keep every record in your own Google Sheet.
```

**Full description** (4000 characters at most)

```
SpendSheet is an expense tracker that keeps your records in a Google Sheet in your own Google Drive. There is no SpendSheet server and no SpendSheet account: the app talks only to Google, and the spreadsheet belongs to you.

LOG IN SECONDS
• Add expenses, income, transfers and loans with a large number pad
• Your most-used categories come first, and every category is one tap away
• Works offline; changes sync when you are back online

SEE WHERE THE MONEY GOES
• This month's income, expenses and savings at a glance
• Spending by category, by week, month or year
• Budgets with progress bars and alerts when you get close

KEEP TRACK OF MONEY BETWEEN PEOPLE
• Record money you lent or borrowed, and settle it later
• See who owes you and whom you owe

YOUR DATA, YOUR SPREADSHEET
• Every transaction is a row in your own Google Sheet
• Open it any time to sort, filter, chart or share it your way
• SpendSheet can only reach the files it creates, not the rest of your Drive

GOOGLE WALLET PAYMENTS (OPTIONAL, OFF BY DEFAULT)
Pay with Google Wallet and SpendSheet lists the payment, with the amount, the merchant and a suggested category, ready to add as an expense with one tap. This needs notification access. SpendSheet reads only Google Wallet's notifications, keeps them on your phone, and adds nothing until you tap Add.

PRIVATE BY DESIGN
• Optional App Lock with your fingerprint, face or screen lock
• No ads, no analytics, no tracking
• Light and dark themes

SpendSheet is a personal record keeper. It does not offer loans, move money, or connect to your bank.
```

**Category:** Finance
**Tags:** Budgeting, Personal finance (pick what Play Console offers)
**Contact email:** the address in the privacy policy
**Privacy policy URL:** the public address of `docs/privacy-policy.html`, for
example with GitHub Pages turned on for this repository:
`https://aslammhdms.github.io/SpendApp/privacy-policy.html` (only after
Pages is set to serve the `docs` folder)

### Graphics

| Asset | File | Play requirement |
|---|---|---|
| App icon | `icon-512.png` | 512 × 512 PNG |
| Feature graphic | `feature-graphic.png` | 1024 × 500 |
| Phone screenshots | `screenshots/1-home.png` … `8-dark-home.png` | 2–8 images, 9:16 recommended; these are 1080 × 1920 |

The screenshots use sample data. Upload them in the numbered order.

## App content forms

### Privacy policy
The URL above.

### Ads
No, the app has no ads.

### App access
All functionality needs a Google sign-in. Choose **All or some functionality
is restricted** and give these instructions (no username or password needed):

```
Tap "Sign in with Google" and use any Google account. On the next screen,
tap "Create New SpendSheet"; the app creates a spreadsheet in that
account's Google Drive and opens. Everything can then be tested with that
account. The optional Google Wallet capture is under Settings and needs
notification access and the Google Wallet app.
```

This works only once the Google Cloud **OAuth consent screen** is set to
**In production**. While it is in Testing, only listed test users can sign
in, and the reviewer's sign-in fails.

### Content rating
Questionnaire category: **Utility, productivity, communication, or other**.
No violence, sexual content, profanity, drugs, gambling or user-generated
content shared with other users; no location sharing; no purchases.

### Target audience
18 and over. Not designed for children.

### News app
No.

### Financial features
The app is a **personal finance tracker / budgeting tool**. It does **not**
offer personal loans, credit, banking, payments, money transfers, crypto or
investments. The "Loans" screen only records money a user lent to or
borrowed from people they know, as a reminder; no money moves through the
app.

### Health, government, etc.
No.

### Data safety

Play counts data as **collected** when the app sends it off the phone, even
to the user's own Google account. Answers:

**Does your app collect or share any of the required user data types?** Yes.

**Is all of the user data collected by your app encrypted in transit?** Yes
(all requests go to Google's APIs over HTTPS; cleartext is refused).

**Do you provide a way for users to request that their data is deleted?**
Yes. Records are in the user's own spreadsheet, which they can delete in
Google Drive; the copy on the phone is deleted by uninstalling the app or
clearing its data. Link to section 5 of the privacy policy.

Data types:

| Data type | Collected | Shared | Optional | Purpose |
|---|---|---|---|---|
| Financial info → Purchase history | Yes | No | No (core feature) | App functionality |
| Financial info → Other financial info (accounts, budgets, amounts owed) | Yes | No | No | App functionality |
| Personal info → Name, Email address | No (read from Google sign-in, kept only on the phone) | No | — | — |
| App activity, location, contacts, messages, photos, device IDs | No | No | — | — |

Notes for the reviewer if asked:
- The data is sent only to the user's own Google Sheet through Google's
  APIs; the developer never receives it. Google acts as the service the
  user chose, so this is not "sharing".
- Google Wallet notification text is read and stored only on the phone.
  A payment reaches the spreadsheet only as an ordinary expense, after the
  user taps Add.

### Permissions to explain if Play asks

| Permission | Why |
|---|---|
| Notification access (`BIND_NOTIFICATION_LISTENER_SERVICE`) | Optional Google Wallet capture. Shown with an in-app disclosure and an Agree button before Android's settings screen opens. Only notifications from `com.google.android.apps.walletnfcrel` are read. |
| `POST_NOTIFICATIONS` | Budget alerts. |
| `USE_BIOMETRIC` | Optional App Lock. |
| `RECEIVE_BOOT_COMPLETED` | Keeps scheduled notifications after a restart (from the notifications plugin). |

## Before the first upload

1. Create `android/key.properties` and the release key (see "Building for
   Production" in the main README).
2. `flutter build appbundle`
3. In Google Cloud, set the OAuth consent screen to **In production**. The
   app only asks for `drive.file`, which needs no Google review.
4. Upload to **Internal testing** first; copy the **App signing key**
   SHA-1 from **App integrity** into a new Android OAuth client; install
   from the Play testing link and check that sign-in works.
5. Personal developer accounts: run a **Closed test** with at least 12
   testers for 14 days in a row, then apply for production.
