"""Local integration-test server. All Azure responses are synthetic fixtures.

python -m uvicorn backend.tests.mock_server:app --port 8769
"""
import json
from pathlib import Path

import httpx

from backend.app import create_app, Settings

_result = json.loads((Path(__file__).parents[2] / 'test/fixtures/azure_layout.json').read_text())
_endpoint = 'https://unit-test.cognitiveservices.azure.com'


def azure(request):
    if request.method == 'POST':
        return httpx.Response(202, headers={'Operation-Location':
            _endpoint + '/documentintelligence/documentModels/prebuilt-layout/analyzeResults/mock'})
    return httpx.Response(200, json={'status': 'succeeded', 'analyzeResult': _result})


app = create_app(Settings(endpoint=_endpoint, key='local-test-only', poll_seconds=0),
                 transport=httpx.MockTransport(azure))
