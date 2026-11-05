# Azure nutrition scanning

Analyze uses Azure Document Intelligence's `prebuilt-layout` model when the app
is started with `NUTRIPAL_SCAN_API_URL`. It calls the NutriPal Python backend;
the Azure key stays on that server. Without this option the app uses on-device
ML Kit. An online failure offers an explicit on-device retry.

Azure table indexes determine nutrient row/column ownership. All detected
nutrient names are retained; there is no fixed nutrient list for extraction or
portion calculations. The adapter retains separate per-serving, per-100-g,
per-100-ml and percentage columns. Missing cells never shift later values left.

## 1. Configure Azure (once)

Create a **Document Intelligence** resource in the [Azure portal](https://portal.azure.com).
Copy its endpoint and key from **Keys and Endpoint**. An Azure subscription and
an available resource quota are required; check the selected tier's billing.
This integration uses the GA REST API `2024-11-30`.

Copy `backend/.env.example` to `backend/.env`, then fill in your endpoint and key:

```dotenv
AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT=https://YOUR-RESOURCE.cognitiveservices.azure.com
AZURE_DOCUMENT_INTELLIGENCE_KEY=your-resource-key
```

The endpoint is the resource's origin, without `/documentintelligence` or a model
path. Keep the key in `backend/.env` or server environment variables. This file
is ignored by Git. Do not place the key in Dart, a Flutter `--dart-define`, or a
committed file.

## 2. Start the backend

Use Python 3.11 or newer. In PowerShell, from the repository root:

```powershell
py -m venv backend/.venv
backend/.venv/Scripts/python -m pip install -r backend/requirements.txt
backend/.venv/Scripts/python -m uvicorn backend.app:app --env-file backend/.env --host 127.0.0.1 --port 8000
```

On macOS/Linux use `python3` for creating the environment and
`backend/.venv/bin/python` for the remaining commands.

Open <http://127.0.0.1:8000/health>. It should return
`{"status":"ok","azure_configured":true}`. This checks configuration presence;
the first Analyze request verifies whether Azure accepts the key/resource.
Leave this terminal running.

## 3. Run Flutter on Android

Open a second terminal in the repository root:

```powershell
flutter pub get --enforce-lockfile
flutter devices
```

For the Android emulator:

```powershell
flutter run --dart-define=NUTRIPAL_SCAN_API_URL=http://10.0.2.2:8000
```

For an Android phone connected by USB, enable USB debugging and accept its
debugging prompt. Forward the port with Android SDK platform-tools:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=NUTRIPAL_SCAN_API_URL=http://127.0.0.1:8000
```

If several devices are attached, add `-d DEVICE_ID` to Flutter commands and
`-s DEVICE_ID` immediately after `adb`. Reapply `adb reverse` after reconnecting.
Restart `flutter run` after changing `--dart-define`; hot reload does not change
the backend address. HTTP is permitted in Android **debug** builds for local
development. Release builds must use a deployed HTTPS endpoint.

For iOS, use a reachable HTTPS backend and the normal native camera/ML Kit
requirements. Chrome and desktop platforms do not support this app's native
camera/OCR flow.

## 4. Review and calculate

Open **Scan**, photograph the full nutrition table, and tap **Analyse label**.
The preview explains that the photo is sent to Azure. The review identifies
the extraction source and preserves the original table order.

Compare the table, headings and serving size with the photo. In **Calculate
your portion**, choose a source column, enter your portion and unit, tick the
confirmation, and calculate. Arbitrary nutrients keep their units. Energy cells
can contain both kJ and kcal. Missing, merged, conflicting, low-confidence or
unitless cells and printed limits (`<`, `>`) are excluded and listed explicitly.
Percent daily values are not treated as nutrient amounts. Grams and millilitres
are never interchanged. A confidently read, compatible serving size is required
to convert between weight/volume and servings.

Other features can call `NutritionPortionCalculator.calculate(...)` and consume
the ordered `NutritionPortionResult.nutrients` (`rowId`, name and quantities).
`excludedNutrients` identifies omissions; they must not be treated as zero.
The existing `perServing`/`per100` projections remain available for legacy code,
but dynamic rows are the source of truth. Calculated values are estimates based
on label rounding, not laboratory measurements.

## Checks and practical limits

```powershell
flutter analyze --no-pub
flutter test --no-pub
backend/.venv/Scripts/python -m unittest discover -s backend/tests -v
```

To test the real Flutter-to-Python HTTP boundary locally with a **synthetic Azure
response**, run `python -m uvicorn backend.tests.mock_server:app --port 8769`.
Then in another PowerShell terminal:

```powershell
$env:NUTRIPAL_TEST_API_URL="http://127.0.0.1:8769"
flutter test --no-pub test/azure_backend_http_test.dart
Remove-Item Env:NUTRIPAL_TEST_API_URL
```

Fixtures and mocked cloud responses verify mapping and arithmetic, not Azure's
recognition accuracy. No Azure resource credentials or real label photos were
available during implementation. Validate on an Android/iOS device with your
actual labels before using the results for decisions. Word confidence is a
filter, not a guarantee that a digit is correct; user comparison is still needed.

Crop to one nutrition table. Multiple plausible tables require a rescan. Unclear
headings and absent word-confidence evidence remain review-only. JPEG, PNG and
WebP uploads up to 12 MB / 30 megapixels are accepted. Unsupported gallery
formats should be converted to JPEG. The backend corrects EXIF orientation and
does not persist photos/results. Clear focus, readable print and minimal glare
are still needed; neither extraction engine can recover invisible text.

The backend defaults to localhost for development. Before public deployment,
place it behind HTTPS, authenticated access, and per-user quotas. The current
prototype login is not a backend authentication system. Configure your hosting
logs to avoid retaining uploaded photos or extracted personal information.

API references: [Analyze](https://learn.microsoft.com/en-us/rest/api/aiservices/document-models/analyze-document?view=rest-aiservices-v4.0%20(2024-11-30)),
[result structure](https://learn.microsoft.com/en-us/rest/api/aiservices/document-models/get-analyze-result?view=rest-aiservices-v4.0%20(2024-11-30)).
