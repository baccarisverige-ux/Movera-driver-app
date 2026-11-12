import json
import os
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import testlab_summary  # noqa: E402

# Made-up values in the shape of a phone number and a code (not real ones).
FAKE_PHONE = '+46000000000'
FAKE_CODE = '0000'


class TestlabSummaryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        device = self.root / 'driver-device' / 'oriole-33-en_US-portrait'
        device.mkdir(parents=True)
        self.logcat = device / 'logcat'
        self.logcat.write_text('\n'.join([
            'I MoveraTL: run-time values handed to the test: 3',
            'I flutter : MOVERA-TL CHECK SIGN-IN PASS test driver reaches Home: Home is open',
            'I flutter : MOVERA-TL CHECK G24 FAIL position sends are taken: sends=0',
            'E AndroidRuntime: FATAL EXCEPTION: main',
            'E AndroidRuntime: java.lang.SecurityException: Neither user nor current process has android.permission.WAKE_LOCK.',
            'I am_instrument: -e movera_tl_phone %s -e movera_tl_code %s' % (FAKE_PHONE, FAKE_CODE),
        ]) + '\n')
        (device / 'test_result_1.xml').write_text(
            '<testsuite><testcase name="staging device checks"><failure>x</failure></testcase></testsuite>')
        (device / 'shot.png').write_bytes(b'\x89PNG\0\0' + FAKE_PHONE.encode())

    def tearDown(self):
        self.tmp.cleanup()

    def test_scrub_removes_values_from_text_files_only(self):
        changed = testlab_summary.scrub(str(self.root), [FAKE_PHONE, FAKE_CODE, '', '12'])
        self.assertEqual(changed, 1)
        text = self.logcat.read_text()
        self.assertNotIn(FAKE_PHONE, text)
        self.assertNotIn(FAKE_CODE, text)
        self.assertIn('[REDACTED]', text)

    def test_summary_reads_logcat_checks_crashes_and_junit(self):
        text = testlab_summary.summary_text(str(self.root))
        self.assertIn('| SIGN-IN  | PASS |', text)
        self.assertIn('| G24  | FAIL |', text)
        self.assertIn('SecurityException', text)
        self.assertIn('failures=1', text)
        self.assertNotIn('MOVERA-TL CHECK', text.split('Crash / error lines')[1])

    def test_summary_json_wins_over_logcat(self):
        (self.root / 'summary.json').write_text(json.dumps([
            {'id': 'G17', 'title': 'SOS numbers', 'outcome': 'pass', 'detail': 'zone=Z001'},
        ]))
        text = testlab_summary.summary_text(str(self.root))
        self.assertIn('| G17 SOS numbers | PASS | zone=Z001 |', text)
        self.assertNotIn('G24', text.split('JUnit')[0])

    def test_nothing_found_says_not_checked(self):
        empty = tempfile.TemporaryDirectory()
        self.addCleanup(empty.cleanup)
        self.assertIn('NOT CHECKED', testlab_summary.summary_text(empty.name))

    def test_skip_line_says_not_checked(self):
        self.logcat.write_text('I flutter : MOVERA-TL SKIP all checks: no test number at run time\n')
        self.assertIn('NOT CHECKED: SKIP all checks', testlab_summary.summary_text(str(self.root)))

    def test_workflow_passes_numbers_only_at_run_time(self):
        workflow = pathlib.Path(__file__).resolve().parents[2] / '.github/workflows/android-test-apk.yml'
        text = workflow.read_text()
        job = text.split('  device-checks:', 1)[1]
        self.assertIn('--type instrumentation', job)
        self.assertIn('--environment-variables', job)
        self.assertIn('::add-mask::', job)
        self.assertIn('testlab_summary.py scrub', job)
        self.assertIn('name: testlab-results', job)
        self.assertIn('--timeout 9m', job)
        # The build lines carry no test number or code.
        build = job.split('flutter build apk --debug', 1)[1].split('mkdir -p out', 1)[0]
        self.assertNotIn('tl/phone', build)
        self.assertNotIn('TL_NUMBERS', build)
        on = text.split('jobs:', 1)[0]
        self.assertNotIn('pull_request', on)
        self.assertNotIn('push:', on)


if __name__ == '__main__':
    unittest.main()
