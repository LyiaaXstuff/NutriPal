import base64
from io import BytesIO
import json
from pathlib import Path
import unittest

from fastapi.testclient import TestClient
import httpx
from PIL import Image

from backend.app import create_app, normalized_photo, Settings, MAX_UPLOAD_BYTES

RESULT = json.loads((Path(__file__).parents[2] / 'test/fixtures/azure_layout.json').read_text())
ENDPOINT = 'https://unit-test.cognitiveservices.azure.com'
OPERATION = ENDPOINT + '/documentintelligence/documentModels/prebuilt-layout/analyzeResults/test?api-version=2024-11-30'


def image_bytes():
    output = BytesIO()
    Image.new('RGB', (40, 20), 'white').save(output, format='JPEG')
    return output.getvalue()


class BackendTests(unittest.TestCase):
    def client(self, handler, **overrides):
        settings = Settings(endpoint=ENDPOINT, key='unit-test-key', poll_seconds=0, **overrides)
        return TestClient(create_app(settings, transport=httpx.MockTransport(handler)))

    def test_full_upload_submit_poll_flow_and_server_only_key(self):
        calls = []

        def azure(request):
            calls.append(request.method)
            self.assertEqual(request.headers['Ocp-Apim-Subscription-Key'], 'unit-test-key')
            if request.method == 'POST':
                self.assertEqual(request.url.params['stringIndexType'], 'unicodeCodePoint')
                self.assertEqual(request.url.params['pages'], '1')
                self.assertEqual(request.url.params['api-version'], '2024-11-30')
                photo = base64.b64decode(json.loads(request.content)['base64Source'])
                self.assertEqual(Image.open(BytesIO(photo)).size, (40, 20))
                return httpx.Response(202, headers={'Operation-Location': OPERATION})
            if len(calls) == 2:
                return httpx.Response(200, json={'status': 'running'})
            return httpx.Response(200, json={'status': 'succeeded', 'analyzeResult': RESULT})

        with self.client(azure) as client:
            response = client.post('/api/v1/nutrition/analyze', content=image_bytes(),
                                   headers={'Content-Type': 'application/octet-stream'})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json(), {'provider': 'azure-layout', 'analyzeResult': RESULT})
            self.assertNotIn('unit-test-key', response.text)
            self.assertEqual(calls, ['POST', 'GET', 'GET'])

    def test_missing_configuration_reports_not_ready(self):
        with TestClient(create_app(Settings())) as client:
            self.assertFalse(client.get('/health').json()['azure_configured'])
            self.assertEqual(client.post('/api/v1/nutrition/analyze').status_code, 503)

    def test_upload_validation_happens_before_azure(self):
        def no_azure(_):
            self.fail('Invalid upload reached Azure')
        with self.client(no_azure) as client:
            for body, kind, expected in [(b'', 'image/jpeg', 400),
                    (b'bad image', 'image/png', 415),
                    (image_bytes(), 'text/plain', 415),
                    (b'x' * (MAX_UPLOAD_BYTES + 1), 'image/jpeg', 413)]:
                with self.subTest(expected=expected):
                    response = client.post('/api/v1/nutrition/analyze', content=body,
                                           headers={'Content-Type': kind})
                    self.assertEqual(response.status_code, expected)

    def test_normalizes_exif_orientation(self):
        source = Image.new('RGB', (40, 20))
        exif = source.getexif()
        exif[274] = 6
        output = BytesIO()
        source.save(output, format='JPEG', exif=exif)
        normalized = Image.open(BytesIO(normalized_photo(output.getvalue())))
        self.assertEqual(normalized.size, (20, 40))
        self.assertNotIn(274, normalized.getexif())

    def test_does_not_forward_key_to_other_operation_host(self):
        calls = []
        def azure(request):
            calls.append(request)
            return httpx.Response(202, headers={'Operation-Location': 'https://untrusted.example/steal'})
        with self.client(azure) as client:
            response = client.post('/api/v1/nutrition/analyze', content=image_bytes(),
                                   headers={'Content-Type': 'image/jpeg'})
            self.assertEqual(response.status_code, 502)
            self.assertEqual(len(calls), 1)

    def test_upstream_errors_are_redacted_and_typed(self):
        for status in [401, 403, 429, 500]:
            with self.subTest(status=status):
                with self.client(lambda _: httpx.Response(status, text='secret account detail')) as client:
                    response = client.post('/api/v1/nutrition/analyze', content=image_bytes(),
                                           headers={'Content-Type': 'image/jpeg'})
                    self.assertEqual(response.status_code, 503 if status == 429 else 502)
                    self.assertNotIn('secret account detail', response.text)

    def test_failed_and_malformed_operations_are_reported(self):
        for payload in [{'status': 'failed', 'error': {'message': 'private'}},
                        {'status': 'succeeded'}, {'status': 'unknown'}]:
            def azure(request):
                return httpx.Response(202, headers={'Operation-Location': OPERATION}) if request.method == 'POST' else httpx.Response(200, json=payload)
            with self.subTest(payload=payload), self.client(azure) as client:
                response = client.post('/api/v1/nutrition/analyze', content=image_bytes(),
                                       headers={'Content-Type': 'image/jpeg'})
                self.assertEqual(response.status_code, 502)
                self.assertNotIn('private', response.text)

    def test_processing_has_a_deadline(self):
        def azure(request):
            return httpx.Response(202, headers={'Operation-Location': OPERATION}) if request.method == 'POST' else httpx.Response(200, json={'status': 'running'})
        with self.client(azure, timeout_seconds=0.01) as client:
            response = client.post('/api/v1/nutrition/analyze', content=image_bytes(),
                                   headers={'Content-Type': 'image/jpeg'})
            self.assertEqual(response.status_code, 504)


if __name__ == '__main__':
    unittest.main()
