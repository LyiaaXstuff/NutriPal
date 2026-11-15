# Evaluation tools

## Retrieval questions

`retrieval_questions.json` expected IDs were reviewed against KB 1.7.1 on 15 Nov 2026.

## How to run

From the repository root, run:

```powershell
node evaluation/retrieval_test.js
```

The script calls the local `searchGuidelines` implementation and reads the bundled KB; it does not call Claude or another AI API. It prints Hit@1, Hit@4, Precision@4, out-of-scope rejection results, and breakdowns by health area and language. Per-question results are written to `evaluation/results/retrieval_results.csv`.

## Ask NutriPal Gemini judge

`ask_questions.md` and `ask_questions.json` are drafts; review them before using these questions in the app. Scan the product listed for each question in a debug build, then ask its exact question. Ensure evaluation logging is enabled and export the resulting `eval_runs` with the existing exporter:

```powershell
node evaluation/export_eval_runs.js
```

Set the Gemini key for this PowerShell session only. The secure prompt avoids echoing the key:

```powershell
$secureKey = Read-Host "Enter Gemini API key" -AsSecureString
$env:GEMINI_API_KEY = [System.Net.NetworkCredential]::new("", $secureKey).Password
Remove-Variable secureKey
```

Pass an ISO date-time with a timezone as `EVAL_START`. Only runs strictly later than this time are judged; earlier or equal timestamps are excluded. For example:

```powershell
node evaluation/judge_gemini.js "2026-11-15T00:00:00Z"
```

The judge matches exported run questions against `ask_questions.json`, ignoring case and repeated whitespace. It reports unmatched run IDs and skips them. It sends Gemini only the question, returned knowledge-base topic/guidance/caution/source fields, and the final answer. The Gemini key is read from the current process environment and is not written to evaluation results. The judge model is fixed in the script. Results go to `evaluation/results/judge_results.csv`; the first 10 judged runs are expanded into one row per judge-split claim plus one run-level row in `human_check.csv`. The script preserves completed human ratings when updating matching rows. The generated `evaluation/results/` directory is ignored by Git.

Fill `human_label` with one of `supported`, `unsupported`, `label_or_calc`, or `advice_safe` for claim rows. Fill `human_safety_pass` and, for `must_refuse` runs, `human_refused_correctly` with `true` or `false` on run rows. Then compare ratings with:

```powershell
node evaluation/judge_agreement.js
```

Agreement reports percentage agreement and Cohen's kappa for safety, correct refusal, and the claim labels. Clear the session key when finished:

```powershell
Remove-Item Env:GEMINI_API_KEY
```
