# NutriPal AI label check — setup

NutriPal reads nutrition tables on the phone first. When that reading looks
unreliable (missing rows or headings, values without units, automatic
corrections, or per-serving values that don't match the serving size), it
sends a crop of **only the nutrition table** to the `extractNutritionLabel`
Cloud Function. The function asks Claude to read the table, and the app then
checks every number against the phone's own OCR before using it.

Until the steps below are done, the app keeps working with on-device reading
only.

The AI check is also used for labels printed partly in a script the phone's
OCR cannot read, such as Arabic, Thai or Tamil (ML Kit only reads Latin,
Chinese, Devanagari, Japanese and Korean). Claude reads those names in their
own script, and gives the English name for rows printed only in that script.

---

## 1. Accounts (one-off)

1. **Firebase project**: <https://console.firebase.google.com> → *Add project*
   (e.g. `nutripal-fyp`).
2. **Blaze plan**: Cloud Functions are not available on the free Spark plan.
   In the console: *Upgrade* → *Blaze*. Blaze still includes the free monthly
   quota (2 million function calls), which an FYP will not exceed.
   **Set a budget alert** (Google Cloud console → *Billing* → *Budgets & alerts*),
   e.g. USD 1, so you are emailed before anything is charged.
3. **Anthropic API key**: <https://platform.claude.com> → *API keys* →
   *Create key*. Add a small amount of credit and set a monthly spend limit.
   Keep the key private; it only goes into Firebase Secret Manager (step 3 below).

## 2. Tools (one-off, PowerShell)

```powershell
# Node.js 22 LTS from https://nodejs.org, then:
npm install -g firebase-tools
firebase login

dart pub global activate flutterfire_cli
```

## 3. Deploy the function

From the `nutripal` folder:

```powershell
firebase use --add            # pick your Firebase project, alias "default"

cd functions
npm install
npm test                      # 7 tests, no API key needed

firebase functions:secrets:set ANTHROPIC_API_KEY   # paste the key when asked
firebase deploy --only functions
cd ..
```

The function runs in `asia-southeast1` (Singapore), closest to Malaysia.

## 4. Connect the app

From the `nutripal` folder:

```powershell
flutterfire configure         # pick the same project; tick android (and ios)
flutter pub get
flutter test                  # parser + assessor tests
flutter run
```

`flutterfire configure` creates `android/app/google-services.json` and
`lib/firebase_options.dart`. `main.dart` calls `Firebase.initializeApp()`,
which picks up `google-services.json` on Android.

## 5. Check it works

Scan a label in a debug build and watch the console:

```
[NutriPal extraction] on-device: 12 rows, problems: [...]
[NutriPal extraction] AI: 12 rows, confirmed 23/24, inconsistent [], accepted true
```

The review screen says whether the table was read on the phone or by NutriPal
AI, and lists any values to double-check.

Function logs: `firebase functions:log` (shows rows found, tokens used, time).

---

## Options

| Setting | Where | Default | Notes |
|---|---|---|---|
| `ANTHROPIC_MODEL` | `functions/.env` | `claude-haiku-5-5` | `claude-sonnet-5-5` is stronger and costs more |
| `REQUIRE_AUTH` | `functions/.env` | `false` | Set `true` once the app signs users in with Firebase Auth, so only NutriPal users can spend your credits |
| `enforceAppCheck` | `functions/index.js` | `false` | Turn on after adding Firebase App Check to the app |
| `alwaysUseAi` | `NutritionExtractionService` | `false` | Set `true` to send every scan to the AI, useful for comparing on-device vs AI accuracy in your evaluation |

Example `functions/.env`:

```
ANTHROPIC_MODEL=claude-haiku-5-5
REQUIRE_AUTH=false
```

## Cost

The phone sends a JPEG of the table only (at most 2000 px on the long side). A
typical table is about 2–4 thousand image tokens plus up to about a thousand
output tokens per AI check. Scans that read cleanly on the phone never call the
AI. See current prices at <https://platform.claude.com/docs/en/about-claude/pricing>.

## Privacy

Only the cropped nutrition table is sent, never the whole photo, unless the
phone could not find the table at all. No personal or health-profile data goes
to the AI for this step.
